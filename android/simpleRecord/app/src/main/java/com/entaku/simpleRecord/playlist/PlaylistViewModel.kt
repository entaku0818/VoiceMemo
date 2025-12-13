package com.entaku.simpleRecord.playlist

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.entaku.simpleRecord.RecordingData
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

class PlaylistViewModel(
    private val repository: PlaylistRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(PlaylistListUiState())
    val uiState: StateFlow<PlaylistListUiState> = _uiState.asStateFlow()

    fun loadPlaylists() {
        viewModelScope.launch {
            repository.getAllPlaylists().collect { playlists ->
                _uiState.value = _uiState.value.copy(
                    playlists = playlists,
                    isLoading = false
                )
            }
        }
    }

    fun createPlaylist(name: String) {
        viewModelScope.launch {
            repository.createPlaylist(name)
        }
    }

    fun updatePlaylistName(uuid: UUID, newName: String) {
        viewModelScope.launch {
            repository.updatePlaylistName(uuid, newName)
        }
    }

    fun deletePlaylist(uuid: UUID) {
        viewModelScope.launch {
            repository.deletePlaylist(uuid)
        }
    }
}

data class PlaylistListUiState(
    val playlists: List<PlaylistData> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null
)

class PlaylistDetailViewModel(
    private val repository: PlaylistRepository,
    private val playlistUuid: UUID
) : ViewModel() {

    private val _uiState = MutableStateFlow(PlaylistDetailUiState())
    val uiState: StateFlow<PlaylistDetailUiState> = _uiState.asStateFlow()

    init {
        loadPlaylistDetail()
    }

    fun loadPlaylistDetail() {
        viewModelScope.launch {
            val playlist = repository.getPlaylistById(playlistUuid)
            _uiState.value = _uiState.value.copy(playlist = playlist)

            repository.getRecordingsForPlaylist(playlistUuid).collect { recordings ->
                _uiState.value = _uiState.value.copy(
                    recordings = recordings,
                    isLoading = false
                )
            }
        }
    }

    fun removeRecording(recordingUuid: UUID) {
        viewModelScope.launch {
            repository.removeRecordingFromPlaylist(playlistUuid, recordingUuid)
        }
    }

    fun addRecording(recordingUuid: UUID) {
        viewModelScope.launch {
            repository.addRecordingToPlaylist(playlistUuid, recordingUuid)
        }
    }
}

data class PlaylistDetailUiState(
    val playlist: PlaylistData? = null,
    val recordings: List<RecordingData> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null
)

class PlaylistViewModelFactory(
    private val repository: PlaylistRepository
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(PlaylistViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return PlaylistViewModel(repository) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}

class PlaylistDetailViewModelFactory(
    private val repository: PlaylistRepository,
    private val playlistUuid: UUID
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(PlaylistDetailViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return PlaylistDetailViewModel(repository, playlistUuid) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
