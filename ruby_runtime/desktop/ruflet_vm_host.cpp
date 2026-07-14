#include "ruflet_vm_host.h"

#include <mruby.h>
#include <mruby/array.h>
#include <mruby/compile.h>
#include <mruby/irep.h>
#include <mruby/string.h>
#include <mruby/variable.h>

#include <atomic>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include "vm_bootstrap.h"

namespace {

std::atomic<bool> g_running(false);
std::mutex g_state_mutex;
std::mutex g_vm_mutex;
std::string g_error;
std::string g_error_file;
std::string g_stop_file;

std::string exception_to_string(mrb_state *mrb) {
  if (mrb == nullptr || mrb->exc == nullptr)
    return "unknown mruby error";
  mrb_value exception = mrb_obj_value(mrb->exc);
  const char *class_name = mrb_obj_classname(mrb, exception);
  mrb_value message = mrb_funcall(mrb, exception, "to_s", 0);
  if (mrb->exc != nullptr) {
    mrb->exc = nullptr;
    return "failed to render mruby exception";
  }
  const char *text = mrb_string_value_cstr(mrb, &message);
  std::string rendered = class_name == nullptr ? "Exception" : class_name;
  rendered += ": ";
  rendered += text == nullptr ? "<empty>" : text;
  mrb->exc = nullptr;
  return rendered;
}

void reraise_pending(mrb_state *mrb) {
  if (mrb->exc == nullptr)
    return;
  mrb_value exception = mrb_obj_value(mrb->exc);
  mrb->exc = nullptr;
  mrb_exc_raise(mrb, exception);
}

mrb_value runtime_eval(mrb_state *mrb, mrb_value) {
  mrb_value source;
  mrb_value filename = mrb_nil_value();
  mrb_get_args(mrb, "S|S", &source, &filename);
  mrbc_context *context = mrbc_context_new(mrb);
  context->capture_errors = true;
  if (mrb_string_p(filename)) {
    mrbc_filename(mrb, context, mrb_string_value_cstr(mrb, &filename));
  }
  mrb_value result = mrb_load_nstring_cxt(mrb, RSTRING_PTR(source),
                                          RSTRING_LEN(source), context);
  mrbc_context_free(mrb, context);
  reraise_pending(mrb);
  return result;
}

mrb_value runtime_load_irep(mrb_state *mrb, mrb_value) {
  mrb_value bytes;
  mrb_get_args(mrb, "S", &bytes);
  mrb_value result = mrb_load_irep_buf(
      mrb, reinterpret_cast<const uint8_t *>(RSTRING_PTR(bytes)),
      RSTRING_LEN(bytes));
  reraise_pending(mrb);
  return result;
}

mrb_value runtime_getenv(mrb_state *mrb, mrb_value) {
  mrb_value name;
  mrb_get_args(mrb, "S", &name);
  const char *value = std::getenv(mrb_string_value_cstr(mrb, &name));
  return value == nullptr ? mrb_nil_value() : mrb_str_new_cstr(mrb, value);
}

void register_native_primitives(mrb_state *mrb) {
  RClass *runtime = mrb_define_module(mrb, "RubyRuntime");
  mrb_define_module_function(mrb, runtime, "__eval", runtime_eval,
                             MRB_ARGS_ARG(1, 1));
  mrb_define_module_function(mrb, runtime, "__load_irep", runtime_load_irep,
                             MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, runtime, "__getenv", runtime_getenv,
                             MRB_ARGS_REQ(1));
}

void set_process_environment(const std::string &key, const std::string &value) {
#if defined(_WIN32)
  _putenv_s(key.c_str(), value.c_str());
#else
  setenv(key.c_str(), value.c_str(), 1);
#endif
}

bool valid_entrypoint(const std::string &root_value,
                      const std::string &path_value) {
  if (root_value.empty() || path_value.empty())
    return false;
  const std::filesystem::path root =
      std::filesystem::path(root_value).lexically_normal();
  const std::filesystem::path path =
      std::filesystem::path(path_value).lexically_normal();
  const std::string extension = path.extension().string();
  if (extension != ".rb" && extension != ".mrb")
    return false;
  auto root_it = root.begin();
  auto path_it = path.begin();
  for (; root_it != root.end(); ++root_it, ++path_it) {
    if (path_it == path.end() || *root_it != *path_it)
      return false;
  }
  return true;
}

void replace_file(const std::string &path, const std::string &contents) {
  if (path.empty())
    return;
  std::ofstream stream(path, std::ios::binary | std::ios::trunc);
  stream << contents;
}

void remove_file(const std::string &path) {
  if (path.empty())
    return;
  std::error_code ignored;
  std::filesystem::remove(path, ignored);
}

std::string read_file(const std::string &path) {
  if (path.empty())
    return {};
  std::ifstream stream(path, std::ios::binary);
  if (!stream)
    return {};
  return std::string(std::istreambuf_iterator<char>(stream),
                     std::istreambuf_iterator<char>());
}

void set_error(std::string error) {
  std::lock_guard<std::mutex> lock(g_state_mutex);
  g_error = std::move(error);
}

} // namespace

