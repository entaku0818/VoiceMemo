package com.entaku.simpleRecord.transcription

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.entaku.simpleRecord.record.RecordingRepository
import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.util.UUID

/**
 * 議事録テキストの保存フォーマット（iOS の MeetingMinutesFeature と同一形式）。
 *
 * ```
 * # 要約
 * <summary>
 *
 * # TODO
 * - <todo1>
 * ```
 */
object MeetingMinutesFormatter {

    private const val SUMMARY_HEADER = "# 要約"
    private const val TODO_HEADER = "# TODO"

    fun format(result: MinutesResult): String = buildString {
        append(SUMMARY_HEADER)
        append('\n')
        append(result.summary)
        if (result.todos.isNotEmpty()) {
            append("\n\n")
            append(TODO_HEADER)
            result.todos.forEach { todo ->
                append("\n- ")
                append(todo)
            }
        }
    }

    fun parse(text: String): MinutesResult? {
        if (!text.startsWith(SUMMARY_HEADER)) return null
        val todoIndex = text.indexOf(TODO_HEADER)
        val summary = if (todoIndex >= 0) {
            text.substring(SUMMARY_HEADER.length, todoIndex)
        } else {
            text.substring(SUMMARY_HEADER.length)
        }.trim()
        val todos = if (todoIndex >= 0) {
            text.substring(todoIndex + TODO_HEADER.length)
                .lines()
                .map { it.trim() }
                .filter { it.startsWith("- ") }
                .map { it.removePrefix("- ").trim() }
        } else {
            emptyList()
        }
        if (summary.isEmpty()) return null
        return MinutesResult(summary = summary, todos = todos)
    }
}

sealed class MeetingMinutesUiState {
    object Loading : MeetingMinutesUiState()
    data class Idle(
        val savedMinutes: MinutesResult?,
        val hasTranscription: Boolean
    ) : MeetingMinutesUiState()
    object Generating : MeetingMinutesUiState()
    data class Done(val result: MinutesResult) : MeetingMinutesUiState()
    data class Failed(val message: String) : MeetingMinutesUiState()
}

class MeetingMinutesViewModel(
    private val recordingUuid: UUID,
    private val repository: RecordingRepository,
    private val client: TranscriptionApiClient = TranscriptionApiClient(),
    private val tokenProvider: suspend () -> String = ::firebaseIdToken
) : ViewModel() {

    private val _uiState = MutableStateFlow<MeetingMinutesUiState>(MeetingMinutesUiState.Loading)
    val uiState: StateFlow<MeetingMinutesUiState> = _uiState.asStateFlow()

    private var transcriptionText: String? = null

    init {
        viewModelScope.launch {
            val recording = repository.getRecording(recordingUuid)
            transcriptionText = recording?.transcriptionText?.takeIf { it.isNotBlank() }
            val saved = recording?.meetingMinutesText?.let { MeetingMinutesFormatter.parse(it) }
            _uiState.value = MeetingMinutesUiState.Idle(
                savedMinutes = saved,
                hasTranscription = transcriptionText != null
            )
        }
    }

    fun generate() {
        val text = transcriptionText ?: return
        viewModelScope.launch {
            _uiState.value = MeetingMinutesUiState.Generating
            try {
                val idToken = tokenProvider()
                val result = client.generateMinutes(idToken, text, detectSystemLanguage())
                _uiState.value = MeetingMinutesUiState.Done(result)
            } catch (e: Exception) {
                _uiState.value = MeetingMinutesUiState.Failed(e.message ?: "Unknown error")
            }
        }
    }

    fun save(onSaved: () -> Unit) {
        val done = _uiState.value as? MeetingMinutesUiState.Done ?: return
        viewModelScope.launch {
            repository.updateMeetingMinutes(recordingUuid, MeetingMinutesFormatter.format(done.result))
            _uiState.value = MeetingMinutesUiState.Idle(
                savedMinutes = done.result,
                hasTranscription = transcriptionText != null
            )
            onSaved()
        }
    }

    private fun detectSystemLanguage(): String {
        val lang = java.util.Locale.getDefault().language
        return when {
            lang.startsWith("ja") -> "ja"
            lang.startsWith("zh") -> "zh"
            lang.startsWith("ko") -> "ko"
            lang.startsWith("de") -> "de"
            lang.startsWith("fr") -> "fr"
            lang.startsWith("es") -> "es"
            else -> "en"
        }
    }
}

private suspend fun firebaseIdToken(): String {
    val auth = FirebaseAuth.getInstance()
    if (auth.currentUser == null) {
        auth.signInAnonymously().await()
    }
    return auth.currentUser!!.getIdToken(false).await().token
        ?: error("Failed to get Firebase ID token")
}

class MeetingMinutesViewModelFactory(
    private val recordingUuid: UUID,
    private val repository: RecordingRepository
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        @Suppress("UNCHECKED_CAST")
        return MeetingMinutesViewModel(recordingUuid, repository) as T
    }
}
