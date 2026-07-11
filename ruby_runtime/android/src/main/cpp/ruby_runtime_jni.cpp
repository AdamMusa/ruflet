#include <jni.h>

#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

extern "C" {
#include <mruby.h>
#include <mruby/irep.h>
#include <mruby/string.h>
#include <mruby/variable.h>
}

#include "../../../../../shared/embedded_ruflet_runtime.h"

namespace {

constexpr int kRufletServerPort = 8550;

std::mutex g_vm_mutex;
std::mutex g_state_mutex;
mrb_state* g_mrb = nullptr;
bool g_server_running = false;
std::string g_stop_signal_path;
std::string g_runtime_error_path;
std::string g_last_server_error;

void throw_runtime_error(JNIEnv* env, const std::string& message) {
  jclass exception_class = env->FindClass("java/lang/RuntimeException");
  if (exception_class != nullptr) {
    env->ThrowNew(exception_class, message.c_str());
  }
}

std::string jstring_value(JNIEnv* env, jstring value, const char* name) {
  if (value == nullptr) {
    throw_runtime_error(env, std::string(name) + " argument is null");
    return "";
  }
  const char* chars = env->GetStringUTFChars(value, nullptr);
  if (chars == nullptr) {
    throw_runtime_error(env, std::string("failed to access ") + name);
    return "";
  }
  std::string result(chars);
  env->ReleaseStringUTFChars(value, chars);
  return result;
}

std::vector<uint8_t> read_bytecode(const std::string& path) {
  std::ifstream input(path, std::ios::binary);
  if (!input) {
    return {};
  }
  return std::vector<uint8_t>(
      std::istreambuf_iterator<char>(input),
      std::istreambuf_iterator<char>());
}

std::string exception_to_string(mrb_state* mrb) {
  if (mrb == nullptr || mrb->exc == nullptr) {
    return "unknown mruby error";
  }

  mrb_value exception = mrb_obj_value(mrb->exc);
  const char* class_name = mrb_obj_classname(mrb, exception);
  mrb_value message = mrb_funcall(mrb, exception, "to_s", 0);
  if (mrb->exc != nullptr) {
    mrb->exc = nullptr;
    return "failed to render mruby exception";
  }

  const char* text = mrb_string_value_cstr(mrb, &message);
  std::string result = class_name == nullptr ? "Exception" : class_name;
  result += ": ";
  result += text == nullptr ? "<empty>" : text;
  mrb->exc = nullptr;
  return result;
}

bool valid_entrypoint(const std::string& project_root, const std::string& entrypoint) {
  if (project_root.empty() || entrypoint.empty() ||
      entrypoint.size() < 4 || entrypoint.substr(entrypoint.size() - 4) != ".mrb") {
    return false;
  }
  std::string prefix = project_root;
  if (prefix.back() != '/') {
    prefix += '/';
  }
  return entrypoint.rfind(prefix, 0) == 0;
}

void set_runtime_error(const std::string& error) {
  std::lock_guard<std::mutex> state_lock(g_state_mutex);
  g_last_server_error = error;
}

void finish_runtime() {
  std::lock_guard<std::mutex> state_lock(g_state_mutex);
  g_server_running = false;
}

void request_stop() {
  std::string stop_path;
  {
    std::lock_guard<std::mutex> state_lock(g_state_mutex);
    stop_path = g_stop_signal_path;
  }
  if (stop_path.empty()) {
    return;
  }
  std::ofstream output(stop_path);
  if (output) {
    output << "stop";
  }
}

}  // namespace

extern "C" JNIEXPORT void JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeStart(
    JNIEnv* env,
    jobject /* this */,
    jstring project_root_value,
    jstring entrypoint_value,
    jstring stop_signal_path_value) {
  std::string project_root = jstring_value(env, project_root_value, "projectRoot");
  if (env->ExceptionCheck()) return;
  std::string entrypoint = jstring_value(env, entrypoint_value, "entrypoint");
  if (env->ExceptionCheck()) return;
  std::string stop_path = jstring_value(env, stop_signal_path_value, "stopSignalPath");
  if (env->ExceptionCheck()) return;

  if (!valid_entrypoint(project_root, entrypoint)) {
    throw_runtime_error(env, "Ruflet requires a .mrb entrypoint inside projectRoot.");
    return;
  }

  std::vector<uint8_t> bytecode = read_bytecode(entrypoint);
  if (bytecode.empty()) {
    throw_runtime_error(env, "Unable to read Ruflet entrypoint: " + entrypoint);
    return;
  }

  {
    std::lock_guard<std::mutex> state_lock(g_state_mutex);
    if (g_server_running) {
      return;
    }
    g_server_running = true;
    g_stop_signal_path = stop_path;
    g_runtime_error_path = project_root + "/.ruflet-runtime.error";
    g_last_server_error.clear();
  }
  std::remove(stop_path.c_str());
  std::remove((project_root + "/.ruflet-runtime.error").c_str());

  std::thread([project_root, stop_path, bytecode = std::move(bytecode)]() {
    setenv("RUFLET_PROD_STOP_FILE", stop_path.c_str(), 1);
    setenv("RUFLET_STRICT_PORT", "1", 1);
    const std::string runtime_error_path = project_root + "/.ruflet-runtime.error";
    setenv("RUFLET_RUNTIME_ERROR_FILE", runtime_error_path.c_str(), 1);

    std::lock_guard<std::mutex> vm_lock(g_vm_mutex);
    if (g_mrb != nullptr) {
      mrb_close(g_mrb);
    }
    g_mrb = mrb_open();

    if (g_mrb == nullptr) {
      set_runtime_error("Unable to initialize mruby.");
      finish_runtime();
      return;
    }

    mrb_load_irep(g_mrb, kEmbeddedRufletRuntimeIrep);
    if (g_mrb->exc == nullptr) {
      mrb_sym root_symbol = mrb_intern_lit(g_mrb, "$__ruflet_app_root");
      mrb_gv_set(g_mrb, root_symbol, mrb_str_new_cstr(g_mrb, project_root.c_str()));
      mrb_sym error_path_symbol =
          mrb_intern_lit(g_mrb, "$__ruflet_runtime_error_file");
      mrb_gv_set(
          g_mrb,
          error_path_symbol,
          mrb_str_new_cstr(g_mrb, runtime_error_path.c_str()));
      mrb_load_irep_buf(g_mrb, bytecode.data(), bytecode.size());
    }

    if (g_mrb->exc != nullptr) {
      set_runtime_error(exception_to_string(g_mrb));
    } else {
      std::ifstream stop_file(stop_path);
      if (!stop_file.good()) {
        set_runtime_error("Ruflet server exited unexpectedly.");
      }
    }

    mrb_close(g_mrb);
    g_mrb = nullptr;
    finish_runtime();
  }).detach();
}

extern "C" JNIEXPORT void JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeStop(
    JNIEnv* env,
    jobject /* this */) {
  request_stop();
  (void)env;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeIsRunning(
    JNIEnv* env,
    jobject /* this */) {
  std::lock_guard<std::mutex> state_lock(g_state_mutex);
  (void)env;
  return g_server_running ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeLastError(
    JNIEnv* env,
    jobject /* this */) {
  std::lock_guard<std::mutex> state_lock(g_state_mutex);
  std::string error = g_last_server_error;
  if (!g_runtime_error_path.empty()) {
    std::ifstream input(g_runtime_error_path);
    if (input) {
      error.assign(
          std::istreambuf_iterator<char>(input),
          std::istreambuf_iterator<char>());
    }
  }
  return env->NewStringUTF(error.c_str());
}
