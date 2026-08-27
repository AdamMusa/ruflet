#include "ruflet_vm_host.h"

#include <ruby.h>

#include <atomic>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#if defined(RUFLET_CRUBY_STATIC_EXTENSIONS)
extern "C" void Ruflet_Init_enc(void);
extern "C" int Ruflet_Load_static_ext(const char *name);
#endif

namespace {

std::atomic<bool> g_running(false);
std::mutex g_state_mutex;
std::string g_error;
std::string g_error_file;
std::string g_stop_file;

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
      std::filesystem::weakly_canonical(root_value);
  const std::filesystem::path path =
      std::filesystem::weakly_canonical(path_value);
  if (path.extension() != ".rb")
    return false;
  auto root_it = root.begin();
  auto path_it = path.begin();
  for (; root_it != root.end(); ++root_it, ++path_it) {
    if (path_it == path.end() || *root_it != *path_it)
      return false;
  }
  return true;
}

bool requests_in_process_transport(
    const std::vector<std::pair<std::string, std::string>> &environment) {
  for (const auto &entry : environment) {
    if (entry.first == "RUFLET_RUNTIME_TRANSPORT")
      return entry.second == "in_process";
  }
  return false;
}

VALUE bridge_read_nonblock(VALUE) {
  uint8_t *bytes = nullptr;
  size_t length = 0;
  const int status = ruflet_bridge_try_receive_for_ruby(&bytes, &length);
  if (status == RUFLET_BRIDGE_CLOSED)
    return Qnil;
  if (status == RUFLET_BRIDGE_EMPTY)
    return Qfalse;
  if (status != RUFLET_BRIDGE_MESSAGE)
    rb_raise(rb_eRuntimeError,
             "Unable to receive from the Ruflet in-process bridge");

  VALUE message = rb_str_new(reinterpret_cast<const char *>(bytes), length);
  ruflet_bridge_free_message(bytes);
  return message;
}

VALUE bridge_write(VALUE, VALUE payload) {
  StringValue(payload);
  const int status = ruflet_bridge_send_to_renderer(
      reinterpret_cast<const uint8_t *>(RSTRING_PTR(payload)),
      static_cast<size_t>(RSTRING_LEN(payload)));
  if (status != RUFLET_BRIDGE_MESSAGE)
    rb_raise(rb_eRuntimeError, "Ruflet in-process bridge is closed");
  return Qnil;
}

VALUE bridge_close(VALUE) {
  ruflet_bridge_close();
  return Qnil;
}

void register_native_primitives() {
  VALUE runtime = rb_define_module("RubyRuntime");
  rb_define_singleton_method(runtime, "__bridge_read_nonblock",
                             RUBY_METHOD_FUNC(bridge_read_nonblock), 0);
  rb_define_singleton_method(runtime, "__bridge_write",
                             RUBY_METHOD_FUNC(bridge_write), 1);
  rb_define_singleton_method(runtime, "__bridge_close",
                             RUBY_METHOD_FUNC(bridge_close), 0);
}

#if defined(RUFLET_CRUBY_STATIC_EXTENSIONS)
struct RequireArguments {
  VALUE receiver;
  VALUE feature;
};

VALUE call_original_require(VALUE opaque) {
  auto *arguments = reinterpret_cast<RequireArguments *>(opaque);
  return rb_funcall(arguments->receiver,
                    rb_intern("__ruflet_require_without_static_fallback"), 1,
                    arguments->feature);
}

VALUE require_with_static_fallback(VALUE receiver, VALUE feature) {
  RequireArguments arguments{receiver, feature};
  int state = 0;
  VALUE result = rb_protect(call_original_require,
                            reinterpret_cast<VALUE>(&arguments), &state);
  if (state == 0)
    return result;

  VALUE original_error = rb_errinfo();
  if (!rb_obj_is_kind_of(original_error, rb_eLoadError))
    rb_jump_tag(state);

  StringValue(feature);
  rb_set_errinfo(Qnil);
  const int loaded = Ruflet_Load_static_ext(StringValueCStr(feature));
  if (loaded >= 0)
    return loaded ? Qtrue : Qfalse;

  rb_set_errinfo(original_error);
  rb_jump_tag(state);
  return Qnil;
}

