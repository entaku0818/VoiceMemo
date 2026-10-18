package com.entaku.simpleRecord.transcription

import com.entaku.simpleRecord.RecordingData
import com.entaku.simpleRecord.record.RecordingRepository
import io.mockk.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.*
import org.junit.*
import org.junit.Assert.*
import java.io.File
import java.util.UUID

@OptIn(ExperimentalCoroutinesApi::class)
class AIConsentTest {
    @Before fun setup() { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After fun cleanup() { Dispatchers.resetMain() }

    @Test fun `audio before permission and decline do not authenticate or send`() = runTest {
        val consent = MemoryConsent()
        val client = mockk<TranscriptionApiClient>()
        var authCalls = 0
        val vm = TranscriptionViewModel("test.m4a", client, consent) { authCalls++; "token" }
        vm.startTranscription()
        assertTrue(vm.needsConsent.value)
        vm.declineConsent()
        vm.acceptConsent() // stale accept cannot authorize after dismissal
        assertFalse(consent.allowed(AIPurpose.AUDIO))
        assertEquals(0, authCalls)
        coVerify { client wasNot Called }
        coEvery { client.getUploadUrl(any(), any()) } returns ("https://example.invalid" to "blob")
        coEvery { client.uploadAudio(any(), any(), any()) } just Runs
        coEvery { client.transcribe(any(), any(), any()) } returns TranscriptionResult("text", emptyList(), "summary")
        vm.startTranscription()
        vm.acceptConsent()
        assertTrue(vm.uiState.value is TranscriptionUiState.Done)
        assertFalse(consent.allowed(AIPurpose.MINUTES))
        coVerify(exactly = 1) { client.uploadAudio(any(), any(), any()) }
        consent.reset()
        vm.startTranscription()
        assertTrue(vm.needsConsent.value)
        coVerify(exactly = 1) { client.uploadAudio(any(), any(), any()) }
    }

    @Test fun `minutes require separate consent and reject sends nothing`() = runTest {
        val id = UUID.randomUUID()
        val recording = mockk<RecordingData>()
        every { recording.transcriptionText } returns "meeting"
        every { recording.meetingMinutesText } returns null
        val repository = mockk<RecordingRepository>()
        coEvery { repository.getRecording(id) } returns recording
        val client = mockk<TranscriptionApiClient>()
        val consent = MemoryConsent().apply { allow(AIPurpose.AUDIO) }
        var authCalls = 0
        val vm = MeetingMinutesViewModel(id, repository, client, consent) { authCalls++; "token" }
        vm.generate()
        vm.declineConsent()
        vm.acceptConsent()
        assertEquals(0, authCalls)
        coVerify { client wasNot Called }
        coEvery { client.generateMinutes(any(), any(), any()) } returns MinutesResult("summary", emptyList())
        vm.generate()
        vm.acceptConsent()
        assertTrue(vm.uiState.value is MeetingMinutesUiState.Done)
        coVerify(exactly = 1) { client.generateMinutes(any(), "meeting", any()) }
    }

    @Test fun `revoking while authentication completes blocks upload URL`() = runTest {
        val consent = MemoryConsent().apply { allow(AIPurpose.AUDIO) }
        val client = mockk<TranscriptionApiClient>()
        val vm = TranscriptionViewModel("test.m4a", client, consent) { consent.reset(); "token" }
        vm.startTranscription()
        assertTrue(vm.uiState.value is TranscriptionUiState.Failed)
        coVerify { client wasNot Called }
    }

    @Test fun `all live network entry points reject without permission`() = runTest {
        val client = TranscriptionApiClient(MemoryConsent())
        val operations: List<suspend () -> Unit> = listOf(
            { client.getUploadUrl("token", "m4a"); Unit },
            { client.uploadAudio("not-a-url", File("missing"), "audio/mp4") },
            { client.transcribe("token", "blob", "en"); Unit },
            { client.generateMinutes("token", "text", "en"); Unit }
        )
        operations.forEach { operation ->
            try { operation(); fail("Expected consent rejection") }
            catch (e: IllegalStateException) { assertTrue(e.message!!.contains("permission")) }
        }
    }
}
