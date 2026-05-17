package com.entaku.simpleRecord.settings

import android.content.Context
import android.content.SharedPreferences
import android.media.MediaRecorder
import androidx.core.content.edit

data class RecordingSettings(
    val fileExtension: String,
    val outputFormat: Int,
    val audioEncoder: Int,
    val sampleRate: Int,
    val bitRate: Int,
    val channels: Int,
    val micVolume: Float = 1.0f,
    val noiseSuppressor: Boolean = false,
    val autoGainControl: Boolean = false
)

class SettingsRepository(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(
        "app_settings", Context.MODE_PRIVATE
    )

    private val defaultSettings = RecordingSettings(
        fileExtension = "3gp",
        outputFormat = MediaRecorder.OutputFormat.THREE_GPP,
        audioEncoder = MediaRecorder.AudioEncoder.AMR_NB,
        sampleRate = 44100,
        bitRate = 16,
        channels = 1,
        micVolume = 1.0f,
        noiseSuppressor = false,
        autoGainControl = false
    )

    fun getRecordingSettings(): RecordingSettings {
        return RecordingSettings(
            fileExtension = prefs.getString("file_extension", defaultSettings.fileExtension)!!,
            outputFormat = prefs.getInt("output_format", defaultSettings.outputFormat),
            audioEncoder = prefs.getInt("audio_encoder", defaultSettings.audioEncoder),
            sampleRate = prefs.getInt("sample_rate", defaultSettings.sampleRate),
            bitRate = prefs.getInt("bit_rate", defaultSettings.bitRate),
            channels = prefs.getInt("channels", defaultSettings.channels),
            micVolume = prefs.getFloat("mic_volume", defaultSettings.micVolume),
            noiseSuppressor = prefs.getBoolean("noise_suppressor", defaultSettings.noiseSuppressor),
            autoGainControl = prefs.getBoolean("auto_gain_control", defaultSettings.autoGainControl)
        )
    }

    fun saveRecordingSettings(settings: RecordingSettings) {
        prefs.edit {
            putString("file_extension", settings.fileExtension)
            putInt("output_format", settings.outputFormat)
            putInt("audio_encoder", settings.audioEncoder)
            putInt("sample_rate", settings.sampleRate)
            putInt("bit_rate", settings.bitRate)
            putInt("channels", settings.channels)
            putFloat("mic_volume", settings.micVolume)
            putBoolean("noise_suppressor", settings.noiseSuppressor)
            putBoolean("auto_gain_control", settings.autoGainControl)
        }
    }
}
