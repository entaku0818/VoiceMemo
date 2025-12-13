package com.entaku.simpleRecord.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import android.media.MediaRecorder

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecordingSettingsScreen(
    currentSettings: RecordingSettings,
    onSettingsChanged: (RecordingSettings) -> Unit,
    onNavigateBack: () -> Unit
) {
    var settings by remember { mutableStateOf(currentSettings) }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Recording Settings") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // ファイル形式選択
            Text("File Format", style = MaterialTheme.typography.titleMedium)
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
            Text("Sampling Rate", style = MaterialTheme.typography.titleMedium)
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
            Text("Bit Rate", style = MaterialTheme.typography.titleMedium)
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
            Text("Channels", style = MaterialTheme.typography.titleMedium)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                ChannelOption(
                    text = "Mono",
                    selected = settings.channels == 1,
                    onClick = {
                        settings = settings.copy(channels = 1)
                    }
                )
                ChannelOption(
                    text = "Stereo",
                    selected = settings.channels == 2,
                    onClick = {
                        settings = settings.copy(channels = 2)
                    }
                )
            }
            
            Spacer(modifier = Modifier.weight(1f))
            
            Button(
                onClick = { 
                    onSettingsChanged(settings)
                    onNavigateBack()
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Save Settings")
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
