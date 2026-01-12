package com.entaku.simpleRecord

import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDateTime
import java.util.UUID

class RecordingDataTest {

    @Test
    fun `create RecordingData with all fields`() {
        val uuid = UUID.randomUUID()
        val now = LocalDateTime.now()

        val recording = RecordingData(
            uuid = uuid,
            title = "Test Recording",
            creationDate = now,
            fileExtension = "m4a",
            khz = "44.1",
            bitRate = 128000,
            channels = 2,
            duration = 120L,
            filePath = "/path/to/file.m4a"
        )

        assertEquals(uuid, recording.uuid)
        assertEquals("Test Recording", recording.title)
        assertEquals(now, recording.creationDate)
        assertEquals("m4a", recording.fileExtension)
        assertEquals("44.1", recording.khz)
        assertEquals(128000, recording.bitRate)
        assertEquals(2, recording.channels)
        assertEquals(120L, recording.duration)
        assertEquals("/path/to/file.m4a", recording.filePath)
    }

    @Test
    fun `create RecordingData with null uuid`() {
        val recording = RecordingData(
            uuid = null,
            title = "Test Recording",
            creationDate = LocalDateTime.now(),
            fileExtension = "mp3",
            khz = "48",
            bitRate = 192000,
            channels = 1,
            duration = 60L,
            filePath = "/path/to/file.mp3"
        )

        assertNull(recording.uuid)
        assertEquals("Test Recording", recording.title)
    }

    @Test
    fun `RecordingData equality`() {
        val uuid = UUID.randomUUID()
        val now = LocalDateTime.now()

        val recording1 = RecordingData(
            uuid = uuid,
            title = "Test",
            creationDate = now,
            fileExtension = "m4a",
            khz = "44.1",
            bitRate = 128000,
            channels = 2,
            duration = 120L,
            filePath = "/path"
        )

        val recording2 = RecordingData(
            uuid = uuid,
            title = "Test",
            creationDate = now,
            fileExtension = "m4a",
            khz = "44.1",
            bitRate = 128000,
            channels = 2,
            duration = 120L,
            filePath = "/path"
        )

        assertEquals(recording1, recording2)
    }

    @Test
    fun `RecordingData copy`() {
        val original = RecordingData(
            uuid = UUID.randomUUID(),
            title = "Original",
            creationDate = LocalDateTime.now(),
            fileExtension = "m4a",
            khz = "44.1",
            bitRate = 128000,
            channels = 2,
            duration = 120L,
            filePath = "/path"
        )

        val copy = original.copy(title = "Modified")

        assertEquals("Modified", copy.title)
        assertEquals(original.uuid, copy.uuid)
        assertEquals(original.duration, copy.duration)
    }
}
