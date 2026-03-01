package com.example.ruby_runtime

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MrubyRuntimePlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    private external fun nativeEval(code: String): String
    private external fun nativeRunFile(path: String): String
    private external fun nativeReset()

    companion object {
        init {
            System.loadLibrary("ruby_runtime")
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ruby_runtime")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "eval" -> {
                    val code = call.argument<String>("code")
                    if (code.isNullOrBlank()) {
                        result.error("invalid_args", "Missing 'code' argument.", null)
                        return
                    }
                    result.success(nativeEval(code))
                }

                "runFile" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_args", "Missing 'path' argument.", null)
                        return
                    }
                    result.success(nativeRunFile(path))
                }

                "reset" -> {
                    nativeReset()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("mruby_error", e.message ?: "Unknown mruby error", null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
