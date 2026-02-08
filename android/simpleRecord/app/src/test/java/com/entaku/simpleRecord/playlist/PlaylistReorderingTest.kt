package com.entaku.simpleRecord.playlist

import com.entaku.simpleRecord.RecordingData
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import java.time.LocalDateTime
import java.util.UUID

/**
 * Unit tests for playlist reordering functionality (Issue #97)
 *
 * Tests cover:
 * - Basic reordering operations
 * - Edge cases (first/last positions)
 * - Multiple reorderings
 * - Position persistence
 */
@ExperimentalCoroutinesApi
class PlaylistReorderingTest {

    private lateinit var mockRepository: MockPlaylistRepository

    @Before
    fun setup() {
        mockRepository = MockPlaylistRepository()
    }

    @Test
    fun `reorderRecordings - move item down in list`() = runTest {
        // Given: Playlist with 3 recordings [A, B, C]
        val playlistUuid = UUID.randomUUID()
        val recordingA = createTestRecording("Recording A", 0)
        val recordingB = createTestRecording("Recording B", 1)
        val recordingC = createTestRecording("Recording C", 2)

        val initialRecordings = listOf(recordingA, recordingB, recordingC)
        mockRepository.setRecordingsForPlaylist(playlistUuid, initialRecordings)

        // When: Move A (index 0) to position 2
        val reorderedPositions = listOf(
            recordingB.uuid!! to 0,  // B moves to 0
            recordingC.uuid!! to 1,  // C moves to 1
            recordingA.uuid!! to 2   // A moves to 2
        )
        mockRepository.reorderRecordings(playlistUuid, reorderedPositions)

        // Then: Order should be [B, C, A]
        val result = mockRepository.getRecordingPositions(playlistUuid)
        assertEquals(0, result[recordingB.uuid])
        assertEquals(1, result[recordingC.uuid])
        assertEquals(2, result[recordingA.uuid])
    }

    @Test
    fun `reorderRecordings - move item up in list`() = runTest {
        // Given: Playlist with 3 recordings [A, B, C]
        val playlistUuid = UUID.randomUUID()
        val recordingA = createTestRecording("Recording A", 0)
        val recordingB = createTestRecording("Recording B", 1)
        val recordingC = createTestRecording("Recording C", 2)

        val initialRecordings = listOf(recordingA, recordingB, recordingC)
        mockRepository.setRecordingsForPlaylist(playlistUuid, initialRecordings)

        // When: Move C (index 2) to position 0
        val reorderedPositions = listOf(
            recordingC.uuid!! to 0,  // C moves to 0
            recordingA.uuid!! to 1,  // A moves to 1
            recordingB.uuid!! to 2   // B moves to 2
        )
        mockRepository.reorderRecordings(playlistUuid, reorderedPositions)

        // Then: Order should be [C, A, B]
        val result = mockRepository.getRecordingPositions(playlistUuid)
        assertEquals(0, result[recordingC.uuid])
        assertEquals(1, result[recordingA.uuid])
        assertEquals(2, result[recordingB.uuid])
    }

    @Test
    fun `reorderRecordings - swap adjacent items`() = runTest {
        // Given: Playlist with 4 recordings [A, B, C, D]
        val playlistUuid = UUID.randomUUID()
        val recordingA = createTestRecording("Recording A", 0)
        val recordingB = createTestRecording("Recording B", 1)
        val recordingC = createTestRecording("Recording C", 2)
        val recordingD = createTestRecording("Recording D", 3)

        val initialRecordings = listOf(recordingA, recordingB, recordingC, recordingD)
        mockRepository.setRecordingsForPlaylist(playlistUuid, initialRecordings)

        // When: Swap B and C
        val reorderedPositions = listOf(
            recordingA.uuid!! to 0,
            recordingC.uuid!! to 1,  // C moves to 1 (was 2)
            recordingB.uuid!! to 2,  // B moves to 2 (was 1)
            recordingD.uuid!! to 3
        )
        mockRepository.reorderRecordings(playlistUuid, reorderedPositions)

        // Then: Order should be [A, C, B, D]
        val result = mockRepository.getRecordingPositions(playlistUuid)
        assertEquals(0, result[recordingA.uuid])
        assertEquals(1, result[recordingC.uuid])
        assertEquals(2, result[recordingB.uuid])
        assertEquals(3, result[recordingD.uuid])
    }

