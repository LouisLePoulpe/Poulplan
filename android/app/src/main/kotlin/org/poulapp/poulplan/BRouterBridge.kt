package org.poulapp.poulplan

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import btools.routingapp.IBRouterService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Offline routes through the BRouter app, when installed: Poulplan ships no
 * routing engine nor data. Channel `org.poulapp.poulplan/brouter`.
 */
class BRouterBridge(private val context: Context, messenger: BinaryMessenger) {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        MethodChannel(messenger, "org.poulapp.poulplan/brouter").setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(installed())
                "route" -> route(
                    call.argument<List<Double>>("lats")!!.toDoubleArray(),
                    call.argument<List<Double>>("lons")!!.toDoubleArray(),
                    call.argument<String>("vehicle")!!,
                    result,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun installed(): Boolean = try {
        context.packageManager.getPackageInfo(PACKAGE, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    private fun route(lats: DoubleArray, lons: DoubleArray, vehicle: String, result: MethodChannel.Result) {
        val intent = Intent().setClassName(PACKAGE, "$PACKAGE.BRouterService")
        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                val service = IBRouterService.Stub.asInterface(binder)
                val connection = this
                executor.execute {
                    val answer = try {
                        val params = Bundle().apply {
                            putDoubleArray("lats", lats)
                            putDoubleArray("lons", lons)
                            putString("v", vehicle)
                            putBoolean("fast", vehicle == "motorcar")
                            putString("trackFormat", "json")
                        }
                        Result.success(service.getTrackFromParams(params) ?: "")
                    } catch (e: Exception) {
                        Result.failure(e)
                    }
                    main.post {
                        context.unbindService(connection)
                        answer.fold(
                            { result.success(it) },
                            { result.error("BROUTER", it.message, null) },
                        )
                    }
                }
            }

            override fun onServiceDisconnected(name: ComponentName?) {}
        }
        if (!context.bindService(intent, connection, Context.BIND_AUTO_CREATE)) {
            result.error("UNAVAILABLE", "BRouter service not found", null)
        }
    }

    private companion object {
        const val PACKAGE = "btools.routingapp"
    }
}
