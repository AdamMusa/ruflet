package com.izeesoft.ruby_runtime

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.Executors

class MrubyRuntimePlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    // Answering serverUrl means waiting for the VM to finish booting, which
    // must never happen on the platform thread.
    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "ruflet-runtime-plugin").apply { isDaemon = true }
    }
    private val mainThread = Handler(Looper.getMainLooper())

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
        worker.shutdown()
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
                    // The VM boots once per process. When autostart owns it, a
                    // start() call cannot take effect: nativeStart sees a
                    // running VM and returns without adopting any of the
                    // arguments, so the runtime keeps writing to the paths
                    // autostart chose and the caller waits forever on a port
                    // file nothing will write. Say so instead.
                    if (RufletRuntimeAutostart.attempted) {
                        result.error(
                            "autostart_owns_runtime",
                            "The platform already started the runtime " +
                                "(ruflet.runtime.autostart). Use serverUrl() instead of " +
                                "start(), or turn autostart off.",
                            null,
                        )
                        return
                    }

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
                "serverUrl" -> {
                    val enabled = RufletRuntimeAutostart.attempted
                    worker.execute {
                        val resolved = RufletRuntimeAutostart.awaitUrl()
                        // A MethodChannel result must be delivered on the
                        // platform thread; the wait above must not be.
                        mainThread.post {
                            resolved.fold(
                                onSuccess = { result.success(mapOf("url" to it)) },
                                onFailure = {
                                    result.error(
                                        if (enabled) "ruflet_runtime_error" else "autostart_disabled",
                                        it.message,
                                        null,
                                    )
                                },
                            )
                        }
                    }
                }
                "timeline" ->
                    result.success(mapOf("sinceLoadMs" to RufletRuntimeAutostart.millisSinceLoad()))
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
