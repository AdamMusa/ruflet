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
#include <mruby/array.h>
#include <mruby/compile.h>
#include <mruby/irep.h>
#include <mruby/string.h>
}

#include "vm_bootstrap.h"
#include "ruflet_in_process_bridge.h"

namespace {
std::mutex g_vm_mutex;
std::mutex g_state_mutex;
mrb_state* g_mrb = nullptr;
bool g_running = false;
std::string g_stop_path;
std::string g_error_path;
std::string g_last_error;

void fail(JNIEnv* env, const std::string& message) {
  jclass type = env->FindClass("java/lang/RuntimeException");
  if (type) env->ThrowNew(type, message.c_str());
}

std::string string_value(JNIEnv* env, jstring value, const char* name) {
  if (!value) { fail(env, std::string("missing ") + name); return {}; }
  const char* chars = env->GetStringUTFChars(value, nullptr);
  if (!chars) return {};
  std::string result(chars);
  env->ReleaseStringUTFChars(value, chars);
  return result;
}

std::vector<std::string> string_array(JNIEnv* env, jobjectArray values) {
  std::vector<std::string> result;
  if (!values) return result;
  const jsize count = env->GetArrayLength(values);
  result.reserve(count);
  for (jsize i = 0; i < count; ++i) {
    auto value = static_cast<jstring>(env->GetObjectArrayElement(values, i));
    result.push_back(string_value(env, value, "array value"));
    env->DeleteLocalRef(value);
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

mrb_value rr_eval(mrb_state* mrb, mrb_value) {
  mrb_value source, filename = mrb_nil_value();
  mrb_get_args(mrb, "S|S", &source, &filename);
  mrbc_context* context = mrbc_context_new(mrb);
  context->capture_errors = TRUE;
  if (mrb_string_p(filename)) mrbc_filename(mrb, context, mrb_string_value_cstr(mrb, &filename));
  mrb_value result = mrb_load_nstring_cxt(mrb, RSTRING_PTR(source), RSTRING_LEN(source), context);
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

mrb_value rr_getenv(mrb_state* mrb, mrb_value) {
  mrb_value name;
  mrb_get_args(mrb, "S", &name);
  const char* value = getenv(mrb_string_value_cstr(mrb, &name));
  return value ? mrb_str_new_cstr(mrb, value) : mrb_nil_value();
}

mrb_value rr_bridge_read_nonblock(mrb_state* mrb, mrb_value) {
  uint8_t* bytes = nullptr;
  size_t length = 0;
  const int status = ruflet_bridge_try_receive_for_ruby(&bytes, &length);
  if (status == RUFLET_BRIDGE_CLOSED) return mrb_nil_value();
  if (status == RUFLET_BRIDGE_EMPTY) return mrb_false_value();
  if (status != RUFLET_BRIDGE_MESSAGE) {
    mrb_raise(mrb, E_RUNTIME_ERROR,
              "Unable to receive from the Ruflet in-process bridge");
  }

  mrb_value message = mrb_str_new(
      mrb, reinterpret_cast<const char*>(bytes), static_cast<mrb_int>(length));
  ruflet_bridge_free_message(bytes);
  return message;
}

mrb_value rr_bridge_write(mrb_state* mrb, mrb_value) {
  mrb_value payload;
  mrb_get_args(mrb, "S", &payload);
  const int status = ruflet_bridge_send_to_renderer(
      reinterpret_cast<const uint8_t*>(RSTRING_PTR(payload)),
      static_cast<size_t>(RSTRING_LEN(payload)));
  if (status != RUFLET_BRIDGE_MESSAGE) {
    mrb_raise(mrb, E_RUNTIME_ERROR, "Ruflet in-process bridge is closed");
  }
  return mrb_nil_value();
}

mrb_value rr_bridge_close(mrb_state*, mrb_value) {
  ruflet_bridge_close();
  return mrb_nil_value();
}

void register_primitives(mrb_state* mrb) {
  struct RClass* runtime = mrb_define_module(mrb, "RubyRuntime");
  mrb_define_module_function(mrb, runtime, "__eval", rr_eval, MRB_ARGS_ARG(1, 1));
  mrb_define_module_function(mrb, runtime, "__load_irep", rr_load_irep, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, runtime, "__getenv", rr_getenv, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, runtime, "__bridge_read_nonblock",
                             rr_bridge_read_nonblock, MRB_ARGS_NONE());
  mrb_define_module_function(mrb, runtime, "__bridge_write", rr_bridge_write,
                             MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, runtime, "__bridge_close", rr_bridge_close,
                             MRB_ARGS_NONE());
}

bool requests_in_process_transport(const std::vector<std::string>& keys,
                                   const std::vector<std::string>& values) {
  for (size_t i = 0; i < keys.size(); ++i) {
    if (keys[i] == "RUFLET_RUNTIME_TRANSPORT") {
      return values[i] == "in_process";
    }
  }
  return false;
}

void set_finished(const std::string& error) {
  std::lock_guard<std::mutex> lock(g_state_mutex);
  g_last_error = error;
  g_running = false;
}
}  // namespace

extern "C" JNIEXPORT void JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeStart(
    JNIEnv* env, jobject, jstring root_value, jstring entrypoint_value,
    jobjectArray load_path_values, jobjectArray environment_keys,
    jobjectArray environment_values, jstring error_path_value, jstring stop_path_value) {
  std::string root = string_value(env, root_value, "projectRoot");
  std::string entrypoint = string_value(env, entrypoint_value, "entrypoint");
  auto load_paths = string_array(env, load_path_values);
  auto keys = string_array(env, environment_keys);
  auto values = string_array(env, environment_values);
  std::string error_path = string_value(env, error_path_value, "errorFilePath");
  std::string stop_path = string_value(env, stop_path_value, "stopSignalPath");
  if (env->ExceptionCheck()) return;
  if (!valid_entrypoint(root, entrypoint)) {
    fail(env, "start requires a .rb or .mrb entrypoint inside projectRoot.");
    return;
  }
  if (keys.size() != values.size()) { fail(env, "invalid environment"); return; }
  const bool in_process_transport = requests_in_process_transport(keys, values);
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
  if (in_process_transport) ruflet_bridge_reset();

  std::thread([root, entrypoint, load_paths, keys, values, in_process_transport]() {
    for (size_t i = 0; i < keys.size(); ++i) setenv(keys[i].c_str(), values[i].c_str(), 1);
    std::lock_guard<std::mutex> vm_lock(g_vm_mutex);
    if (g_mrb) mrb_close(g_mrb);
    g_mrb = mrb_open();
    if (!g_mrb) {
      if (in_process_transport) ruflet_bridge_close();
      set_finished("Unable to initialize mruby.");
      return;
    }
    register_primitives(g_mrb);
    mrb_load_irep(g_mrb, kRubyRuntimeVmBootstrapIrep);
    if (!g_mrb->exc) {
      struct RClass* runtime = mrb_module_get(g_mrb, "RubyRuntime");
      mrb_value paths = mrb_ary_new_capa(g_mrb, static_cast<mrb_int>(load_paths.size()));
      for (const auto& path : load_paths) mrb_ary_push(g_mrb, paths, mrb_str_new_cstr(g_mrb, path.c_str()));
      mrb_funcall(g_mrb, mrb_obj_value(runtime), "boot", 3,
                  mrb_str_new_cstr(g_mrb, root.c_str()),
                  mrb_str_new_cstr(g_mrb, entrypoint.c_str()), paths);
    }
    std::string error = g_mrb->exc ? exception_text(g_mrb) : "";
    mrb_close(g_mrb);
    g_mrb = nullptr;
    if (in_process_transport) ruflet_bridge_close();
    set_finished(error);
  }).detach();
}

extern "C" JNIEXPORT void JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeStop(JNIEnv*, jobject) {
  ruflet_bridge_close();
  std::string path;
  { std::lock_guard<std::mutex> lock(g_state_mutex); path = g_stop_path; }
  if (!path.empty()) { std::ofstream output(path); output << "stop"; }
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeIsRunning(JNIEnv*, jobject) {
  std::lock_guard<std::mutex> lock(g_state_mutex);
  return g_running ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeLastError(JNIEnv* env, jobject) {
  std::lock_guard<std::mutex> lock(g_state_mutex);
  std::string error = g_last_error;
  if (!g_error_path.empty()) {
    std::ifstream input(g_error_path);
    if (input) error.assign(std::istreambuf_iterator<char>(input), {});
  }
  return env->NewStringUTF(error.c_str());
}
