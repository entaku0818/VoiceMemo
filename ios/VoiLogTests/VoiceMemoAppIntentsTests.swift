import XCTest
import ComposableArchitecture
@testable import VoiLog

// MARK: - StartRecordingIntent / StopRecordingIntent

@MainActor
final class VoiceMemoAppIntentsTests: XCTestCase {

    private func makeAppStore(
        recordingState: RecordingFeature.State.RecordingState = .idle,
        requestRecordPermission: @escaping @Sendable () async -> Bool = { true },
        startRecording: @escaping @Sendable (URL, RecordingConfiguration) async throws -> Bool = { _, _ in true },
        stopRecording: @escaping @Sendable () async -> Void = {},
        insert: @escaping @MainActor (VoiceMemoRepositoryClient.RecordingVoice) -> Void = { _ in }
    ) -> StoreOf<VoiceAppFeature> {
        Store(
            initialState: VoiceAppFeature.State(
                recordingFeature: RecordingFeature.State(recordingState: recordingState)
            )
        ) {
            VoiceAppFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.continuousClock = TestClock()
            $0.longRecordingAudioClient = .init(
                currentTime: { 0 },
                requestRecordPermission: requestRecordPermission,
                startRecording: startRecording,
                stopRecording: stopRecording,
                pauseRecording: {},
                resumeRecording: {},
                audioLevel: { 0 },
                recordingState: { .idle },
                recognizeAudio: { _ in nil }
            )
            $0.liveActivityClient = .init(
                startActivity: {},
                updateActivity: { _, _ in },
                endActivity: {}
            )
            $0.voiceMemoRepository = .init(
                insert: insert,
                selectAllData: { [] },
                fetch: { _ in nil },
                delete: { _ in },
                update: { _ in },
                updateTitle: { _, _ in },
                updateTags: { _, _ in },
                updateMeetingMinutes: { _, _ in },
                syncToCloud: { true },
                checkForDifferences: { false }
            )
        }
    }

    // MARK: StartRecordingIntent

    func testStartRecording_fromIdle_startsRecording() async throws {
        let store = makeAppStore(recordingState: .idle)

        _ = try await StartRecordingIntent.run(store: store)

        XCTAssertEqual(store.recordingFeature.recordingState, .recording)
    }

    func testStartRecording_whileAlreadyRecording_doesNotRestart() async throws {
        let startCalled = LockIsolated(false)
        let store = makeAppStore(
            recordingState: .recording,
            startRecording: { _, _ in
                startCalled.setValue(true)
                return true
            }
        )

        _ = try await StartRecordingIntent.run(store: store)

        XCTAssertFalse(startCalled.value, "既に録音中なら録音を開始し直してはいけない")
        XCTAssertEqual(store.recordingFeature.recordingState, .recording)
    }

    func testStartRecording_permissionDenied_staysIdle() async throws {
        let store = makeAppStore(
            recordingState: .idle,
            requestRecordPermission: { false }
        )

        _ = try await StartRecordingIntent.run(store: store)

        XCTAssertEqual(store.recordingFeature.recordingState, .idle)
        XCTAssertEqual(store.recordingFeature.audioPermission, .denied)
    }

    // MARK: StopRecordingIntent

    func testStopRecording_whileRecording_stopsAndSaves() async throws {
        let insertedTitles = LockIsolated<[String]>([])
        let store = makeAppStore(
            recordingState: .recording,
            insert: { recordingVoice in
                insertedTitles.withValue { $0.append(recordingVoice.title) }
            }
        )

        _ = try await StopRecordingIntent.run(store: store)

        XCTAssertEqual(store.recordingFeature.recordingState, .idle)
        XCTAssertEqual(insertedTitles.value.count, 1, "スキップ保存でDBに1件保存されるはず")
    }

    func testStopRecording_whileNotRecording_doesNothing() async throws {
        let insertCalled = LockIsolated(false)
        let store = makeAppStore(
            recordingState: .idle,
            insert: { _ in insertCalled.setValue(true) }
        )

        _ = try await StopRecordingIntent.run(store: store)

        XCTAssertFalse(insertCalled.value, "録音していない時は何も保存してはいけない")
        XCTAssertEqual(store.recordingFeature.recordingState, .idle)
    }
}

// MARK: - LatestRecordingTranscriptionRunner

@MainActor
final class LatestRecordingTranscriptionRunnerTests: XCTestCase {

    private let testURL = URL(fileURLWithPath: "/tmp/latest.m4a")

    private func makeRecording(
        title: String = "テスト録音",
        aiMeetingMinutesText: String = ""
    ) -> VoiceMemoRepositoryClient.VoiceMemoVoice {
        VoiceMemoRepositoryClient.VoiceMemoVoice(
            uuid: UUID(),
            date: Date(),
            duration: 12,
            title: title,
            url: testURL,
            text: "",
            timestampedText: nil,
            aiTranscriptionText: "",
            aiMeetingMinutesText: aiMeetingMinutesText,
            fileFormat: "m4a",
            samplingFrequency: 44100,
            quantizationBitDepth: 16,
            numberOfChannels: 1
        )
    }

