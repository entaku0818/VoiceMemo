package com.entaku.simpleRecord.playlist

import java.time.LocalDateTime
import java.util.UUID

data class PlaylistData(
    val uuid: UUID,
    val name: String,
    val creationDate: LocalDateTime,
    val updatedDate: LocalDateTime,
    val recordingCount: Int = 0
)
