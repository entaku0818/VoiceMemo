package com.entaku.simpleRecord

import java.time.LocalDateTime
import java.util.UUID

data class RecordingData(
    val uuid: UUID? = null,
    val title: String,
    val creationDate: LocalDateTime,
    val fileExtension: String,
    val khz: String,
    val bitRate: Int,
    val channels: Int,
    val duration: Long,
    val filePath: String
)