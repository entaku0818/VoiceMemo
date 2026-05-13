package com.entaku.simpleRecord.feedback

import android.os.Build
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.entaku.simpleRecord.BuildConfig
import com.entaku.simpleRecord.R

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FeedbackScreen(
    viewModel: FeedbackViewModel,
    onNavigateBack: () -> Unit
) {
    val state by viewModel.state.collectAsState()

    if (state.showSuccess) {
        AlertDialog(
            onDismissRequest = onNavigateBack,
            title = { Text(stringResource(R.string.feedback_sent)) },
            text = { Text(stringResource(R.string.feedback_thanks)) },
            confirmButton = {
                Button(onClick = onNavigateBack) { Text(stringResource(R.string.ok)) }
            }
        )
    }

    if (state.errorMessage != null) {
        AlertDialog(
            onDismissRequest = { viewModel.clearError() },
            title = { Text(stringResource(R.string.feedback_error)) },
            text = { Text(state.errorMessage ?: "") },
            confirmButton = {
                Button(onClick = { viewModel.clearError() }) { Text(stringResource(R.string.ok)) }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.feedback)) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState())
        ) {
            Text(stringResource(R.string.feedback_category), style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            Row {
                FeedbackCategory.entries.forEach { cat ->
                    FilterChip(
                        selected = state.category == cat,
                        onClick = { viewModel.setCategory(cat) },
                        label = { Text(stringResource(cat.labelRes)) },
                        modifier = Modifier.padding(end = 8.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
            Text(stringResource(R.string.feedback_message), style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = state.message,
                onValueChange = { viewModel.setMessage(it) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp),
                placeholder = { Text(stringResource(R.string.feedback_message_hint)) }
            )

            Spacer(modifier = Modifier.height(16.dp))
            Text(stringResource(R.string.feedback_email_optional), style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = state.email,
                onValueChange = { viewModel.setEmail(it) },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text(stringResource(R.string.feedback_email_hint)) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                singleLine = true
            )

            Spacer(modifier = Modifier.height(24.dp))
            Button(
                onClick = {
                    viewModel.submit(
                        appVersion = BuildConfig.VERSION_NAME,
                        osVersion = Build.VERSION.RELEASE,
                        deviceModel = Build.MODEL
                    )
                },
                enabled = state.message.isNotBlank() && !state.isSending,
                modifier = Modifier.fillMaxWidth()
            ) {
                if (state.isSending) {
                    CircularProgressIndicator(modifier = Modifier.height(20.dp))
                } else {
                    Text(stringResource(R.string.feedback_send))
                }
            }
        }
    }
}