    @Test
    fun `reorderRecordings - move to first position`() = runTest {
        // Given: Playlist with 5 recordings
        val playlistUuid = UUID.randomUUID()
        val recordings = (0..4).map { createTestRecording("Recording $it", it) }
        mockRepository.setRecordingsForPlaylist(playlistUuid, recordings)

        // When: Move last item to first position
        val lastRecording = recordings.last()
        val reorderedPositions = mutableListOf<Pair<UUID, Int>>()
        reorderedPositions.add(lastRecording.uuid!! to 0)
        recordings.dropLast(1).forEachIndexed { index, recording ->
            reorderedPositions.add(recording.uuid!! to index + 1)
        }
        mockRepository.reorderRecordings(playlistUuid, reorderedPositions)

        // Then: Last item should be first
        val result = mockRepository.getRecordingPositions(playlistUuid)
        assertEquals(0, result[lastRecording.uuid])
    }

    @Test
    fun `reorderRecordings - move to last position`() = runTest {
        // Given: Playlist with 5 recordings
        val playlistUuid = UUID.randomUUID()
        val recordings = (0..4).map { createTestRecording("Recording $it", it) }
        mockRepository.setRecordingsForPlaylist(playlistUuid, recordings)

        // When: Move first item to last position
        val firstRecording = recordings.first()
        val reorderedPositions = mutableListOf<Pair<UUID, Int>>()
        recordings.drop(1).forEachIndexed { index, recording ->
            reorderedPositions.add(recording.uuid!! to index)
        }
        reorderedPositions.add(firstRecording.uuid!! to recordings.size - 1)
        mockRepository.reorderRecordings(playlistUuid, reorderedPositions)

        // Then: First item should be last
        val result = mockRepository.getRecordingPositions(playlistUuid)
        assertEquals(recordings.size - 1, result[firstRecording.uuid])
    }

    @Test
    fun `reorderRecordings - no change when positions are same`() = runTest {
        // Given: Playlist with 3 recordings
        val playlistUuid = UUID.randomUUID()
        val recordings = (0..2).map { createTestRecording("Recording $it", it) }
        mockRepository.setRecordingsForPlaylist(playlistUuid, recordings)

        // When: Reorder with same positions
        val samePositions = recordings.mapIndexed { index, recording ->
            recording.uuid!! to index
        }
        mockRepository.reorderRecordings(playlistUuid, samePositions)

        // Then: Positions should remain unchanged
        val result = mockRepository.getRecordingPositions(playlistUuid)
        recordings.forEachIndexed { index, recording ->
            assertEquals(index, result[recording.uuid])
        }
    }

    @Test
    fun `reorderRecordings - handles empty playlist`() = runTest {
        // Given: Empty playlist
        val playlistUuid = UUID.randomUUID()
        mockRepository.setRecordingsForPlaylist(playlistUuid, emptyList())

        // When: Try to reorder (no-op)
        mockRepository.reorderRecordings(playlistUuid, emptyList())

        // Then: No error should occur
        val result = mockRepository.getRecordingPositions(playlistUuid)
        assertEquals(0, result.size)
    }

    @Test
    fun `reorderRecordings - handles single item playlist`() = runTest {
        // Given: Playlist with single recording
        val playlistUuid = UUID.randomUUID()
        val recording = createTestRecording("Recording A", 0)
        mockRepository.setRecordingsForPlaylist(playlistUuid, listOf(recording))

        // When: Reorder single item (no-op)
        mockRepository.reorderRecordings(playlistUuid, listOf(recording.uuid!! to 0))

        // Then: Position should remain 0
        val result = mockRepository.getRecordingPositions(playlistUuid)
        assertEquals(0, result[recording.uuid])
    }

