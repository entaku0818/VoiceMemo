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
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
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
    private val playlistUuid = UUID.randomUUID()

    private val testPlaylist = PlaylistData(
        uuid = playlistUuid,
        name = "Test Playlist",
        creationDate = LocalDateTime.now(),
        updatedDate = LocalDateTime.now(),
        recordingCount = 2
    )

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
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun createViewModel(): PlaylistDetailViewModel {
        coEvery { repository.getPlaylistById(playlistUuid) } returns testPlaylist
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(emptyList())
        return PlaylistDetailViewModel(repository, playlistUuid)
    }

    @Test
    fun `initial state is loading`() {
        coEvery { repository.getPlaylistById(playlistUuid) } returns null
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(emptyList())

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        val state = viewModel.uiState.value
        assertTrue(state.isLoading)
    }

    @Test
    fun `loadPlaylistDetail loads playlist info`() = runTest {
        coEvery { repository.getPlaylistById(playlistUuid) } returns testPlaylist
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(emptyList())

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.uiState.test {
            val state = awaitItem()
            assertNotNull(state.playlist)
            assertEquals("Test Playlist", state.playlist?.name)
        }
    }

    @Test
    fun `loadPlaylistDetail loads recordings`() = runTest {
        val recordings = listOf(testRecording)
        coEvery { repository.getPlaylistById(playlistUuid) } returns testPlaylist
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(recordings)

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.uiState.test {
            val state = awaitItem()
            assertEquals(1, state.recordings.size)
            assertEquals("Test Recording", state.recordings[0].title)
            assertFalse(state.isLoading)
        }
    }

    @Test
    fun `removeRecording calls repository`() = runTest {
        val viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()

        val recordingUuid = UUID.randomUUID()
        viewModel.removeRecording(recordingUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.removeRecordingFromPlaylist(playlistUuid, recordingUuid) }
    }

    @Test
    fun `addRecording calls repository`() = runTest {
        val viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()

        val recordingUuid = UUID.randomUUID()
        viewModel.addRecording(recordingUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.addRecordingToPlaylist(playlistUuid, recordingUuid) }
    }

    @Test
    fun `loadPlaylistDetail with multiple recordings returns all`() = runTest {
        val recordings = listOf(
            testRecording,
            testRecording.copy(uuid = UUID.randomUUID(), title = "Second Recording"),
            testRecording.copy(uuid = UUID.randomUUID(), title = "Third Recording")
        )
        coEvery { repository.getPlaylistById(playlistUuid) } returns testPlaylist
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(recordings)

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.uiState.test {
            val state = awaitItem()
            assertEquals(3, state.recordings.size)
        }
    }

    @Test
    fun `empty playlist shows empty recordings list`() = runTest {
        coEvery { repository.getPlaylistById(playlistUuid) } returns testPlaylist
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(emptyList())

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.uiState.test {
            val state = awaitItem()
            assertTrue(state.recordings.isEmpty())
            assertFalse(state.isLoading)
        }
    }

    @Test
    fun `playlist not found returns null`() = runTest {
        coEvery { repository.getPlaylistById(playlistUuid) } returns null
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(emptyList())

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.uiState.test {
            val state = awaitItem()
            assertEquals(null, state.playlist)
        }
    }

    @Test
    fun `recording durations are preserved`() = runTest {
        val recordings = listOf(testRecording.copy(duration = 300L))
        coEvery { repository.getPlaylistById(playlistUuid) } returns testPlaylist
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(recordings)

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.uiState.test {
            val state = awaitItem()
            assertEquals(300L, state.recordings[0].duration)
        }
    }
}
