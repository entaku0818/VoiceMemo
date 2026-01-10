package com.entaku.simpleRecord.play

import android.media.MediaPlayer
import android.media.PlaybackParams
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.entaku.simpleRecord.RecordingData
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.IOException

enum class RepeatMode {
    OFF,      // No repeat
    ONE,      // Repeat current track
    ALL       // Repeat entire playlist
}

// Playbackの状態をまとめたデータクラス
data class PlaybackState(
    val isPlaying: Boolean = false,
    val currentPosition: Int = 0,
    val playbackSpeed: Float = 1.0f,
    val repeatMode: RepeatMode = RepeatMode.OFF,
    val isShuffleEnabled: Boolean = false,
    val currentTrackIndex: Int = 0,
    val playlist: List<RecordingData> = emptyList(),
    val shuffledIndices: List<Int> = emptyList(),
    val isPlaylistMode: Boolean = false
)

class PlaybackViewModel : ViewModel() {

    // 状態をStateFlowにまとめる
    private val _playbackState = MutableStateFlow(PlaybackState())
    val playbackState: StateFlow<PlaybackState> = _playbackState

    private var mediaPlayer: MediaPlayer? = null
    private var updateJob: Job? = null

    fun setupMediaPlayer(filePath: String) {
        releaseMediaPlayer()
        mediaPlayer = MediaPlayer().apply {
            try {
                setDataSource(filePath)
                prepare()
                setOnCompletionListener {
                    handleTrackCompletion()
                }
            } catch (e: IOException) {
                Log.e("MediaPlayer", "Failed to set data source", e)
            } catch (e: IllegalStateException) {
                Log.e("MediaPlayer", "Illegal state during media preparation", e)
            }
        }
    }

    fun setupPlaylist(recordings: List<RecordingData>, startIndex: Int) {
        if (recordings.isEmpty()) return

        val shuffledIndices = if (_playbackState.value.isShuffleEnabled) {
            createShuffledIndices(recordings.size, startIndex)
        } else {
            recordings.indices.toList()
        }

        _playbackState.update { currentState ->
            currentState.copy(
                playlist = recordings,
                currentTrackIndex = startIndex,
                shuffledIndices = shuffledIndices,
                isPlaylistMode = true
            )
        }

        val actualIndex = if (_playbackState.value.isShuffleEnabled) {
            shuffledIndices.indexOf(startIndex).takeIf { it >= 0 } ?: 0
        } else {
            startIndex
        }

        playTrackAtIndex(actualIndex)
    }

    private fun createShuffledIndices(size: Int, startIndex: Int): List<Int> {
        val indices = (0 until size).toMutableList()
        indices.shuffle()
        // Move the start index to the front
        indices.remove(startIndex)
        indices.add(0, startIndex)
        return indices
    }

    private fun playTrackAtIndex(index: Int) {
        val state = _playbackState.value
        val playlist = state.playlist
        if (playlist.isEmpty()) return

        val actualIndex = if (state.isShuffleEnabled) {
            state.shuffledIndices.getOrNull(index) ?: return
        } else {
            index
        }

        if (actualIndex < 0 || actualIndex >= playlist.size) return

        val recording = playlist[actualIndex]

        _playbackState.update { currentState ->
            currentState.copy(
                currentTrackIndex = actualIndex,
                currentPosition = 0,
                isPlaying = false
            )
        }

        setupMediaPlayer(recording.filePath)
        playOrPause() // Auto-play
    }

    private fun handleTrackCompletion() {
        val state = _playbackState.value

        stopUpdatingProgress()
        _playbackState.update { it.copy(isPlaying = false) }

        if (!state.isPlaylistMode) {
            // Single track mode
            when (state.repeatMode) {
                RepeatMode.ONE, RepeatMode.ALL -> {
                    mediaPlayer?.seekTo(0)
                    playOrPause()
                }
                RepeatMode.OFF -> {
                    // Do nothing, playback ends
                }
            }
            return
        }

        // Playlist mode
        when (state.repeatMode) {
            RepeatMode.ONE -> {
                // Repeat current track
                mediaPlayer?.seekTo(0)
                playOrPause()
            }
            RepeatMode.ALL -> {
                // Play next track, loop to start if at end
                val nextIndex = getNextTrackIndex(state)
                playTrackAtIndex(nextIndex)
            }
            RepeatMode.OFF -> {
                // Play next track if available
                val currentIndex = if (state.isShuffleEnabled) {
                    state.shuffledIndices.indexOf(state.currentTrackIndex)
                } else {
                    state.currentTrackIndex
                }

                if (currentIndex < state.playlist.size - 1) {
                    playTrackAtIndex(currentIndex + 1)
                }
                // Otherwise, playback ends
            }
        }
    }