    @Test
    fun `reorderRecordings - multiple reorderings persist correctly`() = runTest {
        // Given: Playlist with 3 recordings [A, B, C]
        val playlistUuid = UUID.randomUUID()
        val recordingA = createTestRecording("Recording A", 0)
        val recordingB = createTestRecording("Recording B", 1)
        val recordingC = createTestRecording("Recording C", 2)

        val initialRecordings = listOf(recordingA, recordingB, recordingC)
        mockRepository.setRecordingsForPlaylist(playlistUuid, initialRecordings)

        // When: First reorder [A, B, C] -> [B, A, C]
        mockRepository.reorderRecordings(
            playlistUuid,
            listOf(
                recordingB.uuid!! to 0,
                recordingA.uuid!! to 1,
                recordingC.uuid!! to 2
            )
        )

        // Then: Verify first reorder
        var result = mockRepository.getRecordingPositions(playlistUuid)
        assertEquals(0, result[recordingB.uuid])
        assertEquals(1, result[recordingA.uuid])
        assertEquals(2, result[recordingC.uuid])

        // When: Second reorder [B, A, C] -> [C, B, A]
        mockRepository.reorderRecordings(
            playlistUuid,
            listOf(
                recordingC.uuid!! to 0,
                recordingB.uuid!! to 1,
                recordingA.uuid!! to 2
            )
        )

        // Then: Verify second reorder
        result = mockRepository.getRecordingPositions(playlistUuid)
        assertEquals(0, result[recordingC.uuid])
        assertEquals(1, result[recordingB.uuid])
        assertEquals(2, result[recordingA.uuid])
    }

    // Helper functions

    private fun createTestRecording(title: String, position: Int): RecordingData {
        return RecordingData(
            uuid = UUID.randomUUID(),
            title = title,
            creationDate = LocalDateTime.now(),
            fileExtension = "m4a",
            khz = "44100",
            bitRate = 128,
            channels = 1,
            duration = 60,
            filePath = "/test/path/$title.m4a"
        )
    }
}

/**
 * Mock implementation of PlaylistRepository for testing
 */
class MockPlaylistRepository : PlaylistRepository {
    private val recordings = mutableMapOf<UUID, MutableList<RecordingData>>()
    private val recordingPositions = mutableMapOf<UUID, MutableMap<UUID, Int>>()

    fun setRecordingsForPlaylist(playlistUuid: UUID, recordingList: List<RecordingData>) {
        recordings[playlistUuid] = recordingList.toMutableList()
        recordingPositions[playlistUuid] = recordingList.mapIndexed { index, recording ->
            recording.uuid!! to index
        }.toMap().toMutableMap()
    }

    fun getRecordingPositions(playlistUuid: UUID): Map<UUID, Int> {
        return recordingPositions[playlistUuid] ?: emptyMap()
    }

    override suspend fun reorderRecordings(
        playlistUuid: UUID,
        reorderedRecordings: List<Pair<UUID, Int>>
    ) {
        val positions = recordingPositions[playlistUuid] ?: mutableMapOf()
        reorderedRecordings.forEach { (recordingUuid, newPosition) ->
            positions[recordingUuid] = newPosition
        }
        recordingPositions[playlistUuid] = positions
    }

    // Other required interface methods (not used in tests)
    override suspend fun createPlaylist(name: String): UUID = UUID.randomUUID()
    override fun getAllPlaylists() = TODO("Not needed for reordering tests")
    override suspend fun getPlaylistById(uuid: UUID) = null
    override fun getRecordingsForPlaylist(playlistUuid: UUID) = TODO("Not needed")
    override suspend fun updatePlaylistName(uuid: UUID, newName: String) {}
    override suspend fun deletePlaylist(uuid: UUID) {}
    override suspend fun addRecordingToPlaylist(playlistUuid: UUID, recordingUuid: UUID) {}
    override suspend fun removeRecordingFromPlaylist(playlistUuid: UUID, recordingUuid: UUID) {}
}
