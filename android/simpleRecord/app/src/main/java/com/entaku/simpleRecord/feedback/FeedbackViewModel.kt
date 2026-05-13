package com.entaku.simpleRecord.feedback

import androidx.annotation.StringRes
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.entaku.simpleRecord.R
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class FeedbackCategory(@StringRes val labelRes: Int) {
    BUG(R.string.feedback_category_bug),
    FEATURE(R.string.feedback_category_feature),
    OTHER(R.string.feedback_category_other)
}

data class FeedbackState(
    val category: FeedbackCategory = FeedbackCategory.FEATURE,
    val message: String = "",
    val email: String = "",
    val isSending: Boolean = false,
    val showSuccess: Boolean = false,
    val errorMessage: String? = null
)

class FeedbackViewModel(
    private val repository: FeedbackRepository = FirebaseFeedbackRepository()
) : ViewModel() {

    private val _state = MutableStateFlow(FeedbackState())
    val state: StateFlow<FeedbackState> = _state.asStateFlow()

    fun setCategory(category: FeedbackCategory) {
        _state.update { it.copy(category = category) }
    }

    fun setMessage(message: String) {
        _state.update { it.copy(message = message) }
    }

    fun setEmail(email: String) {
        _state.update { it.copy(email = email) }
    }

    fun clearError() {
        _state.update { it.copy(errorMessage = null) }
    }

    fun submit(appVersion: String, osVersion: String, deviceModel: String) {
        val current = _state.value
        if (current.message.isBlank() || current.isSending) return

        _state.update { it.copy(isSending = true) }

        viewModelScope.launch {
            try {
                val data = mapOf(
                    "category" to current.category.name.lowercase(),
                    "message" to current.message,
                    "email" to current.email,
                    "appVersion" to appVersion,
                    "osVersion" to osVersion,
                    "deviceModel" to deviceModel,
                    "platform" to "android"
                )
                repository.submit(data)
                _state.update { it.copy(isSending = false, showSuccess = true) }
            } catch (e: Exception) {
                _state.update { it.copy(isSending = false, errorMessage = e.localizedMessage ?: "Unknown error") }
            }
        }
    }

    class Factory(private val repository: FeedbackRepository) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            FeedbackViewModel(repository) as T
    }
}
