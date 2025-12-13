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

    // Function to set the selected recording
    fun selectRecording(recording: RecordingData) {
        _selectedRecording.value = recording
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
