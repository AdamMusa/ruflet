#include <jni.h>

#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <mutex>
#include <string>
#include <thread>
#include <cstdlib>

extern "C" {
#include <mruby.h>
#include <mruby/array.h>
#include <mruby/compile.h>
#include <mruby/irep.h>
#include <mruby/string.h>
}

#include "../../../../../shared/embedded_ruflet_runtime.h"

namespace {
std::mutex g_vm_mutex;
std::mutex g_state_mutex;
mrb_state* g_mrb = nullptr;
bool g_runtime_loaded = false;
bool g_server_running = false;
std::string g_stop_signal_path;
std::string g_port_file_path;
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

// Returns the port the embedded server reported through RUFLET_PORT_FILE,
// or 0 when the server has not bound a port yet.
long read_server_port_locked() {
  if (g_port_file_path.empty()) {
    return 0;
  }
  const std::string contents = read_file(g_port_file_path);
  if (contents.empty()) {
    return 0;
  }
  const long port = std::strtol(contents.c_str(), nullptr, 10);
  if (port <= 0 || port > 65535) {
    return 0;
  }
  return port;
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
  return result;
}

bool valid_entrypoint(const std::string& root, const std::string& entrypoint) {
  if (root.empty() || entrypoint.empty()) return false;
  std::string prefix = root;
  if (prefix.back() != '/') prefix += '/';
  const bool source = entrypoint.size() >= 3 && entrypoint.substr(entrypoint.size() - 3) == ".rb";
  const bool bytecode = entrypoint.size() >= 4 && entrypoint.substr(entrypoint.size() - 4) == ".mrb";
  return (source || bytecode) && entrypoint.rfind(prefix, 0) == 0;
}

std::string exception_text(mrb_state* mrb) {
  if (!mrb || !mrb->exc) return "unknown mruby error";
  mrb_print_backtrace(mrb);
  mrb_value exception = mrb_obj_value(mrb->exc);
  const char* klass = mrb_obj_classname(mrb, exception);
  mrb_value message = mrb_funcall(mrb, exception, "to_s", 0);
  if (mrb->exc) mrb->exc = nullptr;
  const char* text = mrb_string_value_cstr(mrb, &message);
  return std::string(klass ? klass : "Exception") + ": " + (text ? text : "<empty>");
}

void reraise_pending(mrb_state* mrb) {
  if (!mrb->exc) return;
  mrb_value exception = mrb_obj_value(mrb->exc);
  mrb->exc = nullptr;
  mrb_exc_raise(mrb, exception);
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
  reraise_pending(mrb);
  return result;
}

mrb_value rr_load_irep(mrb_state* mrb, mrb_value) {
  mrb_value bytes;
  mrb_get_args(mrb, "S", &bytes);
  mrb_value result = mrb_load_irep_buf(mrb, reinterpret_cast<const uint8_t*>(RSTRING_PTR(bytes)), RSTRING_LEN(bytes));
  reraise_pending(mrb);
  return result;
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
  if (keys.size() != values.size()) { fail(env, "invalid environment"); return; }
  {
    std::lock_guard<std::mutex> lock(g_state_mutex);
    if (g_running) return;
    g_running = true;
    g_stop_path = stop_path;
    g_error_path = error_path;
    g_last_error.clear();
  }
  std::remove(stop_path.c_str());
  if (!error_path.empty()) std::remove(error_path.c_str());

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
  g_port_file_path.clear();
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

  const size_t slash = file_path.find_last_of('/');
  const std::string app_root = slash == std::string::npos ? "." : file_path.substr(0, slash);
  const std::string port_path = app_root + "/server.port";

  {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_server_running) {
      return env->NewStringUTF("");
    }
    g_stop_signal_path = stop_path;
    g_port_file_path = port_path;
    g_last_server_error.clear();
    g_server_running = true;
  }

  std::remove(stop_path.c_str());
  std::remove(port_path.c_str());
  std::string source = read_file(file_path);
  if (source.empty()) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_server_running = false;
    g_last_server_error = "unable to read Ruby file: " + file_path;
    throw_runtime_error(env, g_last_server_error);
    return nullptr;
  }
  // The embedded VM's ENV is isolated from the process environment, so
  // configuration must be seeded through the Ruby prelude. The server binds
  // any free port and reports the bound port through RUFLET_PORT_FILE.
  source = "$__ruflet_app_root = '" + escape_single_quotes(app_root) + "'\n" +
           "ENV['RUFLET_PROD_STOP_FILE'] = '" + escape_single_quotes(stop_path) +
           "' if Object.const_defined?(:ENV)\n" +
           "ENV['RUFLET_PORT_FILE'] = '" + escape_single_quotes(port_path) +
           "' if Object.const_defined?(:ENV)\n" +
           source;

  std::thread([file_path, stop_path, port_path, source]() {
    setenv("RUFLET_PROD_STOP_FILE", stop_path.c_str(), 1);
    setenv("RUFLET_PORT_FILE", port_path.c_str(), 1);

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

extern "C" JNIEXPORT jint JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeServerPort(
    JNIEnv* env,
    jobject /* this */) {
  std::lock_guard<std::mutex> lock(g_mutex);
  (void)env;
  return static_cast<jint>(read_server_port_locked());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeLastFileServerError(
    JNIEnv* env,
    jobject /* this */) {
  std::lock_guard<std::mutex> lock(g_mutex);
  return env->NewStringUTF(g_last_server_error.c_str());
}
