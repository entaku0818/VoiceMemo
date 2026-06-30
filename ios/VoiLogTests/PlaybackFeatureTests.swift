import XCTest
import ComposableArchitecture
@testable import VoiLog

// Suspends until task cancellation by resuming the continuation via withTaskCancellationHandler.
// Used in NeverClock and play mocks to block without the UInt64 overflow issue of Task.sleep(nanoseconds: .max).
private func blockUntilCancelled() async throws {
    final class ContinuationBox: @unchecked Sendable {
        var value: CheckedContinuation<Void, Error>?
    }
    let box = ContinuationBox()
    try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            if Task.isCancelled {
                cont.resume(throwing: CancellationError())
            } else {
                box.value = cont
            }
        }
    } onCancel: {
        box.value?.resume(throwing: CancellationError())
    }
}

// A Clock whose sleep never resolves until the task is cancelled.
// This prevents clock.timer from firing ticks during playback tests.
private struct NeverClock: Clock {
    typealias Instant = ContinuousClock.Instant
    var now: ContinuousClock.Instant { ContinuousClock().now }
    var minimumResolution: Duration { .nanoseconds(1) }
    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        try await blockUntilCancelled()
    }
}

@MainActor
final class PlaybackFeatureTests: XCTestCase {

    private let testID = UUID()

    private func makeMemo(id: UUID? = nil) -> PlaybackFeature.VoiceMemo {
        PlaybackFeature.VoiceMemo(
            id: id ?? testID,
            title: "テスト録音",
            date: Date(),
            duration: 5.0,
            url: URL(fileURLWithPath: "/tmp/test.m4a")
        )
    }

    private func mockRepository() -> VoiceMemoRepositoryClient {
        .init(
            insert: { _ in },
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

    // MARK: - toggleRepeatOne: false → true

    func testToggleRepeatOne_falseBecomesTrue() async {
        await withMainSerialExecutor {
            let store = TestStore(initialState: PlaybackFeature.State()) {
                PlaybackFeature()
            } withDependencies: {
                $0.voiceMemoRepository = mockRepository()
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true },
                    stop: { true },
                    getCurrentTime: { 0 }
                )
            }
            store.exhaustivity = .off

            await store.send(.view(.toggleRepeatOne)) {
                $0.isRepeatOne = true
            }
        }
    }

    // MARK: - toggleRepeatOne: true → false（独立ストアで検証）

    func testToggleRepeatOne_trueBecomeFalse() async {
        await withMainSerialExecutor {
            let store = TestStore(initialState: PlaybackFeature.State()) {
                PlaybackFeature()
            } withDependencies: {
                $0.voiceMemoRepository = mockRepository()
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true },
                    stop: { true },
                    getCurrentTime: { 0 }
                )
            }
            store.exhaustivity = .off

