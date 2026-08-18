package com.cwreader.cwreader

import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "cwreader/wake_lock"
    private val AUDIO_CHANNEL = "cwreader/audio"
    private var audioStreamer: CwAudioStreamer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    ContextCompat.startForegroundService(
                        this,
                        Intent(this, PlaybackService::class.java)
                    )
                    result.success(true)
                }
                "disable" -> {
                    stopService(Intent(this, PlaybackService::class.java))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val streamer = CwAudioStreamer(this)
        audioStreamer = streamer
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> {
                        val sampleRate = call.argument<Int>("sampleRate") ?: 44100
                        val channels = call.argument<Int>("channels") ?: 1
                        try {
                            streamer.init(sampleRate, channels)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("init_failed", e.message, null)
                        }
                    }
                    "write" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes != null) {
                            streamer.write(bytes)
                            result.success(true)
                        } else {
                            result.error("bad_bytes", "bytes is null", null)
                        }
                    }
                    "flush" -> {
                        streamer.flush()
                        result.success(true)
                    }
                    "reset" -> {
                        streamer.reset()
                        result.success(true)
                    }
                    "pause" -> {
                        streamer.pause()
                        result.success(true)
                    }
                    "resume" -> {
                        streamer.resume()
                        result.success(true)
                    }
                    "getPlayedFrames" -> result.success(streamer.getPlayedFrames())
                    "stop" -> {
                        streamer.stop()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        audioStreamer?.stop()
        audioStreamer = null
        super.onDestroy()
    }
}
