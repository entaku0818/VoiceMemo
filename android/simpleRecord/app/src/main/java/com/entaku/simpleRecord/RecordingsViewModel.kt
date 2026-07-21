package com.entaku.simpleRecord

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.entaku.simpleRecord.record.RecordingRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

class RecordingsViewModel(
    private val repository: RecordingRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(RecordingsUiState())
    val uiState: StateFlow<RecordingsUiState> = _uiState.asStateFlow()

    private var allRecordings: List<RecordingData> = emptyList()

    fun loadRecordings() {
        viewModelScope.launch {
            repository.getAllRecordings().collect { recordings ->
                allRecordings = recordings
                _uiState.value = _uiState.value.copy(
                    recordings = applyFilters(
                        recordings = recordings,
                        query = _uiState.value.searchQuery,
                        sortOption = _uiState.value.sortOption,
                        durationFilter = _uiState.value.durationFilter
                    ),
                    isLoading = false
                )
            }
        }
    }

    fun deleteRecording(uuid: UUID) {
        viewModelScope.launch {
            repository.deleteRecording(uuid)
            loadRecordings()
        }
    }

    fun updateRecordingTitle(uuid: UUID, newTitle: String) {
        viewModelScope.launch {
            repository.updateRecordingTitle(uuid, newTitle)
            loadRecordings()
        }
    }

    fun setSearchQuery(query: String) {
        val newState = _uiState.value.copy(searchQuery = query)
        _uiState.value = newState.copy(
            recordings = applyFilters(allRecordings, query, newState.sortOption, newState.durationFilter)
        )
    }

    fun setSortOption(option: SortOption) {
        val newState = _uiState.value.copy(sortOption = option)
        _uiState.value = newState.copy(
            recordings = applyFilters(allRecordings, newState.searchQuery, option, newState.durationFilter)
        )
    }

    fun setDurationFilter(filter: DurationFilter) {
        val newState = _uiState.value.copy(durationFilter = filter)
        _uiState.value = newState.copy(
            recordings = applyFilters(allRecordings, newState.searchQuery, newState.sortOption, filter)
        )
    }

    private fun applyFilters(
        recordings: List<RecordingData>,
        query: String,
        sortOption: SortOption,
        durationFilter: DurationFilter
    ): List<RecordingData> {
        var result = recordings

        if (query.isNotBlank()) {
            result = result.filter { it.title.contains(query, ignoreCase = true) }
        }

        result = result.filter { durationFilter.matches(it.duration) }

        result = when (sortOption) {
            SortOption.DATE_DESCENDING -> result.sortedByDescending { it.creationDate }
            SortOption.DATE_ASCENDING -> result.sortedBy { it.creationDate }
            SortOption.TITLE_ASCENDING -> result.sortedBy { it.title.lowercase() }
            SortOption.TITLE_DESCENDING -> result.sortedByDescending { it.title.lowercase() }
            SortOption.DURATION_DESCENDING -> result.sortedByDescending { it.duration }
            SortOption.DURATION_ASCENDING -> result.sortedBy { it.duration }
        }

        return result
    }
}

data class RecordingsUiState(
    val recordings: List<RecordingData> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
    val searchQuery: String = "",
    val sortOption: SortOption = SortOption.DATE_DESCENDING,
    val durationFilter: DurationFilter = DurationFilter.ALL
)

enum class SortOption {
    DATE_DESCENDING,
    DATE_ASCENDING,
    TITLE_ASCENDING,
    TITLE_DESCENDING,
    DURATION_DESCENDING,
    DURATION_ASCENDING
}

enum class DurationFilter {
    ALL,
    SHORT,
    MEDIUM,
    LONG;

    /** [durationSeconds] is expressed in seconds (see RecordingData.duration). */
    fun matches(durationSeconds: Long): Boolean = when (this) {
        ALL -> true
        SHORT -> durationSeconds < SHORT_THRESHOLD_SECONDS
        MEDIUM -> durationSeconds in SHORT_THRESHOLD_SECONDS until LONG_THRESHOLD_SECONDS
        LONG -> durationSeconds >= LONG_THRESHOLD_SECONDS
    }

    companion object {
        private const val SHORT_THRESHOLD_SECONDS = 60L
        private const val LONG_THRESHOLD_SECONDS = 300L
    }
}