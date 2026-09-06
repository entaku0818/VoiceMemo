import XCTest
import ComposableArchitecture
@testable import VoiLog

/// 設定画面の「消えた録音を復元」導線のテスト
@MainActor
final class SettingRecoveryFeatureTests: XCTestCase {

    private func makeState() -> SettingReducer.State {
        SettingReducer.State(
            selectedFileFormat: "m4a",
            samplingFrequency: 44100,
            quantizationBitDepth: 16,
            numberOfChannels: 1,
            microphonesVolume: 0.5,
            developerSupported: false,
            hasPurchasedPremium: false
        )
    }

    func testRestoreRecordings_restoresAndNotifiesDelegate() async {
        let store = TestStore(initialState: makeState()) {
            SettingReducer()
        } withDependencies: {
            $0.voiceMemoRepository.restoreOrphanedRecordings = { 3 }
        }

        await store.send(.restoreRecordings) {
            $0.isRestoringRecordings = true
        }
        await store.receive(\.restoreRecordingsResponse) {
            $0.isRestoringRecordings = false
            $0.restoredRecordingsCount = 3
        }
        // 復元した録音を一覧へ反映させるため親へ通知する
        await store.receive(\.delegate.recordingsRestored)

        await store.send(.dismissRestoreRecordingsAlert) {
            $0.restoredRecordingsCount = nil
        }
    }

    func testRestoreRecordings_noOrphansDoesNotNotifyDelegate() async {
        let store = TestStore(initialState: makeState()) {
            SettingReducer()
        } withDependencies: {
            $0.voiceMemoRepository.restoreOrphanedRecordings = { 0 }
        }

        await store.send(.restoreRecordings) {
            $0.isRestoringRecordings = true
        }
        // 0件なら一覧の再読み込みは不要（delegate を送らない）
        await store.receive(\.restoreRecordingsResponse) {
            $0.isRestoringRecordings = false
            $0.restoredRecordingsCount = 0
        }
    }

    func testRestoreRecordings_ignoresTapWhileAlreadyRunning() async {
        let store = TestStore(initialState: makeState()) {
            SettingReducer()
        } withDependencies: {
            $0.voiceMemoRepository.restoreOrphanedRecordings = { 1 }
        }
        store.exhaustivity = .off

        await store.send(.restoreRecordings) {
            $0.isRestoringRecordings = true
        }
        // 実行中の再タップは無視される（二重復元を防ぐ）
        await store.send(.restoreRecordings)

        await store.skipReceivedActions()
    }
}
