#include <jni.h>

#include <fstream>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>
#include <cstdlib>

extern "C" {
#include <mruby.h>
#include <mruby/compile.h>
#include <mruby/string.h>
}

#include "../../../../../generated/embedded_ruflet_runtime.h"

namespace {

std::mutex g_mutex;
mrb_state* g_mrb = nullptr;
bool g_runtime_loaded = false;
bool g_server_running = false;
std::string g_stop_signal_path;
std::string g_last_server_error;

struct EvalResult {
  bool ok;
  std::string value;
};

EvalResult eval_locked(const std::string& code, const char* filename = nullptr);
std::string exception_to_string(mrb_state* mrb);

mrb_state* ensure_mrb() {
  if (g_mrb == nullptr) {
    g_mrb = mrb_open();
  }
  return g_mrb;
}

EvalResult preload_embedded_runtime_locked() {
  if (g_runtime_loaded) {
    return {true, ""};
  }

  mrb_state* mrb = ensure_mrb();
  if (mrb == nullptr) {
    return {false, "failed to initialize mruby runtime"};
  }

  mrbc_context* context = mrbc_context_new(mrb);
  if (context == nullptr) {
    return {false, "failed to create preload compile context"};
  }

  mrbc_filename(mrb, context, "/__ruflet__/embedded_runtime.rb");
  mrb_load_string_cxt(mrb, kEmbeddedRufletRuntime, context);
  mrbc_context_free(mrb, context);

  if (mrb->exc != nullptr) {
    return {false, exception_to_string(mrb)};
  }

  g_runtime_loaded = true;
  return {true, ""};
}

std::string read_file(const std::string& path) {
  std::ifstream in(path);
  if (!in) {
    return "";
  }
  std::ostringstream content;
  content << in.rdbuf();
  return content.str();
}

EvalResult run_file_locked(const std::string& file_path) {
  std::string source = read_file(file_path);
  if (source.empty()) {
    return {false, "unable to read Ruby file: " + file_path};
  }
  return eval_locked(source, file_path.c_str());
}

std::string escape_single_quotes(const std::string& value) {
  std::string escaped;
  escaped.reserve(value.size());
  for (char ch : value) {
    if (ch == '\'') {
      escaped += "\\'";
    } else {
      escaped += ch;
    }
  }
  return escaped;
}

std::string exception_to_string(mrb_state* mrb) {
  if (mrb == nullptr || mrb->exc == nullptr) {
    return "unknown mruby error";
  }

  mrb_value exc = mrb_obj_value(mrb->exc);
  const char* klass = mrb_obj_classname(mrb, exc);

  mrb_value text = mrb_funcall(mrb, exc, "to_s", 0);
  if (mrb->exc != nullptr) {
    // Avoid recursive failures while formatting an exception.
    mrb->exc = nullptr;
    std::string fallback = klass == nullptr ? "Exception" : klass;
    fallback += ": <failed to render exception message>";
    return fallback;
  }

  const char* cstr = mrb_string_value_cstr(mrb, &text);
  std::string message = klass == nullptr ? "Exception" : klass;
  message += ": ";
  message += (cstr == nullptr ? "<empty>" : cstr);
  mrb->exc = nullptr;
  return message;
}

EvalResult eval_locked(const std::string& code, const char* filename) {
  mrb_state* mrb = ensure_mrb();
  if (mrb == nullptr) {
    return {false, "failed to initialize mruby runtime"};
  }

  EvalResult preload = preload_embedded_runtime_locked();
  if (!preload.ok) {
    return preload;
  }

  mrbc_context* context = mrbc_context_new(mrb);
  if (context == nullptr) {
    return {false, "failed to create mruby compile context"};
  }

  if (filename != nullptr && filename[0] != '\0') {
    mrbc_filename(mrb, context, filename);
  }

  mrb_value result_value = mrb_load_string_cxt(mrb, code.c_str(), context);
  mrbc_context_free(mrb, context);

  if (mrb->exc != nullptr) {
    return {false, exception_to_string(mrb)};
  }

  mrb_value display_value;
  if (mrb_string_p(result_value)) {
    display_value = result_value;
  } else {
    display_value = mrb_inspect(mrb, result_value);
  }
  if (mrb->exc != nullptr) {
    return {false, exception_to_string(mrb)};
  }

  const char* result_cstr = mrb_string_value_cstr(mrb, &display_value);
  return {true, result_cstr == nullptr ? "" : result_cstr};
}

void throw_runtime_error(JNIEnv* env, const std::string& message) {
  jclass exception_class = env->FindClass("java/lang/RuntimeException");
  if (exception_class != nullptr) {
    env->ThrowNew(exception_class, message.c_str());
  }
}

void request_stop_server_locked() {
  if (g_stop_signal_path.empty()) {
    return;
  }
  std::ofstream out(g_stop_signal_path);
  if (out) {
    out << "stop";
  }
}

}  // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeEval(
    JNIEnv* env,
    jobject /* this */,
    jstring code) {
  if (code == nullptr) {
    throw_runtime_error(env, "code argument is null");
    return nullptr;
  }

  const char* code_chars = env->GetStringUTFChars(code, nullptr);
  if (code_chars == nullptr) {
    throw_runtime_error(env, "failed to access code argument");
    return nullptr;
  }

  std::string source(code_chars);
  env->ReleaseStringUTFChars(code, code_chars);

  std::lock_guard<std::mutex> lock(g_mutex);
  EvalResult result = eval_locked(source, nullptr);
  if (!result.ok) {
    throw_runtime_error(env, result.value);
    return nullptr;
  }

  return env->NewStringUTF(result.value.c_str());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeRunFile(
    JNIEnv* env,
    jobject /* this */,
    jstring path) {
  if (path == nullptr) {
    throw_runtime_error(env, "path argument is null");
    return nullptr;
  }

  const char* path_chars = env->GetStringUTFChars(path, nullptr);
  if (path_chars == nullptr) {
    throw_runtime_error(env, "failed to access path argument");
    return nullptr;
  }

  std::string file_path(path_chars);
  env->ReleaseStringUTFChars(path, path_chars);

  std::lock_guard<std::mutex> lock(g_mutex);
  EvalResult result = run_file_locked(file_path);
  if (!result.ok) {
    throw_runtime_error(env, result.value);
    return nullptr;
  }

  return env->NewStringUTF(result.value.c_str());
}

extern "C" JNIEXPORT void JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeReset(
    JNIEnv* env,
    jobject /* this */) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_server_running) {
    request_stop_server_locked();
    (void)env;
    return;
  }
  if (g_mrb != nullptr) {
    mrb_close(g_mrb);
    g_mrb = nullptr;
  }
  g_runtime_loaded = false;
  g_last_server_error.clear();
  (void)env;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeStartFileServer(
    JNIEnv* env,
    jobject /* this */,
    jstring path,
    jstring stop_signal_path) {
  if (path == nullptr) {
    throw_runtime_error(env, "path argument is null");
    return nullptr;
  }
  if (stop_signal_path == nullptr) {
    throw_runtime_error(env, "stopSignalPath argument is null");
    return nullptr;
  }

  const char* path_chars = env->GetStringUTFChars(path, nullptr);
  if (path_chars == nullptr) {
    throw_runtime_error(env, "failed to access path argument");
    return nullptr;
  }
  const char* stop_chars = env->GetStringUTFChars(stop_signal_path, nullptr);
  if (stop_chars == nullptr) {
    env->ReleaseStringUTFChars(path, path_chars);
    throw_runtime_error(env, "failed to access stopSignalPath argument");
    return nullptr;
  }

  std::string file_path(path_chars);
  std::string stop_path(stop_chars);
  env->ReleaseStringUTFChars(path, path_chars);
  env->ReleaseStringUTFChars(stop_signal_path, stop_chars);

  {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_server_running) {
      return env->NewStringUTF("");
    }
    g_stop_signal_path = stop_path;
    g_last_server_error.clear();
    g_server_running = true;
  }

  std::remove(stop_path.c_str());
  std::string source = read_file(file_path);
  if (source.empty()) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_server_running = false;
    g_last_server_error = "unable to read Ruby file: " + file_path;
    throw_runtime_error(env, g_last_server_error);
    return nullptr;
  }

  std::thread([file_path, stop_path, source]() {
    setenv("RUFLET_PROD_STOP_FILE", stop_path.c_str(), 1);

    std::lock_guard<std::mutex> lock(g_mutex);
    EvalResult result = eval_locked(source, file_path.c_str());
    if (result.ok && !result.value.empty() && result.value[0] == ':') {
      const std::string safe_path = escape_single_quotes(file_path);
      const std::string bootstrap =
          "app_root = File.expand_path(File.dirname('" + safe_path + "')); "
          "manifest_path = File.join(app_root, 'manifest.json'); "
          "manifest = RufletProd::JsonParser.parse(File.read(manifest_path)); "
          "RufletProd::Server.new(host: '0.0.0.0', port: 8550, manifest: manifest).start";
      result = eval_locked(bootstrap, file_path.c_str());
    }

    if (!result.ok) {
      g_last_server_error = result.value;
    } else {
      g_last_server_error = "server script exited: " + result.value;
    }
    g_server_running = false;
  }).detach();

  return env->NewStringUTF("");
}

extern "C" JNIEXPORT void JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeStopFileServer(
    JNIEnv* env,
    jobject /* this */) {
  std::lock_guard<std::mutex> lock(g_mutex);
  request_stop_server_locked();
  (void)env;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeIsFileServerRunning(
    JNIEnv* env,
    jobject /* this */) {
  std::lock_guard<std::mutex> lock(g_mutex);
  (void)env;
  return g_server_running ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeLastFileServerError(
    JNIEnv* env,
    jobject /* this */) {
  std::lock_guard<std::mutex> lock(g_mutex);
  return env->NewStringUTF(g_last_server_error.c_str());
}
