import XCTest
import ComposableArchitecture
@testable import VoiLog

@MainActor
final class VoiceAppFeatureTests: XCTestCase {

    // MARK: - Recording Will Start Tests

    func testRecordingWillStart_StopsPlaybackWhenPlaying() async {
        // Given: 再生中の状態
        var playbackState = PlaybackFeature.State()
        playbackState.playbackState = .playing
        playbackState.currentPlayingMemo = UUID()

        let store = TestStore(
            initialState: VoiceAppFeature.State(
                playbackFeature: playbackState
            )
        ) {
            VoiceAppFeature()
        }

        // When: 録音開始のdelegateアクションを受け取る
        await store.send(.recordingFeature(.delegate(.recordingWillStart)))

        // Then: 再生停止のアクションが送信される
        await store.receive(\.playbackFeature.view.stopButtonTapped) {
            $0.playbackFeature.playbackState = .idle
            $0.playbackFeature.currentPlayingMemo = nil
            $0.playbackFeature.currentTime = 0
        }
    }

    func testRecordingWillStart_DoesNothingWhenNotPlaying() async {
        // Given: 再生していない状態
        var playbackState = PlaybackFeature.State()
        playbackState.playbackState = .idle

        let store = TestStore(
            initialState: VoiceAppFeature.State(
                playbackFeature: playbackState
            )
        ) {
            VoiceAppFeature()
        }

        // When: 録音開始のdelegateアクションを受け取る
        await store.send(.recordingFeature(.delegate(.recordingWillStart)))

        // Then: 何も起こらない（追加のアクションなし）
    }

    // MARK: - Recording Completed Tests

    func testRecordingCompleted_SwitchesToPlaybackTab() async {
        let store = TestStore(
            initialState: VoiceAppFeature.State(
                selectedTab: 0  // 録音タブ
            )
        ) {
            VoiceAppFeature()
        }

        let result = RecordingFeature.RecordingResult(
            url: URL(fileURLWithPath: "/test.m4a"),
            duration: 10.0,
            title: "Test Recording",
            date: Date()
        )

        // When: 録音完了のdelegateアクションを受け取る
        await store.send(.recordingFeature(.delegate(.recordingCompleted(result)))) {
            $0.selectedTab = 1  // 再生タブに切り替え
        }

        // Then: データ再読み込みのアクションが送信される
        await store.receive(\.playbackFeature.view.reloadData)
    }

    // MARK: - Tab Switching Tests

    func testTabSwitching_UpdatesSelectedTab() async {
        let store = TestStore(
            initialState: VoiceAppFeature.State(
                selectedTab: 0
            )
        ) {
            VoiceAppFeature()
        }

        // 録音タブから再生タブに切り替え
        await store.send(.binding(.set(\.selectedTab, 1))) {
            $0.selectedTab = 1
        }

        // 再生タブからプレイリストタブに切り替え
        await store.send(.binding(.set(\.selectedTab, 2))) {
            $0.selectedTab = 2
        }

        // 設定タブに切り替え
        await store.send(.binding(.set(\.selectedTab, 3))) {
            $0.selectedTab = 3
        }
    }
}
