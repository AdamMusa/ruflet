#include "ruflet_in_process_bridge.h"

#include <jni.h>

#include <cstdint>

extern "C" JNIEXPORT jboolean JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeBridgeSend(
    JNIEnv *env, jobject, jbyteArray message) {
  if (message == nullptr) {
    return JNI_FALSE;
  }

  const jsize length = env->GetArrayLength(message);
  jbyte *bytes = env->GetByteArrayElements(message, nullptr);
  if (bytes == nullptr && length > 0) {
    return JNI_FALSE;
  }
  const int status = ruflet_bridge_send_to_ruby(
      reinterpret_cast<const uint8_t *>(bytes), static_cast<size_t>(length));
  if (bytes != nullptr) {
    env->ReleaseByteArrayElements(message, bytes, JNI_ABORT);
  }
  return status == RUFLET_BRIDGE_MESSAGE ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeBridgeReceive(
    JNIEnv *env, jobject) {
  uint8_t *bytes = nullptr;
  size_t length = 0;
  const int status = ruflet_bridge_receive_for_renderer(&bytes, &length);
  if (status == RUFLET_BRIDGE_CLOSED) {
    return nullptr;
  }
  if (status != RUFLET_BRIDGE_MESSAGE || length > static_cast<size_t>(INT32_MAX)) {
    ruflet_bridge_free_message(bytes);
    return nullptr;
  }

  jbyteArray message = env->NewByteArray(static_cast<jsize>(length));
  if (message != nullptr && length > 0) {
    env->SetByteArrayRegion(message, 0, static_cast<jsize>(length),
                            reinterpret_cast<const jbyte *>(bytes));
  }
  ruflet_bridge_free_message(bytes);
  return message;
}

extern "C" JNIEXPORT void JNICALL
Java_com_izeesoft_ruby_1runtime_MrubyRuntimePlugin_nativeBridgeClose(
    JNIEnv *, jobject) {
  ruflet_bridge_close();
}
