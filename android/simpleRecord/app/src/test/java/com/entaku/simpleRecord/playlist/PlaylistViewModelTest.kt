package com.entaku.simpleRecord.playlist

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
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
    fun `initial state has empty playlists and isLoading true`() = runTest {
        viewModel = PlaylistViewModel(repository)
        val state = viewModel.uiState.value
        assertTrue(state.playlists.isEmpty())
        assertTrue(state.isLoading)
    }

    @Test
    fun `loadPlaylists updates state with playlists from repository`() = runTest {
        val testPlaylists = listOf(
            createTestPlaylist("Playlist 1"),
            createTestPlaylist("Playlist 2")
        )
        coEvery { repository.getAllPlaylists() } returns flowOf(testPlaylists)

        viewModel = PlaylistViewModel(repository)
        viewModel.loadPlaylists()
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(2, state.playlists.size)
        assertEquals("Playlist 1", state.playlists[0].name)
        assertEquals("Playlist 2", state.playlists[1].name)
    }

    @Test
    fun `loadPlaylists sets isLoading to false after loading`() = runTest {
        coEvery { repository.getAllPlaylists() } returns flowOf(emptyList())

        viewModel = PlaylistViewModel(repository)
        viewModel.loadPlaylists()
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(false, state.isLoading)
    }

    @Test
    fun `loadPlaylists handles empty list correctly`() = runTest {
        coEvery { repository.getAllPlaylists() } returns flowOf(emptyList())

        viewModel = PlaylistViewModel(repository)
        viewModel.loadPlaylists()
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertTrue(state.playlists.isEmpty())
        assertEquals(false, state.isLoading)
    }

    @Test
    fun `createPlaylist calls repository createPlaylist`() = runTest {
        coEvery { repository.createPlaylist(any()) } returns UUID.randomUUID()

        viewModel = PlaylistViewModel(repository)
        viewModel.createPlaylist("New Playlist")
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.createPlaylist("New Playlist") }
    }

    @Test
    fun `updatePlaylistName calls repository updatePlaylistName`() = runTest {
        val uuid = UUID.randomUUID()
        val newName = "Updated Name"

        viewModel = PlaylistViewModel(repository)
        viewModel.updatePlaylistName(uuid, newName)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.updatePlaylistName(uuid, newName) }
    }

    @Test
    fun `deletePlaylist calls repository deletePlaylist`() = runTest {
        val uuid = UUID.randomUUID()

        viewModel = PlaylistViewModel(repository)
        viewModel.deletePlaylist(uuid)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { repository.deletePlaylist(uuid) }
    }

    @Test
    fun `multiple playlists are loaded correctly`() = runTest {
        val testPlaylists = listOf(
            createTestPlaylist("Work"),
            createTestPlaylist("Personal"),
            createTestPlaylist("Music")
        )
        coEvery { repository.getAllPlaylists() } returns flowOf(testPlaylists)

        viewModel = PlaylistViewModel(repository)
        viewModel.loadPlaylists()
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(3, state.playlists.size)
    }

    private fun createTestPlaylist(name: String): PlaylistData {
        return PlaylistData(
            uuid = UUID.randomUUID(),
            name = name,
            creationDate = LocalDateTime.now(),
            updatedDate = LocalDateTime.now(),
            recordingCount = 0
        )
    }
}
