import XCTest
import ComposableArchitecture
@testable import VoiLog

/// 設定画面の「消えた録音を復元」「診断情報を共有」導線のテスト
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

    func testRestoreRecordings_restoresFromDeviceAndNotifiesDelegate() async {
        let store = TestStore(initialState: makeState()) {
            SettingReducer()
        } withDependencies: {
            $0.voiceMemoRepository.collectRecoveryDiagnostics = { .empty }
            $0.voiceMemoRepository.restoreOrphanedRecordings = { 3 }
            $0.voiceMemoRepository.restoreFromCloud = { .init(isCloudAvailable: true) }
        }

        await store.send(.restoreRecordings) {
            $0.isRestoringRecordings = true
        }
        await store.receive(\.restoreRecordingsResponse) {
            $0.isRestoringRecordings = false
            $0.restoreOutcome = .init(localCount: 3, cloudCount: 0, isCloudAvailable: true)
        }
        // 復元した録音を一覧へ反映させるため親へ通知する
        await store.receive(\.delegate.recordingsRestored)

        await store.send(.dismissRestoreRecordingsAlert) {
            $0.restoreOutcome = nil
        }
    }

    func testRestoreRecordings_restoresFromCloudWhenDeviceHasNothing() async {
        let store = TestStore(initialState: makeState()) {
            SettingReducer()
        } withDependencies: {
            $0.voiceMemoRepository.collectRecoveryDiagnostics = { .empty }
            $0.voiceMemoRepository.restoreOrphanedRecordings = { 0 }
            $0.voiceMemoRepository.restoreFromCloud = {
                .init(restoredCount: 5, isCloudAvailable: true, cloudRecordCount: 5)
            }
        }

        await store.send(.restoreRecordings) {
            $0.isRestoringRecordings = true
        }
        // 端末内が空でも iCloud から戻れば一覧の再読み込みが要る
        await store.receive(\.restoreRecordingsResponse) {
            $0.isRestoringRecordings = false
            $0.restoreOutcome = .init(localCount: 0, cloudCount: 5, isCloudAvailable: true)
        }
        await store.receive(\.delegate.recordingsRestored)
    }

    func testRestoreRecordings_noOrphansDoesNotNotifyDelegate() async {
        let store = TestStore(initialState: makeState()) {
            SettingReducer()
        } withDependencies: {
            $0.voiceMemoRepository.collectRecoveryDiagnostics = { .empty }
            $0.voiceMemoRepository.restoreOrphanedRecordings = { 0 }
            $0.voiceMemoRepository.restoreFromCloud = { .init(isCloudAvailable: true) }
        }

        await store.send(.restoreRecordings) {
            $0.isRestoringRecordings = true
        }
        // 0件なら一覧の再読み込みは不要（delegate を送らない）
        await store.receive(\.restoreRecordingsResponse) {
            $0.isRestoringRecordings = false
            $0.restoreOutcome = .init(localCount: 0, cloudCount: 0, isCloudAvailable: true)
        }
    }

    func testRestoreRecordings_ignoresTapWhileAlreadyRunning() async {
        let store = TestStore(initialState: makeState()) {
            SettingReducer()
        } withDependencies: {
            $0.voiceMemoRepository.collectRecoveryDiagnostics = { .empty }
            $0.voiceMemoRepository.restoreOrphanedRecordings = { 1 }
            $0.voiceMemoRepository.restoreFromCloud = { .init(isCloudAvailable: true) }
        }
        store.exhaustivity = .off

        await store.send(.restoreRecordings) {
            $0.isRestoringRecordings = true
        }
        // 実行中の再タップは無視される（二重復元を防ぐ）
        await store.send(.restoreRecordings)

        await store.skipReceivedActions()
    }

    // MARK: - 診断情報

    func testPrepareDiagnostics_producesShareableText() async {
        var diagnostics = RecoveryDiagnostics.empty
        diagnostics.appVersion = "1.12.2"
        diagnostics.coreDataRowCount = 0
        diagnostics.orphanCount = 7

        let store = TestStore(initialState: makeState()) {
            SettingReducer()
        } withDependencies: {
            $0.voiceMemoRepository.collectRecoveryDiagnostics = { diagnostics }
        }

        await store.send(.prepareDiagnostics) {
            $0.isCollectingDiagnostics = true
        }
        await store.receive(\.diagnosticsPrepared) {
            $0.isCollectingDiagnostics = false
            $0.diagnosticsText = diagnostics.formatted()
        }

        await store.send(.dismissDiagnostics) {
            $0.diagnosticsText = nil
        }
    }

    func testPrepareDiagnostics_ignoresTapWhileAlreadyRunning() async {
        let store = TestStore(initialState: makeState()) {
            SettingReducer()
        } withDependencies: {
            $0.voiceMemoRepository.collectRecoveryDiagnostics = { .empty }
        }
        store.exhaustivity = .off

        await store.send(.prepareDiagnostics) {
            $0.isCollectingDiagnostics = true
        }
        await store.send(.prepareDiagnostics)

        await store.skipReceivedActions()
    }

    // MARK: - 復元結果の文言

    func testRestoreMessage_mentionsBothSourcesWhenBothRestored() {
        let message = SettingView.restoreMessage(
            for: .init(localCount: 2, cloudCount: 3, isCloudAvailable: true)
        )
        XCTAssertTrue(message.contains("2"))
        XCTAssertTrue(message.contains("3"))
    }

    func testRestoreMessage_explainsCloudSignInWhenCloudUnavailable() {
        let message = SettingView.restoreMessage(
            for: .init(localCount: 0, cloudCount: 0, isCloudAvailable: false)
        )
        // iCloud を見られなかったことが分かる案内になっている
        XCTAssertTrue(message.contains("iCloud"))
    }

    func testRestoreMessage_saysNothingFoundWhenCloudCheckedButEmpty() {
        let message = SettingView.restoreMessage(
            for: .init(localCount: 0, cloudCount: 0, isCloudAvailable: true)
        )
        XCTAssertFalse(message.isEmpty)
        XCTAssertNotEqual(
            message,
            SettingView.restoreMessage(for: .init(localCount: 0, cloudCount: 0, isCloudAvailable: false))
        )
    }
}
