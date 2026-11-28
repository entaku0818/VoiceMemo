package com.entaku.simpleRecord.record

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.core.content.PermissionChecker
import com.entaku.simpleRecord.AudioRecorderTheme
import com.entaku.simpleRecord.R
import com.entaku.simpleRecord.components.WaveformView
import com.entaku.simpleRecord.formatTime
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

private val RecordRed = Color(0xFFC62828)

@Composable
fun RecordScreen(
    uiStateFlow: StateFlow<RecordingUiState>,
    onStartRecording: () -> Unit,
    onStopRecording: () -> Unit,
    onPauseRecording: () -> Unit,
    onResumeRecording: () -> Unit,
    onNavigateBack: () -> Unit,
    // ホーム画面ショートカットから起動したときも同じ権限確認を使う (issue #204)。
    autoStartRecording: Boolean = false,
    onAutoStartRecordingConsumed: () -> Unit = {},
    onOpenRecordingSettings: (() -> Unit)? = null
) {
    val uiState by uiStateFlow.collectAsState()
    val context = LocalContext.current
    var microphonePermissionDenied by rememberSaveable { mutableStateOf(false) }
    var requestingPermissions by rememberSaveable { mutableStateOf(false) }

    val state = uiState.recordingState
    val canStart = state == RecordingState.IDLE || state == RecordingState.ERROR
    val isActive = state == RecordingState.RECORDING || state == RecordingState.PAUSED

    LaunchedEffect(state) {
        if (state == RecordingState.FINISHED) onNavigateBack()
    }

    fun hasMicrophonePermission() =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PermissionChecker.PERMISSION_GRANTED

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
        onResult = {
            requestingPermissions = false
            // POST_NOTIFICATIONS のみを要求した場合も、現在のマイク権限で判断する (issue #197)。
            microphonePermissionDenied = !hasMicrophonePermission()
            if (!microphonePermissionDenied) onStartRecording()
        }
    )
    val appSettingsLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult(),
        onResult = { microphonePermissionDenied = !hasMicrophonePermission() }
    )

    fun checkPermissionAndStartRecording() {
        if (requestingPermissions) return
        val permissionsToRequest = buildList {
            if (!hasMicrophonePermission()) add(Manifest.permission.RECORD_AUDIO)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
                PermissionChecker.PERMISSION_GRANTED
            ) {
                add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }

        if (permissionsToRequest.isEmpty()) {
            microphonePermissionDenied = false
            onStartRecording()
        } else {
            requestingPermissions = true
            permissionLauncher.launch(permissionsToRequest.toTypedArray())
        }
    }

    LaunchedEffect(autoStartRecording, canStart) {
        if (autoStartRecording && canStart) {
            checkPermissionAndStartRecording()
            onAutoStartRecordingConsumed()
        }
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        bottomBar = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 16.dp),
                contentAlignment = Alignment.Center
            ) {
                if (isActive) {
                    val paused = state == RecordingState.PAUSED
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(32.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        FilledTonalIconButton(onClick = onStopRecording, modifier = Modifier.size(64.dp)) {
                            Icon(Icons.Default.Stop, contentDescription = stringResource(R.string.stop))
                        }
                        FilledTonalIconButton(
                            onClick = if (paused) onResumeRecording else onPauseRecording,
                            modifier = Modifier.size(64.dp)
                        ) {
                            Icon(
                                imageVector = if (paused) Icons.Default.PlayArrow else Icons.Default.Pause,
                                contentDescription = stringResource(if (paused) R.string.resume else R.string.pause)
                            )
                        }
                    }
                } else {
                    Box(modifier = Modifier.width(208.dp), contentAlignment = Alignment.Center) {
                        val startLabel = stringResource(R.string.start_recording)
                        FilledIconButton(
                            onClick = ::checkPermissionAndStartRecording,
                            enabled = canStart && !requestingPermissions,
                            modifier = Modifier
                                .size(80.dp)
                                .semantics { contentDescription = startLabel },
                            colors = IconButtonDefaults.filledIconButtonColors(
                                containerColor = RecordRed,
                                contentColor = Color.White
                            )
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(30.dp)
                                    .background(LocalContentColor.current, CircleShape)
                            )
                        }
                        if (onOpenRecordingSettings != null) {
                            FilledTonalIconButton(
                                onClick = onOpenRecordingSettings,
                                modifier = Modifier
                                    .align(Alignment.CenterEnd)
                                    .size(48.dp)
                            ) {
                                Icon(
                                    Icons.Default.Settings,
                                    contentDescription = stringResource(R.string.recording_settings)
                                )
                            }
                        }
                    }
                }
            }
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = stringResource(R.string.record),
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .align(Alignment.Start)
                    .padding(bottom = 24.dp)
                    .semantics { heading() }
            )
            RecordingStatus(state)
            Text(
                text = uiState.elapsedTime.formatTime(),
                style = MaterialTheme.typography.displaySmall,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 4.dp)
            )

            if (isActive) {
                RecordingLevels(uiState)
            } else if (microphonePermissionDenied || state == RecordingState.ERROR) {
                Text(
                    text = stringResource(
                        if (microphonePermissionDenied) R.string.recording_microphone_permission_required
                        else R.string.recording_error
                    ),
                    color = MaterialTheme.colorScheme.error,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .padding(top = 24.dp)
                        .semantics { liveRegion = LiveRegionMode.Polite }
                )
                if (microphonePermissionDenied) {
                    TextButton(
                        onClick = {
                            appSettingsLauncher.launch(
                                Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.fromParts("package", context.packageName, null)
                                )
                            )
                        },
                        modifier = Modifier.padding(top = 8.dp)
                    ) {
                        Text(stringResource(R.string.recording_open_app_settings))
                    }
                }
            }
        }
    }
}

