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
import org.junit.Assert.assertFalse
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

    private val testRecording = RecordingData(
        uuid = UUID.randomUUID(),
        title = "Test Recording",
        creationDate = LocalDateTime.now(),
        fileExtension = "m4a",
        khz = "44.1",
        bitRate = 128,
        channels = 2,
        duration = 120L,
        filePath = "/test/path/recording.m4a"
    )

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        repository = mockk(relaxed = true)
        viewModel = RecordingsViewModel(repository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `initial state is loading`() {
        val state = viewModel.uiState.value
        assertTrue(state.isLoading)
        assertTrue(state.recordings.isEmpty())
    }

    @Test
    fun `loadRecordings updates state with recordings`() = runTest {
        val recordings = listOf(testRecording)
        coEvery { repository.getAllRecordings() } returns flowOf(recordings)

        viewModel.loadRecordings()
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.uiState.test {
            val state = awaitItem()
            assertEquals(1, state.recordings.size)
            assertEquals("Test Recording", state.recordings[0].title)
            assertFalse(state.isLoading)
        }
    }

    @Test
    fun `loadRecordings with empty list shows empty state`() = runTest {
        coEvery { repository.getAllRecordings() } returns flowOf(emptyList())

        viewModel.loadRecordings()
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.uiState.test {
            val state = awaitItem()
            assertTrue(state.recordings.isEmpty())
            assertFalse(state.isLoading)
        }
    }

    @Test
    fun `deleteRecording calls repository delete`() = runTest {
        val uuid = UUID.randomUUID()
        coEvery { repository.getAllRecordings() } returns flowOf(emptyList())

        viewModel.deleteRecording(uuid)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.deleteRecording(uuid) }
    }

    @Test
    fun `updateRecordingTitle calls repository update`() = runTest {
        val uuid = UUID.randomUUID()
        val newTitle = "Updated Title"
        coEvery { repository.getAllRecordings() } returns flowOf(emptyList())

        viewModel.updateRecordingTitle(uuid, newTitle)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.updateRecordingTitle(uuid, newTitle) }
    }

    @Test
    fun `loadRecordings with multiple recordings returns all`() = runTest {
        val recordings = listOf(
            testRecording,
            testRecording.copy(uuid = UUID.randomUUID(), title = "Second Recording"),
            testRecording.copy(uuid = UUID.randomUUID(), title = "Third Recording")
        )
        coEvery { repository.getAllRecordings() } returns flowOf(recordings)

        viewModel.loadRecordings()
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.uiState.test {
            val state = awaitItem()
            assertEquals(3, state.recordings.size)
        }
    }
}
