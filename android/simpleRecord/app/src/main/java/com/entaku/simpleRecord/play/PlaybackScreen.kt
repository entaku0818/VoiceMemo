package com.entaku.simpleRecord.play

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.RepeatOne
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.entaku.simpleRecord.R
import com.entaku.simpleRecord.RecordingData
import com.entaku.simpleRecord.components.PlaybackWaveformView
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

private fun formatMs(ms: Int): String {
    val totalSec = ms / 1000
    val min = totalSec / 60
    val sec = totalSec % 60
    return "%d:%02d".format(min, sec)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlaybackScreen(
    recordingData: RecordingData,
    playbackState: PlaybackState,
    onPlayPause: () -> Unit,
    onStop: () -> Unit,
    onNavigateBack: () -> Unit,
    onSpeedChange: (Float) -> Unit,
    onSeekTo: (Int) -> Unit = {},
    onToggleRepeat: () -> Unit = {},
    onSetAbLoopStart: () -> Unit = {},
    onSetAbLoopEnd: () -> Unit = {},
    onClearAbLoop: () -> Unit = {},
) {
    val duration = if (playbackState.duration > 0) playbackState.duration
                   else (recordingData.duration * 1000).toInt()
    val progress = if (duration > 0) playbackState.currentPosition.toFloat() / duration else 0f

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.play)) },
                navigationIcon = {
                    IconButton(onClick = {
                        onStop()
                        onNavigateBack()
                    }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(24.dp))

            // タイトル
            Text(
                text = recordingData.title.ifEmpty { stringResource(R.string.untitled_recording) },
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.fillMaxWidth()
            )

            // 作成日
            Text(
                text = recordingData.creationDate.format(DateTimeFormatter.ofPattern("yyyy/MM/dd")),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 4.dp)
            )

            Spacer(modifier = Modifier.height(32.dp))

            // 波形 / プログレス
            PlaybackWaveformView(
                progress = progress,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(80.dp)
                    .clip(RoundedCornerShape(12.dp))
            )

            Spacer(modifier = Modifier.height(8.dp))

            // シークバー
            Slider(
                value = progress,
                onValueChange = { ratio ->
                    onSeekTo((ratio * duration).toInt())
                },
                modifier = Modifier.fillMaxWidth()
            )

            // 経過時間 / 合計時間
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = formatMs(playbackState.currentPosition),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = formatMs(duration),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.height(32.dp))

            // 再生 / 一時停止ボタン（大きく中央）
            FilledIconButton(
                onClick = onPlayPause,
                modifier = Modifier.size(72.dp),
                shape = CircleShape
            ) {
                Icon(
                    imageVector = if (playbackState.isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                    contentDescription = if (playbackState.isPlaying) stringResource(R.string.pause) else stringResource(R.string.play),
                    modifier = Modifier.size(36.dp)
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // 再生速度
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                listOf(0.5f, 1.0f, 1.5f, 2.0f).forEach { speed ->
                    val selected = playbackState.playbackSpeed == speed
                    FilterChip(
                        selected = selected,
                        onClick = { onSpeedChange(speed) },
                        label = { Text("${speed}x", fontSize = 13.sp) }
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // リピート・ABループ
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onToggleRepeat) {
                    Icon(
                        imageVector = if (playbackState.isRepeatOne) Icons.Default.RepeatOne else Icons.Default.Repeat,
                        contentDescription = stringResource(R.string.repeat),
                        tint = if (playbackState.isRepeatOne) MaterialTheme.colorScheme.primary
                               else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                AbLoopControls(
                    abLoopStart = playbackState.abLoopStart,
                    abLoopEnd = playbackState.abLoopEnd,
                    onSetStart = onSetAbLoopStart,
                    onSetEnd = onSetAbLoopEnd,
                    onClear = onClearAbLoop
                )
            }
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
                text = if (abLoopStart != null) "A: ${formatMs(abLoopStart)}" else stringResource(R.string.ab_loop_set_a),
                fontSize = 12.sp,
                color = if (abLoopStart != null) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurface
            )
        }
        OutlinedButton(
            onClick = onSetEnd,
            enabled = abLoopStart != null,
            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
        ) {
            Text(
                text = if (abLoopEnd != null) "B: ${formatMs(abLoopEnd)}" else stringResource(R.string.ab_loop_set_b),
                fontSize = 12.sp,
                color = if (abLoopEnd != null) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurface
            )
        }
        if (hasLoop) {
            TextButton(
                onClick = onClear,
                contentPadding = PaddingValues(horizontal = 6.dp, vertical = 4.dp)
            ) {
                Text(stringResource(R.string.ab_loop_clear), fontSize = 12.sp)
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
            containerColor = if (speed == currentSpeed) MaterialTheme.colorScheme.primary
                             else MaterialTheme.colorScheme.secondary
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
        duration = 120000,
        playbackSpeed = 1.0f
    )
    PlaybackScreen(
        recordingData = dummyRecordingData,
        playbackState = dummyPlaybackState,
        onPlayPause = {},
        onStop = {},
        onNavigateBack = {},
        onSpeedChange = {}
    )
}
