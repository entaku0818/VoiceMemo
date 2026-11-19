import XCTest
import ComposableArchitecture
@testable import VoiLog

@MainActor
final class VoiceAppFeatureTests: XCTestCase {

    // MARK: - Premium Status

    func testPremiumRefreshUpdatesAllFeaturesForActiveEntitlement() async {
        let store = TestStore(initialState: VoiceAppFeature.State()) {
            VoiceAppFeature()
        } withDependencies: {
            $0.purchaseManager = MockPurchaseManager(premiumStatus: true)
        }

        await store.send(.view(.refreshPremiumStatus))
        await store.receive(\.premiumStatusRefreshed) {
            $0.settingFeature.hasPurchasedPremium = true
            $0.playbackFeature.hasPurchasedPremium = true
            $0.playlistFeature.hasPurchasedPremium = true
        }
    }

    func testPremiumRefreshClearsExpiredEntitlementInAllFeatures() async {
        var initialState = VoiceAppFeature.State()
        initialState.settingFeature.hasPurchasedPremium = true
        initialState.playbackFeature.hasPurchasedPremium = true
        initialState.playlistFeature.hasPurchasedPremium = true
        let store = TestStore(initialState: initialState) {
            VoiceAppFeature()
        } withDependencies: {
            $0.purchaseManager = MockPurchaseManager(premiumStatus: false)
        }

        await store.send(.view(.refreshPremiumStatus))
        await store.receive(\.premiumStatusRefreshed) {
            $0.settingFeature.hasPurchasedPremium = false
            $0.playbackFeature.hasPurchasedPremium = false
            $0.playlistFeature.hasPurchasedPremium = false
        }
    }

    func testLatePremiumRefreshDismissesUpgradeOffersAndRewardedAdConfirmation() async {
        var initialState = VoiceAppFeature.State()
        initialState.showPaywall = true
        initialState.paywallSource = .monthlyLaunch
        initialState.showTrialPromotion = true
        initialState.playbackFeature.showPaywall = true
        initialState.playbackFeature.showTranscriptionPremiumPrompt = true
        initialState.playbackFeature.showRewardedAdConfirmation = true
        initialState.playlistFeature.isShowingPaywall = true
        let store = TestStore(initialState: initialState) { VoiceAppFeature() }

        await store.send(.premiumStatusRefreshed(true)) {
            $0.settingFeature.hasPurchasedPremium = true
            $0.playbackFeature.hasPurchasedPremium = true
            $0.playlistFeature.hasPurchasedPremium = true
            $0.showPaywall = false
            $0.showTrialPromotion = false
            $0.playbackFeature.showPaywall = false
            $0.playbackFeature.showTranscriptionPremiumPrompt = false
            $0.playbackFeature.showRewardedAdConfirmation = false
            $0.playlistFeature.isShowingPaywall = false
        }
        // The dismissal action owns resetting analytics source after the cover disappears.
        XCTAssertEqual(store.state.paywallSource, .monthlyLaunch)
    }

    func testFailedOrInactivePremiumRefreshKeepsExistingUpgradeOffer() async {
        var initialState = VoiceAppFeature.State()
        initialState.showPaywall = true
        initialState.showTrialPromotion = true
        let store = TestStore(initialState: initialState) { VoiceAppFeature() }

        await store.send(.premiumStatusRefreshed(nil))
        await store.send(.premiumStatusRefreshed(false))
    }

    func testPremiumRefreshKeepsAllFeaturesUnlockedOnNetworkFailure() async {
        var initialState = VoiceAppFeature.State()
        initialState.settingFeature.hasPurchasedPremium = true
        initialState.playbackFeature.hasPurchasedPremium = true
        initialState.playlistFeature.hasPurchasedPremium = true
        let store = TestStore(initialState: initialState) {
            VoiceAppFeature()
        } withDependencies: {
            $0.purchaseManager = MockPurchaseManager.failing
        }

        await store.send(.view(.refreshPremiumStatus))
        await store.receive(\.premiumStatusRefreshed)
    }

