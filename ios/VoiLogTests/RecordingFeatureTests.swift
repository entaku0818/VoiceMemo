import XCTest
import ComposableArchitecture
@testable import VoiLog

@MainActor
final class RecordingFeatureTests: XCTestCase {

    // MARK: - Pause/Resume Timer Tests

    func testPauseRecording_StopsTimerUpdates() async {
        await withMainSerialExecutor {
            let clock = TestClock()

            let store = TestStore(
                initialState: RecordingFeature.State(
                    recordingState: .recording,
                    duration: 5.0
                )
            ) {
                RecordingFeature()
            } withDependencies: {
                $0.continuousClock = clock
                $0.longRecordingAudioClient = .init(
                    currentTime: { 5.0 },
                    requestRecordPermission: { true },
                    startRecording: { _, _ in true },
                    stopRecording: {},
                    pauseRecording: {},
                    resumeRecording: {},
                    audioLevel: { 0.5 },
                    recordingState: { .paused(startTime: Date(), pausedTime: Date(), duration: 5.0) },
                    recognizeAudio: { _ in nil }
                )
                $0.liveActivityClient = .init(
                    startActivity: {},
                    updateActivity: { _, _ in },
                    endActivity: {}
                )
            }

            // When: 一時停止ボタンをタップ
            await store.send(.view(.pauseResumeButtonTapped)) {
                $0.recordingState = .paused
            }

            // Then: タイマーが進んでも時間が更新されない
            await clock.advance(by: .seconds(1))

            // duration は 5.0 のまま変化しないはず
            await store.finish()
        }
    }

    func testResumeRecording_RestartsTimerUpdates() async {
        await withMainSerialExecutor {
            let clock = TestClock()
            var currentTime: TimeInterval = 0.0
            var recordingState: RecordingState = .recording(startTime: Date())

            let store = TestStore(
                initialState: RecordingFeature.State(
                    recordingState: .idle,
                    audioPermission: .granted
                )
            ) {
                RecordingFeature()
            } withDependencies: {
                $0.continuousClock = clock
                $0.uuid = .constant(UUID())
                $0.longRecordingAudioClient = .init(
                    currentTime: { currentTime },
                    requestRecordPermission: { true },
                    startRecording: { _, _ in true },
                    stopRecording: {},
                    pauseRecording: {},
                    resumeRecording: {},
                    audioLevel: { 0.5 },
                    recordingState: { recordingState },
                    recognizeAudio: { _ in nil }
                )
                $0.voiceMemoRepository = .init(
                    insert: { _ in },
                    selectAllData: { [] },
                    fetch: { _ in nil },
                    delete: { _ in },
                    update: { _ in },
                    updateTitle: { _, _ in },
                    syncToCloud: { true },
                    checkForDifferences: { false }
                )
                $0.liveActivityClient = .init(
                    startActivity: {},
                    updateActivity: { _, _ in },
                    endActivity: {}
                )
            }

            store.exhaustivity = .off

            // Given: 録音を開始
            await store.send(.permissionResponse(true)) {
                $0.recordingState = .recording
                $0.audioPermission = .granted
                $0.duration = 0
            }

            // 録音が進む（1tick=100msのみ発火させてキュー汚染を防ぐ）
            currentTime = 5.0
            await clock.advance(by: .milliseconds(100))
            await store.receive(\.timerUpdated) {
                $0.duration = 5.0
            }

            // When: 一時停止
            recordingState = .paused(startTime: Date(), pausedTime: Date(), duration: 5.0)
            await store.send(.view(.pauseResumeButtonTapped)) {
                $0.recordingState = .paused
            }

            // タイマーが進んでも時間は更新されない
            await clock.advance(by: .milliseconds(100))

            // When: 再開
            recordingState = .recording(startTime: Date())
            await store.send(.view(.pauseResumeButtonTapped)) {
                $0.recordingState = .recording
            }

            // Then: タイマーが再開され、時間が更新される
            currentTime = 6.0
            await clock.advance(by: .milliseconds(100))
            await store.receive(\.timerUpdated) {
                $0.duration = 6.0
            }
        }
    }

