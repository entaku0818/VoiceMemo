package com.entaku.simpleRecord.playlist

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.entaku.simpleRecord.RecordingData
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * Repeat mode for playlist playback
 */
enum class RepeatMode {
    OFF,    // No repeat
    ONE,    // Repeat current track
    ALL     // Repeat entire playlist
}

/**
 * State for playlist playback
 */
data class PlaylistPlaybackState(
    val playlist: List<RecordingData> = emptyList(),
    val currentIndex: Int = 0,
    val repeatMode: RepeatMode = RepeatMode.OFF,
    val shuffleEnabled: Boolean = false,
    val isPlaying: Boolean = false
) {
    val currentRecording: RecordingData?
        get() = playlist.getOrNull(currentIndex)

    val hasNext: Boolean
        get() = when {
            shuffleEnabled -> playlist.size > 1
            repeatMode == RepeatMode.ALL -> true
            else -> currentIndex < playlist.size - 1
        }

    val hasPrevious: Boolean
        get() = when {
            shuffleEnabled -> playlist.size > 1
            repeatMode == RepeatMode.ALL -> true
            else -> currentIndex > 0
        }
}

/**
 * ViewModel for managing playlist playback
 * Handles continuous playback, repeat modes, and shuffle
 */
class PlaylistPlaybackViewModel : ViewModel() {

    private val _state = MutableStateFlow(PlaylistPlaybackState())
    val state: StateFlow<PlaylistPlaybackState> = _state

    private var originalPlaylist: List<RecordingData> = emptyList()
    private val playedIndices = mutableSetOf<Int>()

    /**
     * Start playlist playback
     */
    fun startPlaylistPlayback(
        recordings: List<RecordingData>,
        startIndex: Int = 0
    ) {
        originalPlaylist = recordings
        playedIndices.clear()

        _state.update {
            it.copy(
                playlist = if (it.shuffleEnabled) {
                    shufflePlaylist(recordings, startIndex)
                } else {
                    recordings
                },
                currentIndex = if (it.shuffleEnabled) 0 else startIndex,
                isPlaying = true
            )
        }
    }

    /**
     * Play next track
     */
    fun playNext() {
        val currentState = _state.value

        when {
            // Shuffle enabled
            currentState.shuffleEnabled -> {
                playedIndices.add(currentState.currentIndex)

                if (playedIndices.size >= currentState.playlist.size) {
                    // All tracks played
                    if (currentState.repeatMode == RepeatMode.ALL) {
                        playedIndices.clear()
                        _state.update { it.copy(currentIndex = 0) }
                    } else {
                        stopPlayback()
                    }
                } else {
                    // Select random unplayed track
                    val unplayedIndices = currentState.playlist.indices.toSet() - playedIndices
                    val nextIndex = unplayedIndices.random()
                    _state.update { it.copy(currentIndex = nextIndex) }
                }
            }

            // Repeat one track
            currentState.repeatMode == RepeatMode.ONE -> {
                // Stay on same track
                _state.update { it }
            }

            // Last track
            currentState.currentIndex >= currentState.playlist.size - 1 -> {
                if (currentState.repeatMode == RepeatMode.ALL) {
                    _state.update { it.copy(currentIndex = 0) }
                } else {
                    stopPlayback()
                }
            }

            // Normal next
            else -> {
                _state.update { it.copy(currentIndex = it.currentIndex + 1) }
            }
        }
    }

    /**
     * Play previous track
     */
    fun playPrevious() {
        val currentState = _state.value

        when {
            currentState.shuffleEnabled -> {
                // In shuffle mode, go to previously played track
                if (playedIndices.isNotEmpty()) {
                    val previousIndex = playedIndices.last()
                    playedIndices.remove(previousIndex)
                    _state.update { it.copy(currentIndex = previousIndex) }
                }
            }

            currentState.currentIndex > 0 -> {
                _state.update { it.copy(currentIndex = it.currentIndex - 1) }
            }

            currentState.repeatMode == RepeatMode.ALL -> {
                _state.update { it.copy(currentIndex = it.playlist.size - 1) }
            }
        }
    }

    /**
     * Toggle repeat mode: OFF → ONE → ALL → OFF
     */
    fun toggleRepeat() {
        _state.update {
            it.copy(
                repeatMode = when (it.repeatMode) {
                    RepeatMode.OFF -> RepeatMode.ONE
                    RepeatMode.ONE -> RepeatMode.ALL
                    RepeatMode.ALL -> RepeatMode.OFF
                }
            )
        }
    }

    /**
     * Toggle shuffle mode
     */
    fun toggleShuffle() {
        _state.update { currentState ->
            val newShuffleEnabled = !currentState.shuffleEnabled

            if (newShuffleEnabled) {
                // Enable shuffle
                val currentRecording = currentState.currentRecording
                val shuffled = currentRecording?.let {
                    shufflePlaylist(originalPlaylist, originalPlaylist.indexOf(it))
                } ?: originalPlaylist.shuffled()
                playedIndices.clear()

                currentState.copy(
                    shuffleEnabled = true,
                    playlist = shuffled,
                    currentIndex = 0
                )
            } else {
                // Disable shuffle
                val currentRecording = currentState.currentRecording
                val originalIndex = currentRecording?.let { originalPlaylist.indexOf(it) } ?: 0

                currentState.copy(
                    shuffleEnabled = false,
                    playlist = originalPlaylist,
                    currentIndex = originalIndex.takeIf { it >= 0 } ?: 0
                )
            }
        }
    }

    /**
     * Jump to specific track
     */
    fun jumpToTrack(index: Int) {
        if (index in _state.value.playlist.indices) {
            _state.update { it.copy(currentIndex = index) }
        }
    }

    /**
     * Handle track completion
     * Called when current track finishes playing
     */
    fun onTrackComplete() {
        if (_state.value.repeatMode == RepeatMode.ONE) {
            // Repeat one: stay on same track
            return
        }

        if (_state.value.hasNext) {
            playNext()
        } else {
            stopPlayback()
        }
    }

    /**
     * Stop playback
     */
    fun stopPlayback() {
        _state.update {
            it.copy(
                isPlaying = false,
                currentIndex = 0
            )
        }
    }

    /**
     * Set playing state
     */
    fun setPlaying(isPlaying: Boolean) {
        _state.update { it.copy(isPlaying = isPlaying) }
    }

    /**
     * Shuffle playlist keeping current track first
     */
    private fun shufflePlaylist(
        recordings: List<RecordingData>,
        currentIndex: Int
    ): List<RecordingData> {
        if (recordings.isEmpty()) return recordings
        if (currentIndex !in recordings.indices) return recordings.shuffled()

        val current = recordings[currentIndex]
        val others = recordings.toMutableList().apply { removeAt(currentIndex) }.shuffled()
        return listOf(current) + others
    }
}