            // 1回目: false → true
            await store.send(.view(.toggleRepeatOne)) {
                $0.isRepeatOne = true
            }
            // 2回目: true → false（リグレッション: isRepeatOne がトグルできる）
            await store.send(.view(.toggleRepeatOne)) {
                $0.isRepeatOne = false
            }
        }
    }

    // MARK: - audioPlayerDidFinish: isRepeatOne off

    func testAudioPlayerDidFinish_repeatOneOff_sendsPlaybackFinished() async {
        await withMainSerialExecutor {
            var initial = PlaybackFeature.State()
            initial.isRepeatOne = false
            initial.voiceMemos = [makeMemo()]
            initial.currentPlayingMemo = testID
            initial.playbackState = .playing

            let store = TestStore(initialState: initial) {
                PlaybackFeature()
            } withDependencies: {
                $0.voiceMemoRepository = mockRepository()
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true },
                    stop: { true },
                    getCurrentTime: { 0 }
                )
            }

            await store.send(.audioPlayerDidFinish)
            await store.receive(\.playbackFinished, timeout: .seconds(5)) {
                $0.playbackState = .idle
                $0.currentPlayingMemo = nil
                $0.currentTime = 0
            }
        }
    }

    // MARK: - audioPlayerDidFinish: isRepeatOne on, no memo

    func testAudioPlayerDidFinish_repeatOneOn_noCurrentMemo_fallsThrough() async {
        await withMainSerialExecutor {
            var initial = PlaybackFeature.State()
            initial.isRepeatOne = true
            // currentPlayingMemo = nil のままなのでメモが見つからず playbackFinished に落ちる

            let store = TestStore(initialState: initial) {
                PlaybackFeature()
            } withDependencies: {
                $0.voiceMemoRepository = mockRepository()
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true },
                    stop: { true },
                    getCurrentTime: { 0 }
                )
            }

            await store.send(.audioPlayerDidFinish)
            await store.receive(\.playbackFinished)
        }
    }

    // MARK: - audioPlayerDidFinish: isRepeatOne on, restartsPlayback

    /// isRepeatOne ON 時に audioPlayerDidFinish → playbackFinished でなく
    /// 先頭から再生が再開されることを確認（playbackFinished → state リセットが起きない）
    func testAudioPlayerDidFinish_repeatOneOn_restartsAtBeginning() async {
        var initial = PlaybackFeature.State()
        initial.isRepeatOne = true
        initial.voiceMemos = [makeMemo()]
        initial.currentPlayingMemo = testID
        initial.playbackState = .playing

        let playStartTimes = LockIsolated<[TimeInterval]>([])
        let (playSignal, playSignalCont) = AsyncStream<TimeInterval>.makeStream()

        let store = TestStore(initialState: initial) {
            PlaybackFeature()
        } withDependencies: {
            $0.voiceMemoRepository = mockRepository()
            $0.continuousClock = NeverClock()
            $0.audioPlayer = AudioPlayerClient(
                play: { _, startTime, _, _, _ in
                    playStartTimes.withValue { $0.append(startTime) }
                    playSignalCont.yield(startTime)
                    // Blocks until task cancellation; throws CancellationError so
                    // startPlayback's catch block runs instead of re-sending audioPlayerDidFinish
                    try await blockUntilCancelled()
                    return true
                },
                stop: { true },
                getCurrentTime: { 0 }
            )
        }
        store.exhaustivity = .off

        await store.send(.audioPlayerDidFinish)

        // play(startTime: 0) が呼ばれるまで待機
        let firstStartTime = await playSignal.first(where: { _ in true })
        XCTAssertEqual(firstStartTime, 0, "repeat.1 ON: 先頭 (startTime=0) から再生")
        XCTAssertEqual(playStartTimes.value.count, 1, "play が1回だけ呼ばれる")
        // playbackFinished は送られていないのでリセットされない
        XCTAssertEqual(store.state.currentPlayingMemo, testID)
        XCTAssertTrue(store.state.isRepeatOne)

        // Cancel the running effect before test ends to prevent task leak
        await store.send(.view(.stopButtonTapped))
    }

    // MARK: - geminiTranscriptionSaved: state更新 + リポジトリ永続化

    func testGeminiTranscriptionSaved_updatesStateAndPersists() async {
        await withMainSerialExecutor {
            var initial = PlaybackFeature.State()
            initial.voiceMemos = [makeMemo()]
            initial.selectedMemoForTranscription = testID
            initial.showTranscriptionSheet = true

            let updatedVoices = LockIsolated<[VoiceMemoRepositoryClient.VoiceMemoVoice]>([])

            let store = TestStore(initialState: initial) {
                PlaybackFeature()
            } withDependencies: {
                $0.voiceMemoRepository = VoiceMemoRepositoryClient(
                    insert: { _ in },
                    selectAllData: { [] },
                    fetch: { _ in nil },
                    delete: { _ in },
                    update: { voice in updatedVoices.withValue { $0.append(voice) } },
                    updateTitle: { _, _ in },
                    updateTags: { _, _ in },
                    updateMeetingMinutes: { _, _ in },
                    syncToCloud: { true },
                    checkForDifferences: { false }
                )
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true },
                    stop: { true },
                    getCurrentTime: { 0 }
                )
            }

            await store.send(.view(.geminiTranscriptionSaved(testID, "文字起こしテキスト"))) {
                $0.showTranscriptionSheet = false
                $0.selectedMemoForTranscription = nil
                $0.voiceMemos[0].aiTranscriptionText = "文字起こしテキスト"
            }
            await store.finish()

            // Core Data への永続化が呼ばれたことを確認
            XCTAssertEqual(updatedVoices.value.count, 1, "voiceMemoRepository.update が1回呼ばれるべき")
            XCTAssertEqual(updatedVoices.value.first?.aiTranscriptionText, "文字起こしテキスト")
            XCTAssertEqual(updatedVoices.value.first?.uuid, testID)
        }
    }

    // MARK: - showTranscription: sheet表示状態の設定

    func testShowTranscription_setsSheetState() async {
        await withMainSerialExecutor {
            var initialState = PlaybackFeature.State()
            initialState.hasPurchasedPremium = true

            let store = TestStore(initialState: initialState) {
                PlaybackFeature()
            } withDependencies: {
                $0.voiceMemoRepository = mockRepository()
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true },
                    stop: { true },
                    getCurrentTime: { 0 }
                )
                $0.rewardedAdClient = RewardedAdClient(
                    preload: { },
                    show: { _, _ in XCTFail("premium user should not see ad") }
                )
            }

            await store.send(.view(.showTranscription(testID))) {
                $0.selectedMemoForTranscription = self.testID
                $0.showTranscriptionSheet = true
            }
        }
    }

    // MARK: - hideTranscription: sheet非表示状態のリセット

    func testHideTranscription_clearsSheetState() async {
        await withMainSerialExecutor {
            var initial = PlaybackFeature.State()
            initial.selectedMemoForTranscription = testID
            initial.showTranscriptionSheet = true

            let store = TestStore(initialState: initial) {
                PlaybackFeature()
            } withDependencies: {
                $0.voiceMemoRepository = mockRepository()
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true },
                    stop: { true },
                    getCurrentTime: { 0 }
                )
            }

            await store.send(.view(.hideTranscription)) {
                $0.showTranscriptionSheet = false
                $0.selectedMemoForTranscription = nil
            }
        }
    }

    // MARK: - geminiTranscriptionSaved: 存在しないmemoIDは無視

    func testGeminiTranscriptionSaved_unknownID_doesNothing() async {
        await withMainSerialExecutor {
            let unknownID = UUID()
            var initial = PlaybackFeature.State()
            initial.voiceMemos = [makeMemo()]  // testID のメモのみ
            initial.showTranscriptionSheet = true
            initial.selectedMemoForTranscription = unknownID

            let store = TestStore(initialState: initial) {
                PlaybackFeature()
            } withDependencies: {
                $0.voiceMemoRepository = mockRepository()
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true },
                    stop: { true },
                    getCurrentTime: { 0 }
                )
            }

            // unknownID は voiceMemos に存在しないので状態変化はsheetのクリアのみ
            await store.send(.view(.geminiTranscriptionSaved(unknownID, "テキスト"))) {
                $0.showTranscriptionSheet = false
                $0.selectedMemoForTranscription = nil
            }
            // メモのテキストは変化しない
            XCTAssertEqual(store.state.voiceMemos[0].text, "")
        }
    }

    // MARK: - リワード広告 / 文字起こし premium gate

    func testShowTranscription_premiumUser_opensSheetDirectly() async {
        await withMainSerialExecutor {
            let memoID = UUID()
            var initialState = PlaybackFeature.State()
            initialState.hasPurchasedPremium = true
            initialState.voiceMemos = [
                PlaybackFeature.VoiceMemo(
                    id: memoID, title: "test", date: .now, duration: 10,
                    url: URL(fileURLWithPath: "/tmp/test.m4a")
                )
            ]
            initialState.selectedMemoForTranscription = memoID

            let store = TestStore(initialState: initialState) {
                PlaybackFeature()
            } withDependencies: {
                $0.voiceMemoRepository = mockRepository()
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true }, stop: { true }, getCurrentTime: { 0 }
                )
                $0.rewardedAdClient = RewardedAdClient(
                    preload: { },
                    show: { _, _ in XCTFail("premium user should not see ad") }
                )
            }
            store.exhaustivity = .off

            await store.send(.view(.showTranscription(memoID))) {
                $0.showTranscriptionSheet = true
            }
        }
    }

    func testShowTranscription_freeUser_adWatched_opensSheet() async {
        await withMainSerialExecutor {
            let memoID = UUID()
            var rewardedCalled = false
            var initialState = PlaybackFeature.State()
            initialState.hasPurchasedPremium = false
            initialState.selectedMemoForTranscription = memoID

            let store = TestStore(initialState: initialState) {
                PlaybackFeature()
            } withDependencies: {
                $0.voiceMemoRepository = mockRepository()
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true }, stop: { true }, getCurrentTime: { 0 }
                )
                $0.rewardedAdClient = RewardedAdClient(
                    preload: { },
                    show: { onRewarded, _ in
                        rewardedCalled = true
                        onRewarded()
                    }
                )
            }
            store.exhaustivity = .off

            await store.send(.view(.showTranscription(memoID)))
            await store.receive(\.view.rewardedAdCompleted) {
                $0.showTranscriptionSheet = true
            }
            XCTAssertTrue(rewardedCalled)
        }
    }

    func testShowTranscription_freeUser_adSkipped_showsPremiumPrompt() async {
        await withMainSerialExecutor {
            let memoID = UUID()
            var initialState = PlaybackFeature.State()
            initialState.hasPurchasedPremium = false

            let store = TestStore(initialState: initialState) {
                PlaybackFeature()
            } withDependencies: {
                $0.voiceMemoRepository = mockRepository()
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true }, stop: { true }, getCurrentTime: { 0 }
                )
                $0.rewardedAdClient = RewardedAdClient(
                    preload: { },
                    show: { _, onSkipped in onSkipped() }
                )
            }
            store.exhaustivity = .off

            await store.send(.view(.showTranscription(memoID)))
            await store.receive(\.view.rewardedAdSkipped) {
                $0.selectedMemoForTranscription = nil
                $0.showTranscriptionPremiumPrompt = true
            }
        }
    }

    func testUpgradeFromTranscriptionPrompt_dismissesAndShowsPaywall() async {
        await withMainSerialExecutor {
            var initialState = PlaybackFeature.State()
            initialState.showTranscriptionPremiumPrompt = true

            let store = TestStore(initialState: initialState) {
                PlaybackFeature()
            } withDependencies: {
                $0.voiceMemoRepository = mockRepository()
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true }, stop: { true }, getCurrentTime: { 0 }
                )
                $0.rewardedAdClient = .testValue
            }
            store.exhaustivity = .off

            await store.send(.view(.upgradeFromTranscriptionPrompt)) {
                $0.showTranscriptionPremiumPrompt = false
            }
            // delegate(.showPaywall) はここで dispatch されるが Action が Equatable 非準拠のため
            // exhaustivity = .off で skip（VoiceAppFeature 側でペイウォール制御をテスト済み）
        }
    }

    // MARK: - volumeBoostChanged: state更新 + UserDefaults永続化

    func testVolumeBoostChanged_updatesStateAndPersists() async {
        await withMainSerialExecutor {
            let store = TestStore(initialState: PlaybackFeature.State()) {
                PlaybackFeature()
            } withDependencies: {
                $0.voiceMemoRepository = mockRepository()
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true },
                    stop: { true },
                    getCurrentTime: { 0 }
                )
            }
            store.exhaustivity = .off

            await store.send(.view(.volumeBoostChanged(2.0))) {
                $0.volumeBoost = 2.0
            }

            XCTAssertEqual(UserDefaultsManager.shared.playbackVolumeBoost, 2.0)

            // cleanup
            UserDefaultsManager.shared.playbackVolumeBoost = 1.0
        }
    }

    // MARK: - volumeBoostApplied: 再生中ならstartPlaybackを呼ぶ

    func testVolumeBoostApplied_whenNotPlaying_doesNothing() async {
        await withMainSerialExecutor {
            var initial = PlaybackFeature.State()
            initial.playbackState = .idle

            let store = TestStore(initialState: initial) {
                PlaybackFeature()
            } withDependencies: {
                $0.voiceMemoRepository = mockRepository()
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in
                        XCTFail("play should not be called when not playing")
                        return true
                    },
                    stop: { true },
                    getCurrentTime: { 0 }
                )
            }

            await store.send(.view(.volumeBoostApplied))
        }
    }
}
