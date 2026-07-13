package com.izeesoft.ruby_runtime

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MrubyRuntimePlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    external fun nativeStart(
        projectRoot: String,
        entrypoint: String,
        loadPaths: Array<String>,
        environmentKeys: Array<String>,
        environmentValues: Array<String>,
        errorFilePath: String,
        stopSignalPath: String,
    )
    external fun nativeStop()
    external fun nativeIsRunning(): Boolean
    external fun nativeLastError(): String

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        System.loadLibrary("ruby_runtime")
        channel = MethodChannel(binding.binaryMessenger, "ruflet_runtime")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun status(): Map<String, Any> {
        val running = nativeIsRunning()
        return mapOf(
            "running" to running,
            "error" to nativeLastError(),
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "start" -> {
                    val projectRoot = call.argument<String>("projectRoot")
                    val entrypoint = call.argument<String>("entrypoint")
                    if (projectRoot.isNullOrBlank() || entrypoint.isNullOrBlank()) {
                        result.error(
                            "invalid_args",
                            "Missing projectRoot or entrypoint.",
                            null,
                        )
                        return
                    }
                    val loadPaths = call.argument<List<String>>("loadPaths") ?: emptyList()
                    val environment =
                        call.argument<Map<String, String>>("environment") ?: emptyMap()
                    val stopSignalPath =
                        call.argument<String>("stopSignalPath")?.takeIf { it.isNotBlank() }
                            ?: "$projectRoot/.runtime.stop"
                    val errorFilePath = call.argument<String>("errorFilePath") ?: ""
                    nativeStart(
                        projectRoot,
                        entrypoint,
                        loadPaths.toTypedArray(),
                        environment.keys.toTypedArray(),
                        environment.values.toTypedArray(),
                        errorFilePath,
                        stopSignalPath,
                    )
                    result.success(status())
                }
                "status" -> result.success(status())
                "stop" -> {
                    nativeStop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: RuntimeException) {
            result.error("ruflet_runtime_error", error.message, null)
        }
    }
}
