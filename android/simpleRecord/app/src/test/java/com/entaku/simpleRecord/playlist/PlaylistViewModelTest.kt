package com.entaku.simpleRecord.playlist

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import app.cash.turbine.test
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
class PlaylistViewModelTest {

    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var repository: PlaylistRepository
    private lateinit var viewModel: PlaylistViewModel

    private val testPlaylist = PlaylistData(
        uuid = UUID.randomUUID(),
        name = "Test Playlist",
        creationDate = LocalDateTime.now(),
        updatedDate = LocalDateTime.now(),
        recordingCount = 5
    )

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        repository = mockk(relaxed = true)
        viewModel = PlaylistViewModel(repository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `initial state is loading`() {
        val state = viewModel.uiState.value
        assertTrue(state.isLoading)
        assertTrue(state.playlists.isEmpty())
    }

    @Test
    fun `loadPlaylists updates state with playlists`() = runTest {
        val playlists = listOf(testPlaylist)
        coEvery { repository.getAllPlaylists() } returns flowOf(playlists)

        viewModel.loadPlaylists()
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.uiState.test {
            val state = awaitItem()
            assertEquals(1, state.playlists.size)
            assertEquals("Test Playlist", state.playlists[0].name)
            assertFalse(state.isLoading)
        }
    }

    @Test
    fun `loadPlaylists with empty list shows empty state`() = runTest {
        coEvery { repository.getAllPlaylists() } returns flowOf(emptyList())

        viewModel.loadPlaylists()
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.uiState.test {
            val state = awaitItem()
            assertTrue(state.playlists.isEmpty())
            assertFalse(state.isLoading)
        }
    }

    @Test
    fun `createPlaylist calls repository create`() = runTest {
        val playlistName = "New Playlist"
        coEvery { repository.createPlaylist(playlistName) } returns UUID.randomUUID()

        viewModel.createPlaylist(playlistName)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.createPlaylist(playlistName) }
    }

    @Test
    fun `updatePlaylistName calls repository update`() = runTest {
        val uuid = UUID.randomUUID()
        val newName = "Updated Playlist"

        viewModel.updatePlaylistName(uuid, newName)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.updatePlaylistName(uuid, newName) }
    }

    @Test
    fun `deletePlaylist calls repository delete`() = runTest {
        val uuid = UUID.randomUUID()

        viewModel.deletePlaylist(uuid)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.deletePlaylist(uuid) }
    }

    @Test
    fun `loadPlaylists with multiple playlists returns all`() = runTest {
        val playlists = listOf(
            testPlaylist,
            testPlaylist.copy(uuid = UUID.randomUUID(), name = "Second Playlist"),
            testPlaylist.copy(uuid = UUID.randomUUID(), name = "Third Playlist")
        )
        coEvery { repository.getAllPlaylists() } returns flowOf(playlists)

        viewModel.loadPlaylists()
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.uiState.test {
            val state = awaitItem()
            assertEquals(3, state.playlists.size)
        }
    }

    @Test
    fun `playlist recording count is preserved`() = runTest {
        val playlists = listOf(testPlaylist.copy(recordingCount = 10))
        coEvery { repository.getAllPlaylists() } returns flowOf(playlists)

        viewModel.loadPlaylists()
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.uiState.test {
            val state = awaitItem()
            assertEquals(10, state.playlists[0].recordingCount)
        }
    }
}
