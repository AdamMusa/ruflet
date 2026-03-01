#include <jni.h>

#include <fstream>
#include <mutex>
#include <sstream>
#include <string>

extern "C" {
#include <mruby.h>
#include <mruby/compile.h>
#include <mruby/string.h>
}

namespace {

std::mutex g_mutex;
mrb_state* g_mrb = nullptr;

struct EvalResult {
  bool ok;
  std::string value;
};

mrb_state* ensure_mrb() {
  if (g_mrb == nullptr) {
    g_mrb = mrb_open();
  }
  return g_mrb;
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

EvalResult eval_locked(const std::string& code) {
  mrb_state* mrb = ensure_mrb();
  if (mrb == nullptr) {
    return {false, "failed to initialize mruby runtime"};
  }

  mrbc_context* context = mrbc_context_new(mrb);
  if (context == nullptr) {
    return {false, "failed to create mruby compile context"};
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

}  // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_ruby_1runtime_MrubyRuntimePlugin_nativeEval(
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
  EvalResult result = eval_locked(source);
  if (!result.ok) {
    throw_runtime_error(env, result.value);
    return nullptr;
  }

  return env->NewStringUTF(result.value.c_str());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_ruby_1runtime_MrubyRuntimePlugin_nativeRunFile(
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

  std::string source = read_file(file_path);
  if (source.empty()) {
    throw_runtime_error(env, "unable to read Ruby file: " + file_path);
    return nullptr;
  }

  std::lock_guard<std::mutex> lock(g_mutex);
  EvalResult result = eval_locked(source);
  if (!result.ok) {
    throw_runtime_error(env, result.value);
    return nullptr;
  }

  return env->NewStringUTF(result.value.c_str());
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_ruby_1runtime_MrubyRuntimePlugin_nativeReset(
    JNIEnv* env,
    jobject /* this */) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_mrb != nullptr) {
    mrb_close(g_mrb);
    g_mrb = nullptr;
  }
  (void)env;
}
