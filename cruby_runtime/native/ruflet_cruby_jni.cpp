#include "ruflet_vm_host.h"

#include <jni.h>

#include <string>
#include <vector>

namespace {

void fail(JNIEnv *env, const std::string &message) {
  jclass type = env->FindClass("java/lang/RuntimeException");
  if (type != nullptr)
    env->ThrowNew(type, message.c_str());
}

std::string string_value(JNIEnv *env, jstring value, const char *name) {
  if (value == nullptr) {
    fail(env, std::string("missing ") + name);
    return {};
  }
  const char *characters = env->GetStringUTFChars(value, nullptr);
  if (characters == nullptr)
    return {};
  std::string result(characters);
  env->ReleaseStringUTFChars(value, characters);
  return result;
}

std::vector<std::string> string_array(JNIEnv *env, jobjectArray values) {
  std::vector<std::string> result;
  if (values == nullptr)
    return result;
  const jsize count = env->GetArrayLength(values);
  result.reserve(static_cast<size_t>(count));
  for (jsize index = 0; index < count; ++index) {
    auto value =
        static_cast<jstring>(env->GetObjectArrayElement(values, index));
    result.push_back(string_value(env, value, "array value"));
    env->DeleteLocalRef(value);
  }
  return result;
}

std::vector<const char *> string_pointers(
    const std::vector<std::string> &values) {
  std::vector<const char *> result;
  result.reserve(values.size());
  for (const auto &value : values)
    result.push_back(value.c_str());
  return result;
}

} // namespace

extern "C" JNIEXPORT void JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeStart(
    JNIEnv *env, jobject, jstring root_value, jstring entrypoint_value,
    jobjectArray load_path_values, jobjectArray environment_keys,
    jobjectArray environment_values, jstring error_path_value,
    jstring stop_path_value) {
  const std::string root = string_value(env, root_value, "projectRoot");
  const std::string entrypoint =
      string_value(env, entrypoint_value, "entrypoint");
  const std::vector<std::string> load_paths =
      string_array(env, load_path_values);
  const std::vector<std::string> keys = string_array(env, environment_keys);
  const std::vector<std::string> values =
      string_array(env, environment_values);
  const std::string error_path =
      string_value(env, error_path_value, "errorFilePath");
  const std::string stop_path =
      string_value(env, stop_path_value, "stopSignalPath");
  if (env->ExceptionCheck())
    return;
  if (keys.size() != values.size()) {
    fail(env, "invalid environment");
    return;
  }

  const std::vector<const char *> load_path_pointers =
      string_pointers(load_paths);
  const std::vector<const char *> key_pointers = string_pointers(keys);
  const std::vector<const char *> value_pointers = string_pointers(values);
  const int status = ruflet_vm_start(
      root.c_str(), entrypoint.c_str(), load_path_pointers.data(),
      load_path_pointers.size(), key_pointers.data(), value_pointers.data(),
      key_pointers.size(), stop_path.c_str(), error_path.c_str());
  if (status != 0) {
    fail(env,
         "start requires a .rb entrypoint inside projectRoot for full CRuby.");
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeStop(JNIEnv *,
                                                              jobject) {
  ruflet_vm_stop();
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeIsRunning(JNIEnv *,
                                                                   jobject) {
  return ruflet_vm_is_running() ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeLastError(
    JNIEnv *env, jobject) {
  const size_t size = ruflet_vm_copy_error(nullptr, 0);
  if (size <= 1)
    return env->NewStringUTF("");
  std::vector<char> error(size, '\0');
  ruflet_vm_copy_error(error.data(), error.size());
  return env->NewStringUTF(error.data());
}
