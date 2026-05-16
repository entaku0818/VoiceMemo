package com.entaku.simpleRecord.settings

import android.media.MediaRecorder

enum class RecordingPreset(
    val labelKey: String,
    val fileExtension: String,
    val outputFormat: Int,
    val audioEncoder: Int,
    val sampleRate: Int,
    val bitRate: Int,
    val channels: Int
) {
    MEETING(
        labelKey = "preset_meeting",
        fileExtension = "mp4",
        outputFormat = MediaRecorder.OutputFormat.MPEG_4,
        audioEncoder = MediaRecorder.AudioEncoder.AAC,
        sampleRate = 16000,
        bitRate = 16,
        channels = 1
    ),
    LECTURE(
        labelKey = "preset_lecture",
        fileExtension = "mp4",
        outputFormat = MediaRecorder.OutputFormat.MPEG_4,
        audioEncoder = MediaRecorder.AudioEncoder.AAC,
        sampleRate = 16000,
        bitRate = 16,
        channels = 1
    ),
    INTERVIEW(
        labelKey = "preset_interview",
        fileExtension = "mp4",
        outputFormat = MediaRecorder.OutputFormat.MPEG_4,
        audioEncoder = MediaRecorder.AudioEncoder.AAC,
        sampleRate = 44100,
        bitRate = 24,
        channels = 2
    ),
    VOICE_MEMO(
        labelKey = "preset_voice_memo",
        fileExtension = "3gp",
        outputFormat = MediaRecorder.OutputFormat.THREE_GPP,
        audioEncoder = MediaRecorder.AudioEncoder.AMR_NB,
        sampleRate = 8000,
        bitRate = 8,
        channels = 1
    );

    fun applyTo(settings: RecordingSettings): RecordingSettings = settings.copy(
        fileExtension = fileExtension,
        outputFormat = outputFormat,
        audioEncoder = audioEncoder,
        sampleRate = sampleRate,
        bitRate = bitRate,
        channels = channels
    )

    companion object {
        fun detect(settings: RecordingSettings): RecordingPreset? =
            entries.firstOrNull { preset ->
                preset.fileExtension == settings.fileExtension &&
                    preset.outputFormat == settings.outputFormat &&
                    preset.sampleRate == settings.sampleRate &&
                    preset.bitRate == settings.bitRate &&
                    preset.channels == settings.channels
            }
    }
}
