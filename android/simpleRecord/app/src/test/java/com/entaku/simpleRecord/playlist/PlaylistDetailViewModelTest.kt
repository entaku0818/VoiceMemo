package com.entaku.simpleRecord.playlist

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import app.cash.turbine.test
import com.entaku.simpleRecord.RecordingData
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
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.time.LocalDateTime
import java.util.UUID

@OptIn(ExperimentalCoroutinesApi::class)
class PlaylistDetailViewModelTest {

    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var repository: PlaylistRepository
    private lateinit var viewModel: PlaylistDetailViewModel

    private val testPlaylistUuid = UUID.randomUUID()
    private val testPlaylist = PlaylistData(
        uuid = testPlaylistUuid,
        name = "Test Playlist",
        creationDate = LocalDateTime.now(),
        updatedDate = LocalDateTime.now(),
        recordingCount = 2
    )

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
        coEvery { repository.getPlaylistById(testPlaylistUuid) } returns testPlaylist
        coEvery { repository.getRecordingsForPlaylist(testPlaylistUuid) } returns flowOf(testRecordings)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `initial state has null playlist and isLoading true`() = runTest {
        // Create ViewModel without advancing dispatcher to capture initial state
        coEvery { repository.getPlaylistById(any()) } returns null
        coEvery { repository.getRecordingsForPlaylist(any()) } returns flowOf(emptyList())

        viewModel = PlaylistDetailViewModel(repository, testPlaylistUuid)

        val state = viewModel.uiState.value
        assertNull(state.playlist)
        assertTrue(state.recordings.isEmpty())
        assertTrue(state.isLoading)
    }

    @Test
    fun `loadPlaylistDetail loads playlist from repository`() = runTest {
        viewModel = PlaylistDetailViewModel(repository, testPlaylistUuid)

        viewModel.uiState.test {
            awaitItem() // Initial state

            testDispatcher.scheduler.advanceUntilIdle()

            // Should receive state with playlist
            val stateWithPlaylist = awaitItem()
            assertEquals(testPlaylist, stateWithPlaylist.playlist)

            // Should receive state with recordings
            val stateWithRecordings = awaitItem()
            assertEquals(testRecordings.size, stateWithRecordings.recordings.size)
            assertEquals(false, stateWithRecordings.isLoading)

            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `loadPlaylistDetail handles null playlist`() = runTest {
        coEvery { repository.getPlaylistById(testPlaylistUuid) } returns null
        coEvery { repository.getRecordingsForPlaylist(testPlaylistUuid) } returns flowOf(emptyList())

        viewModel = PlaylistDetailViewModel(repository, testPlaylistUuid)

        viewModel.uiState.test {
            awaitItem() // Initial state

            testDispatcher.scheduler.advanceUntilIdle()

            val state = awaitItem()
            assertNull(state.playlist)

            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `loadPlaylistDetail handles empty recordings`() = runTest {
        coEvery { repository.getRecordingsForPlaylist(testPlaylistUuid) } returns flowOf(emptyList())

        viewModel = PlaylistDetailViewModel(repository, testPlaylistUuid)

        viewModel.uiState.test {
            awaitItem() // Initial state

            testDispatcher.scheduler.advanceUntilIdle()

            // Skip playlist update
            awaitItem()

            val state = awaitItem()
            assertTrue(state.recordings.isEmpty())
            assertEquals(false, state.isLoading)

            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `removeRecording calls repository remove method`() = runTest {
        viewModel = PlaylistDetailViewModel(repository, testPlaylistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        val recordingUuid = testRecordings[0].uuid!!

        viewModel.removeRecording(recordingUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.removeRecordingFromPlaylist(testPlaylistUuid, recordingUuid) }
    }

    @Test
    fun `addRecording calls repository add method`() = runTest {
        viewModel = PlaylistDetailViewModel(repository, testPlaylistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        val newRecordingUuid = UUID.randomUUID()

        viewModel.addRecording(newRecordingUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.addRecordingToPlaylist(testPlaylistUuid, newRecordingUuid) }
    }

    @Test
    fun `loadPlaylistDetail is called on init`() = runTest {
        viewModel = PlaylistDetailViewModel(repository, testPlaylistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.getPlaylistById(testPlaylistUuid) }
        coVerify { repository.getRecordingsForPlaylist(testPlaylistUuid) }
    }

    @Test
    fun `multiple recordings can be added sequentially`() = runTest {
        viewModel = PlaylistDetailViewModel(repository, testPlaylistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        val recordingUuid1 = UUID.randomUUID()
        val recordingUuid2 = UUID.randomUUID()

        viewModel.addRecording(recordingUuid1)
        viewModel.addRecording(recordingUuid2)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.addRecordingToPlaylist(testPlaylistUuid, recordingUuid1) }
        coVerify { repository.addRecordingToPlaylist(testPlaylistUuid, recordingUuid2) }
    }

    @Test
    fun `multiple recordings can be removed sequentially`() = runTest {
        viewModel = PlaylistDetailViewModel(repository, testPlaylistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        val recordingUuid1 = testRecordings[0].uuid!!
        val recordingUuid2 = testRecordings[1].uuid!!

        viewModel.removeRecording(recordingUuid1)
        viewModel.removeRecording(recordingUuid2)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.removeRecordingFromPlaylist(testPlaylistUuid, recordingUuid1) }
        coVerify { repository.removeRecordingFromPlaylist(testPlaylistUuid, recordingUuid2) }
    }
}