    func testDismissPaywallUpdatesPlaylistEntitlementAlongsideOtherFeatures() async {
        let store = TestStore(initialState: VoiceAppFeature.State()) {
            VoiceAppFeature()
        } withDependencies: {
            $0.userDefaults.hasPurchasedProduct = { true }
        }

        await store.send(.view(.dismissPaywall)) {
            $0.settingFeature.hasPurchasedPremium = true
            $0.playbackFeature.hasPurchasedPremium = true
            $0.playlistFeature.hasPurchasedPremium = true
        }
    }

    func testRestoringPurchasesUpdatesAllFeatures() async {
        let store = TestStore(initialState: VoiceAppFeature.State()) {
            VoiceAppFeature()
        } withDependencies: {
            $0.userDefaults.hasPurchasedProduct = { true }
        }

        await store.send(.settingFeature(.restoreResponse(true))) {
            $0.settingFeature.hasPurchasedPremium = true
            $0.settingFeature.showRestoreSuccessAlert = true
            $0.playbackFeature.hasPurchasedPremium = true
            $0.playlistFeature.hasPurchasedPremium = true
        }
    }

    // MARK: - Recording Will Start Tests

    func testRecordingWillStart_StopsPlaybackWhenPlaying() async {
        await withMainSerialExecutor {
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
            } withDependencies: {
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true },
                    stop: { true },
                    getCurrentTime: { 0 }
                )
                $0.nowPlayingClient = NowPlayingClient(update: { _ in })
            }
            store.exhaustivity = .off

            // When: 録音開始のdelegateアクションを受け取る
            await store.send(.recordingFeature(.delegate(.recordingWillStart)))

            // Then: 再生停止のアクションが送信される
            await store.receive(\.playbackFeature.view.stopButtonTapped)
        }
    }

    func testRecordingWillStart_DoesNothingWhenNotPlaying() async {
        await withMainSerialExecutor {
            // Given: 再生していない状態
            var playbackState = PlaybackFeature.State()
            playbackState.playbackState = .idle

            let store = TestStore(
                initialState: VoiceAppFeature.State(
                    playbackFeature: playbackState
                )
            ) {
                VoiceAppFeature()
            } withDependencies: {
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true },
                    stop: { true },
                    getCurrentTime: { 0 }
                )
            }
            store.exhaustivity = .off

            // When: 録音開始のdelegateアクションを受け取る
            await store.send(.recordingFeature(.delegate(.recordingWillStart)))

            // Then: 何も起こらない（追加のアクションなし）
        }
    }

    // MARK: - Recording Completed Tests

    func testRecordingCompleted_SwitchesToPlaybackTab() async {
        await withMainSerialExecutor {
            let store = TestStore(
                initialState: VoiceAppFeature.State(
                    selectedTab: 0  // 録音タブ
                )
            ) {
                VoiceAppFeature()
            } withDependencies: {
                // 録音回数（UserDefaults.standard）が10回目に当たるとトライアル訴求の日時を記録するため時計を固定する（issue #228）
                $0.date = .constant(Date(timeIntervalSince1970: 0))
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true },
                    stop: { true },
                    getCurrentTime: { 0 }
                )
            }
            store.exhaustivity = .off

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
    }

    // MARK: - Tab Switching Tests

    func testTabSwitching_UpdatesSelectedTab() async {
        await withMainSerialExecutor {
            let store = TestStore(
                initialState: VoiceAppFeature.State(
                    selectedTab: 0
                )
            ) {
                VoiceAppFeature()
            } withDependencies: {
                $0.audioPlayer = AudioPlayerClient(
                    play: { _, _, _, _, _ in true },
                    stop: { true },
                    getCurrentTime: { 0 }
                )
            }
            store.exhaustivity = .off

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
}
