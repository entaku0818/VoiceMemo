import XCTest
import ComposableArchitecture
@testable import VoiLog

// MARK: - Mock

private struct MockAudioProcessingService: AudioProcessingServiceProtocol {
    var splitResult: Result<[URL], Error>

    func generateWaveformData(for url: URL) async throws -> [Float] { [] }
    func trimAudio(at url: URL, range: ClosedRange<Double>) async throws -> URL { url }
    func splitAudio(at url: URL, atTime: Double) async throws -> [URL] {
        switch splitResult {
        case .success(let urls): return urls
        case .failure(let error): throw error
        }
    }
    func mergeAudio(urls: [URL]) async throws -> URL { urls[0] }
    func adjustVolume(at url: URL, level: Float, range: ClosedRange<Double>?) async throws -> URL { url }
}

@MainActor
final class AudioEditorReducerTests: XCTestCase {

    private let testURL = URL(fileURLWithPath: "/tmp/test.m4a")
    private let testID = UUID()

    // MARK: - Reducer ガード: 選択範囲なし

    /// 選択範囲が nil の場合は .split が即時エラー（effect 発行なし）
    func testSplit_noSelectionRange_showsError() async {
        await withMainSerialExecutor {
            let store = TestStore(
                initialState: AudioEditorReducer.State(
                    memoID: testID,
                    audioURL: testURL,
                    originalTitle: "テスト録音",
                    duration: 10.0,
                    selectedRange: nil
                )
            ) {
                AudioEditorReducer()
            } withDependencies: {
                $0.audioProcessingService = MockAudioProcessingService(splitResult: .success([]))
            }

            // String(localized:table:) でロケール非依存に reducer と同じ文字列を参照
            await store.send(.split) {
                $0.errorMessage = String(localized: "分割するポイントを選択してください。", table: "AudioEditor")
            }
        }
    }

    /// 選択範囲が点でない（範囲選択）場合は .split が即時エラー
    func testSplit_rangeSelection_showsError() async {
        await withMainSerialExecutor {
            let store = TestStore(
                initialState: AudioEditorReducer.State(
                    memoID: testID,
                    audioURL: testURL,
                    originalTitle: "テスト録音",
                    duration: 10.0,
                    selectedRange: 2.0...5.0
                )
            ) {
                AudioEditorReducer()
            } withDependencies: {
                $0.audioProcessingService = MockAudioProcessingService(splitResult: .success([]))
            }

            await store.send(.split) {
                $0.errorMessage = String(localized: "分割するポイントを選択してください。", table: "AudioEditor")
            }
        }
    }

    // MARK: - Crash #2: splitAudio エラー時に errorMessage が設定される