    private fun getNextTrackIndex(state: PlaybackState): Int {
        val currentIndex = if (state.isShuffleEnabled) {
            state.shuffledIndices.indexOf(state.currentTrackIndex)
        } else {
            state.currentTrackIndex
        }

        val nextIndex = currentIndex + 1
        return if (nextIndex >= state.playlist.size) 0 else nextIndex
    }

    fun playNext() {
        val state = _playbackState.value
        if (!state.isPlaylistMode || state.playlist.isEmpty()) return

        val currentIndex = if (state.isShuffleEnabled) {
            state.shuffledIndices.indexOf(state.currentTrackIndex)
        } else {
            state.currentTrackIndex
        }

        val nextIndex = if (currentIndex < state.playlist.size - 1) {
            currentIndex + 1
        } else if (state.repeatMode == RepeatMode.ALL) {
            0
        } else {
            return
        }

        playTrackAtIndex(nextIndex)
    }

    fun playPrevious() {
        val state = _playbackState.value
        if (!state.isPlaylistMode || state.playlist.isEmpty()) return

        // If more than 3 seconds into the track, restart it
        if (state.currentPosition > 3000) {
            mediaPlayer?.seekTo(0)
            _playbackState.update { it.copy(currentPosition = 0) }
            return
        }

        val currentIndex = if (state.isShuffleEnabled) {
            state.shuffledIndices.indexOf(state.currentTrackIndex)
        } else {
            state.currentTrackIndex
        }

        val prevIndex = if (currentIndex > 0) {
            currentIndex - 1
        } else if (state.repeatMode == RepeatMode.ALL) {
            state.playlist.size - 1
        } else {
            0
        }

        playTrackAtIndex(prevIndex)
    }

    fun toggleRepeatMode() {
        _playbackState.update { currentState ->
            val newMode = when (currentState.repeatMode) {
                RepeatMode.OFF -> RepeatMode.ALL
                RepeatMode.ALL -> RepeatMode.ONE
                RepeatMode.ONE -> RepeatMode.OFF
            }
            currentState.copy(repeatMode = newMode)
        }
    }

    fun toggleShuffle() {
        val state = _playbackState.value

        _playbackState.update { currentState ->
            val newShuffleEnabled = !currentState.isShuffleEnabled
            val newShuffledIndices = if (newShuffleEnabled && currentState.playlist.isNotEmpty()) {
                createShuffledIndices(currentState.playlist.size, currentState.currentTrackIndex)
            } else {
                currentState.playlist.indices.toList()
            }
            currentState.copy(
                isShuffleEnabled = newShuffleEnabled,
                shuffledIndices = newShuffledIndices
            )
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

    private fun releaseMediaPlayer() {
        mediaPlayer?.let {
            try {
                if (it.isPlaying) {
                    it.stop()
                }
                it.reset()
                it.release()
            } catch (e: IllegalStateException) {
                Log.e("MediaPlayer", "Error releasing media player", e)
            } finally {
                mediaPlayer = null
            }
        }
    }

    fun stopPlayback() {
        releaseMediaPlayer()
        stopUpdatingProgress()
        _playbackState.update { currentState ->
            currentState.copy(
                isPlaying = false,
                currentPosition = 0,
                isPlaylistMode = false,
                playlist = emptyList(),
                shuffledIndices = emptyList()
            )
        }
    }

    fun getCurrentRecording(): RecordingData? {
        val state = _playbackState.value
        if (!state.isPlaylistMode || state.playlist.isEmpty()) return null
        return state.playlist.getOrNull(state.currentTrackIndex)
    }

    override fun onCleared() {
        super.onCleared()
        stopPlayback()
    }
}
