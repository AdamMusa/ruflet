package com.izeesoft.ruby_runtime

import android.content.Context
import androidx.startup.Initializer

/**
 * Starts the embedded Ruby VM as early as an Android process allows.
 *
 * androidx.startup runs initializers from a ContentProvider, which the system
 * creates before Application.onCreate and well before any Activity or the
 * FlutterEngine. That is the whole point: the VM boots in parallel with Flutter
 * rather than after it.
 *
 * The provider entry is contributed by this library's manifest, so applications
 * get it through manifest merging without changing any code. Whether it
 * actually starts anything is still the application's decision -- see
 * ruflet.runtime.autostart in [RufletRuntimeAutostart].
 */
class RufletRuntimeInitializer : Initializer<Unit> {
    override fun create(context: Context) {
        RufletRuntimeAutostart.beginIfEnabled(context)
    }

    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}
