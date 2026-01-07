package com.entaku.simpleRecord

import androidx.lifecycle.ViewModel
import com.entaku.simpleRecord.record.RecordingState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class SharedRecordingsViewModel : ViewModel() {
    private val _selectedRecording = MutableStateFlow<RecordingData?>(null)
    val selectedRecording: StateFlow<RecordingData?> = _selectedRecording

    // 録音状態を共有するためのStateFlow
    private val _recordingState = MutableStateFlow(RecordingState.IDLE)
    val recordingState: StateFlow<RecordingState> = _recordingState

    // Playlist playback state
    private val _playlistRecordings = MutableStateFlow<List<RecordingData>>(emptyList())
    val playlistRecordings: StateFlow<List<RecordingData>> = _playlistRecordings

    private val _playlistStartIndex = MutableStateFlow(0)
    val playlistStartIndex: StateFlow<Int> = _playlistStartIndex

    private val _isPlaylistMode = MutableStateFlow(false)
    val isPlaylistMode: StateFlow<Boolean> = _isPlaylistMode

    // Function to set the selected recording
    fun selectRecording(recording: RecordingData) {
        _selectedRecording.value = recording
        _isPlaylistMode.value = false
        _playlistRecordings.value = emptyList()
    }

    // Function to set playlist playback
    fun selectPlaylist(recordings: List<RecordingData>, startIndex: Int) {
        if (recordings.isNotEmpty() && startIndex in recordings.indices) {
            _playlistRecordings.value = recordings
            _playlistStartIndex.value = startIndex
            _selectedRecording.value = recordings[startIndex]
            _isPlaylistMode.value = true
        }
    }

    // 録音状態を更新する関数
    fun updateRecordingState(state: RecordingState) {
        _recordingState.value = state
    }

    // 録音中またはポーズ中かどうかを確認する関数
    fun isRecordingOrPaused(): Boolean {
        return _recordingState.value == RecordingState.RECORDING ||
               _recordingState.value == RecordingState.PAUSED
    }
}
