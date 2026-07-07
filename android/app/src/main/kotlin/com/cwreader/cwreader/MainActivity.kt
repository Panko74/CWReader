package com.cwreader.cwreader

import android.content.Context
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "cwreader/wake_lock"
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    if (wakeLock == null) {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        wakeLock = pm.newWakeLock(
                            PowerManager.PARTIAL_WAKE_LOCK,
                            "CWReader::AudioWakeLock"
                        )
                    }
                    wakeLock?.acquire()
                    result.success(true)
                }
                "disable" -> {
                    wakeLock?.release()
                    wakeLock = null
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