void install_static_require_resolution() {
  rb_alias(rb_mKernel, rb_intern("__ruflet_require_without_static_fallback"),
           rb_intern("require"));
  rb_define_private_method(rb_mKernel, "require",
                           RUBY_METHOD_FUNC(require_with_static_fallback), 1);
}
#endif

void prepend_load_path(const std::filesystem::path &path) {
  if (!std::filesystem::is_directory(path))
    return;
  VALUE load_path = rb_gv_get("$LOAD_PATH");
  rb_ary_unshift(load_path, rb_utf8_str_new_cstr(path.string().c_str()));
}

void add_packaged_gem_paths(const std::filesystem::path &root) {
  const std::filesystem::path ruby_root = root / "vendor" / "bundle" / "ruby";
  if (!std::filesystem::is_directory(ruby_root))
    return;

  std::error_code ignored;
  for (const auto &version : std::filesystem::directory_iterator(ruby_root, ignored)) {
    const std::filesystem::path gems = version.path() / "gems";
    if (std::filesystem::is_directory(gems)) {
      for (const auto &gem : std::filesystem::directory_iterator(gems, ignored))
        prepend_load_path(gem.path() / "lib");
    }

    const std::filesystem::path extensions = version.path() / "extensions";
    if (std::filesystem::is_directory(extensions)) {
      for (const auto &entry :
           std::filesystem::recursive_directory_iterator(extensions, ignored)) {
        if (entry.is_regular_file() && entry.path().filename() == "gem.build_complete")
          prepend_load_path(entry.path().parent_path());
      }
    }
  }
}

struct BootArguments {
  std::string root;
  std::string entrypoint;
  std::vector<std::string> load_paths;
};

VALUE boot_project(VALUE opaque) {
  auto *arguments = reinterpret_cast<BootArguments *>(opaque);
#if defined(RUFLET_CRUBY_STATIC_EXTENSIONS)
  // Ruby's Android cross-build can classify registered native extensions as
  // shared features before reaching the static table. Only known static
  // extension names receive the conventional `.so` suffix; ordinary project
  // and gem requires retain CRuby's normal behavior.
  install_static_require_resolution();
#endif
  register_native_primitives();
  add_packaged_gem_paths(arguments->root);
  for (auto path = arguments->load_paths.rbegin();
       path != arguments->load_paths.rend(); ++path)
    prepend_load_path(*path);
  prepend_load_path(arguments->root);
  rb_load(rb_utf8_str_new_cstr(arguments->entrypoint.c_str()), 0);
  return Qnil;
}

std::string exception_to_string() {
  VALUE exception = rb_errinfo();
  if (NIL_P(exception))
    return "unknown CRuby error";
  VALUE rendered = rb_funcall(exception, rb_intern("full_message"), 0);
  StringValue(rendered);
  std::string result(RSTRING_PTR(rendered), RSTRING_LEN(rendered));
  rb_set_errinfo(Qnil);
  return result;
}

