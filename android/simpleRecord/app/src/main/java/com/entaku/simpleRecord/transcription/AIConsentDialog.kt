package com.entaku.simpleRecord.transcription

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.heightIn
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import com.entaku.simpleRecord.R

@Composable
fun AIConsentDialog(purpose: AIPurpose, onAllow: () -> Unit, onDecline: () -> Unit) {
    val uriHandler = LocalUriHandler.current
    AlertDialog(
        onDismissRequest = onDecline,
        title = { Text(stringResource(R.string.ai_consent_title)) },
        text = {
            Column(Modifier.heightIn(max = (LocalConfiguration.current.screenHeightDp * 0.45f).dp)
                .verticalScroll(rememberScrollState())) {
                Text(stringResource(if (purpose == AIPurpose.AUDIO) R.string.ai_consent_audio else R.string.ai_consent_minutes))
                Text(stringResource(R.string.ai_consent_common))
                TextButton(onClick = { uriHandler.openUri("https://voilog.web.app/privacy_policy.html") }) {
                    Text(stringResource(R.string.ai_consent_policy))
                }
            }
        },
        confirmButton = { TextButton(onClick = onAllow) { Text(stringResource(R.string.ai_consent_allow)) } },
        dismissButton = { TextButton(onClick = onDecline) { Text(stringResource(R.string.ai_consent_decline)) } }
    )
}
