package com.entaku.simpleRecord.play

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaPlayer
import android.media.PlaybackParams
import android.media.audiofx.LoudnessEnhancer
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException
import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.sqrt

// Playbackの状態をまとめたデータクラス
data class PlaybackState(
    val isPlaying: Boolean = false,
    val currentPosition: Int = 0,
    val duration: Int = 0,
    val playbackSpeed: Float = 1.0f,
    val isRepeatOne: Boolean = false,
    val abLoopStart: Int? = null,
    val abLoopEnd: Int? = null,
    val waveformData: List<Float> = emptyList(),
    val volumeBoost: Float = PlaybackViewModel.DEFAULT_VOLUME_BOOST
)

class PlaybackViewModel : ViewModel() {

    companion object {
        // iOS版(PlaybackFeature.swift)と同じレンジ: 1.0x(ブーストなし)〜3.0x
        const val MIN_VOLUME_BOOST = 1.0f
        const val MAX_VOLUME_BOOST = 3.0f
        const val DEFAULT_VOLUME_BOOST = MIN_VOLUME_BOOST

        // LoudnessEnhancerのtarget gainの安全上限(mB=1/100dB)。
        // 音割れ・スピーカー保護のため20dBを超えては増幅しない。
        private const val MAX_TARGET_GAIN_MILLIBEL = 2000
    }

    // 状態をStateFlowにまとめる
    private val _playbackState = MutableStateFlow(PlaybackState())
    val playbackState: StateFlow<PlaybackState> = _playbackState

    private var mediaPlayer: MediaPlayer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var updateJob: Job? = null
    private var onCompletionCallback: (() -> Unit)? = null

    fun setupMediaPlayer(filePath: String) {
        mediaPlayer = MediaPlayer().apply {
            try {
                setDataSource(filePath)
                prepare()

                setOnCompletionListener {
                    if (_playbackState.value.isRepeatOne) {
                        seekTo(0)
                        start()
                        _playbackState.update { it.copy(currentPosition = 0) }
                    } else {
                        _playbackState.update { it.copy(isPlaying = false, currentPosition = 0) }
                        onCompletionCallback?.invoke()
                    }
                }

                _playbackState.update { it.copy(duration = duration) }

                try {
                    loudnessEnhancer = LoudnessEnhancer(audioSessionId)
                    applyVolumeBoost(_playbackState.value.volumeBoost)
                } catch (e: Exception) {
                    // LoudnessEnhancerが使えない機種でも再生自体は継続する
                    Log.e("Playback", "Failed to initialize LoudnessEnhancer", e)
                    loudnessEnhancer = null
                }
            } catch (e: IOException) {
                Log.e("MediaPlayer", "Failed to set data source", e)
            } catch (e: IllegalStateException) {
                Log.e("MediaPlayer", "Illegal state during media preparation", e)
            }
        }
        viewModelScope.launch { extractWaveform(filePath) }
    }

    /**
     * Set volume boost (loudness enhancement) applied on top of normal playback volume.
     * Value is clamped to [MIN_VOLUME_BOOST, MAX_VOLUME_BOOST] to avoid excessive
     * amplification that could distort audio or stress the device speaker.
     */
    fun setVolumeBoost(boost: Float) {
        val clamped = boost.coerceIn(MIN_VOLUME_BOOST, MAX_VOLUME_BOOST)
        _playbackState.update { it.copy(volumeBoost = clamped) }
        applyVolumeBoost(clamped)
    }

    private fun applyVolumeBoost(boost: Float) {
        val enhancer = loudnessEnhancer ?: return
        try {
            val gainMillibel = boostToTargetGainMillibel(boost)
            enhancer.setTargetGain(gainMillibel)
            enhancer.enabled = gainMillibel > 0
        } catch (e: Exception) {
            Log.e("Playback", "Failed to apply volume boost", e)
        }
    }