    private func withRunner<T>(
        selectAllData: @escaping @MainActor () -> [VoiceMemoRepositoryClient.VoiceMemoVoice] = { [] },
        update: @escaping @MainActor (VoiceMemoRepositoryClient.VoiceMemoVoice) -> Void = { _ in },
        uploadURL: @escaping @Sendable (String, String) async throws -> TranscriptionClient.UploadURLResponse = { _, _ in
            .init(uploadUrl: "https://signed.example.com/audio", fileId: "file-1", blobName: "blob-1")
        },
        transcribe: @escaping @Sendable (String, String, String) async throws -> TranscriptionClient.TranscriptionResponse = { _, _, _ in
            .init(transcription: "文字起こし結果", segments: nil, summary: "要約結果")
        },
        uploadAudio: @escaping @Sendable (URL, String, String) async throws -> Void = { _, _, _ in },
        generateMinutes: @escaping @Sendable (String, String, String) async throws -> TranscriptionClient.MinutesResponse = { _, _, _ in
            .init(summary: "要約結果", todos: [])
        },
        currentUserIDToken: @escaping @Sendable (Bool) async throws -> String = { _ in "test-token" },
        _ operation: (LatestRecordingTranscriptionRunner) async throws -> T
    ) async rethrows -> T {
        try await withDependencies {
            $0.voiceMemoRepository = .init(
                insert: { _ in },
                selectAllData: selectAllData,
                fetch: { _ in nil },
                delete: { _ in },
                update: update,
                updateTitle: { _, _ in },
                updateTags: { _, _ in },
                updateMeetingMinutes: { _, _ in },
                syncToCloud: { true },
                checkForDifferences: { false }
            )
            $0.transcriptionClient = TranscriptionClient(
                uploadURL: uploadURL,
                transcribe: transcribe,
                uploadAudio: uploadAudio,
                generateMinutes: generateMinutes
            )
            $0.firebaseAuthClient = FirebaseAuthClient(currentUserIDToken: currentUserIDToken)
        } operation: {
            try await operation(LatestRecordingTranscriptionRunner())
        }
    }

    func testLatestRecording_noRecordings_returnsNil() async throws {
        try await withRunner(selectAllData: { [] }) { runner in
            XCTAssertNil(runner.latestRecording())
        }
    }

    func testLatestRecording_returnsFirstFromRepository() async throws {
        let recording = makeRecording(title: "最新の録音")
        try await withRunner(selectAllData: { [recording] }) { runner in
            XCTAssertEqual(runner.latestRecording()?.title, "最新の録音")
        }
    }

    func testTranscribe_success_reportsProgressAndReturnsTranscription() async throws {
        let recording = makeRecording()

        let progressUpdates = LockIsolated<[Int64]>([])
        let text = try await withRunner(
            transcribe: { _, _, _ in
                .init(transcription: "文字起こし結果", segments: nil, summary: "要約結果")
            }
        ) { runner in
            try await runner.transcribe(recording) { count in
                progressUpdates.withValue { $0.append(count) }
            }
        }

        XCTAssertEqual(text, "文字起こし結果")
        XCTAssertEqual(progressUpdates.value, [1, 2, 3])
    }

    func testTranscribe_savesResultIntoRepository() async throws {
        let saved = LockIsolated<VoiceMemoRepositoryClient.VoiceMemoVoice?>(nil)
        let recording = makeRecording()

        _ = try await withRunner(
            update: { saved.setValue($0) },
            transcribe: { _, _, _ in .init(transcription: "本文", segments: nil, summary: "要約") }
        ) { runner in
            try await runner.transcribe(recording) { _ in }
        }

        XCTAssertEqual(saved.value?.aiTranscriptionText, "本文")
        XCTAssertEqual(saved.value?.aiMeetingMinutesText, "要約")
    }

    func testTranscribe_emptySummary_doesNotOverwriteExistingMinutes() async throws {
        let saved = LockIsolated<VoiceMemoRepositoryClient.VoiceMemoVoice?>(nil)
        let recording = makeRecording(aiMeetingMinutesText: "既存の議事録")

        _ = try await withRunner(
            update: { saved.setValue($0) },
            transcribe: { _, _, _ in .init(transcription: "本文", segments: nil, summary: "") }
        ) { runner in
            try await runner.transcribe(recording) { _ in }
        }

        XCTAssertEqual(saved.value?.aiMeetingMinutesText, "既存の議事録", "summaryが空なら既存の議事録を上書きしない")
    }

    func testTranscribe_uploadURL401_retriesWithForcedRefreshToken() async throws {
        let recording = makeRecording()
        let text = try await withRunner(
            uploadURL: { token, _ in
                if token == "stale-token" {
                    throw TranscriptionError.serverError(401, "Unauthorized")
                }
                return .init(uploadUrl: "https://signed.url/audio", fileId: "f1", blobName: "b1")
            },
            transcribe: { _, _, _ in .init(transcription: "再試行成功", segments: nil, summary: nil) },
            currentUserIDToken: { forcingRefresh in forcingRefresh ? "fresh-token" : "stale-token" }
        ) { runner in
            try await runner.transcribe(recording) { _ in }
        }

        XCTAssertEqual(text, "再試行成功")
    }

    func testTranscribe_serverError_throws() async {
        let recording = makeRecording()
        do {
            _ = try await withRunner(
                transcribe: { _, _, _ in throw TranscriptionError.serverError(500, "Internal Server Error") }
            ) { runner in
                try await runner.transcribe(recording) { _ in }
            }
            XCTFail("エラーが送出されるはず")
        } catch {
            // 期待どおり失敗
        }
    }
}
