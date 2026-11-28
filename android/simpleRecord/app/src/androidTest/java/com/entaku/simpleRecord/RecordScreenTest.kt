package com.entaku.simpleRecord

import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import androidx.test.platform.app.InstrumentationRegistry
import com.entaku.simpleRecord.record.RecordScreen
import com.entaku.simpleRecord.record.RecordingState
import com.entaku.simpleRecord.record.RecordingUiState
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import java.time.Duration

class RecordScreenTest {
    @get:Rule val compose = createComposeRule()

    @Test
    fun timerStaysInPlaceAndControlsFollowRecordingState() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val state = MutableStateFlow(RecordingUiState())
        var openedSettings = false
        var openedRecordings = false

        compose.setContent {
            AudioRecorderTheme {
                RecordScreen(
                    uiStateFlow = state,
                    onStartRecording = {},
                    onStopRecording = { state.value = RecordingUiState(recordingState = RecordingState.FINISHED) },
                    onPauseRecording = {
                        state.value = state.value.copy(recordingState = RecordingState.PAUSED)
                    },
                    onResumeRecording = {
                        state.value = state.value.copy(recordingState = RecordingState.RECORDING)
                    },
                    onNavigateBack = { openedRecordings = true },
                    onOpenRecordingSettings = { openedSettings = true }
                )
            }
        }

        fun status(label: Int) = compose.onNodeWithText(context.getString(label)).assertIsDisplayed()
        fun control(label: Int) = compose.onNodeWithContentDescription(context.getString(label))
        fun visibleControl(label: Int) = control(label).assertIsDisplayed().assertHasClickAction().also {
            val bounds = it.getUnclippedBoundsInRoot()
            assertTrue(bounds.right - bounds.left >= 48.dp && bounds.bottom - bounds.top >= 48.dp)
        }
        fun timer(duration: Duration) = compose.onNodeWithText(duration.formatTime())
            .assertIsDisplayed().fetchSemanticsNode().boundsInRoot

        status(R.string.recording_ready)
        val readyTimer = timer(Duration.ZERO)
        val start = visibleControl(R.string.start_recording)
        val settings = visibleControl(R.string.recording_settings)
        assertTrue(start.getUnclippedBoundsInRoot().right < settings.getUnclippedBoundsInRoot().left)
        settings.performClick()
        compose.runOnIdle { assertTrue(openedSettings) }

        val elapsed = Duration.ofSeconds(24)
        compose.runOnIdle {
            state.value = RecordingUiState(recordingState = RecordingState.RECORDING, elapsedTime = elapsed)
        }
        status(R.string.recording_notification_title)
        val recordingTimer = timer(elapsed)
        assertEquals(readyTimer.center.x, recordingTimer.center.x, 1f)
        assertEquals(readyTimer.top, recordingTimer.top, 1f)
        control(R.string.recording_settings).assertDoesNotExist()

        val stop = visibleControl(R.string.stop)
        val pause = visibleControl(R.string.pause)
        assertTrue(stop.getUnclippedBoundsInRoot().right < pause.getUnclippedBoundsInRoot().left)
        pause.performClick()
        status(R.string.recording_notification_title_paused)
        val pausedTimer = timer(elapsed)
        assertEquals(recordingTimer.center.x, pausedTimer.center.x, 1f)
        assertEquals(recordingTimer.top, pausedTimer.top, 1f)

        val resume = visibleControl(R.string.resume)
        assertTrue(stop.getUnclippedBoundsInRoot().right < resume.getUnclippedBoundsInRoot().left)
        resume.performClick()
        status(R.string.recording_notification_title)
        stop.performClick()
        compose.runOnIdle { assertTrue(openedRecordings) }
    }
}