    /**
     * Convert a linear volume multiplier (1.0x = no boost) into LoudnessEnhancer's
     * target gain in millibel (1/100 dB), clamped to a safe upper bound.
     */
    private fun boostToTargetGainMillibel(boost: Float): Int {
        val clamped = boost.coerceIn(MIN_VOLUME_BOOST, MAX_VOLUME_BOOST)
        val gainDb = 20.0 * log10(clamped.toDouble())
        return (gainDb * 100).toInt().coerceIn(0, MAX_TARGET_GAIN_MILLIBEL)
    }

    private suspend fun extractWaveform(filePath: String, targetSamples: Int = 100) {
        val result = withContext(Dispatchers.IO) {
            val extractor = MediaExtractor()
            try {
                extractor.setDataSource(filePath)
                val trackIndex = (0 until extractor.trackCount).firstOrNull { i ->
                    extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
                } ?: return@withContext emptyList<Float>()

                extractor.selectTrack(trackIndex)
                val format = extractor.getTrackFormat(trackIndex)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: return@withContext emptyList<Float>()

                val codec = MediaCodec.createDecoderByType(mime)
                codec.configure(format, null, null, 0)
                codec.start()

                val rmsValues = mutableListOf<Float>()
                val chunkBuffer = mutableListOf<Short>()
                val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION))
                    format.getLong(MediaFormat.KEY_DURATION) else 0L
                val chunkSize = if (durationUs > 0)
                    (durationUs / 1_000_000.0 * 44100 / targetSamples).toInt().coerceAtLeast(1)
                else 4410

                var sawEos = false
                val bufferInfo = MediaCodec.BufferInfo()

                while (!sawEos || rmsValues.size < targetSamples) {
                    // feed input
                    if (!sawEos) {
                        val inputIndex = codec.dequeueInputBuffer(10_000)
                        if (inputIndex >= 0) {
                            val buf = codec.getInputBuffer(inputIndex)!!
                            val sampleSize = extractor.readSampleData(buf, 0)
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                sawEos = true
                            } else {
                                codec.queueInputBuffer(inputIndex, 0, sampleSize, extractor.sampleTime, 0)
                                extractor.advance()
                            }
                        }
                    }
                    // drain output
                    val outputIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000)
                    if (outputIndex >= 0) {
                        val outBuf = codec.getOutputBuffer(outputIndex)!!
                        val shortArray = ShortArray(bufferInfo.size / 2)
                        outBuf.asShortBuffer().get(shortArray)
                        chunkBuffer.addAll(shortArray.toList())

                        while (chunkBuffer.size >= chunkSize) {
                            val chunk = chunkBuffer.subList(0, chunkSize)
                            val rms = sqrt(chunk.sumOf { (it * it).toDouble() } / chunkSize).toFloat()
                            rmsValues.add(rms / Short.MAX_VALUE)
                            repeat(chunkSize) { if (chunkBuffer.isNotEmpty()) chunkBuffer.removeAt(0) }
                        }
                        codec.releaseOutputBuffer(outputIndex, false)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                    }
                }

                codec.stop()
                codec.release()
                extractor.release()

                // normalize
                val max = rmsValues.maxOrNull()?.takeIf { it > 0f } ?: 1f
                rmsValues.map { (it / max).coerceIn(0f, 1f) }
            } catch (e: Exception) {
                Log.e("Waveform", "extraction failed", e)
                extractor.release()
                emptyList()
            }
        }
        if (result.isNotEmpty()) {
            _playbackState.update { it.copy(waveformData = result) }
        }
    }

    fun setPlaybackSpeed(speed: Float) {
        mediaPlayer?.let {
            try {
                val params = PlaybackParams().apply {
                    this.speed = speed
                    pitch = 1.0f // ピッチは変更しない
                }
                it.playbackParams = params
                _playbackState.update { currentState ->
                    currentState.copy(playbackSpeed = speed)
                }
            } catch (e: IllegalStateException) {
                Log.e("MediaPlayer", "Error setting playback speed", e)
            }
        }
    }

    fun playOrPause() {
        mediaPlayer?.let {
            if (_playbackState.value.isPlaying) {
                it.pause()
                stopUpdatingProgress()
                Log.d("Playback", "Paused")
                _playbackState.update { currentState ->
                    currentState.copy(isPlaying = false)
                }
            } else {
                try {
                    it.start()
                    Log.d("Playback", "Started")
                    _playbackState.update { currentState ->
                        currentState.copy(isPlaying = true)
                    }

                    // 進行状況の更新を開始
                    startUpdatingProgress()
                } catch (e: IllegalStateException) {
                    Log.e("MediaPlayer", "Error starting playback", e)
                }
            }
        }
    }

    private fun startUpdatingProgress() {
        updateJob?.cancel()
        updateJob = viewModelScope.launch {
            while (_playbackState.value.isPlaying) {
                val position = mediaPlayer?.currentPosition ?: 0
                val state = _playbackState.value
                val loopStart = state.abLoopStart
                val loopEnd = state.abLoopEnd
                if (loopStart != null && loopEnd != null && position >= loopEnd) {
                    mediaPlayer?.seekTo(loopStart)
                    _playbackState.update { it.copy(currentPosition = loopStart) }
                } else {
                    _playbackState.update { it.copy(currentPosition = position) }
                }
                delay(100)
            }
        }
    }

    private fun stopUpdatingProgress() {
        updateJob?.cancel()
        updateJob = null
    }

    fun stopPlayback() {
        mediaPlayer?.let {
            try {
                if (it.isPlaying) {
                    it.stop()
                }
                it.reset()
                it.release()
            } catch (e: IllegalStateException) {
                Log.e("MediaPlayer", "Error stopping media player", e)
            } finally {
                mediaPlayer = null
            }
        }
        releaseLoudnessEnhancer()
        stopUpdatingProgress()
        _playbackState.update { currentState ->
            currentState.copy(
                isPlaying = false,
                currentPosition = 0
            )
        }
    }

    /**
     * Set callback to be invoked when track completes
     * Used for playlist continuous playback
     */
    fun setOnCompletionListener(callback: () -> Unit) {
        onCompletionCallback = callback
    }

    /**
     * Clear completion callback
     */
    fun clearOnCompletionListener() {
        onCompletionCallback = null
    }

    /**
     * Get current playback duration
     */
    fun getDuration(): Int {
        return mediaPlayer?.duration ?: 0
    }

    fun toggleRepeatOne() {
        _playbackState.update { it.copy(isRepeatOne = !it.isRepeatOne) }
    }

    fun setAbLoopStart() {
        val position = mediaPlayer?.currentPosition ?: _playbackState.value.currentPosition
        _playbackState.update { it.copy(abLoopStart = position, abLoopEnd = null) }
    }

    fun setAbLoopEnd() {
        val position = mediaPlayer?.currentPosition ?: _playbackState.value.currentPosition
        val loopStart = _playbackState.value.abLoopStart ?: return
        if (position > loopStart) {
            _playbackState.update { it.copy(abLoopEnd = position) }
        }
    }

    fun clearAbLoop() {
        _playbackState.update { it.copy(abLoopStart = null, abLoopEnd = null) }
    }

    /**
     * Seek to specific position in milliseconds
     */
    fun seekTo(position: Int) {
        mediaPlayer?.let {
            try {
                it.seekTo(position)
                _playbackState.update { currentState ->
                    currentState.copy(currentPosition = position)
                }
            } catch (e: IllegalStateException) {
                Log.e("MediaPlayer", "Error seeking to position", e)
            }
        }
    }

    private fun releaseLoudnessEnhancer() {
        try {
            loudnessEnhancer?.release()
        } catch (e: Exception) {
            Log.e("Playback", "Error releasing LoudnessEnhancer", e)
        } finally {
            loudnessEnhancer = null
        }
    }

    override fun onCleared() {
        super.onCleared()
        stopPlayback()
        onCompletionCallback = null
    }
}
