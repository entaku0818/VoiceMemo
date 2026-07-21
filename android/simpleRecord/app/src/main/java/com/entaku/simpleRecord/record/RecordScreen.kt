package com.entaku.simpleRecord.record

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import com.entaku.simpleRecord.components.WaveformView
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import android.os.Build
import com.entaku.simpleRecord.R
import androidx.core.content.ContextCompat
import androidx.core.content.PermissionChecker
import com.entaku.simpleRecord.formatTime
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.time.Duration


@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecordScreen(
    uiStateFlow: StateFlow<RecordingUiState>,
    onStartRecording: () -> Unit,
    onStopRecording: () -> Unit,
    onPauseRecording: () -> Unit,
    onResumeRecording: () -> Unit,
    onNavigateBack: () -> Unit
) {
    val uiState by uiStateFlow.collectAsState()
    val context = LocalContext.current

    // FINISHED 状態を検知して onNavigateBack を実行
    LaunchedEffect(uiState.recordingState) {
        if (uiState.recordingState == RecordingState.FINISHED) {
            onNavigateBack()
        }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
        onResult = { results ->
            // 録音の常時通知(ongoing notification)表示にはPOST_NOTIFICATIONSが必要だが、
            // 拒否されても録音自体は継続できるためRECORD_AUDIOの許可のみを起動条件にする (issue #197)。
            if (results[Manifest.permission.RECORD_AUDIO] == true) {
                onStartRecording()
            }
        }
    )

    fun checkPermissionAndStartRecording() {
        val permissionsToRequest = mutableListOf<String>()
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) !=
            PermissionChecker.PERMISSION_GRANTED
        ) {
            permissionsToRequest.add(Manifest.permission.RECORD_AUDIO)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PermissionChecker.PERMISSION_GRANTED
        ) {
            permissionsToRequest.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        if (permissionsToRequest.isEmpty()) {
            onStartRecording()
        } else {
            permissionLauncher.launch(permissionsToRequest.toTypedArray())
        }
    }

    Scaffold(
        topBar = {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(R.string.record),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {

                if (uiState.recordingState == RecordingState.RECORDING || 
                    uiState.recordingState == RecordingState.PAUSED) {
                    Text(
                        text = uiState.elapsedTime.formatTime(),
                        style = MaterialTheme.typography.headlineMedium,
                        modifier = Modifier.padding(bottom = 16.dp)
                    )
                    
                    // 録音中または一時停止中の場合、コントロールボタンを表示
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // 一時停止/再開ボタン
                        Button(
                            onClick = {
                                if (uiState.recordingState == RecordingState.RECORDING) {
                                    onPauseRecording()
                                } else {
                                    onResumeRecording()
                                }
                            },
                            modifier = Modifier.padding(end = 8.dp)
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    if (uiState.recordingState == RecordingState.RECORDING) 
                                        Icons.Default.Pause 
                                    else 
                                        Icons.Default.PlayArrow,
                                    contentDescription = if (uiState.recordingState == RecordingState.RECORDING)
                                        stringResource(R.string.pause)
                                    else
                                        stringResource(R.string.resume)
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    if (uiState.recordingState == RecordingState.RECORDING)
                                        stringResource(R.string.pause)
                                    else
                                        stringResource(R.string.resume)
                                )
                            }
                        }
                        
                        // 停止ボタン
                        Button(
                            onClick = { onStopRecording() },
                            modifier = Modifier.padding(start = 8.dp)
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    Icons.Default.Stop,
                                    contentDescription = stringResource(R.string.stop)
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(stringResource(R.string.stop))
                            }
                        }
                    }
                } else {
                    // 録音開始ボタン
                    Button(
                        onClick = {
                            when (uiState.recordingState) {
                                RecordingState.IDLE -> checkPermissionAndStartRecording()
                                RecordingState.ERROR -> checkPermissionAndStartRecording()
                                else -> {}  // 何もしない
                            }
                        },
                        enabled = uiState.recordingState != RecordingState.FINISHED
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Default.Mic,
                                contentDescription = stringResource(R.string.start_recording)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(stringResource(R.string.start_recording))
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))



                if (uiState.recordingState == RecordingState.RECORDING ||
                    uiState.recordingState == RecordingState.PAUSED) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                    ) {
                        Text(
                            text = stringResource(R.string.volume_label, uiState.currentVolume),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(bottom = 8.dp)
                        )

                        // Waveform display
                        WaveformView(
                            amplitudes = uiState.amplitudeHistory,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(120.dp)
                                .clip(RoundedCornerShape(12.dp)),
                            waveformColor = when {
                                uiState.currentVolume > 80 -> MaterialTheme.colorScheme.error
                                uiState.currentVolume > 60 -> MaterialTheme.colorScheme.tertiary
                                else -> MaterialTheme.colorScheme.primary
                            },
                            backgroundColor = MaterialTheme.colorScheme.surfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun PreviewRecordScreen() {
    RecordScreen(
        uiStateFlow = MutableStateFlow(RecordingUiState()),
        onStartRecording = {},
        onStopRecording = {},
        onPauseRecording = {},
        onResumeRecording = {},
        onNavigateBack = {}
    )
}
