package com.example.gps_inf

import android.os.Bundle
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "wake_lock").setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireWakeLock" -> {
                    acquireWakeLock()
                    result.success("WakeLock acquired")
                }
                "releaseWakeLock" -> {
                    releaseWakeLock()
                    result.success("WakeLock released")
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "MyApp::MyWakeLockTag")
            wakeLock?.acquire(10 * 60 * 1000L /*10 minutes*/)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.release()
        wakeLock = null
    }
}