@Composable
private fun RecordingStatus(state: RecordingState) {
    val currentStatus = when (state) {
        RecordingState.RECORDING -> R.string.recording_notification_title
        RecordingState.PAUSED -> R.string.recording_notification_title_paused
        else -> R.string.recording_ready
    }
    val scheme = MaterialTheme.colorScheme
    val recordingColor = if (scheme.background.luminance() < 0.5f) Color(0xFFFF827B) else RecordRed
    // Keep the timer in place even when a translated status wraps at large font sizes.
    val statuses = listOf(
        R.string.recording_ready,
        R.string.recording_notification_title,
        R.string.recording_notification_title_paused
    )
    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.BottomCenter) {
        for (status in statuses) {
            Text(
                text = stringResource(status),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                color = if (state == RecordingState.RECORDING) recordingColor else scheme.onBackground,
                modifier = if (status == currentStatus) {
                    Modifier.semantics { liveRegion = LiveRegionMode.Polite }
                } else {
                    Modifier
                        .alpha(0f)
                        .clearAndSetSemantics {}
                }
            )
        }
    }
}

@Composable
private fun RecordingLevels(uiState: RecordingUiState) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 24.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = stringResource(R.string.volume_label, uiState.currentVolume),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        WaveformView(
            amplitudes = uiState.amplitudeHistory,
            modifier = Modifier.clip(RoundedCornerShape(12.dp))
        )

        if (uiState.isTranscriptionActive) {
            Text(
                text = stringResource(R.string.realtime_transcription_label),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 8.dp)
            )
            Text(
                text = uiState.transcribedText.ifBlank {
                    stringResource(R.string.realtime_transcription_placeholder)
                },
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(12.dp))
                    .padding(12.dp)
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
fun PreviewRecordScreen() {
    AudioRecorderTheme {
        RecordScreen(
            uiStateFlow = MutableStateFlow(RecordingUiState()),
            onStartRecording = {},
            onStopRecording = {},
            onPauseRecording = {},
            onResumeRecording = {},
            onNavigateBack = {},
            onOpenRecordingSettings = {}
        )
    }
}
