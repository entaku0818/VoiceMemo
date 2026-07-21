package com.entaku.simpleRecord.edit

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.entaku.simpleRecord.R

private fun formatMs(ms: Long): String {
    val totalSec = ms / 1000
    val min = totalSec / 60
    val sec = totalSec % 60
    return "%d:%02d".format(min, sec)
}

@Composable
private fun trimErrorMessage(key: String): String = when (key) {
    TrimViewModel.ERROR_INVALID_RANGE -> stringResource(R.string.trim_error_invalid_range)
    TrimViewModel.ERROR_UNSUPPORTED_FORMAT -> stringResource(R.string.trim_error_unsupported_format)
    else -> stringResource(R.string.trim_error_generic)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TrimScreen(
    title: String,
    uiState: TrimUiState,
    onStartChange: (Long) -> Unit,
    onEndChange: (Long) -> Unit,
    onTrimClick: () -> Unit,
    onNavigateBack: () -> Unit,
) {
    val durationRange = 0f..uiState.durationMs.toFloat().coerceAtLeast(0f)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.trim_title)) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
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

            Text(
                text = title,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(32.dp))

            Text(stringResource(R.string.trim_start_label, formatMs(uiState.startMs)))
            Slider(
                value = uiState.startMs.toFloat().coerceIn(durationRange.start, durationRange.endInclusive),
                onValueChange = { onStartChange(it.toLong()) },
                valueRange = durationRange,
                enabled = !uiState.isProcessing
            )

            Spacer(modifier = Modifier.height(16.dp))

            Text(stringResource(R.string.trim_end_label, formatMs(uiState.endMs)))
            Slider(
                value = uiState.endMs.toFloat().coerceIn(durationRange.start, durationRange.endInclusive),
                onValueChange = { onEndChange(it.toLong()) },
                valueRange = durationRange,
                enabled = !uiState.isProcessing
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = stringResource(
                    R.string.trim_result_duration,
                    formatMs((uiState.endMs - uiState.startMs).coerceAtLeast(0))
                ),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            uiState.errorMessage?.let { errorKey ->
                Text(
                    text = trimErrorMessage(errorKey),
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            Button(
                onClick = onTrimClick,
                enabled = !uiState.isProcessing && uiState.endMs > uiState.startMs
            ) {
                if (uiState.isProcessing) {
                    CircularProgressIndicator(modifier = Modifier.height(20.dp))
                } else {
                    Text(stringResource(R.string.trim_apply_button))
                }
            }

            if (uiState.isSaved) {
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = stringResource(R.string.trim_success),
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}