    /// atTime=0 等で splitAudio が throw した場合、errorMessage が設定されクラッシュしない
    func testSplit_serviceThrows_setsErrorMessage() async {
        await withMainSerialExecutor {
            let splitError = NSError(
                domain: "AudioProcessing",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "分割ポイントが無効です（0秒または音声の終端以降）"]
            )
            let store = TestStore(
                initialState: AudioEditorReducer.State(
                    memoID: testID,
                    audioURL: testURL,
                    originalTitle: "テスト録音",
                    duration: 10.0,
                    selectedRange: 0.0...0.0
                )
            ) {
                AudioEditorReducer()
            } withDependencies: {
                $0.audioProcessingService = MockAudioProcessingService(splitResult: .failure(splitError))
            }

            await store.send(.split) {
                $0.processingOperation = .split(atTime: 0.0)
            }
            await store.receive(\.splitCompleted) {
                $0.processingOperation = nil
                $0.errorMessage = String(format: String(localized: "分割に失敗しました: %@", table: "AudioEditor"), splitError.localizedDescription)
            }
        }
    }

    // MARK: - adjustVolume

    /// adjustVolume 成功時に editHistory に記録される（nil順序バグの回帰テスト）
    func testAdjustVolume_success_updatesEditHistory() async {
        await withMainSerialExecutor {
            let store = TestStore(
                initialState: AudioEditorReducer.State(
                    memoID: testID,
                    audioURL: testURL,
                    originalTitle: "テスト録音",
                    duration: 10.0,
                    selectedRange: 2.0...8.0
                )
            ) {
                AudioEditorReducer()
            } withDependencies: {
                $0.audioProcessingService = MockAudioProcessingService(splitResult: .success([]))
            }

            await store.send(.adjustVolume(0.5)) {
                $0.processingOperation = .adjustVolume(level: 0.5, range: 2.0...8.0)
            }
            await store.receive(\.adjustVolumeCompleted) {
                $0.processingOperation = nil
                $0.isEdited = true
                $0.isLoadingWaveform = true
                $0.editHistory = [.adjustVolume(level: 0.5, range: 2.0...8.0)]
            }
            await store.receive(\.audioLoaded) {
                $0.isLoadingWaveform = false
            }
        }
    }

    /// 正常な中間点で分割成功した場合、audioURL が更新され isEdited = true になる
    func testSplit_validMidpoint_updatesURL() async {
        await withMainSerialExecutor {
            let firstURL = URL(fileURLWithPath: "/tmp/first.m4a")
            let secondURL = URL(fileURLWithPath: "/tmp/second.m4a")
            let store = TestStore(
                initialState: AudioEditorReducer.State(
                    memoID: testID,
                    audioURL: testURL,
                    originalTitle: "テスト録音",
                    duration: 10.0,
                    selectedRange: 5.0...5.0
                )
            ) {
                AudioEditorReducer()
            } withDependencies: {
                $0.audioProcessingService = MockAudioProcessingService(splitResult: .success([firstURL, secondURL]))
            }
            await store.send(.split) {
                $0.processingOperation = .split(atTime: 5.0)
            }
            await store.receive(\.splitCompleted) {
                $0.processingOperation = nil
                $0.audioURL = firstURL
                $0.isEdited = true
                $0.isLoadingWaveform = true
                $0.editHistory = [.split(atTime: 5.0)]
                $0.errorMessage = String(
                    format: String(localized: "分割が完了しました。\n分割ポイントまでの「%@」\nとして保存されました。", table: "AudioEditor"),
                    String(format: String(localized: "%@ (前半)", table: "AudioEditor"), "テスト録音")
                )
            }
            await store.receive(\.audioLoaded) {
                $0.isLoadingWaveform = false
            }
            // 成功メッセージはロケールに関係なく成功アラートとして判定される（#221）
            XCTAssertTrue(store.state.isShowingSplitCompletedMessage)
        }
    }

    /// 失敗メッセージは成功アラート扱いにならない
    func testSplitFailureMessage_isNotTreatedAsSuccess() {
        var state = AudioEditorReducer.State(
            memoID: testID,
            audioURL: testURL,
            originalTitle: "テスト録音",
            duration: 10.0
        )
        XCTAssertFalse(state.isShowingSplitCompletedMessage)
        state.errorMessage = String(format: String(localized: "分割に失敗しました: %@", table: "AudioEditor"), "x")
        XCTAssertFalse(state.isShowingSplitCompletedMessage)
        state.errorMessage = AudioEditorReducer.State.splitCompletedMessage(originalTitle: "テスト録音")
        XCTAssertTrue(state.isShowingSplitCompletedMessage)
        XCTAssertTrue(state.errorMessage?.contains("テスト録音") == true)
    }

    // MARK: - 編集履歴の説明・分割後タイトル（#221: 日本語直書きをやめてカタログから引く）

    func testEditOperationDescriptions_comeFromCatalog() {
        let oneDecimal = EditOperation.oneDecimal
        let cases: [(EditOperation, String, [String])] = [
            (.trim(startTime: 1.25, endTime: 3.0), "トリム: %1$@秒 - %2$@秒", [oneDecimal(1.25), oneDecimal(3.0)]),
            (.split(atTime: 5.0), "分割: %@秒", [oneDecimal(5.0)]),
            (.adjustVolume(level: 1.5, range: 2.0...8.0), "音量調整: %1$@倍 (%2$@秒 - %3$@秒)", [oneDecimal(1.5), oneDecimal(2.0), oneDecimal(8.0)]),
            (.adjustVolume(level: 0.5, range: nil), "音量調整: %@倍 (全体)", [oneDecimal(0.5)])
        ]
        for (operation, key, args) in cases {
            let expected = String(format: String(localized: String.LocalizationValue(key), table: "AudioEditor"), arguments: args)
            XCTAssertEqual(operation.description, expected)
            XCTAssertFalse(operation.description.contains("%"), "書式指定子が残っている: \(operation.description)")
            for arg in args {
                XCTAssertTrue(operation.description.contains(arg), "\(arg) が含まれない: \(operation.description)")
            }
        }
        XCTAssertEqual(EditOperation.merge(withMemoID: UUID()).description, String(localized: "結合", table: "AudioEditor"))
    }

    func testOneDecimal_usesOneFractionDigit() {
        XCTAssertEqual(EditOperation.oneDecimal(2.0).count, 3)
        XCTAssertEqual(EditOperation.oneDecimal(12.34).count, 4)
    }

    func testSplitAudioTitle_containsTimestamp() {
        let title = AudioEditorReducer.State.splitAudioTitle(timestamp: "2026-10-03 12:34:56")
        XCTAssertEqual(title, String(format: String(localized: "分割音声 %@", table: "AudioEditor"), "2026-10-03 12:34:56"))
        XCTAssertTrue(title.contains("2026-10-03 12:34:56"))
        XCTAssertFalse(title.contains("%"))
    }
}

// MARK: - AudioProcessingService 直接テスト（Crash #2 guard 検証）

final class AudioProcessingServiceGuardTests: XCTestCase {

    private let service = AudioProcessingService()

    /// ファイルが存在しない場合でも splitAudio は throw するだけでクラッシュしない
    func testSplitAudio_missingFile_throwsErrorNotCrash() async {
        let url = URL(fileURLWithPath: "/nonexistent/audio.m4a")
        do {
            _ = try await service.splitAudio(at: url, atTime: 0.0)
            XCTFail("Should have thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    /// guard の境界値: atTime <= 0 は guard に引っかかるはずだが、
    /// findAudioFile が先に失敗するため最低でもクラッシュしないことを確認
    func testSplitAudio_atTimeNegative_throwsErrorNotCrash() async {
        let url = URL(fileURLWithPath: "/nonexistent/audio.m4a")
        do {
            _ = try await service.splitAudio(at: url, atTime: -1.0)
            XCTFail("Should have thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
