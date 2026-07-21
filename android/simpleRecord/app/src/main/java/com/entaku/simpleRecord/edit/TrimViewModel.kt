package com.entaku.simpleRecord.edit

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.entaku.simpleRecord.RecordingData
import com.entaku.simpleRecord.record.RecordingRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File
import java.time.LocalDateTime
import java.util.UUID

data class TrimUiState(
    val durationMs: Long = 0L,
    val startMs: Long = 0L,
    val endMs: Long = 0L,
    val isProcessing: Boolean = false,
    val isSaved: Boolean = false,
    val errorMessage: String? = null
)

/**
 * Manages the state for the audio trim editor (Issue #201, trim-only scope).
 *
 * Trimming always produces a *new* recording rather than overwriting the original, mirroring
 * the iOS AudioEditorReducer's "save" behavior and avoiding destructive edits.
 */
class TrimViewModel(
    private val repository: RecordingRepository,
    private val trimmer: AudioTrimmer = AudioTrimmerImpl()
) : ViewModel() {

    private val _uiState = MutableStateFlow(TrimUiState())
    val uiState: StateFlow<TrimUiState> = _uiState.asStateFlow()

    /** Must be called once with the recording being edited before trim() is invoked. */
    fun initialize(recording: RecordingData) {
        val durationMs = recording.duration * 1000
        _uiState.value = TrimUiState(
            durationMs = durationMs,
            startMs = 0L,
            endMs = durationMs
        )
    }

    fun setStart(startMs: Long) {
        val current = _uiState.value
        val clamped = startMs.coerceIn(0L, current.endMs)
        _uiState.value = current.copy(startMs = clamped, errorMessage = null, isSaved = false)
    }

    fun setEnd(endMs: Long) {
        val current = _uiState.value
        val clamped = endMs.coerceIn(current.startMs, current.durationMs)
        _uiState.value = current.copy(endMs = clamped, errorMessage = null, isSaved = false)
    }

    fun trim(recording: RecordingData) {
        val state = _uiState.value
        if (state.isProcessing) return
        if (state.endMs <= state.startMs) {
            _uiState.value = state.copy(errorMessage = ERROR_INVALID_RANGE)
            return
        }

        _uiState.value = state.copy(isProcessing = true, errorMessage = null, isSaved = false)

        viewModelScope.launch {
            try {
                val sourceFile = File(recording.filePath)
                val parent = sourceFile.parentFile
                    ?: throw IllegalStateException("Source file has no parent directory: ${recording.filePath}")
                val outputFile = File(parent, "${UUID.randomUUID()}.m4a")

                trimmer.trim(recording.filePath, state.startMs, state.endMs, outputFile.absolutePath)

                val trimmedDurationSeconds = (state.endMs - state.startMs) / 1000
                val trimmedRecording = recording.copy(
                    uuid = null,
                    title = "${recording.title} (Trim)",
                    creationDate = LocalDateTime.now(),
                    fileExtension = "m4a",
                    duration = trimmedDurationSeconds,
                    filePath = outputFile.absolutePath,
                    transcriptionText = null,
                    meetingMinutesText = null
                )

                repository.saveRecordingData(trimmedRecording)

                _uiState.value = _uiState.value.copy(isProcessing = false, isSaved = true)
            } catch (e: UnsupportedTrimFormatException) {
                Log.e(TAG, "Unsupported format for trim", e)
                _uiState.value = _uiState.value.copy(isProcessing = false, errorMessage = ERROR_UNSUPPORTED_FORMAT)
            } catch (e: Exception) {
                Log.e(TAG, "Trim failed", e)
                _uiState.value = _uiState.value.copy(isProcessing = false, errorMessage = ERROR_GENERIC)
            }
        }
    }

    companion object {
        private const val TAG = "TrimViewModel"
        const val ERROR_INVALID_RANGE = "invalid_range"
        const val ERROR_UNSUPPORTED_FORMAT = "unsupported_format"
        const val ERROR_GENERIC = "generic"
    }
}

class TrimViewModelFactory(
    private val repository: RecordingRepository
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(TrimViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return TrimViewModel(repository) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
