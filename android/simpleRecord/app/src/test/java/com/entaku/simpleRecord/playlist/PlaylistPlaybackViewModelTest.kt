package com.entaku.simpleRecord.playlist

import com.entaku.simpleRecord.RecordingData
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.time.LocalDateTime
import java.util.UUID

/**
 * Unit tests for PlaylistPlaybackViewModel (Issue #97 Phase 2)
 *
 * Tests cover:
 * - Playlist playback initialization
 * - Next/previous track navigation
 * - Repeat modes (OFF/ONE/ALL)
 * - Shuffle functionality
 * - Track completion handling
 */
@ExperimentalCoroutinesApi
class PlaylistPlaybackViewModelTest {

    private lateinit var viewModel: PlaylistPlaybackViewModel
    private lateinit var testRecordings: List<RecordingData>

    @Before
    fun setup() {
        viewModel = PlaylistPlaybackViewModel()
        testRecordings = (0..4).map { createTestRecording("Track $it") }
    }

    @Test
    fun `startPlaylistPlayback - initializes with correct state`() = runTest {
        // When
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 2)

        // Then
        val state = viewModel.state.value
        assertEquals(5, state.playlist.size)
        assertEquals(2, state.currentIndex)
        assertEquals(testRecordings[2], state.currentRecording)
        assertTrue(state.isPlaying)
        assertFalse(state.shuffleEnabled)
        assertEquals(RepeatMode.OFF, state.repeatMode)
    }

    @Test
    fun `playNext - moves to next track in normal mode`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 0)

        // When
        viewModel.playNext()

        // Then
        val state = viewModel.state.value
        assertEquals(1, state.currentIndex)
        assertEquals(testRecordings[1], state.currentRecording)
    }

    @Test
    fun `playNext - stops at end when repeat OFF`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 4)  // Last track

        // When
        viewModel.playNext()

        // Then
        val state = viewModel.state.value
        assertFalse(state.isPlaying)
    }

    @Test
    fun `playNext - loops to start when repeat ALL`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 4)  // Last track
        viewModel.toggleRepeat()  // OFF -> ONE
        viewModel.toggleRepeat()  // ONE -> ALL

        // When
        viewModel.playNext()

        // Then
        val state = viewModel.state.value
        assertEquals(0, state.currentIndex)
        assertEquals(testRecordings[0], state.currentRecording)
        assertTrue(state.isPlaying)
    }

    @Test
    fun `playNext - stays on same track when repeat ONE`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 2)
        viewModel.toggleRepeat()  // OFF -> ONE

        // When
        viewModel.playNext()

        // Then
        val state = viewModel.state.value
        assertEquals(2, state.currentIndex)
        assertEquals(testRecordings[2], state.currentRecording)
    }

    @Test
    fun `playPrevious - moves to previous track`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 2)

        // When
        viewModel.playPrevious()

        // Then
        val state = viewModel.state.value
        assertEquals(1, state.currentIndex)
        assertEquals(testRecordings[1], state.currentRecording)
    }

    @Test
    fun `playPrevious - stays at first when already at start`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 0)

        // When
        viewModel.playPrevious()

        // Then
        val state = viewModel.state.value
        assertEquals(0, state.currentIndex)
    }

    @Test
    fun `playPrevious - loops to end when repeat ALL`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 0)
        viewModel.toggleRepeat()  // OFF -> ONE
        viewModel.toggleRepeat()  // ONE -> ALL

        // When
        viewModel.playPrevious()

        // Then
        val state = viewModel.state.value
        assertEquals(4, state.currentIndex)
        assertEquals(testRecordings[4], state.currentRecording)
    }

    @Test
    fun `toggleRepeat - cycles through modes correctly`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings)

        // Initial state
        assertEquals(RepeatMode.OFF, viewModel.state.value.repeatMode)

        // When: First toggle
        viewModel.toggleRepeat()

        // Then: Should be ONE
        assertEquals(RepeatMode.ONE, viewModel.state.value.repeatMode)

        // When: Second toggle
        viewModel.toggleRepeat()

        // Then: Should be ALL
        assertEquals(RepeatMode.ALL, viewModel.state.value.repeatMode)

        // When: Third toggle
        viewModel.toggleRepeat()

        // Then: Should be OFF
        assertEquals(RepeatMode.OFF, viewModel.state.value.repeatMode)
    }

    @Test
    fun `toggleShuffle - enables shuffle and keeps current track first`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 2)
        val originalTrack = viewModel.state.value.currentRecording

        // When
        viewModel.toggleShuffle()

        // Then
        val state = viewModel.state.value
        assertTrue(state.shuffleEnabled)
        assertEquals(0, state.currentIndex)  // Current index becomes 0
        assertEquals(originalTrack, state.currentRecording)  // But same track
        assertEquals(5, state.playlist.size)
    }

    @Test
    fun `toggleShuffle - disables shuffle and restores original order`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 2)
        viewModel.toggleShuffle()  // Enable shuffle

        // When
        viewModel.toggleShuffle()  // Disable shuffle

        // Then
        val state = viewModel.state.value
        assertFalse(state.shuffleEnabled)
        assertEquals(testRecordings, state.playlist)  // Original order restored
    }

    @Test
    fun `jumpToTrack - sets correct index`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 0)

        // When
        viewModel.jumpToTrack(3)

        // Then
        val state = viewModel.state.value
        assertEquals(3, state.currentIndex)
        assertEquals(testRecordings[3], state.currentRecording)
    }

    @Test
    fun `jumpToTrack - ignores invalid index`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 2)

        // When
        viewModel.jumpToTrack(10)  // Out of bounds

        // Then
        val state = viewModel.state.value
        assertEquals(2, state.currentIndex)  // Unchanged
    }

    @Test
    fun `onTrackComplete - advances to next track when repeat OFF`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 1)

        // When
        viewModel.onTrackComplete()

        // Then
        val state = viewModel.state.value
        assertEquals(2, state.currentIndex)
        assertTrue(state.isPlaying)
    }

    @Test
    fun `onTrackComplete - stays on same track when repeat ONE`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 2)
        viewModel.toggleRepeat()  // OFF -> ONE

        // When
        viewModel.onTrackComplete()

        // Then
        val state = viewModel.state.value
        assertEquals(2, state.currentIndex)
        assertTrue(state.isPlaying)
    }

    @Test
    fun `onTrackComplete - stops at end when repeat OFF`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 4)  // Last track

        // When
        viewModel.onTrackComplete()

        // Then
        val state = viewModel.state.value
        assertFalse(state.isPlaying)
    }

    @Test
    fun `onTrackComplete - loops to start when repeat ALL`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 4)  // Last track
        viewModel.toggleRepeat()  // OFF -> ONE
        viewModel.toggleRepeat()  // ONE -> ALL

        // When
        viewModel.onTrackComplete()

        // Then
        val state = viewModel.state.value
        assertEquals(0, state.currentIndex)
        assertTrue(state.isPlaying)
    }

    @Test
    fun `stopPlayback - resets state correctly`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 2)

        // When
        viewModel.stopPlayback()

        // Then
        val state = viewModel.state.value
        assertFalse(state.isPlaying)
        assertEquals(0, state.currentIndex)
    }

    @Test
    fun `setPlaying - updates playing state`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings)

        // When
        viewModel.setPlaying(false)

        // Then
        assertFalse(viewModel.state.value.isPlaying)

        // When
        viewModel.setPlaying(true)

        // Then
        assertTrue(viewModel.state.value.isPlaying)
    }

    @Test
    fun `hasNext - returns correct value based on mode`() = runTest {
        // Normal mode at last track
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 4)
        assertFalse(viewModel.state.value.hasNext)

        // Normal mode not at last track
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 2)
        assertTrue(viewModel.state.value.hasNext)

        // Repeat ALL at last track
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 4)
        viewModel.toggleRepeat()  // OFF -> ONE
        viewModel.toggleRepeat()  // ONE -> ALL
        assertTrue(viewModel.state.value.hasNext)
    }

    @Test
    fun `hasPrevious - returns correct value based on mode`() = runTest {
        // Normal mode at first track
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 0)
        assertFalse(viewModel.state.value.hasPrevious)

        // Normal mode not at first track
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 2)
        assertTrue(viewModel.state.value.hasPrevious)

        // Repeat ALL at first track
        viewModel.startPlaylistPlayback(testRecordings, startIndex = 0)
        viewModel.toggleRepeat()  // OFF -> ONE
        viewModel.toggleRepeat()  // ONE -> ALL
        assertTrue(viewModel.state.value.hasPrevious)
    }

    @Test
    fun `shuffle mode - plays all tracks eventually`() = runTest {
        // Given
        viewModel.startPlaylistPlayback(testRecordings)
        viewModel.toggleShuffle()
        val playedTracks = mutableSetOf<RecordingData>()

        // When: Play through all tracks
        repeat(testRecordings.size) {
            viewModel.state.value.currentRecording?.let { playedTracks.add(it) }
            viewModel.playNext()
        }

        // Then: All tracks should have been played
        assertEquals(testRecordings.size, playedTracks.size)
    }

    // Helper function
    private fun createTestRecording(title: String): RecordingData {
        return RecordingData(
            uuid = UUID.randomUUID(),
            title = title,
            creationDate = LocalDateTime.now(),
            fileExtension = "m4a",
            khz = "44100",
            bitRate = 128,
            channels = 1,
            duration = 60,
            filePath = "/test/path/$title.m4a"
        )
    }
}
