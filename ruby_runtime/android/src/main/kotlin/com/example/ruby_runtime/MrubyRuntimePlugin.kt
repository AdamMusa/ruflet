package com.example.ruby_runtime

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

class MrubyRuntimePlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    private external fun nativeEval(code: String): String
    private external fun nativeRunFile(path: String): String
    private external fun nativeStartFileServer(path: String, stopSignalPath: String): String
    private external fun nativeReset()

    @Volatile
    private var serverRunning: Boolean = false
    private var serverThread: Thread? = null
    private var stopSignalPath: String? = null

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

                "startFileServer" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_args", "Missing 'path' argument.", null)
                        return
                    }
                    if (serverRunning) {
                        result.success(null)
                        return
                    }

                    val stopPathArg = call.argument<String>("stopSignalPath")
                    val stopPath = if (stopPathArg.isNullOrBlank()) "$path.stop" else stopPathArg
                    stopSignalPath = stopPath
                    File(stopPath).delete()

                    serverRunning = true
                    val worker = Thread {
                        try {
                            nativeStartFileServer(path, stopPath)
                        } catch (_: Throwable) {
                            // Keep plugin resilient; Dart side handles reconnect logic.
                        } finally {
                            serverRunning = false
                        }
                    }
                    serverThread = worker
                    worker.start()
                    result.success(null)
                }

                "stopFileServer" -> {
                    val stopPath = stopSignalPath
                    if (!stopPath.isNullOrBlank()) {
                        File(stopPath).writeText("stop")
                    }
                    serverThread?.interrupt()
                    result.success(null)
                }

                "isFileServerRunning" -> {
                    result.success(serverRunning)
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
