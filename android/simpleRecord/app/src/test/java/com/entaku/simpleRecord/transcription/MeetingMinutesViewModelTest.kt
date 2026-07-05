package com.entaku.simpleRecord.transcription

import com.entaku.simpleRecord.RecordingData
import com.entaku.simpleRecord.record.RecordingRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDateTime
import java.util.UUID

@OptIn(ExperimentalCoroutinesApi::class)
class MeetingMinutesViewModelTest {

    private val uuid: UUID = UUID.randomUUID()
    private lateinit var repository: FakeRecordingRepository
    private lateinit var client: TranscriptionApiClient

    @Before
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        repository = FakeRecordingRepository()
        client = mockk()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun recording(
        transcription: String? = "会議の文字起こしテキスト",
        minutes: String? = null
    ) = RecordingData(
        uuid = uuid,
        title = "test",
        creationDate = LocalDateTime.of(2026, 7, 5, 0, 0),
        fileExtension = "m4a",
        khz = "44.1",
        bitRate = 128,
        channels = 1,
        duration = 60L,
        filePath = "/tmp/test.m4a",
        transcriptionText = transcription,
        meetingMinutesText = minutes
    )

    private fun viewModel() = MeetingMinutesViewModel(
        recordingUuid = uuid,
        repository = repository,
        client = client,
        tokenProvider = { "fake-token" }
    )

    private fun viewModel(tokenProvider: suspend (Boolean) -> String) = MeetingMinutesViewModel(
        recordingUuid = uuid,
        repository = repository,
        client = client,
        tokenProvider = tokenProvider
    )

    @Test
    fun `init loads recording and becomes Idle with transcription`() = runTest {
        repository.stored = recording()
        val vm = viewModel()
        val state = vm.uiState.value as MeetingMinutesUiState.Idle
        assertTrue(state.hasTranscription)
        assertEquals(null, state.savedMinutes)
    }

    @Test
    fun `init parses saved minutes`() = runTest {
        val saved = MeetingMinutesFormatter.format(MinutesResult("保存済み要約", listOf("既存TODO")))
        repository.stored = recording(minutes = saved)
        val vm = viewModel()
        val state = vm.uiState.value as MeetingMinutesUiState.Idle
        assertEquals(MinutesResult("保存済み要約", listOf("既存TODO")), state.savedMinutes)
    }

    @Test
    fun `init without transcription sets hasTranscription false`() = runTest {
        repository.stored = recording(transcription = null)
        val vm = viewModel()
        val state = vm.uiState.value as MeetingMinutesUiState.Idle
        assertFalse(state.hasTranscription)
    }

    @Test
    fun `generate success transitions to Done`() = runTest {
        repository.stored = recording()
        coEvery { client.generateMinutes(any(), any(), any()) } returns
            MinutesResult("生成された要約", listOf("TODO A"))

        val vm = viewModel()
        vm.generate()

        val state = vm.uiState.value as MeetingMinutesUiState.Done
        assertEquals("生成された要約", state.result.summary)
        assertEquals(listOf("TODO A"), state.result.todos)
    }

    @Test
    fun `generate failure transitions to Failed`() = runTest {
        repository.stored = recording()
        coEvery { client.generateMinutes(any(), any(), any()) } throws RuntimeException("server error")

        val vm = viewModel()
        vm.generate()

        assertTrue(vm.uiState.value is MeetingMinutesUiState.Failed)
    }

    @Test
    fun `generate retries once with forced refresh token on 401`() = runTest {
        repository.stored = recording()
        coEvery { client.generateMinutes("fake-token", any(), any()) } throws
            TranscriptionApiException(401, "unauthorized")
        coEvery { client.generateMinutes("fresh-token", any(), any()) } returns
            MinutesResult("再試行成功", emptyList())

        val vm = viewModel { forceRefresh -> if (forceRefresh) "fresh-token" else "fake-token" }
        vm.generate()

        val state = vm.uiState.value as MeetingMinutesUiState.Done
        assertEquals("再試行成功", state.result.summary)
    }

    @Test
    fun `generate non-401 error does not retry`() = runTest {
        repository.stored = recording()
        coEvery { client.generateMinutes(any(), any(), any()) } throws RuntimeException("server error")

        val vm = viewModel()
        vm.generate()

        assertTrue(vm.uiState.value is MeetingMinutesUiState.Failed)
        coVerify(exactly = 1) { client.generateMinutes(any(), any(), any()) }
    }

    @Test
    fun `generate without transcription does nothing`() = runTest {
        repository.stored = recording(transcription = null)
        val vm = viewModel()
        vm.generate()
        assertTrue(vm.uiState.value is MeetingMinutesUiState.Idle)
    }

    @Test
    fun `save persists formatted minutes and invokes callback`() = runTest {
        repository.stored = recording()
        coEvery { client.generateMinutes(any(), any(), any()) } returns
            MinutesResult("要約", listOf("TODO1"))

        val vm = viewModel()
        vm.generate()
        var savedCallback = false
        vm.save { savedCallback = true }

        assertTrue(savedCallback)
        assertEquals("# 要約\n要約\n\n# TODO\n- TODO1", repository.savedMinutes[uuid])
        val state = vm.uiState.value as MeetingMinutesUiState.Idle
        assertEquals(MinutesResult("要約", listOf("TODO1")), state.savedMinutes)
    }
}

private class FakeRecordingRepository : RecordingRepository {
    var stored: RecordingData? = null
    val savedMinutes = mutableMapOf<UUID, String>()

    override suspend fun saveRecordingData(recordingData: RecordingData) = Unit
    override fun getAllRecordings(): Flow<List<RecordingData>> = flowOf(emptyList())
    override suspend fun deleteRecording(uuid: UUID) = Unit
    override suspend fun updateRecordingTitle(uuid: UUID, newTitle: String) = Unit
    override suspend fun updateTranscription(uuid: UUID, text: String) = Unit
    override suspend fun getRecording(uuid: UUID): RecordingData? = stored
    override suspend fun updateMeetingMinutes(uuid: UUID, text: String) {
        savedMinutes[uuid] = text
    }
}
