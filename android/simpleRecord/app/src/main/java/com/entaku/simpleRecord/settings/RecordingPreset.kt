package com.entaku.simpleRecord.settings

import android.media.MediaRecorder

enum class RecordingPreset(
    val labelKey: String,
    val fileExtension: String,
    val outputFormat: Int,
    val audioEncoder: Int,
    val sampleRate: Int,
    val bitRate: Int,
    val channels: Int,
    val defaultNoiseSuppressor: Boolean,
    val defaultAutoGainControl: Boolean
) {
    MEMO(
        labelKey = "preset_memo",
        fileExtension = "3gp",
        outputFormat = MediaRecorder.OutputFormat.THREE_GPP,
        audioEncoder = MediaRecorder.AudioEncoder.AMR_NB,
        sampleRate = 8000,
        bitRate = 8,
        channels = 1,
        defaultNoiseSuppressor = true,
        defaultAutoGainControl = true
    ),
    MEETING(
        labelKey = "preset_meeting",
        fileExtension = "mp4",
        outputFormat = MediaRecorder.OutputFormat.MPEG_4,
        audioEncoder = MediaRecorder.AudioEncoder.AAC,
        sampleRate = 16000,
        bitRate = 16,
        channels = 1,
        defaultNoiseSuppressor = true,
        defaultAutoGainControl = true
    ),
    INTERVIEW(
        labelKey = "preset_interview",
        fileExtension = "mp4",
        outputFormat = MediaRecorder.OutputFormat.MPEG_4,
        audioEncoder = MediaRecorder.AudioEncoder.AAC,
        sampleRate = 44100,
        bitRate = 24,
        channels = 2,
        defaultNoiseSuppressor = true,
        defaultAutoGainControl = true
    ),
    PODCAST(
        labelKey = "preset_podcast",
        fileExtension = "mp4",
        outputFormat = MediaRecorder.OutputFormat.MPEG_4,
        audioEncoder = MediaRecorder.AudioEncoder.AAC,
        sampleRate = 44100,
        bitRate = 24,
        channels = 2,
        defaultNoiseSuppressor = true,
        defaultAutoGainControl = false
    ),
    MUSIC(
        labelKey = "preset_music",
        fileExtension = "mp4",
        outputFormat = MediaRecorder.OutputFormat.MPEG_4,
        audioEncoder = MediaRecorder.AudioEncoder.AAC,
        sampleRate = 44100,
        bitRate = 24,
        channels = 2,
        defaultNoiseSuppressor = false,
        defaultAutoGainControl = false
    ),
    CUSTOM(
        labelKey = "preset_custom",
        fileExtension = "",
        outputFormat = -1,
        audioEncoder = -1,
        sampleRate = -1,
        bitRate = -1,
        channels = -1,
        defaultNoiseSuppressor = false,
        defaultAutoGainControl = false
    );

    fun applyTo(settings: RecordingSettings): RecordingSettings {
        if (this == CUSTOM) return settings
        return settings.copy(
            fileExtension = fileExtension,
            outputFormat = outputFormat,
            audioEncoder = audioEncoder,
            sampleRate = sampleRate,
            bitRate = bitRate,
            channels = channels,
            noiseSuppressor = defaultNoiseSuppressor,
            autoGainControl = defaultAutoGainControl
        )
    }

    companion object {
        fun detect(settings: RecordingSettings): RecordingPreset =
            entries.firstOrNull { preset ->
                preset != CUSTOM &&
                    preset.fileExtension == settings.fileExtension &&
                    preset.outputFormat == settings.outputFormat &&
                    preset.sampleRate == settings.sampleRate &&
                    preset.bitRate == settings.bitRate &&
                    preset.channels == settings.channels
            } ?: CUSTOM
    }
}
