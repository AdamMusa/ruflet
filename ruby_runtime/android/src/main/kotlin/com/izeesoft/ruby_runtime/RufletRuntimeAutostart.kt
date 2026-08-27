package com.izeesoft.ruby_runtime

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Platform-side startup for the embedded Ruby VM.
 *
 * Runs from an androidx.startup initializer, which Android creates as a
 * ContentProvider before Application.onCreate and long before the FlutterEngine
 * exists. The VM boots on a background thread in parallel with the engine, so
 * by the time Dart calls serverUrl() the embedded server has usually already
 * bound its port.
 *
 * Unlike Apple platforms, Android assets are entries inside the APK rather than
 * files on disk, so the packaged project has to be unpacked before mruby can
 * require anything from it. Doing that here rather than in Dart takes it off
 * the startup critical path, and the copy is skipped on every launch after the
 * first because the unpacked tree is keyed to the install.
 *
 * Opt-in, because a server-driven app has no packaged project and must not boot
 * a VM. In the application's AndroidManifest:
 *
 *     <meta-data android:name="ruflet.runtime.autostart" android:value="true" />
 *     <meta-data android:name="ruflet.runtime.project" android:value="demo" />
 *
 * The project name is only needed when an app packages more than one.
 */
internal object RufletRuntimeAutostart {
    private const val TAG = "RufletRuntime"
    private const val AUTOSTART_KEY = "ruflet.runtime.autostart"
    private const val PROJECT_KEY = "ruflet.runtime.project"
    private const val PROFILE_KEY = "ruflet.runtime.profile"
    private const val ASSET_ROOT = "flutter_assets/assets"
    private const val CRUBY_ASSET_ROOT = "ruflet_cruby"
    private const val CRUBY_ABI = "4.0.0"
    private const val BIND_TIMEOUT_MS = 30_000L

    /**
     * The JNI entry points are bound to MrubyRuntimePlugin's exact class and
     * method names inside the prebuilt .so, so calls go through an instance of
     * it. Declaring the externals again on this object would compile but fail
     * at runtime with UnsatisfiedLinkError.
     */
    private val bridge by lazy { MrubyRuntimePlugin() }

    private val ready = CountDownLatch(1)

    @Volatile private var startedAtNanos: Long = 0L
    @Volatile private var serverUrl: String? = null
    @Volatile private var failure: String? = null

    @Volatile
    var attempted: Boolean = false
        private set

    /** Milliseconds since the initializer ran, for startup measurement. */
    fun millisSinceLoad(): Double {
        if (startedAtNanos == 0L) return -1.0
        return (SystemClock.elapsedRealtimeNanos() - startedAtNanos) / 1_000_000.0
    }

    fun beginIfEnabled(context: Context) {
        startedAtNanos = SystemClock.elapsedRealtimeNanos()
        if (!autostartEnabled(context)) return
        // No packaged project means a server-driven app, which must not boot a
        // VM. Checking for one here is what lets autostart be on by default.
        if (runCatching { resolveProjectName(context) }.isFailure) return

        attempted = true
        val appContext = context.applicationContext
        // Off the main thread: this runs during process creation and anything
        // slow here delays the whole app, which would trade the win away.
        Thread({ begin(appContext) }, "ruflet-runtime-autostart").apply {
            isDaemon = true
            start()
        }
    }

