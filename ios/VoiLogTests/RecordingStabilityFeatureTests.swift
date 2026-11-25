import XCTest
import ComposableArchitecture
@testable import VoiLog

/// 録音の安定性まわり（#223 / #225）の RecordingFeature のテスト
@MainActor
final class RecordingStabilityFeatureTests: XCTestCase {

    private func makeStore(
        clock: TestClock<Duration>,
        isForeground: @escaping @Sendable () async -> Bool = { true },
        currentTimeCalls: LockIsolated<Int> = LockIsolated(0),
        liveActivityUpdates: LockIsolated<Int> = LockIsolated(0),
        savedURLs: LockIsolated<[URL]> = LockIsolated([]),
        insertedRecordings: LockIsolated<[VoiceMemoRepositoryClient.RecordingVoice]> = LockIsolated([]),
        initialState: RecordingFeature.State = RecordingFeature.State(recordingState: .idle, audioPermission: .granted)
    ) -> TestStoreOf<RecordingFeature> {
        TestStore(initialState: initialState) {
            RecordingFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.uuid = .constant(UUID(0))
            $0.appForeground = AppForegroundClient(isForeground: isForeground)
            $0.longRecordingAudioClient = .init(
                currentTime: {
                    currentTimeCalls.withValue { $0 += 1 }
                    return 1.0
                },
                requestRecordPermission: { true },
                startRecording: { _, _ in true },
                stopRecording: {},
                pauseRecording: {},
                resumeRecording: {},
                audioLevel: { -20 },
                recordingState: { .recording(startTime: Date()) },
                recognizeAudio: { _ in nil },
                markRecordingSaved: { url in savedURLs.withValue { $0.append(url) } }
            )
            $0.voiceMemoRepository = .init(
                insert: { recording in insertedRecordings.withValue { $0.append(recording) } },
                selectAllData: { [] },
                fetch: { _ in nil },
                delete: { _ in },
                update: { _ in },
                updateTitle: { _, _ in },
                updateTags: { _, _ in },
                updateMeetingMinutes: { _, _ in },
                syncToCloud: { true },
                checkForDifferences: { false },
                restoreOrphanedRecordings: { 0 }
            )
            $0.liveActivityClient = .init(
                startActivity: {},
                updateActivity: { _, _ in liveActivityUpdates.withValue { $0 += 1 } },
                endActivity: {}
            )
            $0.userDefaults.isTranscriptionEnabled = { false }
        }
    }

    /// バックグラウンドでは時間・音量・波形を更新しない（CPU の起床を減らす）
    func testBackground_DoesNotPollTimeOrVolume() async {
        await withMainSerialExecutor {
            let clock = TestClock()
            let calls = LockIsolated(0)
            let store = makeStore(clock: clock, isForeground: { false }, currentTimeCalls: calls)
            store.exhaustivity = .off

            await store.send(.permissionResponse(true))
            for _ in 0..<5 {
                await clock.advance(by: .seconds(1))
            }

            XCTAssertEqual(calls.value, 0, "バックグラウンドでは currentTime を取りに行かない")
            XCTAssertEqual(store.state.duration, 0)
            await store.send(.view(.stopButtonTapped))
        }
    }

    /// バックグラウンドのまま止めても（Live Activity の停止ボタンなど）、保存する長さは止めた時点のものにする
    func testStopInBackground_RefreshesDurationBeforeSaving() async {
        await withMainSerialExecutor {
            let clock = TestClock()
            let store = makeStore(clock: clock) { false }
            store.exhaustivity = .off

            await store.send(.permissionResponse(true))
            await clock.advance(by: .seconds(3))
            await store.send(.view(.stopButtonTapped))
            await store.receive(\.timerUpdated) {
                $0.duration = 1.0
            }
        }
    }

