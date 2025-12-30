package com.entaku.simpleRecord.cloudsync

import android.content.Context
import android.content.Intent
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class CloudSyncState(
    val isSignedIn: Boolean = false,
    val userEmail: String? = null,
    val isLoading: Boolean = false,
    val progressMessage: String = "",
    val backupInfo: BackupInfo? = null,
    val errorMessage: String? = null,
    val successMessage: String? = null
)

class CloudSyncViewModel(
    private val context: Context
) : ViewModel() {

    private val authManager = GoogleAuthManager(context)

    private val _uiState = MutableStateFlow(CloudSyncState())
    val uiState: StateFlow<CloudSyncState> = _uiState.asStateFlow()

    private var backupService: DriveBackupService? = null

    init {
        checkSignInStatus()
    }

    private fun checkSignInStatus() {
        val account = authManager.getSignedInAccount()
        if (account != null) {
            onSignedIn(account)
        }
    }

    fun getSignInIntent(): Intent = authManager.getSignInIntent()

    fun handleSignInResult(data: Intent?) {
        val account = authManager.handleSignInResult(data)
        if (account != null) {
            onSignedIn(account)
        } else {
            _uiState.value = _uiState.value.copy(
                errorMessage = "Sign in failed"
            )
        }
    }

    private fun onSignedIn(account: GoogleSignInAccount) {
        backupService = DriveBackupService(context, account)
        _uiState.value = _uiState.value.copy(
            isSignedIn = true,
            userEmail = account.email
        )
        loadBackupInfo()
    }

    fun signOut() {
        viewModelScope.launch {
            authManager.signOut()
            backupService = null
            _uiState.value = CloudSyncState()
        }
    }

    private fun loadBackupInfo() {
        viewModelScope.launch {
            val info = backupService?.getBackupInfo()
            _uiState.value = _uiState.value.copy(backupInfo = info)
        }
    }

    fun backup() {
        val service = backupService ?: return

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                isLoading = true,
                errorMessage = null,
                successMessage = null
            )

            val result = service.backup { progress ->
                _uiState.value = _uiState.value.copy(progressMessage = progress)
            }

            result.fold(
                onSuccess = { count ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        progressMessage = "",
                        successMessage = "Backed up $count recordings"
                    )
                    loadBackupInfo()
                },
                onFailure = { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        progressMessage = "",
                        errorMessage = error.message ?: "Backup failed"
                    )
                }
            )
        }
    }

    fun restore() {
        val service = backupService ?: return

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                isLoading = true,
                errorMessage = null,
                successMessage = null
            )

            val result = service.restore { progress ->
                _uiState.value = _uiState.value.copy(progressMessage = progress)
            }

            result.fold(
                onSuccess = { count ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        progressMessage = "",
                        successMessage = "Restored $count recordings"
                    )
                },
                onFailure = { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        progressMessage = "",
                        errorMessage = error.message ?: "Restore failed"
                    )
                }
            )
        }
    }

    fun clearMessages() {
        _uiState.value = _uiState.value.copy(
            errorMessage = null,
            successMessage = null
        )
    }
}

class CloudSyncViewModelFactory(
    private val context: Context
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return CloudSyncViewModel(context) as T
    }
}
