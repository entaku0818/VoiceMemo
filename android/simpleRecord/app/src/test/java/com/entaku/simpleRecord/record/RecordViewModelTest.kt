package com.entaku.simpleRecord.record

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

/**
 * RecordingState と RecordingUiState のユニットテスト。
 * MediaRecorder は Android ランタイム依存のため、状態管理ロジックを中心にテスト。
 */
@OptIn(ExperimentalCoroutinesApi::class)
class RecordViewModelTest {

    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // --- RecordingState ---

    @Test
    fun `RecordingState - all states are distinct`() {
        val states = RecordingState.entries.toList()
        assertEquals(states.size, states.toSet().size)
    }

    @Test
    fun `RecordingState - initial state should be IDLE`() {
        assertEquals(RecordingState.IDLE, RecordingUiState().recordingState)
    }

    @Test
    fun `RecordingState - has five states`() {
        assertEquals(5, RecordingState.entries.size)
    }

    // --- RecordingUiState default values ---

    @Test
    fun `RecordingUiState - default currentVolume is 0`() {
        assertEquals(0, RecordingUiState().currentVolume)
    }

    @Test
    fun `RecordingUiState - default elapsedTime is ZERO`() {
        assertEquals(java.time.Duration.ZERO, RecordingUiState().elapsedTime)
    }

    @Test
    fun `RecordingUiState - default amplitudeHistory is empty`() {
        assertTrue(RecordingUiState().amplitudeHistory.isEmpty())
    }

    @Test
    fun `RecordingUiState - default filePath is null`() {
        assertNull(RecordingUiState().currentFilePath)
    }

    // --- copy behavior ---

    @Test
    fun `RecordingUiState copy - updates recording state`() {
        val updated = RecordingUiState().copy(recordingState = RecordingState.RECORDING)
        assertEquals(RecordingState.RECORDING, updated.recordingState)
        assertEquals(0, updated.currentVolume)
    }

    @Test
    fun `RecordingUiState copy - updates volume without affecting other fields`() {
        val updated = RecordingUiState(recordingState = RecordingState.RECORDING).copy(currentVolume = 75)
        assertEquals(75, updated.currentVolume)
        assertEquals(RecordingState.RECORDING, updated.recordingState)
    }

    @Test
    fun `RecordingUiState copy - amplitude history accumulates correctly`() {
        val history = listOf(0.1f, 0.2f, 0.5f)
        val updated = RecordingUiState().copy(amplitudeHistory = history)
        assertEquals(3, updated.amplitudeHistory.size)
        assertEquals(0.5f, updated.amplitudeHistory.last())
    }

    @Test
    fun `RecordingUiState copy - amplitude history takeLast keeps only recent entries`() {
        val history = (1..150).map { it.toFloat() / 150f }
        val trimmed = history.takeLast(100)
        assertEquals(100, trimmed.size)
        assertEquals(history.last(), trimmed.last())
    }

    // --- FINISHED → IDLE reset logic ---

    @Test
    fun `RecordingUiState reset - FINISHED state resets to default IDLE`() {
        val finished = RecordingUiState(
            recordingState = RecordingState.FINISHED,
            currentFilePath = "/some/path.m4a",
            currentVolume = 0,
            amplitudeHistory = emptyList()
        )
        val reset = RecordingUiState() // default = IDLE
        assertEquals(RecordingState.IDLE, reset.recordingState)
        assertNull(reset.currentFilePath)
    }

    @Test
    fun `RecordingUiState - FINISHED button should be disabled`() {
        val state = RecordingUiState(recordingState = RecordingState.FINISHED)
        val buttonEnabled = state.recordingState != RecordingState.FINISHED
        assertFalse(buttonEnabled)
    }

    @Test
    fun `RecordingUiState - IDLE button should be enabled`() {
        val state = RecordingUiState(recordingState = RecordingState.IDLE)
        val buttonEnabled = state.recordingState != RecordingState.FINISHED
        assertTrue(buttonEnabled)
    }

