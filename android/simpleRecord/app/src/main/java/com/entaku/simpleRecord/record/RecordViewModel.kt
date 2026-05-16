package com.entaku.simpleRecord.record

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import android.media.MediaRecorder
import android.os.Build
import android.os.Environment
import com.entaku.simpleRecord.RecordingData
import com.entaku.simpleRecord.SharedRecordingsViewModel
import com.entaku.simpleRecord.settings.RecordingSettings
import com.entaku.simpleRecord.settings.SettingsManager
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import java.io.IOException
import java.time.LocalDateTime
import java.time.Duration


enum class RecordingState {
    IDLE,      // 録音準備完了
    RECORDING, // 録音中
    PAUSED,    // 録音一時停止中
    ERROR,
    FINISHED
}

data class RecordingUiState(
    val recordingState: RecordingState = RecordingState.IDLE,
    val currentFilePath: String? = null,
    val currentVolume: Int = 0,
    val elapsedTime: Duration = Duration.ZERO,
    val amplitudeHistory: List<Float> = emptyList()
)

class RecordViewModel(
    private val repository: RecordingRepository,
    private val settingsManager: SettingsManager,
    private val sharedViewModel: SharedRecordingsViewModel
) : ViewModel() {

    private val _uiState = MutableStateFlow(RecordingUiState())
    val uiState: StateFlow<RecordingUiState> = _uiState
    
    init {
        // 初期状態をSharedViewModelに設定
        sharedViewModel.updateRecordingState(RecordingState.IDLE)
    }

    private var mediaRecorder: MediaRecorder? = null
    private var startTime: Long = 0
    private var volumeMonitorJob: Job? = null
    private var pausedDuration: Long = 0
    private var pauseStartTime: Long = 0

    // 録音設定パラメータを取得
    private fun getRecordingSettings(): RecordingSettings {
        return settingsManager.getRecordingSettings()
    }

    private var timeUpdateJob: Job? = null

    private fun startTimeUpdates() {
        timeUpdateJob?.cancel()
        timeUpdateJob = viewModelScope.launch {
            while (true) {
                val currentTime = System.currentTimeMillis()
                val elapsed = Duration.ofMillis(currentTime - startTime - pausedDuration)
                _uiState.update { it.copy(elapsedTime = elapsed) }
                delay(1000)
            }
        }
    }

    fun startRecording(applicationContext: Context) {
        val settings = getRecordingSettings()
        val externalFilesDir = applicationContext.getExternalFilesDir(Environment.DIRECTORY_MUSIC)
        val fileName = "recording_${System.currentTimeMillis()}"
        val outputFile = "${externalFilesDir?.absolutePath}/$fileName.${settings.fileExtension}"

        // VOICE_COMMUNICATION enables platform-level noise suppression and AGC.
        // MIC gives raw audio without processing.
        val audioSource = if (settings.noiseSuppressor || settings.autoGainControl) {
            MediaRecorder.AudioSource.VOICE_COMMUNICATION
        } else {
            MediaRecorder.AudioSource.MIC
        }

        mediaRecorder = createMediaRecorder(applicationContext).apply {
            setAudioSource(audioSource)
            setOutputFormat(settings.outputFormat)
            setAudioEncoder(settings.audioEncoder)
            setAudioSamplingRate(settings.sampleRate)
            setAudioEncodingBitRate(settings.bitRate)
            setAudioChannels(settings.channels)
            setOutputFile(outputFile)
            try {
                prepare()
                start()
                startTime = System.currentTimeMillis()
                pausedDuration = 0
                _uiState.update { it.copy(
                    recordingState = RecordingState.RECORDING,
                    currentFilePath = outputFile,
                    elapsedTime = Duration.ZERO,
                    currentVolume = 0,
                    amplitudeHistory = emptyList()
                ) }
                sharedViewModel.updateRecordingState(RecordingState.RECORDING)
                startVolumeMonitoring()
                startTimeUpdates()
            } catch (e: IOException) {
                e.printStackTrace()
            }
        }
    }

    private fun startVolumeMonitoring() {
        volumeMonitorJob?.cancel()
        volumeMonitorJob = viewModelScope.launch {
            while (true) {
                mediaRecorder?.let { recorder ->
                    try {
                        val amplitude = recorder.maxAmplitude
                        val normalizedVolume = (amplitude.toFloat() / 32767.0f * 100).toInt().coerceIn(0, 100)
                        val normalizedAmplitude = amplitude.toFloat() / 32767.0f

                        _uiState.update { state ->
                            val newHistory = (state.amplitudeHistory + normalizedAmplitude)
                                .takeLast(MAX_AMPLITUDE_HISTORY)
                            state.copy(
                                currentVolume = normalizedVolume,
                                amplitudeHistory = newHistory
                            )
                        }
                    } catch (e: IllegalStateException) {
                        e.printStackTrace()
                    }
                }
                delay(100)
            }
        }
    }

    companion object {
        private const val MAX_AMPLITUDE_HISTORY = 100
    }

    fun stopRecording() {
        timeUpdateJob?.cancel()
        timeUpdateJob = null
        volumeMonitorJob?.cancel()
        volumeMonitorJob = null

        mediaRecorder?.apply {
            try {
                stop()
            } catch (e: IllegalStateException) {
                e.printStackTrace()
                return
            } finally {
                release()
            }
        }
        mediaRecorder = null

        val endTime = System.currentTimeMillis()
        val duration = Duration.ofMillis(endTime - startTime - pausedDuration)

        _uiState.value.currentFilePath?.let { filePath ->
            val settings = getRecordingSettings()
            val now = LocalDateTime.now()
            val titleFormatter = java.time.format.DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm")
            val recordingData = RecordingData(
                title = now.format(titleFormatter),
                creationDate = LocalDateTime.now(),
                fileExtension = settings.fileExtension,
                khz = settings.sampleRate.toString(),
                bitRate = settings.bitRate,
                channels = settings.channels,
                duration = duration.seconds,
                filePath = filePath
            )

            viewModelScope.launch {
                repository.saveRecordingData(recordingData)
            }
        }

        _uiState.update {
            it.copy(
                recordingState = RecordingState.FINISHED,
                currentFilePath = null,
                currentVolume = 0,
                elapsedTime = Duration.ZERO,
                amplitudeHistory = emptyList()
            )
        }
        sharedViewModel.updateRecordingState(RecordingState.FINISHED)

        // 画面遷移が発火してから IDLE に戻す（再度録音できるように）
        viewModelScope.launch {
            delay(500)
            if (_uiState.value.recordingState == RecordingState.FINISHED) {
                _uiState.update { RecordingUiState() }
                sharedViewModel.updateRecordingState(RecordingState.IDLE)
            }
        }
    }

    private fun formatDuration(duration: Duration): String {
        val hours = duration.toHours()
        val minutes = duration.toMinutes() % 60
        val seconds = duration.seconds % 60
        return String.format("%02d:%02d:%02d", hours, minutes, seconds)
    }

    private fun createMediaRecorder(context: Context): MediaRecorder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
    }

    fun pauseRecording() {
        if (uiState.value.recordingState == RecordingState.RECORDING) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                mediaRecorder?.pause()
                pauseStartTime = System.currentTimeMillis()
                volumeMonitorJob?.cancel()
                timeUpdateJob?.cancel()
                _uiState.update { it.copy(recordingState = RecordingState.PAUSED) }
                sharedViewModel.updateRecordingState(RecordingState.PAUSED)
            }
        }
    }

    fun resumeRecording() {
        if (uiState.value.recordingState == RecordingState.PAUSED) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                mediaRecorder?.resume()
                pausedDuration += System.currentTimeMillis() - pauseStartTime
                startVolumeMonitoring()
                startTimeUpdates()
                _uiState.update { it.copy(recordingState = RecordingState.RECORDING) }
                sharedViewModel.updateRecordingState(RecordingState.RECORDING)
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        volumeMonitorJob?.cancel()
        timeUpdateJob?.cancel()
        mediaRecorder?.release()
        mediaRecorder = null
    }
}
