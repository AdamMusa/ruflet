package com.izeesoft.ruby_runtime

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MrubyRuntimePlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    external fun nativeEval(code: String): String
    external fun nativeRunFile(path: String): String
    external fun nativeReset()
    external fun nativeStartFileServer(path: String, stopSignalPath: String): String
    external fun nativeStopFileServer()
    external fun nativeIsFileServerRunning(): Boolean
    external fun nativeLastFileServerError(): String

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        System.loadLibrary("ruby_runtime")
        channel = MethodChannel(binding.binaryMessenger, "ruby_runtime")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "eval" -> {
                    val code = call.argument<String>("code")
                    if (code.isNullOrEmpty()) {
                        result.error("invalid_args", "Missing 'code' argument.", null)
                    } else {
                        result.success(nativeEval(code))
                    }
                }
                "runFile" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("invalid_args", "Missing 'path' argument.", null)
                    } else {
                        result.success(nativeRunFile(path))
                    }
                }
                "reset" -> {
                    nativeReset()
                    result.success(null)
                }
                "startFileServer" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("invalid_args", "Missing 'path' argument.", null)
                    } else {
                        val stopSignalPath =
                            call.argument<String>("stopSignalPath")?.takeIf { it.isNotBlank() }
                                ?: "$path.stop"
                        nativeStartFileServer(path, stopSignalPath)
                        result.success(null)
                    }
                }
                "stopFileServer" -> {
                    nativeStopFileServer()
                    result.success(null)
                }
                "isFileServerRunning" -> result.success(nativeIsFileServerRunning())
                "lastFileServerError" -> result.success(nativeLastFileServerError())
                else -> result.notImplemented()
            }
        } catch (error: RuntimeException) {
            result.error("mruby_error", error.message, null)
        }
    }
}
