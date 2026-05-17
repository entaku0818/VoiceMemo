package com.entaku.simpleRecord.transcription

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.entaku.simpleRecord.R
import java.util.UUID

private val speakerColors = listOf(
    androidx.compose.ui.graphics.Color(0xFF2196F3),
    androidx.compose.ui.graphics.Color(0xFFE91E63),
    androidx.compose.ui.graphics.Color(0xFF4CAF50),
    androidx.compose.ui.graphics.Color(0xFFFF9800),
    androidx.compose.ui.graphics.Color(0xFF9C27B0),
    androidx.compose.ui.graphics.Color(0xFF00BCD4),
)

private val speakerColorMap = mutableMapOf<String, androidx.compose.ui.graphics.Color>()
private var colorIndex = 0

private fun speakerColor(speaker: String): androidx.compose.ui.graphics.Color =
    speakerColorMap.getOrPut(speaker) { speakerColors[colorIndex++ % speakerColors.size] }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TranscriptionScreen(
    audioFilePath: String,
    recordingUuid: UUID?,
    onNavigateBack: () -> Unit,
    onTranscriptionSaved: ((UUID, String) -> Unit)? = null
) {
    val factory = remember(audioFilePath) { TranscriptionViewModelFactory(audioFilePath) }
    val viewModel: TranscriptionViewModel = viewModel(factory = factory)
    val uiState by viewModel.uiState.collectAsState()
    val selectedLanguage by viewModel.selectedLanguage.collectAsState()
    val context = LocalContext.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
    ) {
        // Top bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onNavigateBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
            }
            Text(
                text = stringResource(R.string.transcription_title),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f)
            )
            if (uiState is TranscriptionUiState.Done) {
                val result = (uiState as TranscriptionUiState.Done).result
                IconButton(onClick = {
                    val sendIntent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(android.content.Intent.EXTRA_TEXT, result.transcription)
                    }
                    context.startActivity(android.content.Intent.createChooser(sendIntent, null))
                }) {
                    Icon(Icons.Default.Share, contentDescription = null)
                }
                TextButton(onClick = {
                    recordingUuid?.let { onTranscriptionSaved?.invoke(it, result.transcription) }
                    onNavigateBack()
                }) {
                    Text(stringResource(R.string.save))
                }
            }
        }

        when (val state = uiState) {
            is TranscriptionUiState.Idle -> IdleContent(
                selectedLanguage = selectedLanguage,
                onLanguageChanged = viewModel::setLanguage,
                onStart = viewModel::startTranscription
            )
            is TranscriptionUiState.Uploading -> ProgressContent(
                message = stringResource(R.string.transcription_uploading)
            )
            is TranscriptionUiState.Transcribing -> ProgressContent(
                message = stringResource(R.string.transcription_processing),
                hint = stringResource(R.string.transcription_processing_hint)
            )
            is TranscriptionUiState.Done -> ResultContent(result = state.result)
            is TranscriptionUiState.Failed -> FailedContent(
                message = state.message,
                onRetry = viewModel::startTranscription
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun IdleContent(
    selectedLanguage: String,
    onLanguageChanged: (String) -> Unit,
    onStart: () -> Unit
) {
    val languages = listOf(
        "ja" to "日本語",
        "en" to "English",
        "zh" to "中文",
        "ko" to "한국어",
        "de" to "Deutsch",
        "fr" to "Français",
        "es" to "Español"
    )
    var expanded by remember { mutableStateOf(false) }
    val selectedLabel = languages.find { it.first == selectedLanguage }?.second ?: selectedLanguage

    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
            modifier = Modifier.padding(horizontal = 32.dp)
        ) {
            Icon(
                imageVector = Icons.Default.Share,
                contentDescription = null,
                modifier = Modifier.size(52.dp),
                tint = MaterialTheme.colorScheme.primary
            )
            Text(
                text = stringResource(R.string.transcription_idle_title),
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
            )
            Text(
                text = stringResource(R.string.transcription_idle_desc),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
                OutlinedTextField(
                    value = selectedLabel,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text(stringResource(R.string.transcription_language)) },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                    modifier = Modifier
                        .menuAnchor()
                        .fillMaxWidth()
                )
                ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    languages.forEach { (code, label) ->
                        DropdownMenuItem(
                            text = { Text(label) },
                            onClick = { onLanguageChanged(code); expanded = false }
                        )
                    }
                }
            }

            Button(onClick = onStart, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.transcription_start))
            }
        }
    }
}

@Composable
private fun ProgressContent(message: String, hint: String? = null) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            CircularProgressIndicator()
            Text(message, style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold))
            hint?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun FailedContent(message: String, onRetry: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.padding(32.dp)
        ) {
            Text(
                stringResource(R.string.transcription_failed),
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
            )
            Text(message, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Button(onClick = onRetry) { Text(stringResource(R.string.transcription_retry)) }
        }
    }
}

@Composable
private fun ResultContent(result: TranscriptionResult) {
    LazyColumn(modifier = Modifier.fillMaxSize()) {
        if (result.summary.isNotEmpty()) {
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                ) {
                    Text(
                        stringResource(R.string.transcription_summary),
                        style = MaterialTheme.typography.labelMedium.copy(
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(result.summary, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                HorizontalDivider()
            }
        }

        if (result.segments.isEmpty()) {
            item {
                Text(
                    result.transcription,
                    modifier = Modifier.padding(16.dp),
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        } else {
            itemsIndexed(result.segments) { index, seg ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Column(modifier = Modifier.padding(top = 2.dp)) {
                        Text(
                            seg.time,
                            style = MaterialTheme.typography.bodySmall.copy(
                                fontFeatureSettings = "tnum",
                                color = MaterialTheme.colorScheme.primary
                            )
                        )
                        seg.speaker?.takeIf { it.isNotEmpty() }?.let { speaker ->
                            val color = speakerColor(speaker)
                            Text(
                                speaker,
                                style = MaterialTheme.typography.labelSmall.copy(
                                    fontWeight = FontWeight.Bold,
                                    color = color
                                )
                            )
                        }
                    }
                    Text(seg.text, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                }
                if (index < result.segments.lastIndex) {
                    HorizontalDivider(modifier = Modifier.padding(start = 64.dp))
                }
            }
        }
    }
}
