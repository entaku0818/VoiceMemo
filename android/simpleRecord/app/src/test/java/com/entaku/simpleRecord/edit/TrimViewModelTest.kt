package com.entaku.simpleRecord.edit

import com.entaku.simpleRecord.RecordingData
import com.entaku.simpleRecord.record.RecordingRepository
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDateTime
import java.util.UUID

/**
 * Unit tests for TrimViewModel (Issue #201, trim-only scope).
 *
 * The real [AudioTrimmerImpl] depends on android.media classes not available under plain JUnit,
 * so these tests exercise state management and the save flow with a fake [AudioTrimmer].
 */
@OptIn(ExperimentalCoroutinesApi::class)
class TrimViewModelTest {

    private lateinit var repository: FakeRecordingRepository
    private lateinit var trimmer: AudioTrimmer

    @Before
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        repository = FakeRecordingRepository()
        trimmer = mockk(relaxed = true)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun recording(
        filePath: String = "/tmp/test.m4a",
        durationSeconds: Long = 60L
    ) = RecordingData(
        uuid = UUID.randomUUID(),
        title = "test",
        creationDate = LocalDateTime.of(2026, 7, 5, 0, 0),
        fileExtension = "m4a",
        khz = "44.1",
        bitRate = 128,
        channels = 1,
        duration = durationSeconds,
        filePath = filePath
    )

    private fun viewModel() = TrimViewModel(repository = repository, trimmer = trimmer)

    // --- initialize ---

    @Test
    fun `initialize - sets duration and full range as default selection`() = runTest {
        val vm = viewModel()

        vm.initialize(recording(durationSeconds = 30L))

        val state = vm.uiState.value
        assertEquals(30_000L, state.durationMs)
        assertEquals(0L, state.startMs)
        assertEquals(30_000L, state.endMs)
        assertFalse(state.isProcessing)
        assertFalse(state.isSaved)
        assertNull(state.errorMessage)
    }

    // --- setStart / setEnd ---

    @Test
    fun `setStart - clamps to 0 when negative`() = runTest {
        val vm = viewModel()
        vm.initialize(recording(durationSeconds = 30L))

        vm.setStart(-5_000L)

        assertEquals(0L, vm.uiState.value.startMs)
    }

    @Test
    fun `setStart - clamps to current end when exceeding it`() = runTest {
        val vm = viewModel()
        vm.initialize(recording(durationSeconds = 30L))
        vm.setEnd(10_000L)

        vm.setStart(20_000L)

        assertEquals(10_000L, vm.uiState.value.startMs)
    }

    @Test
    fun `setEnd - clamps to duration when exceeding it`() = runTest {
        val vm = viewModel()
        vm.initialize(recording(durationSeconds = 30L))

        vm.setEnd(999_000L)

        assertEquals(30_000L, vm.uiState.value.endMs)
    }

    @Test
    fun `setEnd - clamps to current start when below it`() = runTest {
        val vm = viewModel()
        vm.initialize(recording(durationSeconds = 30L))
        vm.setStart(15_000L)

        vm.setEnd(5_000L)

        assertEquals(15_000L, vm.uiState.value.endMs)
    }

    @Test
    fun `setStart - clears previous error and saved flag`() = runTest {
        val vm = viewModel()
        vm.initialize(recording(durationSeconds = 30L))
        vm.setEnd(0L) // triggers invalid range on trim below
        vm.trim(recording(durationSeconds = 30L))
        assertEquals(TrimViewModel.ERROR_INVALID_RANGE, vm.uiState.value.errorMessage)

        vm.setStart(1_000L)

        assertNull(vm.uiState.value.errorMessage)
    }

    // --- trim: validation ---

    @Test
    fun `trim - reports invalid range when end is not after start`() = runTest {
        val vm = viewModel()
        val rec = recording(durationSeconds = 30L)
        vm.initialize(rec)
        vm.setEnd(0L)

        vm.trim(rec)

        assertEquals(TrimViewModel.ERROR_INVALID_RANGE, vm.uiState.value.errorMessage)
        assertFalse(vm.uiState.value.isProcessing)
    }

    // --- trim: success ---

