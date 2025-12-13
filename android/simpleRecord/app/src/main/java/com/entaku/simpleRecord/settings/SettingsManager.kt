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
    val channels: Int
)

class SettingsManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(
        "app_settings", Context.MODE_PRIVATE
    )
    
    // デフォルト設定
    private val defaultSettings = RecordingSettings(
        fileExtension = "3gp",
        outputFormat = MediaRecorder.OutputFormat.THREE_GPP,
        audioEncoder = MediaRecorder.AudioEncoder.AMR_NB,
        sampleRate = 44100,
        bitRate = 16,
        channels = 1
    )
    
    // 録音設定の取得
    fun getRecordingSettings(): RecordingSettings {
        return RecordingSettings(
            fileExtension = prefs.getString("file_extension", defaultSettings.fileExtension)!!,
            outputFormat = prefs.getInt("output_format", defaultSettings.outputFormat),
            audioEncoder = prefs.getInt("audio_encoder", defaultSettings.audioEncoder),
            sampleRate = prefs.getInt("sample_rate", defaultSettings.sampleRate),
            bitRate = prefs.getInt("bit_rate", defaultSettings.bitRate),
            channels = prefs.getInt("channels", defaultSettings.channels)
        )
    }
    
    // 録音設定の保存
    fun saveRecordingSettings(settings: RecordingSettings) {
        prefs.edit {
            putString("file_extension", settings.fileExtension)
            putInt("output_format", settings.outputFormat)
            putInt("audio_encoder", settings.audioEncoder)
            putInt("sample_rate", settings.sampleRate)
            putInt("bit_rate", settings.bitRate)
            putInt("channels", settings.channels)
        }
    }
}
