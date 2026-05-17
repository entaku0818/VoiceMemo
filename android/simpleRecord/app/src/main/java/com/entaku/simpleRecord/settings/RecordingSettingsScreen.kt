package com.entaku.simpleRecord.settings

import android.media.MediaRecorder
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Help
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.entaku.simpleRecord.BuildConfig
import com.entaku.simpleRecord.R

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecordingSettingsScreen(
    currentSettings: RecordingSettings,
    onSettingsChanged: (RecordingSettings) -> Unit,
    onNavigateBack: () -> Unit,
    onNavigateToFeedback: () -> Unit = {},
    onNavigateToTutorial: () -> Unit = {},
    onNavigateToScreenshotPreview: (() -> Unit)? = null
) {
    var settings by remember { mutableStateOf(currentSettings) }

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
                    text = stringResource(R.string.recording_settings),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // プリセット選択
            Text(stringResource(R.string.preset_label), style = MaterialTheme.typography.titleMedium)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                val activePreset = RecordingPreset.detect(settings)
                RecordingPreset.entries.forEach { preset ->
                    FilterChip(
                        selected = activePreset == preset,
                        onClick = { settings = preset.applyTo(settings) },
                        label = { Text(stringResource(presetStringRes(preset))) }
                    )
                }
            }

            // ファイル形式選択
            Text(stringResource(R.string.file_format), style = MaterialTheme.typography.titleMedium)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FileFormatOption(
                    text = "3GP",
                    selected = settings.fileExtension == "3gp" && settings.outputFormat == MediaRecorder.OutputFormat.THREE_GPP,
                    onClick = {
                        settings = settings.copy(
                            fileExtension = "3gp",
                            outputFormat = MediaRecorder.OutputFormat.THREE_GPP,
                            audioEncoder = MediaRecorder.AudioEncoder.AMR_NB
                        )
                    }
                )
                FileFormatOption(
                    text = "MP4",
                    selected = settings.fileExtension == "mp4" && settings.outputFormat == MediaRecorder.OutputFormat.MPEG_4,
                    onClick = {
                        settings = settings.copy(
                            fileExtension = "mp4",
                            outputFormat = MediaRecorder.OutputFormat.MPEG_4,
                            audioEncoder = MediaRecorder.AudioEncoder.AAC
                        )
                    }
                )
                FileFormatOption(
                    text = "AAC",
                    selected = settings.fileExtension == "aac" && settings.outputFormat == MediaRecorder.OutputFormat.AAC_ADTS,
                    onClick = {
                        settings = settings.copy(
                            fileExtension = "aac",
                            outputFormat = MediaRecorder.OutputFormat.AAC_ADTS,
                            audioEncoder = MediaRecorder.AudioEncoder.AAC
                        )
                    }
                )
            }
            
            // サンプリングレート選択
            Text(stringResource(R.string.sampling_rate), style = MaterialTheme.typography.titleMedium)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                SampleRateOption(
                    text = "8 kHz",
                    selected = settings.sampleRate == 8000,
                    onClick = {
                        settings = settings.copy(sampleRate = 8000)
                    }
                )
                SampleRateOption(
                    text = "16 kHz",
                    selected = settings.sampleRate == 16000,
                    onClick = {
                        settings = settings.copy(sampleRate = 16000)
                    }
                )
                SampleRateOption(
                    text = "44.1 kHz",
                    selected = settings.sampleRate == 44100,
                    onClick = {
                        settings = settings.copy(sampleRate = 44100)
                    }
                )
            }
            
            // ビットレート選択
            Text(stringResource(R.string.bit_rate), style = MaterialTheme.typography.titleMedium)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                BitRateOption(
                    text = "8 bit",
                    selected = settings.bitRate == 8,
                    onClick = {
                        settings = settings.copy(bitRate = 8)
                    }
                )
                BitRateOption(
                    text = "16 bit",
                    selected = settings.bitRate == 16,
                    onClick = {
                        settings = settings.copy(bitRate = 16)
                    }
                )
                BitRateOption(
                    text = "24 bit",
                    selected = settings.bitRate == 24,
                    onClick = {
                        settings = settings.copy(bitRate = 24)
                    }
                )
            }
            
            // チャンネル数選択
            Text(stringResource(R.string.channels), style = MaterialTheme.typography.titleMedium)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                ChannelOption(
                    text = stringResource(R.string.mono),
                    selected = settings.channels == 1,
                    onClick = {
                        settings = settings.copy(channels = 1)
                    }
                )
                ChannelOption(
                    text = stringResource(R.string.stereo),
                    selected = settings.channels == 2,
                    onClick = {
                        settings = settings.copy(channels = 2)
                    }
                )
            }
            
            // マイク音量
            HorizontalDivider()
            Spacer(modifier = Modifier.height(8.dp))
            Text(stringResource(R.string.mic_volume), style = MaterialTheme.typography.titleMedium)
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Slider(
                    value = settings.micVolume,
                    onValueChange = { settings = settings.copy(micVolume = it) },
                    valueRange = 0f..1f,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    text = "${(settings.micVolume * 100).toInt()}%",
                    style = MaterialTheme.typography.bodyMedium
                )
            }

            // ノイズキャンセリング
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(stringResource(R.string.noise_suppressor), style = MaterialTheme.typography.titleSmall)
                    Text(
                        stringResource(R.string.noise_suppressor_desc),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Switch(
                    checked = settings.noiseSuppressor,
                    onCheckedChange = { settings = settings.copy(noiseSuppressor = it) }
                )
            }

            // 自動ゲインコントロール
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(stringResource(R.string.auto_gain_control), style = MaterialTheme.typography.titleSmall)
                    Text(
                        stringResource(R.string.auto_gain_control_desc),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Switch(
                    checked = settings.autoGainControl,
                    onCheckedChange = { settings = settings.copy(autoGainControl = it) }
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            // About / Contact section
            HorizontalDivider()
            Spacer(modifier = Modifier.height(8.dp))
            Text(stringResource(R.string.about), style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(4.dp))

            ListItem(
                headlineContent = { Text(stringResource(R.string.tutorial_title)) },
                trailingContent = {
                    Icon(Icons.Default.Help, contentDescription = null)
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onNavigateToTutorial() }
            )

            ListItem(
                headlineContent = { Text(stringResource(R.string.contact_us)) },
                trailingContent = {
                    Icon(Icons.AutoMirrored.Filled.Send, contentDescription = null)
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onNavigateToFeedback() }
            )

            ListItem(
                headlineContent = { Text(stringResource(R.string.app_version)) },
                trailingContent = { Text(BuildConfig.VERSION_NAME) }
            )

            Spacer(modifier = Modifier.height(8.dp))

            onNavigateToScreenshotPreview?.let { navigate ->
                Button(
                    onClick = navigate,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("🖼 Screenshot Preview (Debug)")
                }
                Spacer(modifier = Modifier.height(8.dp))
            }

            Button(
                onClick = {
                    onSettingsChanged(settings)
                    onNavigateBack()
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(stringResource(R.string.save_settings))
            }
        }
    }
}

