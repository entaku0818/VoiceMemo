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

    private val testPlaylists = listOf(
        PlaylistData(
            uuid = UUID.randomUUID(),
            name = "Playlist 1",
            creationDate = LocalDateTime.now(),
            updatedDate = LocalDateTime.now(),
            recordingCount = 5
        ),
        PlaylistData(
            uuid = UUID.randomUUID(),
            name = "Playlist 2",
            creationDate = LocalDateTime.now().minusDays(1),
            updatedDate = LocalDateTime.now().minusHours(2),
            recordingCount = 3
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
    fun `initial state has empty playlists and isLoading true`() {
        viewModel = PlaylistViewModel(repository)

        val state = viewModel.uiState.value
        assertTrue(state.playlists.isEmpty())
        assertTrue(state.isLoading)
        assertEquals(null, state.error)
    }

    @Test
    fun `loadPlaylists updates state with playlists from repository`() = runTest {
        coEvery { repository.getAllPlaylists() } returns flowOf(testPlaylists)

        viewModel = PlaylistViewModel(repository)

        viewModel.uiState.test {
            // Initial state
            val initialState = awaitItem()
            assertTrue(initialState.isLoading)
            assertTrue(initialState.playlists.isEmpty())

            // Load playlists
            viewModel.loadPlaylists()
            testDispatcher.scheduler.advanceUntilIdle()

            // State after loading
            val loadedState = awaitItem()
            assertEquals(testPlaylists.size, loadedState.playlists.size)
            assertEquals(false, loadedState.isLoading)

            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `loadPlaylists handles empty list`() = runTest {
        coEvery { repository.getAllPlaylists() } returns flowOf(emptyList())

        viewModel = PlaylistViewModel(repository)

        viewModel.uiState.test {
            awaitItem() // Initial state

            viewModel.loadPlaylists()
            testDispatcher.scheduler.advanceUntilIdle()

            val state = awaitItem()
            assertTrue(state.playlists.isEmpty())
            assertEquals(false, state.isLoading)

            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `createPlaylist calls repository create method`() = runTest {
        val playlistName = "New Playlist"
        val newUuid = UUID.randomUUID()
        coEvery { repository.createPlaylist(playlistName) } returns newUuid

        viewModel = PlaylistViewModel(repository)

        viewModel.createPlaylist(playlistName)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.createPlaylist(playlistName) }
    }

    @Test
    fun `updatePlaylistName calls repository update method`() = runTest {
        val uuidToUpdate = testPlaylists[0].uuid
        val newName = "Updated Playlist Name"
        coEvery { repository.updatePlaylistName(uuidToUpdate, newName) } returns Unit

        viewModel = PlaylistViewModel(repository)

        viewModel.updatePlaylistName(uuidToUpdate, newName)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.updatePlaylistName(uuidToUpdate, newName) }
    }

    @Test
    fun `deletePlaylist calls repository delete method`() = runTest {
        val uuidToDelete = testPlaylists[0].uuid
        coEvery { repository.deletePlaylist(uuidToDelete) } returns Unit

        viewModel = PlaylistViewModel(repository)

        viewModel.deletePlaylist(uuidToDelete)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.deletePlaylist(uuidToDelete) }
    }

    @Test
    fun `createPlaylist with empty name still calls repository`() = runTest {
        val emptyName = ""
        val newUuid = UUID.randomUUID()
        coEvery { repository.createPlaylist(emptyName) } returns newUuid

        viewModel = PlaylistViewModel(repository)

        viewModel.createPlaylist(emptyName)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.createPlaylist(emptyName) }
    }

    @Test
    fun `createPlaylist with special characters in name`() = runTest {
        val specialName = "My Playlist 🎵 #1"
        val newUuid = UUID.randomUUID()
        coEvery { repository.createPlaylist(specialName) } returns newUuid

        viewModel = PlaylistViewModel(repository)

        viewModel.createPlaylist(specialName)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.createPlaylist(specialName) }
    }
}
