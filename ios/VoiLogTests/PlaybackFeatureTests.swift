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
            syncToCloud: { true },
            checkForDifferences: { false }
        )
    }

    // MARK: - toggleRepeatOne: false → true

    func testToggleRepeatOne_falseBecomesTrue() async {
        let store = TestStore(initialState: PlaybackFeature.State()) {
            PlaybackFeature()
        } withDependencies: {
            $0.voiceMemoRepository = mockRepository()
            $0.audioPlayer = AudioPlayerClient(
                play: { _, _, _, _ in true },
                stop: { true },
                getCurrentTime: { 0 }
            )
        }
        store.exhaustivity = .off

        await store.send(.view(.toggleRepeatOne)) {
            $0.isRepeatOne = true
        }
    }

    // MARK: - toggleRepeatOne: true → false（独立ストアで検証）

    func testToggleRepeatOne_trueBecomeFalse() async {
        // false→true にしてから false→true の逆を検証するため
        // 同じストアで 2回トグルする
        let store = TestStore(initialState: PlaybackFeature.State()) {
            PlaybackFeature()
        } withDependencies: {
            $0.voiceMemoRepository = mockRepository()
            $0.audioPlayer = AudioPlayerClient(
                play: { _, _, _, _ in true },
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

    // MARK: - audioPlayerDidFinish: isRepeatOne off

    func testAudioPlayerDidFinish_repeatOneOff_sendsPlaybackFinished() async {
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
                play: { _, _, _, _ in true },
                stop: { true },
                getCurrentTime: { 0 }
            )
        }

        await store.send(.audioPlayerDidFinish)
        await store.receive(\.playbackFinished, timeout: 5 * NSEC_PER_SEC) {
            $0.playbackState = .idle
            $0.currentPlayingMemo = nil
            $0.currentTime = 0
        }
    }

    // MARK: - audioPlayerDidFinish: isRepeatOne on, no memo

    func testAudioPlayerDidFinish_repeatOneOn_noCurrentMemo_fallsThrough() async {
        var initial = PlaybackFeature.State()
        initial.isRepeatOne = true
        // currentPlayingMemo = nil のままなのでメモが見つからず playbackFinished に落ちる

        let store = TestStore(initialState: initial) {
            PlaybackFeature()
        } withDependencies: {
            $0.voiceMemoRepository = mockRepository()
            $0.audioPlayer = AudioPlayerClient(
                play: { _, _, _, _ in true },
                stop: { true },
                getCurrentTime: { 0 }
            )
        }

        await store.send(.audioPlayerDidFinish)
        await store.receive(\.playbackFinished, timeout: 5 * NSEC_PER_SEC)
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
                play: { _, startTime, _, _ in
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
}
