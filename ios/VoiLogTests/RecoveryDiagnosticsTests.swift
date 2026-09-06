import XCTest
@testable import VoiLog

/// 消失時の診断スナップショットのテスト
final class RecoveryDiagnosticsTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecoveryDiagnosticsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        directory = nil
    }

    @discardableResult
    private func makeFile(_ name: String, bytes: Int, created: Date? = nil) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(repeating: 0, count: bytes).write(to: url)
        if let created {
            try FileManager.default.setAttributes([.creationDate: created], ofItemAtPath: url.path)
        }
        return url
    }

    // MARK: - audioState

    func testAudioState_countsFilesAndTotalSize() throws {
        try makeFile("\(UUID().uuidString).m4a", bytes: 1000)
        try makeFile("\(UUID().uuidString).wav", bytes: 2000)

        let state = RecoveryDiagnostics.audioState(in: [directory])

        XCTAssertEqual(state.fileCount, 2)
        XCTAssertEqual(state.totalBytes, 3000)
    }

    func testAudioState_ignoresNonAudioFiles() throws {
        try makeFile("\(UUID().uuidString).m4a", bytes: 100)
        try makeFile("Voice.sqlite", bytes: 100)
        try makeFile("notes.txt", bytes: 100)

        XCTAssertEqual(RecoveryDiagnostics.audioState(in: [directory]).fileCount, 1)
    }

    func testAudioState_includesExtensionlessFilesRestoredFromCloud() throws {
        // CloudUploader.downloadVoiceFile は拡張子なしの <UUID> で保存する
        try makeFile(UUID().uuidString, bytes: 500)

        XCTAssertEqual(RecoveryDiagnostics.audioState(in: [directory]).fileCount, 1)
    }

    func testAudioState_countsZeroByteFiles() throws {
        // 復元対象からは外れるサイズでも、状況把握のために数える
        try makeFile("\(UUID().uuidString).m4a", bytes: 0)

        XCTAssertEqual(RecoveryDiagnostics.audioState(in: [directory]).fileCount, 1)
    }

    func testAudioState_reportsOldestAndNewestCreationDate() throws {
        let old = Date(timeIntervalSince1970: 1_000_000)
        let new = Date(timeIntervalSince1970: 2_000_000)
        try makeFile("\(UUID().uuidString).m4a", bytes: 10, created: old)
        try makeFile("\(UUID().uuidString).m4a", bytes: 10, created: new)

        let state = RecoveryDiagnostics.audioState(in: [directory])

        XCTAssertEqual(state.oldest?.timeIntervalSince1970 ?? 0, old.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(state.newest?.timeIntervalSince1970 ?? 0, new.timeIntervalSince1970, accuracy: 1)
    }

    func testAudioState_ignoresMissingDirectory() {
        let missing = directory.appendingPathComponent("does-not-exist")

        XCTAssertEqual(RecoveryDiagnostics.audioState(in: [missing]).fileCount, 0)
    }

    func testAudioState_doesNotDoubleCountSameDirectoryListedTwice() throws {
        try makeFile("\(UUID().uuidString).m4a", bytes: 100)

        XCTAssertEqual(RecoveryDiagnostics.audioState(in: [directory, directory]).fileCount, 1)
    }

    // MARK: - storeState

    func testStoreState_reportsMissingStore() {
        let storeURL = directory.appendingPathComponent("Voice.sqlite")

        let state = RecoveryDiagnostics.storeState(storeURL: storeURL)

        XCTAssertFalse(state.exists)
        XCTAssertEqual(state.sizeBytes, 0)
        XCTAssertTrue(state.quarantinedFileNames.isEmpty)
    }

    func testStoreState_reportsSizeAndQuarantinedFiles() throws {
        let storeURL = try makeFile("Voice.sqlite", bytes: 4096)
        try makeFile("Voice.sqlite.corrupt-20260906-101112", bytes: 10)
        try makeFile("Voice.sqlite-wal.corrupt-20260906-101112", bytes: 10)

        let state = RecoveryDiagnostics.storeState(storeURL: storeURL)

        XCTAssertTrue(state.exists)
        XCTAssertEqual(state.sizeBytes, 4096)
        XCTAssertEqual(state.quarantinedFileNames.count, 2)
    }

    // MARK: - 判定

    func testLooksLikeDataLoss_trueWhenListIsEmptyButFilesRemain() {
        var diagnostics = RecoveryDiagnostics.empty
        diagnostics.coreDataRowCount = 0
        diagnostics.audio.fileCount = 12

        XCTAssertTrue(diagnostics.looksLikeDataLoss)
    }

    func testLooksLikeDataLoss_falseWhenListHasRows() {
        var diagnostics = RecoveryDiagnostics.empty
        diagnostics.coreDataRowCount = 3
        diagnostics.audio.fileCount = 12

        XCTAssertFalse(diagnostics.looksLikeDataLoss)
    }

    func testLooksLikeDataLoss_falseWhenNothingRecordedYet() {
        // 新規インストール直後（一覧も実体も空）は事故ではない
        XCTAssertFalse(RecoveryDiagnostics.empty.looksLikeDataLoss)
    }

    // MARK: - 出力

    func testFormatted_containsEveryFieldSupportNeeds() {
        var diagnostics = RecoveryDiagnostics.empty
        diagnostics.appVersion = "1.12.2"
        diagnostics.buildNumber = "42"
        diagnostics.osVersion = "Version 26.5"
        diagnostics.deviceModel = "iPhone16,1"
        diagnostics.coreDataRowCount = 0
        diagnostics.orphanCount = 37
        diagnostics.cloudRecordCount = 40
        diagnostics.store = .init(
            exists: true,
            sizeBytes: 4096,
            quarantinedFileNames: ["Voice.sqlite.corrupt-20260906-101112"]
        )
        diagnostics.audio = .init(fileCount: 37, totalBytes: 1_500_000)
        diagnostics.lastStoreFailure = "NSCocoaErrorDomain(23) phase=load at 2026-09-06T10:11:12Z"

        let text = diagnostics.formatted()

        XCTAssertTrue(text.contains("1.12.2"))
        XCTAssertTrue(text.contains("iPhone16,1"))
        XCTAssertTrue(text.contains("core data rows: 0"))
        XCTAssertTrue(text.contains("orphaned files: 37"))
        XCTAssertTrue(text.contains("icloud records: 40"))
        XCTAssertTrue(text.contains("Voice.sqlite.corrupt-20260906-101112"))
        XCTAssertTrue(text.contains("phase=load"))
    }

    func testFormatted_marksCloudAsUnavailableWhenNotFetched() {
        let text = RecoveryDiagnostics.empty.formatted()

        XCTAssertTrue(text.contains("icloud records: unavailable"))
        XCTAssertTrue(text.contains("last store failure: none"))
    }

    func testFormatted_doesNotContainRecordingContent() {
        // 診断情報に録音の中身が混ざらないことを担保する（共有シートでそう説明している）
        var diagnostics = RecoveryDiagnostics.empty
        diagnostics.audio = .init(fileCount: 3, totalBytes: 100)

        let text = diagnostics.formatted()

        XCTAssertFalse(text.contains("title"))
        XCTAssertFalse(text.contains("transcription"))
    }

    func testFormatted_usesFixedUnitsRegardlessOfLocale() {
        var diagnostics = RecoveryDiagnostics.empty
        diagnostics.audio = .init(fileCount: 1, totalBytes: 1_500_000)

        // 端末ロケールで単位が訳されると問い合わせの突き合わせが崩れる
        XCTAssertTrue(diagnostics.formatted().contains("1.5 MB"))
    }

    func testCrashlyticsKeys_exposeScalarsOnly() {
        var diagnostics = RecoveryDiagnostics.empty
        diagnostics.coreDataRowCount = 0
        diagnostics.orphanCount = 5
        diagnostics.store = .init(exists: true, sizeBytes: 10, quarantinedFileNames: ["a", "b"])

        let keys = diagnostics.crashlyticsKeys()

        XCTAssertEqual(keys["recovery_core_data_rows"] as? Int, 0)
        XCTAssertEqual(keys["recovery_orphan_count"] as? Int, 5)
        XCTAssertEqual(keys["recovery_quarantined_count"] as? Int, 2)
        XCTAssertEqual(keys["recovery_quarantined_first"] as? String, "a")
        // 未取得は -1 で表現する（Crashlytics は nil を持てない）
        XCTAssertEqual(keys["recovery_icloud_records"] as? Int, -1)
    }
}