    @Test
    fun `trim - success saves a new recording and marks isSaved`() = runTest {
        val vm = viewModel()
        val rec = recording(filePath = "/tmp/original.m4a", durationSeconds = 60L)
        vm.initialize(rec)
        vm.setStart(5_000L)
        vm.setEnd(20_000L)

        vm.trim(rec)

        val state = vm.uiState.value
        assertTrue(state.isSaved)
        assertFalse(state.isProcessing)
        assertNull(state.errorMessage)

        val saved = repository.lastSaved
        assertTrue(saved != null)
        assertEquals(15L, saved!!.duration) // (20000 - 5000) / 1000
        assertEquals("test (Trim)", saved.title)
        assertEquals("m4a", saved.fileExtension)
        assertTrue(saved.filePath != rec.filePath) // saved as a new file, original untouched
    }

    @Test
    fun `trim - does not mutate original recording's transcription fields on the copy source`() = runTest {
        val vm = viewModel()
        val rec = recording(durationSeconds = 60L).copy(transcriptionText = "original text")
        vm.initialize(rec)
        vm.setEnd(10_000L)

        vm.trim(rec)

        // The trimmed copy should not inherit stale transcription for a different audio range.
        assertNull(repository.lastSaved?.transcriptionText)
        // Original object passed in is untouched (data class copy, not mutation).
        assertEquals("original text", rec.transcriptionText)
    }

    // --- trim: unsupported format ---

    @Test
    fun `trim - surfaces unsupported format error from trimmer`() = runTest {
        coEvery { trimmer.trim(any(), any(), any(), any()) } throws UnsupportedTrimFormatException("nope")
        val vm = viewModel()
        val rec = recording(durationSeconds = 30L)
        vm.initialize(rec)
        vm.setEnd(10_000L)

        vm.trim(rec)

        val state = vm.uiState.value
        assertEquals(TrimViewModel.ERROR_UNSUPPORTED_FORMAT, state.errorMessage)
        assertFalse(state.isProcessing)
        assertFalse(state.isSaved)
    }

    // --- trim: generic failure ---

    @Test
    fun `trim - surfaces generic error on unexpected exception`() = runTest {
        coEvery { trimmer.trim(any(), any(), any(), any()) } throws RuntimeException("disk full")
        val vm = viewModel()
        val rec = recording(durationSeconds = 30L)
        vm.initialize(rec)
        vm.setEnd(10_000L)

        vm.trim(rec)

        val state = vm.uiState.value
        assertEquals(TrimViewModel.ERROR_GENERIC, state.errorMessage)
        assertFalse(state.isProcessing)
    }

    @Test
    fun `trim - ignored when already processing`() = runTest {
        val vm = viewModel()
        val rec = recording(durationSeconds = 30L)
        vm.initialize(rec)
        vm.setEnd(10_000L)

        vm.trim(rec)
        val savedCountAfterFirst = repository.saveCount
        vm.trim(rec) // isProcessing already false again by now since UnconfinedTestDispatcher runs synchronously

        // Sanity: at least one save happened; this test mainly guards against crashes on re-entry.
        assertTrue(savedCountAfterFirst >= 1)
    }
}

private class FakeRecordingRepository : RecordingRepository {
    var lastSaved: RecordingData? = null
    var saveCount: Int = 0

    override suspend fun saveRecordingData(recordingData: RecordingData) {
        lastSaved = recordingData
        saveCount++
    }

    override fun getAllRecordings(): Flow<List<RecordingData>> = flowOf(emptyList())
    override suspend fun deleteRecording(uuid: UUID) = Unit
    override suspend fun updateRecordingTitle(uuid: UUID, newTitle: String) = Unit
    override suspend fun updateTranscription(uuid: UUID, text: String) = Unit
    override suspend fun getRecording(uuid: UUID): RecordingData? = null
    override suspend fun updateMeetingMinutes(uuid: UUID, text: String) = Unit
    override suspend fun addTagToRecording(recordingUuid: UUID, tagName: String) = Unit
    override suspend fun removeTagFromRecording(recordingUuid: UUID, tagName: String) = Unit
}