    /**
     * Blocks until the server URL is known. Callers must not run this on the
     * main thread.
     */
    fun awaitUrl(): Result<String> {
        if (!attempted) {
            return Result.failure(
                IllegalStateException(
                    "This app does not start the runtime from the platform layer. " +
                        "Set ruflet.runtime.autostart in AndroidManifest to use " +
                        "serverUrl(), or call start() instead.",
                ),
            )
        }
        if (!ready.await(BIND_TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
            return Result.failure(
                IllegalStateException("The embedded Ruflet server did not publish a port."),
            )
        }
        serverUrl?.let { return Result.success(it) }
        return Result.failure(
            IllegalStateException(failure ?: "The embedded runtime failed to start."),
        )
    }

    /// On unless the application explicitly opts out. What actually decides it
    /// is whether a packaged project exists -- see [beginIfEnabled].
    private fun autostartEnabled(context: Context): Boolean =
        metaData(context)?.getBoolean(AUTOSTART_KEY, true) ?: true

    /**
     * Copies the autostarted server's port into [path] once it is known.
     *
     * A client generated before serverUrl() existed calls start() and then
     * polls the file it named in RUFLET_RUNTIME_PORT_FILE. Its arguments cannot
     * take effect, but the thing it is waiting for already exists, so hand it
     * over there. Those clients keep working -- and get the parallel startup --
     * without knowing anything about it.
     */
    fun mirrorPort(path: String) {
        if (path.isBlank()) return
        Thread({
            awaitUrl().getOrNull()?.substringAfterLast(':')?.let { port ->
                runCatching { File(path).writeText(port) }
            }
        }, "ruflet-runtime-mirror").apply { isDaemon = true }.start()
    }

    private fun metaData(context: Context) =
        try {
            context.packageManager
                .getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
                .metaData
        } catch (error: PackageManager.NameNotFoundException) {
            Log.w(TAG, "Unable to read application metadata", error)
            null
        }

    private fun begin(context: Context) {
        try {
            System.loadLibrary("ruby_runtime")
            val libraryLoadedAt = millisSinceLoad()

            val projectRoot = unpackProject(context)
            val unpackedAt = millisSinceLoad()

            val loadPaths = mutableListOf(projectRoot.absolutePath)
            val profile = runtimeProfile(context)
            if (profile == "full") {
                val runtimeRoot = unpackCRuby(context)
                val rubyLib = File(runtimeRoot, "lib/ruby/$CRUBY_ABI")
                loadPaths += rubyLib.absolutePath
                loadPaths += File(rubyLib, crubyArchitecture()).absolutePath
            }

            val entrypoint = entrypointAt(projectRoot, profile)
            if (entrypoint == null) {
                finish(null, "The packaged Ruflet project does not contain main.mrb or main.rb.")
                return
            }

            // The unpacked tree is reused across launches, so scratch files live
            // beside it and are cleared here rather than accumulating.
            val scratch = File(context.filesDir, "ruflet/runtime").apply { mkdirs() }
            val portFile = File(scratch, "server.port")
            val errorFile = File(scratch, "server.error")
            val stopFile = File(scratch, "server.stop")
            listOf(portFile, errorFile, stopFile).forEach { it.delete() }

            bridge.nativeStart(
                projectRoot.absolutePath,
                entrypoint.absolutePath,
                loadPaths.toTypedArray(),
                arrayOf(
                    "RUFLET_PORT",
                    "RUFLET_ASSETS_DIR",
                    "RUFLET_RUNTIME_PORT_FILE",
                    "RUFLET_RUNTIME_ERROR_FILE",
                    "RUFLET_SUPPRESS_SERVER_BANNER",
                ),
                arrayOf(
                    "0",
                    File(projectRoot, "assets").absolutePath,
                    portFile.absolutePath,
                    errorFile.absolutePath,
                    "1",
                ),
                errorFile.absolutePath,
                stopFile.absolutePath,
            )

            awaitPort(portFile, errorFile)

            // Cheap, and the only way to tell unpacking from VM boot when
            // diagnosing startup on a real device.
            Log.i(
                TAG,
                "startup: library=%.0fms unpack=%.0fms boot=%.0fms total=%.0fms".format(
                    libraryLoadedAt,
                    unpackedAt - libraryLoadedAt,
                    millisSinceLoad() - unpackedAt,
                    millisSinceLoad(),
                ),
            )
        } catch (error: Throwable) {
            finish(null, "${error.javaClass.simpleName}: ${error.message}")
        }
    }

    private fun awaitPort(portFile: File, errorFile: File) {
        val deadline = SystemClock.elapsedRealtime() + BIND_TIMEOUT_MS
        while (SystemClock.elapsedRealtime() < deadline) {
            val port = portFile.takeIf { it.isFile }?.readText()?.trim()?.toIntOrNull() ?: 0
            if (port > 0) {
                finish("http://127.0.0.1:$port", null)
                return
            }
            val reported = errorFile.takeIf { it.isFile }?.readText()?.trim()
            if (!reported.isNullOrEmpty()) {
                finish(null, reported)
                return
            }
            Thread.sleep(1)
        }
        finish(null, "The embedded Ruflet server did not publish a port.")
    }

    private fun finish(url: String?, error: String?) {
        serverUrl = url
        failure = error
        if (error != null) Log.e(TAG, "Embedded runtime failed to start: $error")
        ready.countDown()
    }

    /**
     * Copies the packaged project out of the APK, once per install. The stamp
     * records which install the unpacked tree came from, so an app update
     * re-unpacks and an ordinary launch does not.
     */
    private fun unpackProject(context: Context): File {
        val project = resolveProjectName(context)
        val destination = File(context.filesDir, "ruflet/$project")
        val stamp = File(context.filesDir, "ruflet/.stamp")
        val installed = installIdentity(context)

        if (destination.isDirectory && stamp.isFile && stamp.readText() == installed) {
            return destination
        }

        destination.deleteRecursively()
        destination.mkdirs()
        copyAssetTree(context, "$ASSET_ROOT/$project", destination)
        stamp.parentFile?.mkdirs()
        stamp.writeText(installed)
        return destination
    }

    private fun installIdentity(context: Context): String =
        try {
            "${context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime}"
        } catch (error: PackageManager.NameNotFoundException) {
            "unknown"
        }

    private fun runtimeProfile(context: Context): String =
        metaData(context)?.getString(PROFILE_KEY).orEmpty()

    /** Extracts CRuby's standard library once per installed full build. */
    private fun unpackCRuby(context: Context): File {
        val destination = File(context.filesDir, "ruflet/cruby")
        val stamp = File(context.filesDir, "ruflet/.cruby-stamp")
        val installed = installIdentity(context)
        if (destination.isDirectory && stamp.isFile && stamp.readText() == installed) {
            return destination
        }

        destination.deleteRecursively()
        destination.mkdirs()
        copyAssetTree(context, CRUBY_ASSET_ROOT, destination)
        stamp.parentFile?.mkdirs()
        stamp.writeText(installed)
        return destination
    }

    private fun crubyArchitecture(): String =
        when (Build.SUPPORTED_ABIS.firstOrNull()) {
            "arm64-v8a" -> "aarch64-linux-gnu-android"
            "armeabi-v7a" -> "arm-linux-gnu-android"
            "x86_64" -> "x86_64-linux-gnu-android"
            "x86" -> "i686-linux-gnu-android"
            else -> throw IllegalStateException(
                "The full CRuby runtime does not support ${Build.SUPPORTED_ABIS.joinToString()}.",
            )
        }

    /**
     * The packaged project is the single directory under flutter_assets/assets
     * holding a main.mrb or main.rb, unless the manifest names one.
     */
    private fun resolveProjectName(context: Context): String {
        metaData(context)?.getString(PROJECT_KEY)?.takeIf { it.isNotBlank() }?.let { return it }

        val assets = context.assets
        val candidates = (assets.list(ASSET_ROOT) ?: emptyArray()).filter { entry ->
            val files = assets.list("$ASSET_ROOT/$entry") ?: emptyArray()
            files.contains("main.mrb") || files.contains("main.rb")
        }
        return when (candidates.size) {
            1 -> candidates.single()
            0 -> throw IllegalStateException(
                "No packaged Ruby project was found in the app. " +
                    "Build with `ruflet build --self`.",
            )
            else -> throw IllegalStateException(
                "Multiple packaged Ruflet projects found (${candidates.joinToString()}). " +
                    "Name one with ruflet.runtime.project in AndroidManifest.",
            )
        }
    }

    private fun entrypointAt(root: File, profile: String): File? {
        val candidates = if (profile == "full") listOf("main.rb") else listOf("main.mrb", "main.rb")
        return candidates.map { File(root, it) }.firstOrNull { it.isFile }
    }

    private fun copyAssetTree(context: Context, assetPath: String, destination: File) {
        val entries = context.assets.list(assetPath) ?: emptyArray()
        if (entries.isEmpty()) {
            // A leaf: AssetManager reports files as having no children.
            destination.parentFile?.mkdirs()
            context.assets.open(assetPath).use { input ->
                destination.outputStream().use { output -> input.copyTo(output) }
            }
            return
        }
        destination.mkdirs()
        for (entry in entries) {
            copyAssetTree(context, "$assetPath/$entry", File(destination, entry))
        }
    }
}
