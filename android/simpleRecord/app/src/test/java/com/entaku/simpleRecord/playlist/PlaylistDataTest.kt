package com.entaku.simpleRecord.playlist

import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDateTime
import java.util.UUID

class PlaylistDataTest {

    @Test
    fun `create PlaylistData with all fields`() {
        val uuid = UUID.randomUUID()
        val creationDate = LocalDateTime.now()
        val updatedDate = LocalDateTime.now()

        val playlist = PlaylistData(
            uuid = uuid,
            name = "My Playlist",
            creationDate = creationDate,
            updatedDate = updatedDate,
            recordingCount = 5
        )

        assertEquals(uuid, playlist.uuid)
        assertEquals("My Playlist", playlist.name)
        assertEquals(creationDate, playlist.creationDate)
        assertEquals(updatedDate, playlist.updatedDate)
        assertEquals(5, playlist.recordingCount)
    }

    @Test
    fun `create PlaylistData with default recordingCount`() {
        val uuid = UUID.randomUUID()
        val now = LocalDateTime.now()

        val playlist = PlaylistData(
            uuid = uuid,
            name = "Empty Playlist",
            creationDate = now,
            updatedDate = now
        )

        assertEquals(0, playlist.recordingCount)
    }

    @Test
    fun `PlaylistData equality`() {
        val uuid = UUID.randomUUID()
        val now = LocalDateTime.now()

        val playlist1 = PlaylistData(
            uuid = uuid,
            name = "Test",
            creationDate = now,
            updatedDate = now,
            recordingCount = 3
        )

        val playlist2 = PlaylistData(
            uuid = uuid,
            name = "Test",
            creationDate = now,
            updatedDate = now,
            recordingCount = 3
        )

        assertEquals(playlist1, playlist2)
    }

    @Test
    fun `PlaylistData copy with updated name`() {
        val original = PlaylistData(
            uuid = UUID.randomUUID(),
            name = "Original",
            creationDate = LocalDateTime.now(),
            updatedDate = LocalDateTime.now(),
            recordingCount = 2
        )

        val copy = original.copy(name = "Renamed")

        assertEquals("Renamed", copy.name)
        assertEquals(original.uuid, copy.uuid)
        assertEquals(original.recordingCount, copy.recordingCount)
    }

    @Test
    fun `PlaylistData copy with updated recordingCount`() {
        val original = PlaylistData(
            uuid = UUID.randomUUID(),
            name = "Test",
            creationDate = LocalDateTime.now(),
            updatedDate = LocalDateTime.now(),
            recordingCount = 0
        )

        val copy = original.copy(recordingCount = 10)

        assertEquals(10, copy.recordingCount)
        assertEquals(original.name, copy.name)
    }
}