void run_vm(BootArguments arguments,
            std::vector<std::pair<std::string, std::string>> environment,
            bool in_process_transport) {
  for (const auto &entry : environment)
    set_process_environment(entry.first, entry.second);

  std::string runtime_error;
  int argc = 1;
  char executable[] = "ruflet-cruby";
  char *argv_values[] = {executable, nullptr};
  char **argv = argv_values;
  ruby_sysinit(&argc, &argv);
  RUBY_INIT_STACK;
  if (ruby_setup() != 0) {
    runtime_error = "Unable to initialize CRuby.";
  } else {
    ruby_init_loadpath();
    ruby_script("ruflet-embedded");
#if defined(RUFLET_CRUBY_STATIC_EXTENSIONS)
    // The Android shared runtime otherwise resolves CRuby's Init_enc fallback,
    // which only declares encoding names and leaves constants such as UTF_8
    // unavailable to native stdlib extensions.
    Ruflet_Init_enc();
#endif
    // Make the distribution's real, relocated stdlib visible before late
    // initialization. Otherwise CRuby looks under its build-time prefix and
    // silently skips RubyGems and the default-gem prelude.
    for (auto path = arguments.load_paths.rbegin();
         path != arguments.load_paths.rend(); ++path)
      prepend_load_path(*path);
    // ruby_options performs CRuby's late interpreter initialization (notably
    // the encoding database and gem prelude). Embedded hosts that jump
    // directly from ruby_setup to rb_load leave those facilities half-built.
    char option_program[] = "ruflet-embedded";
    char option_eval[] = "-e";
    char option_source[] = "nil";
    char *option_values[] = {option_program, option_eval, option_source,
                             nullptr};
    (void)ruby_options(3, option_values);
    int state = 0;
    rb_protect(boot_project, reinterpret_cast<VALUE>(&arguments), &state);
    if (state != 0)
      runtime_error = exception_to_string();
    ruby_cleanup(state);
  }

  std::string stop_file;
  std::string error_file;
  {
    std::lock_guard<std::mutex> lock(g_state_mutex);
    stop_file = g_stop_file;
    error_file = g_error_file;
  }
  if (runtime_error.empty() && !std::filesystem::exists(stop_file))
    runtime_error = "Embedded CRuby app exited unexpectedly.";
  if (!runtime_error.empty()) {
    set_error(runtime_error);
    replace_file(error_file, runtime_error);
  }
  if (in_process_transport)
    ruflet_bridge_close();
  g_running = false;
}

} // namespace

int ruflet_vm_start(const char *project_root, const char *entrypoint,
                    const char *const *load_paths, size_t load_path_count,
                    const char *const *environment_keys,
                    const char *const *environment_values,
                    size_t environment_count, const char *stop_signal_path,
                    const char *error_file_path) {
  const std::string requested_root = project_root == nullptr ? "" : project_root;
  const std::string requested_main = entrypoint == nullptr ? "" : entrypoint;
  if (!valid_entrypoint(requested_root, requested_main))
    return 1;
  const std::string root = std::filesystem::weakly_canonical(requested_root);
  const std::string main = std::filesystem::weakly_canonical(requested_main);
  if (g_running.exchange(true))
    return 0;

  BootArguments arguments{root, main, {}};
  arguments.load_paths.reserve(load_path_count);
  for (size_t index = 0; index < load_path_count; ++index) {
    if (load_paths[index] != nullptr)
      arguments.load_paths.emplace_back(load_paths[index]);
  }

  std::vector<std::pair<std::string, std::string>> environment;
  environment.reserve(environment_count);
  for (size_t index = 0; index < environment_count; ++index) {
    if (environment_keys[index] != nullptr && environment_values[index] != nullptr)
      environment.emplace_back(environment_keys[index], environment_values[index]);
  }
  const bool in_process_transport = requests_in_process_transport(environment);
  if (in_process_transport)
    ruflet_bridge_reset();

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

  std::thread(run_vm, std::move(arguments), std::move(environment),
              in_process_transport)
      .detach();
  return 0;
}

int ruflet_vm_is_running(void) { return g_running ? 1 : 0; }

size_t ruflet_vm_copy_error(char *buffer, size_t capacity) {
  std::lock_guard<std::mutex> lock(g_state_mutex);
  const std::string reported = read_file(g_error_file);
  const std::string &error = reported.empty() ? g_error : reported;
  const size_t required = error.size() + 1;
  if (buffer != nullptr && capacity > 0) {
    const size_t count = error.size() < capacity - 1 ? error.size() : capacity - 1;
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
  ruflet_bridge_close();
  replace_file(stop_file, "stop");
}
