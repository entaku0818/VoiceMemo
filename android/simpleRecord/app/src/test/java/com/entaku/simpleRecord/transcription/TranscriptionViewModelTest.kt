package com.entaku.simpleRecord.transcription

import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class TranscriptionViewModelTest {

    private lateinit var client: TranscriptionApiClient

    @Before
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        client = mockk()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun viewModel(tokenProvider: suspend (Boolean) -> String) = TranscriptionViewModel(
        audioFilePath = "/tmp/test.m4a",
        client = client,
        tokenProvider = tokenProvider
    )

    @Test
    fun `success flow reaches Done`() = runTest {
        coEvery { client.getUploadUrl(any(), any()) } returns Pair("https://signed.example.com", "blob-1")
        coEvery { client.uploadAudio(any(), any(), any()) } returns Unit
        coEvery { client.transcribe(any(), any(), any()) } returns
            TranscriptionResult("文字起こし結果", emptyList(), "要約")

        val vm = viewModel { "token" }
        vm.startTranscription()

        val state = vm.uiState.value as TranscriptionUiState.Done
        assertEquals("文字起こし結果", state.result.transcription)
    }

    @Test
    fun `401 on upload-url retries once with forced refresh token`() = runTest {
        var callCount = 0
        val tokenProvider: suspend (Boolean) -> String = { forceRefresh ->
            callCount++
            if (forceRefresh) "fresh-token" else "stale-token"
        }
        coEvery { client.getUploadUrl("stale-token", any()) } throws TranscriptionApiException(401, "unauthorized")
        coEvery { client.getUploadUrl("fresh-token", any()) } returns Pair("https://signed.example.com", "blob-1")
        coEvery { client.uploadAudio(any(), any(), any()) } returns Unit
        coEvery { client.transcribe(any(), any(), any()) } returns
            TranscriptionResult("再試行成功", emptyList(), "")

        val vm = viewModel(tokenProvider)
        vm.startTranscription()

        val state = vm.uiState.value as TranscriptionUiState.Done
        assertEquals("再試行成功", state.result.transcription)
        // upload-url通常取得 + upload-urlの401後の強制リフレッシュ + transcribe通常取得 = 3回
        assertEquals(3, callCount)
    }

    @Test
    fun `401 on transcribe retries once with forced refresh token`() = runTest {
        coEvery { client.getUploadUrl(any(), any()) } returns Pair("https://signed.example.com", "blob-1")
        coEvery { client.uploadAudio(any(), any(), any()) } returns Unit
        coEvery { client.transcribe("stale-token", any(), any()) } throws TranscriptionApiException(401, "unauthorized")
        coEvery { client.transcribe("fresh-token", any(), any()) } returns
            TranscriptionResult("再試行成功", emptyList(), "")

        val vm = viewModel { forceRefresh -> if (forceRefresh) "fresh-token" else "stale-token" }
        vm.startTranscription()

        val state = vm.uiState.value as TranscriptionUiState.Done
        assertEquals("再試行成功", state.result.transcription)
    }

    @Test
    fun `non-401 error does not retry and transitions to Failed`() = runTest {
        coEvery { client.getUploadUrl(any(), any()) } throws TranscriptionApiException(500, "server error")

        val vm = viewModel { "token" }
        vm.startTranscription()

        assertTrue(vm.uiState.value is TranscriptionUiState.Failed)
        coVerify(exactly = 1) { client.getUploadUrl(any(), any()) }
    }

    @Test
    fun `401 twice in a row still fails after single retry`() = runTest {
        coEvery { client.getUploadUrl(any(), any()) } throws TranscriptionApiException(401, "unauthorized")

        val vm = viewModel { "token" }
        vm.startTranscription()

        assertTrue(vm.uiState.value is TranscriptionUiState.Failed)
        coVerify(exactly = 2) { client.getUploadUrl(any(), any()) }
    }
}