int ruflet_vm_start(const char *project_root, const char *entrypoint,
                    const char *const *load_paths, size_t load_path_count,
                    const char *const *environment_keys,
                    const char *const *environment_values,
                    size_t environment_count, const char *stop_signal_path,
                    const char *error_file_path) {
  const std::string root = project_root == nullptr ? "" : project_root;
  const std::string main = entrypoint == nullptr ? "" : entrypoint;
  if (!valid_entrypoint(root, main))
    return 1;
  if (g_running.exchange(true))
    return 0;

  std::vector<std::string> paths;
  paths.reserve(load_path_count);
  for (size_t index = 0; index < load_path_count; ++index) {
    if (load_paths[index] != nullptr)
      paths.emplace_back(load_paths[index]);
  }
  std::vector<std::pair<std::string, std::string>> environment;
  environment.reserve(environment_count);
  for (size_t index = 0; index < environment_count; ++index) {
    if (environment_keys[index] != nullptr &&
        environment_values[index] != nullptr) {
      environment.emplace_back(environment_keys[index],
                               environment_values[index]);
    }
  }

  {
    std::lock_guard<std::mutex> lock(g_state_mutex);
    g_error.clear();
    g_stop_file = stop_signal_path == nullptr || stop_signal_path[0] == '\0'
                      ? (std::filesystem::path(root) / ".runtime.stop").string()
                      : stop_signal_path;
    g_error_file = error_file_path == nullptr ? "" : error_file_path;
    remove_file(g_stop_file);
    remove_file(g_error_file);
  }

  std::thread([root, main, paths = std::move(paths),
               environment = std::move(environment)]() {
    for (const auto &entry : environment) {
      set_process_environment(entry.first, entry.second);
    }

    std::lock_guard<std::mutex> vm_lock(g_vm_mutex);
    mrb_state *mrb = mrb_open();
    std::string runtime_error;
    if (mrb == nullptr) {
      runtime_error = "Unable to initialize mruby.";
    } else {
      register_native_primitives(mrb);
      mrb_load_irep(mrb, kRubyRuntimeVmBootstrapIrep);
      if (mrb->exc != nullptr) {
        runtime_error = exception_to_string(mrb);
      } else {
        RClass *runtime = mrb_module_get(mrb, "RubyRuntime");
        mrb_value ruby_paths = mrb_ary_new_capa(mrb, paths.size());
        for (const std::string &path : paths) {
          mrb_ary_push(mrb, ruby_paths, mrb_str_new_cstr(mrb, path.c_str()));
        }
        mrb_funcall(mrb, mrb_obj_value(runtime), "boot", 3,
                    mrb_str_new_cstr(mrb, root.c_str()),
                    mrb_str_new_cstr(mrb, main.c_str()), ruby_paths);
        if (mrb->exc != nullptr)
          runtime_error = exception_to_string(mrb);
      }
      mrb_close(mrb);
    }

    std::string stop_file;
    std::string error_file;
    {
      std::lock_guard<std::mutex> lock(g_state_mutex);
      stop_file = g_stop_file;
      error_file = g_error_file;
    }
    if (runtime_error.empty() && !std::filesystem::exists(stop_file)) {
      runtime_error = "Embedded Ruby app exited unexpectedly.";
    }
    if (!runtime_error.empty()) {
      set_error(runtime_error);
      replace_file(error_file, runtime_error);
    }
    g_running = false;
  }).detach();
  return 0;
}

int ruflet_vm_is_running(void) { return g_running ? 1 : 0; }

size_t ruflet_vm_copy_error(char *buffer, size_t capacity) {
  std::lock_guard<std::mutex> lock(g_state_mutex);
  const std::string reported = read_file(g_error_file);
  const std::string &error = reported.empty() ? g_error : reported;
  const size_t required = error.size() + 1;
  if (buffer != nullptr && capacity > 0) {
    const size_t count =
        error.size() < capacity - 1 ? error.size() : capacity - 1;
    std::memcpy(buffer, error.data(), count);
    buffer[count] = '\0';
  }
  return required;
}

void ruflet_vm_stop(void) {
  std::string stop_file;
  {
    std::lock_guard<std::mutex> lock(g_state_mutex);
    stop_file = g_stop_file;
  }
  replace_file(stop_file, "stop");
}
