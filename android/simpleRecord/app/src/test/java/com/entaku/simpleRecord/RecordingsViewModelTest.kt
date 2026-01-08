package com.entaku.simpleRecord

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import com.entaku.simpleRecord.record.RecordingRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.time.LocalDateTime
import java.util.UUID

@OptIn(ExperimentalCoroutinesApi::class)
class RecordingsViewModelTest {

    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var repository: RecordingRepository
    private lateinit var viewModel: RecordingsViewModel

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        repository = mockk(relaxed = true)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `initial state has empty recordings and isLoading true`() = runTest {
        viewModel = RecordingsViewModel(repository)
        val state = viewModel.uiState.value
        assertTrue(state.recordings.isEmpty())
        assertTrue(state.isLoading)
    }

    @Test
    fun `loadRecordings updates state with recordings from repository`() = runTest {
        val testRecordings = listOf(
            createTestRecording("Recording 1"),
            createTestRecording("Recording 2")
        )
        coEvery { repository.getAllRecordings() } returns flowOf(testRecordings)

        viewModel = RecordingsViewModel(repository)
        viewModel.loadRecordings()
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(2, state.recordings.size)
        assertEquals("Recording 1", state.recordings[0].title)
        assertEquals("Recording 2", state.recordings[1].title)
    }

    @Test
    fun `loadRecordings sets isLoading to false after loading`() = runTest {
        coEvery { repository.getAllRecordings() } returns flowOf(emptyList())

        viewModel = RecordingsViewModel(repository)
        viewModel.loadRecordings()
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(false, state.isLoading)
    }

    @Test
    fun `loadRecordings handles empty list correctly`() = runTest {
        coEvery { repository.getAllRecordings() } returns flowOf(emptyList())

        viewModel = RecordingsViewModel(repository)
        viewModel.loadRecordings()
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertTrue(state.recordings.isEmpty())
        assertEquals(false, state.isLoading)
    }

    @Test
    fun `deleteRecording calls repository deleteRecording`() = runTest {
        coEvery { repository.getAllRecordings() } returns flowOf(emptyList())
        val uuid = UUID.randomUUID()

        viewModel = RecordingsViewModel(repository)
        viewModel.deleteRecording(uuid)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.deleteRecording(uuid) }
    }

    @Test
    fun `updateRecordingTitle calls repository updateRecordingTitle`() = runTest {
        coEvery { repository.getAllRecordings() } returns flowOf(emptyList())
        val uuid = UUID.randomUUID()
        val newTitle = "Updated Title"

        viewModel = RecordingsViewModel(repository)
        viewModel.updateRecordingTitle(uuid, newTitle)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.updateRecordingTitle(uuid, newTitle) }
    }

    @Test
    fun `deleteRecording reloads recordings after deletion`() = runTest {
        coEvery { repository.getAllRecordings() } returns flowOf(emptyList())
        val uuid = UUID.randomUUID()

        viewModel = RecordingsViewModel(repository)
        viewModel.deleteRecording(uuid)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify(atLeast = 1) { repository.getAllRecordings() }
    }

    private fun createTestRecording(title: String): RecordingData {
        return RecordingData(
            uuid = UUID.randomUUID(),
            title = title,
            creationDate = LocalDateTime.now(),
            fileExtension = "m4a",
            khz = "44.1",
            bitRate = 128,
            channels = 2,
            duration = 60L,
            filePath = "/test/path/$title.m4a"
        )
    }
}
