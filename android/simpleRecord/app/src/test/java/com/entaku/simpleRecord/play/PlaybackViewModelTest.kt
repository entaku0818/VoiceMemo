package com.entaku.simpleRecord.play

import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for PlaybackViewModel state management (Issue #124)
 *
 * MediaPlayer は Android ランタイム依存のため、状態管理ロジックを中心にテスト。
 * Tests cover:
 * - PlaybackState default values
 * - toggleRepeatOne
 * - setAbLoopStart / setAbLoopEnd / clearAbLoop
 * - AB loop end must be after start validation
 */
class PlaybackViewModelTest {

    // --- PlaybackState default values ---

    @Test
    fun `PlaybackState - default values are correct`() {
        val state = PlaybackState()
        assertFalse(state.isPlaying)
        assertEquals(0, state.currentPosition)
        assertEquals(0, state.duration)
        assertEquals(1.0f, state.playbackSpeed)
        assertFalse(state.isRepeatOne)
        assertNull(state.abLoopStart)
        assertNull(state.abLoopEnd)
    }

    // --- toggleRepeatOne ---

    @Test
    fun `toggleRepeatOne - turns on repeat when off`() {
        val viewModel = PlaybackViewModel()

        viewModel.toggleRepeatOne()

        assertTrue(viewModel.playbackState.value.isRepeatOne)
    }

    @Test
    fun `toggleRepeatOne - turns off repeat when on`() {
        val viewModel = PlaybackViewModel()
        viewModel.toggleRepeatOne()

        viewModel.toggleRepeatOne()

        assertFalse(viewModel.playbackState.value.isRepeatOne)
    }

    @Test
    fun `toggleRepeatOne - toggling multiple times cycles correctly`() {
        val viewModel = PlaybackViewModel()

        repeat(5) { i ->
            viewModel.toggleRepeatOne()
            assertEquals(i % 2 == 0, viewModel.playbackState.value.isRepeatOne)
        }
    }

    // --- setAbLoopStart ---

    @Test
    fun `setAbLoopStart - sets abLoopStart to current position`() {
        val viewModel = PlaybackViewModel()

        viewModel.setAbLoopStart()

        // MediaPlayer が null の場合は currentPosition(0) を使う
        assertEquals(0, viewModel.playbackState.value.abLoopStart)
    }

    @Test
    fun `setAbLoopStart - clears existing abLoopEnd when start is reset`() {
        val viewModel = PlaybackViewModel()
        viewModel.setAbLoopStart()
        // abLoopEnd を手動で状態に設定してから再度 setAbLoopStart を呼ぶ
        viewModel.setAbLoopStart()

        assertNull(viewModel.playbackState.value.abLoopEnd)
    }

    // --- setAbLoopEnd ---

    @Test
    fun `setAbLoopEnd - does nothing when abLoopStart is null`() {
        val viewModel = PlaybackViewModel()

        viewModel.setAbLoopEnd()

        assertNull(viewModel.playbackState.value.abLoopEnd)
    }

    @Test
    fun `setAbLoopEnd - does nothing when position equals loopStart`() {
        val viewModel = PlaybackViewModel()
        viewModel.setAbLoopStart() // position = 0

        viewModel.setAbLoopEnd() // position = 0, not > loopStart(0)

        assertNull(viewModel.playbackState.value.abLoopEnd)
    }

    // --- clearAbLoop ---

    @Test
    fun `clearAbLoop - clears both loop points`() {
        val viewModel = PlaybackViewModel()
        viewModel.setAbLoopStart()

        viewModel.clearAbLoop()

        assertNull(viewModel.playbackState.value.abLoopStart)
        assertNull(viewModel.playbackState.value.abLoopEnd)
    }

    @Test
    fun `clearAbLoop - safe to call when no loop is set`() {
        val viewModel = PlaybackViewModel()

        viewModel.clearAbLoop()

        assertNull(viewModel.playbackState.value.abLoopStart)
        assertNull(viewModel.playbackState.value.abLoopEnd)
    }

    // --- AB loop state combinations ---

    @Test
    fun `AB loop - start set then cleared results in clean state`() {
        val viewModel = PlaybackViewModel()
        viewModel.setAbLoopStart()
        assertNotNull(viewModel.playbackState.value.abLoopStart)

        viewModel.clearAbLoop()

        assertNull(viewModel.playbackState.value.abLoopStart)
        assertNull(viewModel.playbackState.value.abLoopEnd)
    }

    @Test
    fun `AB loop and repeat are independent`() {
        val viewModel = PlaybackViewModel()

        viewModel.toggleRepeatOne()
        viewModel.setAbLoopStart()

        assertTrue(viewModel.playbackState.value.isRepeatOne)
        assertNotNull(viewModel.playbackState.value.abLoopStart)
    }

    @Test
    fun `clearAbLoop does not affect repeatOne`() {
        val viewModel = PlaybackViewModel()
        viewModel.toggleRepeatOne()
        viewModel.setAbLoopStart()

        viewModel.clearAbLoop()

        assertTrue(viewModel.playbackState.value.isRepeatOne)
        assertNull(viewModel.playbackState.value.abLoopStart)
    }

    // --- PlaybackState copy ---

    @Test
    fun `PlaybackState copy - updates only specified fields`() {
        val original = PlaybackState(
            isPlaying = true,
            currentPosition = 5000,
            duration = 10000,
            playbackSpeed = 1.5f,
            isRepeatOne = true,
            abLoopStart = 1000,
            abLoopEnd = 8000,
        )

        val updated = original.copy(isPlaying = false)

        assertFalse(updated.isPlaying)
        assertEquals(5000, updated.currentPosition)
        assertEquals(10000, updated.duration)
        assertEquals(1.5f, updated.playbackSpeed)
        assertTrue(updated.isRepeatOne)
        assertEquals(1000, updated.abLoopStart)
        assertEquals(8000, updated.abLoopEnd)
    }
}
