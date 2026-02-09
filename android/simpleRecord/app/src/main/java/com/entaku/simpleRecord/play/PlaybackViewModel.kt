package com.entaku.simpleRecord.play

import android.media.MediaPlayer
import android.media.PlaybackParams
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.IOException

// Playbackの状態をまとめたデータクラス
data class PlaybackState(
    val isPlaying: Boolean = false,
    val currentPosition: Int = 0,
    val playbackSpeed: Float = 1.0f
)

class PlaybackViewModel : ViewModel() {

    // 状態をStateFlowにまとめる
    private val _playbackState = MutableStateFlow(PlaybackState())
    val playbackState: StateFlow<PlaybackState> = _playbackState

    private var mediaPlayer: MediaPlayer? = null
    private var updateJob: Job? = null
    private var onCompletionCallback: (() -> Unit)? = null

    fun setupMediaPlayer(filePath: String) {
        mediaPlayer = MediaPlayer().apply {
            try {
                setDataSource(filePath)
                prepare()

                // Set completion listener for playlist playback
                setOnCompletionListener {
                    _playbackState.update { it.copy(isPlaying = false, currentPosition = 0) }
                    onCompletionCallback?.invoke()
                }
            } catch (e: IOException) {
                Log.e("MediaPlayer", "Failed to set data source", e)
            } catch (e: IllegalStateException) {
                Log.e("MediaPlayer", "Illegal state during media preparation", e)
            }
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
        // すでにジョブが実行中の場合はキャンセル
        updateJob?.cancel()

        updateJob = viewModelScope.launch {
            while (_playbackState.value.isPlaying) {
                val position = mediaPlayer?.currentPosition ?: 0
                _playbackState.update { currentState ->
                    currentState.copy(currentPosition = position)
                }
                delay(100) // 100msごとに更新
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

    override fun onCleared() {
        super.onCleared()
        stopPlayback()
        onCompletionCallback = null
    }
}