    /// フォアグラウンドに戻れば、また時間が更新される
    func testForeground_PollsTime() async {
        await withMainSerialExecutor {
            let clock = TestClock()
            let calls = LockIsolated(0)
            let store = makeStore(clock: clock, currentTimeCalls: calls)
            store.exhaustivity = .off

            await store.send(.permissionResponse(true))
            await clock.advance(by: .milliseconds(100))
            await store.receive(\.timerUpdated) {
                $0.duration = 1.0
            }

            XCTAssertEqual(calls.value, 1)
            await store.send(.view(.stopButtonTapped))
        }
    }

    /// 時間表示はウィジェット側が数えるので、タイマーのたびに Live Activity を更新しない
    func testTimerUpdates_DoNotUpdateLiveActivity() async {
        await withMainSerialExecutor {
            let clock = TestClock()
            let updates = LockIsolated(0)
            let store = makeStore(clock: clock, liveActivityUpdates: updates)
            store.exhaustivity = .off

            await store.send(.timerUpdated(1))
            await store.send(.timerUpdated(2))
            await store.send(.timerUpdated(3))

            XCTAssertEqual(updates.value, 0)
        }
    }

    /// 一覧へ保存したら、強制終了に備えた「録音中」の記録を消す
    func testSaveWithTitle_InsertsAndMarksRecordingSaved() async {
        await withMainSerialExecutor {
            let saved = LockIsolated<[URL]>([])
            let inserted = LockIsolated<[VoiceMemoRepositoryClient.RecordingVoice]>([])
            var state = RecordingFeature.State(recordingState: .encoding, audioPermission: .granted)
            state.recordingId = UUID(1)
            state.recordingFileFormat = "WAV"
            state.tempTitle = "Recording title"
            state.showTitleDialog = true
            let store = makeStore(clock: TestClock(), savedURLs: saved, insertedRecordings: inserted, initialState: state)
            store.exhaustivity = .off

            await store.send(.view(.saveWithTitle))
            await store.finish()

            XCTAssertEqual(inserted.value.map(\.uuid), [UUID(1)])
            XCTAssertEqual(inserted.value.map(\.title), ["Recording title"])
            XCTAssertEqual(inserted.value.map(\.url), saved.value)
            XCTAssertEqual(saved.value.map(\.lastPathComponent), ["\(UUID(1).uuidString).wav"])
        }
    }

    func testSkipTitle_InsertsAndMarksRecordingSaved() async {
        await withMainSerialExecutor {
            let saved = LockIsolated<[URL]>([])
            let inserted = LockIsolated<[VoiceMemoRepositoryClient.RecordingVoice]>([])
            var state = RecordingFeature.State(recordingState: .encoding, audioPermission: .granted)
            state.recordingId = UUID(2)
            state.recordingFileFormat = "M4A"
            state.showTitleDialog = true
            let store = makeStore(clock: TestClock(), savedURLs: saved, insertedRecordings: inserted, initialState: state)
            store.exhaustivity = .off

            await store.send(.view(.skipTitle))
            await store.finish()

            XCTAssertEqual(inserted.value.map(\.uuid), [UUID(2)])
            XCTAssertEqual(inserted.value.map(\.url), saved.value)
            XCTAssertEqual(saved.value.map(\.lastPathComponent), ["\(UUID(2).uuidString).m4a"])
        }
    }

    func testDelayedSkipTitle_AfterSavingWithTitle_DoesNotInsertAgain() async {
        await withMainSerialExecutor {
            let inserted = LockIsolated<[VoiceMemoRepositoryClient.RecordingVoice]>([])
            var state = RecordingFeature.State(recordingState: .encoding, audioPermission: .granted)
            state.recordingId = UUID(3)
            state.recordingFileFormat = "M4A"
            state.showTitleDialog = true
            let store = makeStore(clock: TestClock(), insertedRecordings: inserted, initialState: state)
            store.exhaustivity = .off

            await store.send(.view(.saveWithTitle))
            await store.finish()
            XCTAssertEqual(store.state.recordingState, .idle)

            await store.send(.view(.skipTitle))
            await store.finish()

            XCTAssertEqual(inserted.value.map(\.uuid), [UUID(3)])
        }
    }
}
