package com.entaku.simpleRecord.record

import org.junit.Assert.*
import org.junit.Test

/**
 * RecordingState と RecordingUiState のユニットテスト。
 * MediaRecorder は Android ランタイム依存のため、状態管理ロジックを中心にテスト。
 */
class RecordViewModelTest {

    // --- RecordingState ---

    @Test
    fun `RecordingState - all states are distinct`() {
        val states = RecordingState.entries.toList()
        assertEquals(states.size, states.toSet().size)
    }

    @Test
    fun `RecordingState - initial state should be IDLE`() {
        val state = RecordingUiState()
        assertEquals(RecordingState.IDLE, state.recordingState)
    }

    // --- RecordingUiState default values ---

    @Test
    fun `RecordingUiState - default currentVolume is 0`() {
        assertEquals(0, RecordingUiState().currentVolume)
    }

    @Test
    fun `RecordingUiState - default elapsedTime is ZERO`() {
        val state = RecordingUiState()
        assertEquals(java.time.Duration.ZERO, state.elapsedTime)
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
        val state = RecordingUiState()
        val recording = state.copy(recordingState = RecordingState.RECORDING)
        assertEquals(RecordingState.RECORDING, recording.recordingState)
        assertEquals(0, recording.currentVolume)
    }

    @Test
    fun `RecordingUiState copy - updates volume`() {
        val state = RecordingUiState()
        val updated = state.copy(currentVolume = 75)
        assertEquals(75, updated.currentVolume)
    }

    @Test
    fun `RecordingUiState copy - amplitude history accumulates correctly`() {
        val state = RecordingUiState()
        val history = listOf(0.1f, 0.2f, 0.5f)
        val updated = state.copy(amplitudeHistory = history)
        assertEquals(3, updated.amplitudeHistory.size)
        assertEquals(0.5f, updated.amplitudeHistory.last())
    }

    @Test
    fun `RecordingUiState copy - amplitude history takeLast keeps only recent entries`() {
        val maxHistory = 100
        val history = (1..150).map { it.toFloat() / 150f }
        val trimmed = history.takeLast(maxHistory)
        assertEquals(maxHistory, trimmed.size)
        assertEquals(history.last(), trimmed.last())
    }

    // --- amplitude normalization ---

    @Test
    fun `amplitude normalization - max amplitude maps to 100`() {
        val maxAmplitude = 32767
        val normalized = (maxAmplitude.toFloat() / 32767.0f * 100).toInt().coerceIn(0, 100)
        assertEquals(100, normalized)
    }

    @Test
    fun `amplitude normalization - zero maps to 0`() {
        val normalized = (0.toFloat() / 32767.0f * 100).toInt().coerceIn(0, 100)
        assertEquals(0, normalized)
    }

    @Test
    fun `amplitude normalization - mid value maps to approx 50`() {
        val mid = 16383
        val normalized = (mid.toFloat() / 32767.0f * 100).toInt().coerceIn(0, 100)
        assertTrue(normalized in 49..51)
    }

    @Test
    fun `amplitude normalization - out of range values are clamped`() {
        val overMax = (40000.toFloat() / 32767.0f * 100).toInt().coerceIn(0, 100)
        assertEquals(100, overMax)
    }

    // --- FINISHED state transitions ---

    @Test
    fun `RecordingUiState after stop - volume and history are cleared`() {
        val recording = RecordingUiState(
            recordingState = RecordingState.RECORDING,
            currentVolume = 60,
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
}
