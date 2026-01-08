package com.entaku.simpleRecord

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import app.cash.turbine.test
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

    private val testRecordings = listOf(
        RecordingData(
            uuid = UUID.randomUUID(),
            title = "Recording 1",
            creationDate = LocalDateTime.now(),
            fileExtension = "3gp",
            khz = "44100",
            bitRate = 16,
            channels = 1,
            duration = 120,
            filePath = "/path/to/recording1.3gp"
        ),
        RecordingData(
            uuid = UUID.randomUUID(),
            title = "Recording 2",
            creationDate = LocalDateTime.now().minusDays(1),
            fileExtension = "3gp",
            khz = "44100",
            bitRate = 16,
            channels = 1,
            duration = 180,
            filePath = "/path/to/recording2.3gp"
        )
    )

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
    fun `initial state has empty recordings and isLoading true`() {
        viewModel = RecordingsViewModel(repository)

        val state = viewModel.uiState.value
        assertTrue(state.recordings.isEmpty())
        assertTrue(state.isLoading)
        assertEquals(null, state.error)
    }

    @Test
    fun `loadRecordings updates state with recordings from repository`() = runTest {
        coEvery { repository.getAllRecordings() } returns flowOf(testRecordings)

        viewModel = RecordingsViewModel(repository)

        viewModel.uiState.test {
            // Initial state
            val initialState = awaitItem()
            assertTrue(initialState.isLoading)
            assertTrue(initialState.recordings.isEmpty())

            // Load recordings
            viewModel.loadRecordings()
            testDispatcher.scheduler.advanceUntilIdle()

            // State after loading
            val loadedState = awaitItem()
            assertEquals(testRecordings.size, loadedState.recordings.size)
            assertEquals(false, loadedState.isLoading)

            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `loadRecordings handles empty list`() = runTest {
        coEvery { repository.getAllRecordings() } returns flowOf(emptyList())

        viewModel = RecordingsViewModel(repository)

        viewModel.uiState.test {
            awaitItem() // Initial state

            viewModel.loadRecordings()
            testDispatcher.scheduler.advanceUntilIdle()

            val state = awaitItem()
            assertTrue(state.recordings.isEmpty())
            assertEquals(false, state.isLoading)

            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `deleteRecording calls repository delete method`() = runTest {
        val uuidToDelete = testRecordings[0].uuid!!
        coEvery { repository.getAllRecordings() } returns flowOf(testRecordings)
        coEvery { repository.deleteRecording(uuidToDelete) } returns Unit

        viewModel = RecordingsViewModel(repository)

        viewModel.deleteRecording(uuidToDelete)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.deleteRecording(uuidToDelete) }
    }

    @Test
    fun `updateRecordingTitle calls repository update method`() = runTest {
        val uuidToUpdate = testRecordings[0].uuid!!
        val newTitle = "Updated Title"
        coEvery { repository.getAllRecordings() } returns flowOf(testRecordings)
        coEvery { repository.updateRecordingTitle(uuidToUpdate, newTitle) } returns Unit

        viewModel = RecordingsViewModel(repository)

        viewModel.updateRecordingTitle(uuidToUpdate, newTitle)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.updateRecordingTitle(uuidToUpdate, newTitle) }
    }

    @Test
    fun `deleteRecording triggers loadRecordings after deletion`() = runTest {
        val uuidToDelete = testRecordings[0].uuid!!
        coEvery { repository.getAllRecordings() } returns flowOf(testRecordings)
        coEvery { repository.deleteRecording(uuidToDelete) } returns Unit

        viewModel = RecordingsViewModel(repository)

        viewModel.deleteRecording(uuidToDelete)
        testDispatcher.scheduler.advanceUntilIdle()

        // Verify loadRecordings is called after delete (getAllRecordings should be called)
        coVerify(atLeast = 1) { repository.getAllRecordings() }
    }

    @Test
    fun `updateRecordingTitle triggers loadRecordings after update`() = runTest {
        val uuidToUpdate = testRecordings[0].uuid!!
        val newTitle = "New Title"
        coEvery { repository.getAllRecordings() } returns flowOf(testRecordings)
        coEvery { repository.updateRecordingTitle(uuidToUpdate, newTitle) } returns Unit

        viewModel = RecordingsViewModel(repository)

        viewModel.updateRecordingTitle(uuidToUpdate, newTitle)
        testDispatcher.scheduler.advanceUntilIdle()

        // Verify loadRecordings is called after update (getAllRecordings should be called)
        coVerify(atLeast = 1) { repository.getAllRecordings() }
    }
}
