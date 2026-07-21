package com.entaku.simpleRecord

import com.entaku.simpleRecord.record.RecordingRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDateTime
import java.util.UUID

@OptIn(ExperimentalCoroutinesApi::class)
class RecordingsViewModelTest {

    private val testDispatcher = StandardTestDispatcher()

    private lateinit var fakeRepository: FakeRecordingRepository
    private lateinit var viewModel: RecordingsViewModel

    private val apple = recording(title = "apple", daysAgo = 0, durationSeconds = 90) // medium
    private val banana = recording(title = "Banana", daysAgo = 2, durationSeconds = 30) // short
    private val cherry = recording(title = "Cherry", daysAgo = 1, durationSeconds = 400) // long

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        fakeRepository = FakeRecordingRepository()
        viewModel = RecordingsViewModel(fakeRepository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun loadSample() = runTest {
        fakeRepository.recordingsFlow.value = listOf(apple, banana, cherry)
        viewModel.loadRecordings()
        testDispatcher.scheduler.advanceUntilIdle()
    }

    @Test
    fun `default state is empty and loading`() {
        val state = viewModel.uiState.value
        assertTrue(state.recordings.isEmpty())
        assertTrue(state.isLoading)
        assertEquals("", state.searchQuery)
        assertEquals(SortOption.DATE_DESCENDING, state.sortOption)
        assertEquals(DurationFilter.ALL, state.durationFilter)
    }

    @Test
    fun `loadRecordings populates state sorted by date descending by default`() = runTest {
        loadSample()

        val state = viewModel.uiState.value
        assertEquals(false, state.isLoading)
        assertEquals(listOf(apple, cherry, banana), state.recordings)
    }

    @Test
    fun `setSortOption DATE_ASCENDING orders oldest first`() = runTest {
        loadSample()

        viewModel.setSortOption(SortOption.DATE_ASCENDING)

        assertEquals(listOf(banana, cherry, apple), viewModel.uiState.value.recordings)
    }

    @Test
    fun `setSortOption TITLE_ASCENDING orders case-insensitively A to Z`() = runTest {
        loadSample()

        viewModel.setSortOption(SortOption.TITLE_ASCENDING)

        assertEquals(listOf(apple, banana, cherry), viewModel.uiState.value.recordings)
    }

    @Test
    fun `setSortOption TITLE_DESCENDING orders case-insensitively Z to A`() = runTest {
        loadSample()

        viewModel.setSortOption(SortOption.TITLE_DESCENDING)

        assertEquals(listOf(cherry, banana, apple), viewModel.uiState.value.recordings)
    }

    @Test
    fun `setSortOption DURATION_ASCENDING orders shortest first`() = runTest {
        loadSample()

        viewModel.setSortOption(SortOption.DURATION_ASCENDING)

        assertEquals(listOf(banana, apple, cherry), viewModel.uiState.value.recordings)
    }

    @Test
    fun `setSortOption DURATION_DESCENDING orders longest first`() = runTest {
        loadSample()

        viewModel.setSortOption(SortOption.DURATION_DESCENDING)

        assertEquals(listOf(cherry, apple, banana), viewModel.uiState.value.recordings)
    }

    @Test
    fun `setSearchQuery filters by title case-insensitively`() = runTest {
        loadSample()

        viewModel.setSearchQuery("ap")

        assertEquals(listOf(apple), viewModel.uiState.value.recordings)
        assertEquals("ap", viewModel.uiState.value.searchQuery)
    }

    @Test
    fun `setSearchQuery with blank query keeps all recordings`() = runTest {
        loadSample()

        viewModel.setSearchQuery("")

        assertEquals(3, viewModel.uiState.value.recordings.size)
    }

    @Test
    fun `setSearchQuery with no match returns empty list`() = runTest {
        loadSample()

        viewModel.setSearchQuery("zzz")

        assertTrue(viewModel.uiState.value.recordings.isEmpty())
    }

    @Test
    fun `setDurationFilter SHORT keeps only recordings under 1 minute`() = runTest {
        loadSample()

        viewModel.setDurationFilter(DurationFilter.SHORT)

        assertEquals(listOf(banana), viewModel.uiState.value.recordings)
    }

    @Test
    fun `setDurationFilter MEDIUM keeps only recordings between 1 and 5 minutes`() = runTest {
        loadSample()

        viewModel.setDurationFilter(DurationFilter.MEDIUM)

        assertEquals(listOf(apple), viewModel.uiState.value.recordings)
    }

    @Test
    fun `setDurationFilter LONG keeps only recordings 5 minutes or longer`() = runTest {
        loadSample()

        viewModel.setDurationFilter(DurationFilter.LONG)

        assertEquals(listOf(cherry), viewModel.uiState.value.recordings)
    }

    @Test
    fun `search and duration filter combine`() = runTest {
        loadSample()

        viewModel.setSearchQuery("e") // matches apple and Cherry, not Banana
        viewModel.setDurationFilter(DurationFilter.LONG)

        assertEquals(listOf(cherry), viewModel.uiState.value.recordings)
    }

    @Test
    fun `filters persist across reload after delete`() = runTest {
        loadSample()
        viewModel.setDurationFilter(DurationFilter.SHORT)

        viewModel.deleteRecording(banana.uuid!!)
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals(DurationFilter.SHORT, viewModel.uiState.value.durationFilter)
        assertTrue(viewModel.uiState.value.recordings.isEmpty())
    }

    private fun recording(title: String, daysAgo: Long, durationSeconds: Long): RecordingData {
        return RecordingData(
            uuid = UUID.randomUUID(),
            title = title,
            creationDate = LocalDateTime.now().minusDays(daysAgo),
            fileExtension = "m4a",
            khz = "44.1",
            bitRate = 128000,
            channels = 2,
            duration = durationSeconds,
            filePath = "/path/to/$title.m4a"
        )
    }
}

private class FakeRecordingRepository : RecordingRepository {
    val recordingsFlow = MutableStateFlow<List<RecordingData>>(emptyList())

    override suspend fun saveRecordingData(recordingData: RecordingData) {
        recordingsFlow.value = recordingsFlow.value + recordingData
    }

    override fun getAllRecordings(): Flow<List<RecordingData>> = recordingsFlow

    override suspend fun deleteRecording(uuid: UUID) {
        recordingsFlow.value = recordingsFlow.value.filterNot { it.uuid == uuid }
    }

    override suspend fun updateRecordingTitle(uuid: UUID, newTitle: String) {
        recordingsFlow.value = recordingsFlow.value.map {
            if (it.uuid == uuid) it.copy(title = newTitle) else it
        }
    }

    override suspend fun updateTranscription(uuid: UUID, text: String) {
        recordingsFlow.value = recordingsFlow.value.map {
            if (it.uuid == uuid) it.copy(transcriptionText = text) else it
        }
    }

    override suspend fun getRecording(uuid: UUID): RecordingData? {
        return recordingsFlow.value.firstOrNull { it.uuid == uuid }
    }

    override suspend fun updateMeetingMinutes(uuid: UUID, text: String) {
        recordingsFlow.value = recordingsFlow.value.map {
            if (it.uuid == uuid) it.copy(meetingMinutesText = text) else it
        }
    }
}
