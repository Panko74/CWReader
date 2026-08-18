package com.cwreader.cwreader

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import java.util.concurrent.LinkedBlockingQueue

/**
 * Streaming audio sink based on [AudioTrack] in MODE_STREAM.
 *
 * PCM chunks are pushed from Dart (a few seconds ahead at most) and written by a
 * dedicated thread, giving gapless, low-latency playback without temporary files.
 */
class CwAudioStreamer(private val context: Context) {
    private val pending = LinkedBlockingQueue<ByteArray>()
    private val poison = ByteArray(0)

    @Volatile
    private var audioTrack: AudioTrack? = null

    @Volatile
    private var writerThread: Thread? = null

    @Volatile
    private var running = false

    private val audioManager by lazy {
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    @Synchronized
    fun init(sampleRate: Int, channels: Int) {
        stopInternal()
        val channelMask =
            if (channels > 1) AudioFormat.CHANNEL_OUT_STEREO else AudioFormat.CHANNEL_OUT_MONO
        val minBuffer = AudioTrack.getMinBufferSize(
            sampleRate,
            channelMask,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuffer <= 0) {
            throw IllegalStateException("getMinBufferSize failed: $minBuffer")
        }
        val bufferSize = maxOf(minBuffer, sampleRate * 2)
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelMask)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .build(),
            )
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()

        audioTrack = track
        running = true
        requestFocus()
        track.play()
        pending.clear()
        writerThread = Thread {
            writeLoop(track)
        }.apply {
            isDaemon = true
            name = "cwreader-audio-writer"
            start()
        }
    }

    fun write(bytes: ByteArray) {
        if (!running) return
        pending.put(bytes)
    }

    fun flush() {
        pending.clear()
        audioTrack?.flush()
    }

    fun pause() {
        audioTrack?.pause()
    }

    fun resume() {
        audioTrack?.play()
    }

    fun getPlayedFrames(): Long {
        audioTrack?.let { return it.playbackHeadPosition.toLong() }
        return 0L
    }

    @Synchronized
    fun stop() {
        stopInternal()
    }

    /**
     * Discards buffered audio while keeping the track alive: the pending queue
     * and the track's internal buffer are flushed and playback restarts from a
     * clean state (head position reset to zero). Used on seek / settings regen
     * while playing, where [flush] alone would be a no-op (AudioTrack only
     * flushes when paused or stopped).
     */
    @Synchronized
    fun reset() {
        val track = audioTrack ?: return
        running = false
        try {
            track.pause()
        } catch (_: Throwable) {
        }
        try {
            track.flush()
        } catch (_: Throwable) {
        }
        pending.clear()
        pending.put(poison)
        val thread = writerThread
        writerThread = null
        thread?.join(500)
        try {
            track.play()
        } catch (_: Throwable) {
            // keep going even if the track cannot be restarted
        }
        running = true
        pending.clear()
        writerThread = Thread { writeLoop(track) }.apply {
            isDaemon = true
            name = "cwreader-audio-writer"
            start()
        }
    }

    private fun stopWriter() {
        running = false
        pending.clear()
        pending.put(poison)
        val thread = writerThread
        writerThread = null
        thread?.join(500)
    }

    private fun stopInternal() {
        stopWriter()
        audioTrack?.let {
            try {
                it.pause()
                it.flush()
                it.stop()
            } finally {
                it.release()
            }
        }
        audioTrack = null
        abandonFocus()
    }

    private fun writeLoop(track: AudioTrack) {
        try {
            while (true) {
                val chunk = pending.take()
                if (chunk === poison || !running) break
                var written = 0
                while (written < chunk.size) {
                    if (!running) break
                    val n = track.write(chunk, written, chunk.size - written)
                    if (n <= 0) break
                    written += n
                }
            }
        } catch (_: InterruptedException) {
            // thread is shutting down
        } catch (_: Throwable) {
            // write errors are not fatal for the app
        }
    }

    private fun requestFocus() {
        try {
            audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN,
            )
        } catch (_: Throwable) {
            // ignore
        }
    }

    private fun abandonFocus() {
        try {
            audioManager.abandonAudioFocus(null)
        } catch (_: Throwable) {
            // ignore
        }
    }
}