@Composable
private fun FileFormatOption(
    text: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(text) }
    )
}

@Composable
private fun SampleRateOption(
    text: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(text) }
    )
}

@Composable
private fun BitRateOption(
    text: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(text) }
    )
}

@Composable
private fun ChannelOption(
    text: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(text) }
    )
}

private fun presetStringRes(preset: RecordingPreset): Int = when (preset) {
    RecordingPreset.MEMO -> R.string.preset_memo
    RecordingPreset.MEETING -> R.string.preset_meeting
    RecordingPreset.INTERVIEW -> R.string.preset_interview
    RecordingPreset.PODCAST -> R.string.preset_podcast
    RecordingPreset.MUSIC -> R.string.preset_music
    RecordingPreset.CUSTOM -> R.string.preset_custom
}

@Preview(showBackground = true)
@Composable
fun RecordingSettingsScreenPreview() {
    val defaultSettings = RecordingSettings(
        fileExtension = "3gp",
        outputFormat = MediaRecorder.OutputFormat.THREE_GPP,
        audioEncoder = MediaRecorder.AudioEncoder.AMR_NB,
        sampleRate = 44100,
        bitRate = 16,
        channels = 1
    )
    
    RecordingSettingsScreen(
        currentSettings = defaultSettings,
        onSettingsChanged = {},
        onNavigateBack = {}
    )
}
