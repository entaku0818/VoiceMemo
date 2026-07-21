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
import com.entaku.simpleRecord.settings.SettingsRepository
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
    val amplitudeHistory: List<Float> = emptyList(),
    // 録音中のリアルタイム音声文字起こし結果 (issue #198)。既存の録音後サーバー文字起こしとは独立。
    val transcribedText: String = "",
    val isTranscriptionActive: Boolean = false
)

class RecordViewModel(
    private val repository: RecordingRepository,
    private val settingsManager: SettingsRepository,
    private val sharedViewModel: SharedRecordingsViewModel,
    private val speechTranscriptionController: SpeechTranscriptionController = AndroidSpeechTranscriptionController()
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

    // ロック画面の常時通知(ongoing notification)用。録音中のみ非null。 (issue #197)
    // WeakReferenceで保持し、ViewModelがContextを直接保持し続けることによるリーク(lint: StaticFieldLeak)を避ける。
    private var notificationContextRef: java.lang.ref.WeakReference<Context>? = null
    private var notificationContext: Context?
        get() = notificationContextRef?.get()
        set(value) {
            notificationContextRef = value?.let { java.lang.ref.WeakReference(it) }
        }
    private val recordingActionListener = object : RecordingActionListener {
        override fun onPauseRequested() = pauseRecording()
        override fun onResumeRequested() = resumeRecording()
        override fun onStopRequested() = stopRecording()
    }

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
                updateNotification(isPaused = false)
                delay(1000)
            }
        }
    }

    // ongoing notification の経過時間・音量表示を更新する。
    // chronometer に時間表示を任せているため、呼び出しは1秒に1回程度で十分 (issue #197)。
    private fun updateNotification(isPaused: Boolean) {
        notificationContext?.let { ctx ->
            RecordingNotificationService.updateProgress(
                context = ctx,
                baseTimeMillis = startTime + pausedDuration,
                isPaused = isPaused,
                volume = _uiState.value.currentVolume
            )
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
                notificationContext = applicationContext
                RecordingNotificationService.actionListener = recordingActionListener
                RecordingNotificationService.start(applicationContext, startTime)
                startVolumeMonitoring()
                startTimeUpdates()
                startRealtimeTranscription(applicationContext, initialText = "")
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

    // 録音中のリアルタイム音声文字起こしを開始する (issue #198)。
    // 端末が音声認識に対応していない場合は isTranscriptionActive が false のままとなり、
    // UI 側でリアルタイム文字起こし表示を出さない。
    private fun startRealtimeTranscription(context: Context, initialText: String) {
        val started = speechTranscriptionController.start(context, initialText) { text ->
            _uiState.update { it.copy(transcribedText = text) }
        }
        _uiState.update { it.copy(transcribedText = initialText, isTranscriptionActive = started) }
    }

    private fun stopRealtimeTranscription() {
        speechTranscriptionController.stop()
        _uiState.update { it.copy(isTranscriptionActive = false) }
    }

    // ongoing notification を停止し、リスナー登録を解除する (issue #197)。
    private fun stopNotificationService() {
        notificationContext?.let { RecordingNotificationService.stop(it) }
        notificationContext = null
    }

    fun stopRecording() {
        timeUpdateJob?.cancel()
        timeUpdateJob = null
        volumeMonitorJob?.cancel()
        volumeMonitorJob = null
        stopRealtimeTranscription()

        mediaRecorder?.apply {
            try {
                stop()
            } catch (e: IllegalStateException) {
                e.printStackTrace()
                stopNotificationService()
                return
            } finally {
                release()
            }
        }
        mediaRecorder = null
        stopNotificationService()

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
                amplitudeHistory = emptyList(),
                transcribedText = "",
                isTranscriptionActive = false
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
                stopRealtimeTranscription()
                _uiState.update { it.copy(recordingState = RecordingState.PAUSED) }
                sharedViewModel.updateRecordingState(RecordingState.PAUSED)
                updateNotification(isPaused = true)
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
                notificationContext?.let { ctx ->
                    startRealtimeTranscription(ctx, initialText = _uiState.value.transcribedText)
                }
                _uiState.update { it.copy(recordingState = RecordingState.RECORDING) }
                sharedViewModel.updateRecordingState(RecordingState.RECORDING)
                updateNotification(isPaused = false)
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        volumeMonitorJob?.cancel()
        timeUpdateJob?.cancel()
        mediaRecorder?.release()
        mediaRecorder = null
        stopNotificationService()
        speechTranscriptionController.destroy()
    }
}
