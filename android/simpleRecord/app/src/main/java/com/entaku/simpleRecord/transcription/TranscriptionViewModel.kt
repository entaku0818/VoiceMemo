package com.entaku.simpleRecord.transcription

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.io.File

sealed class TranscriptionUiState {
    object Idle : TranscriptionUiState()
    object Uploading : TranscriptionUiState()
    object Transcribing : TranscriptionUiState()
    data class Done(val result: TranscriptionResult) : TranscriptionUiState()
    data class Failed(val message: String) : TranscriptionUiState()
}

class TranscriptionViewModel(
    private val audioFilePath: String,
    private val client: TranscriptionApiClient = TranscriptionApiClient()
) : ViewModel() {

    private val _uiState = MutableStateFlow<TranscriptionUiState>(TranscriptionUiState.Idle)
    val uiState: StateFlow<TranscriptionUiState> = _uiState.asStateFlow()

    private val _selectedLanguage = MutableStateFlow(detectSystemLanguage())
    val selectedLanguage: StateFlow<String> = _selectedLanguage.asStateFlow()

    fun setLanguage(lang: String) {
        _selectedLanguage.value = lang
    }

    fun reset() {
        _uiState.value = TranscriptionUiState.Idle
    }

    fun startTranscription() {
        viewModelScope.launch {
            _uiState.value = TranscriptionUiState.Uploading
            try {
                val idToken = getFirebaseIdToken()
                val file = File(audioFilePath)
                val ext = file.extension.ifEmpty { "mp4" }
                val mimeType = if (ext == "m4a") "audio/mp4" else "audio/$ext"

                val (signedUrl, blobName) = client.getUploadUrl(idToken, ext)
                _uiState.value = TranscriptionUiState.Uploading

                client.uploadAudio(signedUrl, file, mimeType)
                _uiState.value = TranscriptionUiState.Transcribing

                val result = client.transcribe(idToken, blobName, _selectedLanguage.value)
                _uiState.value = TranscriptionUiState.Done(result)
            } catch (e: Exception) {
                _uiState.value = TranscriptionUiState.Failed(e.message ?: "Unknown error")
            }
        }
    }

    private suspend fun getFirebaseIdToken(): String {
        val auth = FirebaseAuth.getInstance()
        if (auth.currentUser == null) {
            auth.signInAnonymously().await()
        }
        return auth.currentUser!!.getIdToken(false).await().token
            ?: error("Failed to get Firebase ID token")
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

class TranscriptionViewModelFactory(private val audioFilePath: String) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        @Suppress("UNCHECKED_CAST")
        return TranscriptionViewModel(audioFilePath) as T
    }
}
