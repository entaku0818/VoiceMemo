package com.entaku.simpleRecord.record

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.entaku.simpleRecord.RecordingsViewModel
import com.entaku.simpleRecord.SharedRecordingsViewModel
import com.entaku.simpleRecord.settings.SettingsManager

class RecordViewModelFactory(
    private val repository: RecordingRepository,
    private val settingsManager: SettingsManager,
    private val sharedViewModel: SharedRecordingsViewModel
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(RecordViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return RecordViewModel(repository, settingsManager, sharedViewModel) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}

class RecordingsViewModelFactory(
    private val repository: RecordingRepository
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(RecordingsViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return RecordingsViewModel(repository) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
