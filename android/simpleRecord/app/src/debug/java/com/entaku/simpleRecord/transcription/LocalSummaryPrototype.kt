package com.entaku.simpleRecord.transcription

import androidx.compose.runtime.Composable
import com.entaku.simpleRecord.record.RecordingRepository
import java.util.UUID

import androidx.compose.runtime.*
import androidx.compose.material3.*
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.entaku.simpleRecord.R
import com.google.mlkit.genai.summarization.Summarization
import com.google.mlkit.genai.summarization.SummarizerOptions
import com.google.mlkit.genai.summarization.SummarizationRequest
import com.google.mlkit.genai.common.FeatureStatus
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale

/** Debug-only, summary-only experiment. Never falls back to cloud or saves fabricated TODOs. */
@Composable
fun LocalSummaryPrototype(recordingUuid: UUID, repository: RecordingRepository) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var running by remember { mutableStateOf(false) }
    var output by remember { mutableStateOf<String?>(null) }
    val unavailable = stringResource(R.string.local_summary_unavailable)
    val failed = stringResource(R.string.local_summary_failed)
    Text(stringResource(R.string.local_summary_description))
    OutlinedButton(enabled = !running, onClick = {
        running = true
        output = null
        scope.launch {
            try {
                val text = repository.getRecording(recordingUuid)?.transcriptionText.orEmpty()
                output = withContext(Dispatchers.IO) {
                    val language = when (Locale.getDefault().language) {
                        "ja" -> SummarizerOptions.Language.JAPANESE
                        "ko" -> SummarizerOptions.Language.KOREAN
                        "en" -> SummarizerOptions.Language.ENGLISH
                        else -> return@withContext unavailable
                    }
                    val options = SummarizerOptions.builder(context.applicationContext)
                        .setInputType(SummarizerOptions.InputType.ARTICLE)
                        .setOutputType(SummarizerOptions.OutputType.THREE_BULLETS)
                        .setLanguage(language).build()
                    val summarizer = Summarization.getClient(options)
                    try {
                        if (summarizer.checkFeatureStatus().get() != FeatureStatus.AVAILABLE) {
                            unavailable
                        } else {
                            summarizer.runInference(SummarizationRequest.builder(text).build()).get().summary
                        }
                    } finally { summarizer.close() }
                }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) { output = failed }
            finally { running = false }
        }
    }) { Text(stringResource(R.string.local_summary_try)) }
    output?.let { Text(it) }
}
