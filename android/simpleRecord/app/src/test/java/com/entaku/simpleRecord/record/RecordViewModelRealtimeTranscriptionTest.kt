package com.entaku.simpleRecord.record

import android.content.Context
import androidx.lifecycle.ViewModelStore
import androidx.test.core.app.ApplicationProvider
import com.entaku.simpleRecord.SharedRecordingsViewModel
import com.entaku.simpleRecord.settings.SettingsRepository
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 録音中のリアルタイム音声文字起こし (issue #198) の [RecordViewModel] 側の配線をテストする。
 *
 * android.speech.SpeechRecognizer 自体は Android フレームワーク/実機依存のため、
 * [SpeechTranscriptionController] をフェイクに差し替え、
 * 「録音開始/一時停止/再開/終了と連動して呼び出されるか」「結果がuiStateに反映されるか」
 * というViewModelのロジックのみを検証する。
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = android.app.Application::class)
class RecordViewModelRealtimeTranscriptionTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var context: Context
    private lateinit var fakeSpeech: FakeSpeechTranscriptionController
    private lateinit var viewModel: RecordViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        context = ApplicationProvider.getApplicationContext()
        fakeSpeech = FakeSpeechTranscriptionController()
        viewModel = RecordViewModel(
            repository = mockk(relaxed = true),
            settingsManager = SettingsRepository(context),
            sharedViewModel = mockk<SharedRecordingsViewModel>(relaxed = true),
            speechTranscriptionController = fakeSpeech
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `startRecording starts realtime transcription`() {
        viewModel.startRecording(context)

        assertEquals(1, fakeSpeech.startCallCount)
        assertEquals("", fakeSpeech.lastInitialText)
        assertTrue(viewModel.uiState.value.isTranscriptionActive)
    }

    @Test
    fun `startRecording keeps isTranscriptionActive false when device cannot recognize speech`() {
        fakeSpeech.shouldStart = false

        viewModel.startRecording(context)

        assertEquals(1, fakeSpeech.startCallCount)
        assertFalse(viewModel.uiState.value.isTranscriptionActive)
    }

    @Test
    fun `recognition result callback updates transcribedText`() {
        viewModel.startRecording(context)

        fakeSpeech.lastOnResult?.invoke("こんにちは")

        assertEquals("こんにちは", viewModel.uiState.value.transcribedText)
    }

    @Test
    fun `pauseRecording stops realtime transcription`() {
        viewModel.startRecording(context)
        fakeSpeech.lastOnResult?.invoke("録音中のテキスト")

        viewModel.pauseRecording()

        assertEquals(1, fakeSpeech.stopCallCount)
        assertFalse(viewModel.uiState.value.isTranscriptionActive)
        // 一時停止しても認識済みテキスト自体は消えない
        assertEquals("録音中のテキスト", viewModel.uiState.value.transcribedText)
    }

    @Test
    fun `resumeRecording restarts transcription carrying over previous text`() {
        viewModel.startRecording(context)
        fakeSpeech.lastOnResult?.invoke("続きから")
        viewModel.pauseRecording()

        viewModel.resumeRecording()

        assertEquals(2, fakeSpeech.startCallCount)
        assertEquals("続きから", fakeSpeech.lastInitialText)
        assertTrue(viewModel.uiState.value.isTranscriptionActive)
    }

    @Test
    fun `stopRecording stops transcription and clears transcribedText`() {
        viewModel.startRecording(context)
        fakeSpeech.lastOnResult?.invoke("最後のテキスト")

        viewModel.stopRecording()

        assertEquals(1, fakeSpeech.stopCallCount)
        assertEquals("", viewModel.uiState.value.transcribedText)
        assertFalse(viewModel.uiState.value.isTranscriptionActive)
    }

    @Test
    fun `onCleared destroys the transcription controller`() {
        viewModel.startRecording(context)

        // ViewModel#onCleared() は protected のため、ViewModelStore経由で発火させる。
        val store = ViewModelStore()
        store.put("record", viewModel)
        store.clear()

        assertEquals(1, fakeSpeech.destroyCallCount)
    }
}

/**
 * テスト用フェイク。実際の android.speech.SpeechRecognizer には依存せず、
 * 呼び出し回数・引数だけを記録して [RecordViewModel] 側の配線を検証する。
 */
private class FakeSpeechTranscriptionController : SpeechTranscriptionController {
    var shouldStart: Boolean = true
    var startCallCount = 0
    var stopCallCount = 0
    var destroyCallCount = 0
    var lastInitialText: String? = null
    var lastOnResult: ((String) -> Unit)? = null

    override fun start(context: Context, initialText: String, onResult: (String) -> Unit): Boolean {
        startCallCount++
        lastInitialText = initialText
        lastOnResult = onResult
        return shouldStart
    }

    override fun stop() {
        stopCallCount++
    }

    override fun destroy() {
        destroyCallCount++
    }
}
