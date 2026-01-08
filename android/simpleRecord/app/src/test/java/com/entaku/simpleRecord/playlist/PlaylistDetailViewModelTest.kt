package com.entaku.simpleRecord.playlist

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
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
    private val playlistUuid = UUID.randomUUID()

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
    fun `initial state has null playlist and isLoading true`() = runTest {
        coEvery { repository.getPlaylistById(playlistUuid) } returns null
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(emptyList())

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        val state = viewModel.uiState.value

        assertNull(state.playlist)
        assertTrue(state.isLoading)
    }

    @Test
    fun `loadPlaylistDetail loads playlist from repository`() = runTest {
        val testPlaylist = createTestPlaylist("Test Playlist")
        coEvery { repository.getPlaylistById(playlistUuid) } returns testPlaylist
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(emptyList())

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals("Test Playlist", state.playlist?.name)
    }

    @Test
    fun `loadPlaylistDetail loads recordings for playlist`() = runTest {
        val testPlaylist = createTestPlaylist("Test Playlist")
        val testRecordings = listOf(
            createTestRecording("Recording 1"),
            createTestRecording("Recording 2")
        )
        coEvery { repository.getPlaylistById(playlistUuid) } returns testPlaylist
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(testRecordings)

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(2, state.recordings.size)
        assertEquals("Recording 1", state.recordings[0].title)
        assertEquals("Recording 2", state.recordings[1].title)
    }

    @Test
    fun `loadPlaylistDetail sets isLoading to false after loading`() = runTest {
        coEvery { repository.getPlaylistById(playlistUuid) } returns null
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(emptyList())

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(false, state.isLoading)
    }

    @Test
    fun `loadPlaylistDetail handles empty recordings list`() = runTest {
        val testPlaylist = createTestPlaylist("Empty Playlist")
        coEvery { repository.getPlaylistById(playlistUuid) } returns testPlaylist
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(emptyList())

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertTrue(state.recordings.isEmpty())
    }

    @Test
    fun `removeRecording calls repository removeRecordingFromPlaylist`() = runTest {
        coEvery { repository.getPlaylistById(playlistUuid) } returns null
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(emptyList())
        val recordingUuid = UUID.randomUUID()

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        viewModel.removeRecording(recordingUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.removeRecordingFromPlaylist(playlistUuid, recordingUuid) }
    }

    @Test
    fun `addRecording calls repository addRecordingToPlaylist`() = runTest {
        coEvery { repository.getPlaylistById(playlistUuid) } returns null
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(emptyList())
        val recordingUuid = UUID.randomUUID()

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        viewModel.addRecording(recordingUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.addRecordingToPlaylist(playlistUuid, recordingUuid) }
    }

    @Test
    fun `loadPlaylistDetail is called on init`() = runTest {
        coEvery { repository.getPlaylistById(playlistUuid) } returns null
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(emptyList())

        PlaylistDetailViewModel(repository, playlistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.getPlaylistById(playlistUuid) }
        coVerify { repository.getRecordingsForPlaylist(playlistUuid) }
    }

    @Test
    fun `multiple recordings are loaded correctly`() = runTest {
        val testPlaylist = createTestPlaylist("Test Playlist")
        val testRecordings = listOf(
            createTestRecording("Recording 1"),
            createTestRecording("Recording 2"),
            createTestRecording("Recording 3")
        )
        coEvery { repository.getPlaylistById(playlistUuid) } returns testPlaylist
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(testRecordings)

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(3, state.recordings.size)
    }

    @Test
    fun `playlist with recording count is displayed correctly`() = runTest {
        val testPlaylist = PlaylistData(
            uuid = playlistUuid,
            name = "Test Playlist",
            creationDate = LocalDateTime.now(),
            updatedDate = LocalDateTime.now(),
            recordingCount = 5
        )
        coEvery { repository.getPlaylistById(playlistUuid) } returns testPlaylist
        coEvery { repository.getRecordingsForPlaylist(playlistUuid) } returns flowOf(emptyList())

        val viewModel = PlaylistDetailViewModel(repository, playlistUuid)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(5, state.playlist?.recordingCount)
    }

    private fun createTestPlaylist(name: String): PlaylistData {
        return PlaylistData(
            uuid = playlistUuid,
            name = name,
            creationDate = LocalDateTime.now(),
            updatedDate = LocalDateTime.now(),
            recordingCount = 0
        )
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
