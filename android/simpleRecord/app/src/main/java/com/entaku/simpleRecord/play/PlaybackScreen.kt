package com.entaku.simpleRecord.play

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.RepeatOne
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.entaku.simpleRecord.RecordingData
import com.entaku.simpleRecord.components.PlaybackWaveformView
import java.time.LocalDateTime
import java.util.UUID

@Composable
fun PlaybackScreen(
    recordingData: RecordingData,
    playbackState: PlaybackState,
    onPlayPause: () -> Unit,
    onStop: () -> Unit,
    onNavigateBack: () -> Unit,
    onSpeedChange: (Float) -> Unit,
    onToggleRepeat: () -> Unit = {},
    onSetAbLoopStart: () -> Unit = {},
    onSetAbLoopEnd: () -> Unit = {},
    onClearAbLoop: () -> Unit = {},
) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text = "Playing: ${recordingData.title}")

        // 再生速度選択
        Row(
            modifier = Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            SpeedButton(speed = 0.5f, currentSpeed = playbackState.playbackSpeed, onSpeedChange = onSpeedChange)
            SpeedButton(speed = 1.0f, currentSpeed = playbackState.playbackSpeed, onSpeedChange = onSpeedChange)
            SpeedButton(speed = 1.5f, currentSpeed = playbackState.playbackSpeed, onSpeedChange = onSpeedChange)
            SpeedButton(speed = 2.0f, currentSpeed = playbackState.playbackSpeed, onSpeedChange = onSpeedChange)
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Waveform display with playback progress
        val progress = if (recordingData.duration > 0) {
            (playbackState.currentPosition.toFloat() / 1000) / recordingData.duration.toFloat()
        } else 0f

        PlaybackWaveformView(
            progress = progress,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .height(80.dp)
                .clip(RoundedCornerShape(12.dp))
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "${playbackState.currentPosition / 1000} sec / ${recordingData.duration} sec",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(16.dp))

        Button(onClick = onPlayPause) {
            Text(text = if (playbackState.isPlaying) "Pause" else "Play")
        }

        Spacer(modifier = Modifier.height(16.dp))

        // リピート・ABループ コントロール
        Row(
            modifier = Modifier.padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onToggleRepeat) {
                Icon(
                    imageVector = if (playbackState.isRepeatOne) Icons.Default.RepeatOne else Icons.Default.Repeat,
                    contentDescription = "Repeat",
                    tint = if (playbackState.isRepeatOne) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            AbLoopControls(
                abLoopStart = playbackState.abLoopStart,
                abLoopEnd = playbackState.abLoopEnd,
                onSetStart = onSetAbLoopStart,
                onSetEnd = onSetAbLoopEnd,
                onClear = onClearAbLoop,
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        Button(onClick = {
            onStop()
            onNavigateBack()
        }) {
            Text(text = "Back to Recordings")
        }
    }
}

@Composable
private fun AbLoopControls(
    abLoopStart: Int?,
    abLoopEnd: Int?,
    onSetStart: () -> Unit,
    onSetEnd: () -> Unit,
    onClear: () -> Unit,
) {
    val hasLoop = abLoopStart != null && abLoopEnd != null
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        OutlinedButton(
            onClick = onSetStart,
            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
        ) {
            Text(
                text = if (abLoopStart != null) "A: ${abLoopStart / 1000}s" else "Set A",
                fontSize = 12.sp,
                color = if (abLoopStart != null) MaterialTheme.colorScheme.primary else Color.Unspecified
            )
        }
        OutlinedButton(
            onClick = onSetEnd,
            enabled = abLoopStart != null,
            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
        ) {
            Text(
                text = if (abLoopEnd != null) "B: ${abLoopEnd / 1000}s" else "Set B",
                fontSize = 12.sp,
                color = if (abLoopEnd != null) MaterialTheme.colorScheme.primary else Color.Unspecified
            )
        }
        if (hasLoop) {
            TextButton(
                onClick = onClear,
                contentPadding = PaddingValues(horizontal = 6.dp, vertical = 4.dp)
            ) {
                Text("✕", fontSize = 12.sp)
            }
        }
    }
}

@Composable
fun SpeedButton(
    speed: Float,
    currentSpeed: Float,
    onSpeedChange: (Float) -> Unit
) {
    Button(
        onClick = { onSpeedChange(speed) },
        colors = ButtonDefaults.buttonColors(
            containerColor = if (speed == currentSpeed) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary
        )
    ) {
        Text(text = "${speed}x")
    }
}

@Preview(showBackground = true)
@Composable
fun PlaybackScreenPreview() {
    val dummyRecordingData = RecordingData(
        uuid = UUID.randomUUID(),
        title = "Sample Recording",
        creationDate = LocalDateTime.now(),
        fileExtension = ".mp3",
        khz = "44.1",
        bitRate = 128,
        channels = 2,
        duration = 120,
        filePath = "dummy/path/to/audio/file.mp3"
    )

    val dummyPlaybackState = PlaybackState(
        isPlaying = false,
        currentPosition = 10000,
        playbackSpeed = 1.0f
    )

    PlaybackScreen(
        recordingData = dummyRecordingData,
        playbackState = dummyPlaybackState,
        onPlayPause = { },
        onStop = { },
        onNavigateBack = { },
        onSpeedChange = { }
    )
}