    func testRecordingInProgress_UpdatesTimerContinuously() async {
        await withMainSerialExecutor {
            let clock = TestClock()
            var currentTime: TimeInterval = 0.0

            let store = TestStore(
                initialState: RecordingFeature.State(
                    recordingState: .idle,
                    audioPermission: .granted
                )
            ) {
                RecordingFeature()
            } withDependencies: {
                $0.continuousClock = clock
                $0.uuid = .constant(UUID())
                $0.longRecordingAudioClient = .init(
                    currentTime: { currentTime },
                    requestRecordPermission: { true },
                    startRecording: { _, _ in true },
                    stopRecording: {},
                    pauseRecording: {},
                    resumeRecording: {},
                    audioLevel: { 0.5 },
                    recordingState: { .recording(startTime: Date()) },
                    recognizeAudio: { _ in nil }
                )
                $0.voiceMemoRepository = .init(
                    insert: { _ in },
                    selectAllData: { [] },
                    fetch: { _ in nil },
                    delete: { _ in },
                    update: { _ in },
                    updateTitle: { _, _ in },
                    syncToCloud: { true },
                    checkForDifferences: { false }
                )
                $0.liveActivityClient = .init(
                    startActivity: {},
                    updateActivity: { _, _ in },
                    endActivity: {}
                )
            }

            store.exhaustivity = .off

            // When: 録音を開始
            await store.send(.permissionResponse(true)) {
                $0.recordingState = .recording
                $0.audioPermission = .granted
                $0.duration = 0  // 録音開始時にリセット
            }

            // Then: 時間が連続的に更新される
            currentTime = 0.1
            await clock.advance(by: .milliseconds(100))
            await store.receive(\.timerUpdated) {
                $0.duration = 0.1
            }

            currentTime = 0.2
            await clock.advance(by: .milliseconds(100))
            await store.receive(\.timerUpdated) {
                $0.duration = 0.2
            }
        }
    }

    func testPausedRecording_DoesNotUpdateTimer() async {
        await withMainSerialExecutor {
            let clock = TestClock()
            let currentTime: TimeInterval = 5.0

            let store = TestStore(
                initialState: RecordingFeature.State(
                    recordingState: .paused,
                    duration: 5.0
                )
            ) {
                RecordingFeature()
            } withDependencies: {
                $0.continuousClock = clock
                $0.longRecordingAudioClient = .init(
                    currentTime: { currentTime },
                    requestRecordPermission: { true },
                    startRecording: { _, _ in true },
                    stopRecording: {},
                    pauseRecording: {},
                    resumeRecording: {},
                    audioLevel: { 0.5 },
                    recordingState: { .paused(startTime: Date(), pausedTime: Date(), duration: 5.0) },
                    recognizeAudio: { _ in nil }
                )
            }

            store.exhaustivity = .off

            // When: 一時停止中にタイマーが進む
            await clock.advance(by: .seconds(1))
            await clock.advance(by: .seconds(1))
            await clock.advance(by: .seconds(1))

            // Then: timerUpdated アクションが送信されないはず（duration は 5.0 のまま）
            await store.finish()
        }
    }

    // MARK: - Preset Selection Tests

    func testPresetSelected_UpdatesStateAndUserDefaults() async {
        await withMainSerialExecutor {
            let store = TestStore(initialState: RecordingFeature.State()) {
                RecordingFeature()
            } withDependencies: {
                $0.longRecordingAudioClient = .init(
                    currentTime: { 0 },
                    requestRecordPermission: { true },
                    startRecording: { _, _ in true },
                    stopRecording: {},
                    pauseRecording: {},
                    resumeRecording: {},
                    audioLevel: { 0 },
                    recordingState: { .idle },
                    recognizeAudio: { _ in nil }
                )
            }

            await store.send(.view(.presetSelected(.meeting))) {
                $0.selectedPreset = .meeting
                $0.noiseCancellationEnabled = RecordingPreset.meeting.noiseCancellationEnabled
                $0.autoGainControlEnabled = RecordingPreset.meeting.autoGainControlEnabled
            }

            XCTAssertEqual(UserDefaultsManager.shared.selectedRecordingPreset, RecordingPreset.meeting.rawValue)
        }
    }

    func testPresetSelected_Music_DisablesNoiseCancellationAndAutoGain() async {
        await withMainSerialExecutor {
            let store = TestStore(
                initialState: RecordingFeature.State(
                    noiseCancellationEnabled: true,
                    autoGainControlEnabled: true
                )
            ) {
                RecordingFeature()
            } withDependencies: {
                $0.longRecordingAudioClient = .init(
                    currentTime: { 0 },
                    requestRecordPermission: { true },
                    startRecording: { _, _ in true },
                    stopRecording: {},
                    pauseRecording: {},
                    resumeRecording: {},
                    audioLevel: { 0 },
                    recordingState: { .idle },
                    recognizeAudio: { _ in nil }
                )
            }

            await store.send(.view(.presetSelected(.music))) {
                $0.selectedPreset = .music
                $0.noiseCancellationEnabled = false
                $0.autoGainControlEnabled = false
            }
        }
    }

