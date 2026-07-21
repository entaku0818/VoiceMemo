package com.entaku.simpleRecord.record

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.util.Locale

/**
 * android.speech.SpeechRecognizer を用いたリアルタイム文字起こしの実装 (issue #198)。
 *
 * SpeechRecognizer#startListening は無音区間を検知すると発話を区切って結果を返すため、
 * 文字起こしを継続させるには [onError]/[onResults] のコールバック内で再度
 * startListening を呼び直す必要がある。録音が続いている間はこれを繰り返す。
 */
class AndroidSpeechTranscriptionController : SpeechTranscriptionController {

    private var speechRecognizer: SpeechRecognizer? = null
    private var isActive = false
    private var accumulatedText: String = ""
    private var onResultCallback: ((String) -> Unit)? = null

    override fun start(context: Context, initialText: String, onResult: (String) -> Unit): Boolean {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) return false
        if (isActive) return true

        isActive = true
        accumulatedText = initialText
        onResultCallback = onResult

        val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
        recognizer.setRecognitionListener(createListener())
        speechRecognizer = recognizer

        startListening(recognizer)
        return true
    }

    private fun createListener(): RecognitionListener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) = Unit
        override fun onBeginningOfSpeech() = Unit
        override fun onRmsChanged(rmsdB: Float) = Unit
        override fun onBufferReceived(buffer: ByteArray?) = Unit
        override fun onEndOfSpeech() = Unit
        override fun onEvent(eventType: Int, params: Bundle?) = Unit

        override fun onError(error: Int) {
            // ERROR_NO_MATCH / ERROR_SPEECH_TIMEOUT は無音区間の一時的な検知にすぎないため、
            // 録音が継続中であれば聞き取りを再開する。
            restartIfActive()
        }

        override fun onResults(results: Bundle?) {
            appendBestMatch(results)
            restartIfActive()
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val partial = results(partialResults).firstOrNull().orEmpty()
            if (partial.isNotBlank()) {
                onResultCallback?.invoke(joinText(accumulatedText, partial))
            }
        }
    }

    private fun appendBestMatch(results: Bundle?) {
        val best = results(results).firstOrNull()
        if (!best.isNullOrBlank()) {
            accumulatedText = joinText(accumulatedText, best)
            onResultCallback?.invoke(accumulatedText)
        }
    }

    private fun results(bundle: Bundle?): List<String> =
        bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION).orEmpty()

    private fun joinText(base: String, addition: String): String =
        if (base.isBlank()) addition else "$base $addition"

    private fun restartIfActive() {
        if (isActive) {
            speechRecognizer?.let { startListening(it) }
        }
    }

    private fun startListening(recognizer: SpeechRecognizer) {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toString())
        }
        recognizer.startListening(intent)
    }

    override fun stop() {
        isActive = false
        speechRecognizer?.let {
            it.stopListening()
            it.destroy()
        }
        speechRecognizer = null
        onResultCallback = null
    }

    override fun destroy() {
        stop()
    }
}