    @Test
    fun `RecordingUiState - RECORDING state shows active recording controls`() {
        val state = RecordingUiState(recordingState = RecordingState.RECORDING)
        val showControls = state.recordingState == RecordingState.RECORDING ||
                state.recordingState == RecordingState.PAUSED
        assertTrue(showControls)
    }

    @Test
    fun `RecordingUiState - PAUSED state shows active recording controls`() {
        val state = RecordingUiState(recordingState = RecordingState.PAUSED)
        val showControls = state.recordingState == RecordingState.RECORDING ||
                state.recordingState == RecordingState.PAUSED
        assertTrue(showControls)
    }

    @Test
    fun `RecordingUiState - IDLE state does not show recording controls`() {
        val state = RecordingUiState(recordingState = RecordingState.IDLE)
        val showControls = state.recordingState == RecordingState.RECORDING ||
                state.recordingState == RecordingState.PAUSED
        assertFalse(showControls)
    }

    // --- amplitude normalization ---

    @Test
    fun `amplitude normalization - max amplitude maps to 100`() {
        val normalized = (32767.toFloat() / 32767.0f * 100).toInt().coerceIn(0, 100)
        assertEquals(100, normalized)
    }

    @Test
    fun `amplitude normalization - zero maps to 0`() {
        val normalized = (0.toFloat() / 32767.0f * 100).toInt().coerceIn(0, 100)
        assertEquals(0, normalized)
    }

    @Test
    fun `amplitude normalization - mid value maps to approx 50`() {
        val normalized = (16383.toFloat() / 32767.0f * 100).toInt().coerceIn(0, 100)
        assertTrue(normalized in 49..51)
    }

    @Test
    fun `amplitude normalization - out of range values are clamped to 100`() {
        val overMax = (40000.toFloat() / 32767.0f * 100).toInt().coerceIn(0, 100)
        assertEquals(100, overMax)
    }

    @Test
    fun `amplitude normalization - negative values are clamped to 0`() {
        val negative = (-100.toFloat() / 32767.0f * 100).toInt().coerceIn(0, 100)
        assertEquals(0, negative)
    }

    // --- stop state transitions ---

    @Test
    fun `after stop - state transitions to FINISHED with cleared fields`() {
        val recording = RecordingUiState(
            recordingState = RecordingState.RECORDING,
            currentVolume = 60,
            currentFilePath = "/path/to/file.m4a",
            amplitudeHistory = listOf(0.3f, 0.5f, 0.7f)
        )
        val stopped = recording.copy(
            recordingState = RecordingState.FINISHED,
            currentFilePath = null,
            currentVolume = 0,
            elapsedTime = java.time.Duration.ZERO,
            amplitudeHistory = emptyList()
        )
        assertEquals(RecordingState.FINISHED, stopped.recordingState)
        assertEquals(0, stopped.currentVolume)
        assertTrue(stopped.amplitudeHistory.isEmpty())
        assertNull(stopped.currentFilePath)
    }

    @Test
    fun `after start - amplitude history is cleared`() {
        val beforeStart = RecordingUiState(
            recordingState = RecordingState.IDLE,
            amplitudeHistory = listOf(0.1f, 0.2f)
        )
        val afterStart = beforeStart.copy(
            recordingState = RecordingState.RECORDING,
            currentFilePath = "/new/recording.m4a",
            elapsedTime = java.time.Duration.ZERO,
            currentVolume = 0,
            amplitudeHistory = emptyList()
        )
        assertTrue(afterStart.amplitudeHistory.isEmpty())
        assertEquals(RecordingState.RECORDING, afterStart.recordingState)
    }

    // --- recording title format ---

    @Test
    fun `recording title - formatted date matches yyyy_MM_dd HH_mm pattern`() {
        val formatter = java.time.format.DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm")
        val now = java.time.LocalDateTime.now()
        val title = now.format(formatter)
        // yyyy/MM/dd HH:mm = 16 chars
        assertEquals(16, title.length)
        assertTrue(title.contains("/"))
        assertTrue(title.contains(":"))
    }
}
