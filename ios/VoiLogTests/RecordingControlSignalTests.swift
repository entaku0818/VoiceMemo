import XCTest
import ComposableArchitecture
@testable import VoiLog

@MainActor
final class RecordingControlSignalTests: XCTestCase {

    private func makeAppStore(
        recordingState: RecordingFeature.State.RecordingState = .idle,
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
                requestRecordPermission: { true },
                startRecording: { _, _ in true },
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

    // MARK: - pause / resume

    func testHandle_pauseSignal_whileRecording_pausesRecording() async {
        let store = makeAppStore(recordingState: .recording)

        await RecordingControlSignalObserver.shared.handle(
            signalName: RecordingControlSignal.pause,
            store: store
        )

        XCTAssertEqual(store.recordingFeature.recordingState, .paused)
    }

    func testHandle_resumeSignal_whilePaused_resumesRecording() async {
        let store = makeAppStore(recordingState: .paused)

        await RecordingControlSignalObserver.shared.handle(
            signalName: RecordingControlSignal.resume,
            store: store
        )

        XCTAssertEqual(store.recordingFeature.recordingState, .recording)
    }

    func testHandle_pauseSignal_whileIdle_doesNothing() async {
        let store = makeAppStore(recordingState: .idle)

        await RecordingControlSignalObserver.shared.handle(
            signalName: RecordingControlSignal.pause,
            store: store
        )

        XCTAssertEqual(store.recordingFeature.recordingState, .idle)
    }

    // MARK: - stop

    func testHandle_stopSignal_whileRecording_stopsAndSaves() async {
        let insertedTitles = LockIsolated<[String]>([])
        let store = makeAppStore(
            recordingState: .recording,
            insert: { recordingVoice in
                insertedTitles.withValue { $0.append(recordingVoice.title) }
            }
        )

        await RecordingControlSignalObserver.shared.handle(
            signalName: RecordingControlSignal.stop,
            store: store
        )

        XCTAssertEqual(store.recordingFeature.recordingState, .idle)
        XCTAssertEqual(insertedTitles.value.count, 1, "停止信号でDBに1件保存されるはず")
    }

    func testHandle_stopSignal_whileIdle_doesNothing() async {
        let insertCalled = LockIsolated(false)
        let store = makeAppStore(
            recordingState: .idle,
            insert: { _ in insertCalled.setValue(true) }
        )

        await RecordingControlSignalObserver.shared.handle(
            signalName: RecordingControlSignal.stop,
            store: store
        )

        XCTAssertFalse(insertCalled.value, "録音していない時は何も保存してはいけない")
        XCTAssertEqual(store.recordingFeature.recordingState, .idle)
    }

    // MARK: - unknown signal

    func testHandle_unknownSignal_doesNothing() async {
        let store = makeAppStore(recordingState: .recording)

        await RecordingControlSignalObserver.shared.handle(
            signalName: "com.entaku.VoiLog.liveActivity.unknown",
            store: store
        )

        XCTAssertEqual(store.recordingFeature.recordingState, .recording)
    }
}