    func testPresetSelected_Custom_DoesNotOverrideToggles() async {
        await withMainSerialExecutor {
            let store = TestStore(
                initialState: RecordingFeature.State(
                    selectedPreset: .memo,
                    noiseCancellationEnabled: false,
                    autoGainControlEnabled: false
                )
            ) {
                RecordingFeature()
            } withDependencies: {
                $0.longRecordingAudioClient = .init(
                    currentTime: { 0 },
                    requestRecordPermission: { true },
                    startRecording: { _, _ in true },
                    stopRecording: {},
                    pauseRecording: {},
                    resumeRecording: {},
                    audioLevel: { 0 },
                    recordingState: { .idle },
                    recognizeAudio: { _ in nil }
                )
            }

            await store.send(.view(.presetSelected(.custom))) {
                $0.selectedPreset = .custom
                // noiseCancellationEnabled / autoGainControlEnabled は変わらない
            }
        }
    }

    func testNoiseCancellationToggled_SwitchesToCustomPreset() async {
        await withMainSerialExecutor {
            let store = TestStore(
                initialState: RecordingFeature.State(
                    selectedPreset: .memo,
                    noiseCancellationEnabled: true
                )
            ) {
                RecordingFeature()
            } withDependencies: {
                $0.longRecordingAudioClient = .init(
                    currentTime: { 0 },
                    requestRecordPermission: { true },
                    startRecording: { _, _ in true },
                    stopRecording: {},
                    pauseRecording: {},
                    resumeRecording: {},
                    audioLevel: { 0 },
                    recordingState: { .idle },
                    recognizeAudio: { _ in nil }
                )
            }

            await store.send(.view(.noiseCancellationToggled(false))) {
                $0.noiseCancellationEnabled = false
                $0.selectedPreset = .custom
            }

            XCTAssertFalse(UserDefaultsManager.shared.noiseCancellationEnabled)
            XCTAssertEqual(UserDefaultsManager.shared.selectedRecordingPreset, RecordingPreset.custom.rawValue)
        }
    }

    func testAutoGainControlToggled_SwitchesToCustomPreset() async {
        await withMainSerialExecutor {
            let store = TestStore(
                initialState: RecordingFeature.State(
                    selectedPreset: .memo,
                    autoGainControlEnabled: true
                )
            ) {
                RecordingFeature()
            } withDependencies: {
                $0.longRecordingAudioClient = .init(
                    currentTime: { 0 },
                    requestRecordPermission: { true },
                    startRecording: { _, _ in true },
                    stopRecording: {},
                    pauseRecording: {},
                    resumeRecording: {},
                    audioLevel: { 0 },
                    recordingState: { .idle },
                    recognizeAudio: { _ in nil }
                )
            }

            await store.send(.view(.autoGainControlToggled(false))) {
                $0.autoGainControlEnabled = false
                $0.selectedPreset = .custom
            }

            XCTAssertFalse(UserDefaultsManager.shared.autoGainControlEnabled)
            XCTAssertEqual(UserDefaultsManager.shared.selectedRecordingPreset, RecordingPreset.custom.rawValue)
        }
    }

    // MARK: - Volume Update Tests

    func testPausedRecording_DoesNotUpdateVolume() async {
        await withMainSerialExecutor {
            let clock = TestClock()

            let store = TestStore(
                initialState: RecordingFeature.State(
                    recordingState: .paused,
                    volumes: -60
                )
            ) {
                RecordingFeature()
            } withDependencies: {
                $0.continuousClock = clock
                $0.longRecordingAudioClient = .init(
                    currentTime: { 5.0 },
                    requestRecordPermission: { true },
                    startRecording: { _, _ in true },
                    stopRecording: {},
                    pauseRecording: {},
                    resumeRecording: {},
                    audioLevel: { -30.0 },  // 新しい音量値
                    recordingState: { .paused(startTime: Date(), pausedTime: Date(), duration: 5.0) },
                    recognizeAudio: { _ in nil }
                )
            }

            store.exhaustivity = .off

            // When: 一時停止中にタイマーが進む
            await clock.advance(by: .milliseconds(100))
            await clock.advance(by: .milliseconds(100))

            // Then: volumesUpdated アクションが送信されないはず
            await store.finish()
        }
    }
}
