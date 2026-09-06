import XCTest
@testable import VoiLog

/// 「録音が全部消えた」報告 (v1.6.0 / v1.12.2) の救済処理のテスト。
/// Core Data のストアが失われても Documents 配下の音声ファイルは残るため、
/// それを走査して一覧へ復帰できることを担保する。
final class RecordingRecoveryServiceTests: XCTestCase {

    var testDirectory: URL!
    var subDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("RecordingRecoveryTests_\(UUID().uuidString)")
        subDirectory = testDirectory.appendingPathComponent("VoiceMemos", isDirectory: true)
        try FileManager.default.createDirectory(at: subDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: testDirectory)
        testDirectory = nil
        subDirectory = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    @discardableResult
    private func makeAudioFile(
        named name: String,
        in directory: URL,
        byteCount: Int = 4096,
        creationDate: Date? = nil
    ) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(repeating: 0xAA, count: byteCount).write(to: url)
        if let creationDate {
            try FileManager.default.setAttributes(
                [.creationDate: creationDate], ofItemAtPath: url.path
            )
        }
        return url
    }

    // MARK: - 孤児ファイルの検出

    func testFindOrphanedRecordings_findsFilesWithNoCoreDataRow() throws {
        let orphanID = UUID()
        try makeAudioFile(named: "\(orphanID.uuidString).m4a", in: testDirectory)

        let found = RecordingRecoveryService.findOrphanedRecordings(
            in: [testDirectory], knownIDs: []
        )

        XCTAssertEqual(found.count, 1, "Core Data に行が無い音声ファイルは復元候補になること")
        XCTAssertEqual(found.first?.id, orphanID, "ファイル名の UUID がそのまま録音 ID になること")
    }

    func testFindOrphanedRecordings_skipsRecordingsAlreadyInCoreData() throws {
        let knownID = UUID()
        let orphanID = UUID()
        try makeAudioFile(named: "\(knownID.uuidString).m4a", in: testDirectory)
        try makeAudioFile(named: "\(orphanID.uuidString).m4a", in: testDirectory)

        let found = RecordingRecoveryService.findOrphanedRecordings(
            in: [testDirectory], knownIDs: [knownID]
        )

        XCTAssertEqual(found.map(\.id), [orphanID], "登録済みの録音は復元候補に含めないこと")
    }

    func testFindOrphanedRecordings_searchesBothDocumentsAndVoiceMemosDirectory() throws {
        let inDocuments = UUID()
        let inSubDirectory = UUID()
        try makeAudioFile(named: "\(inDocuments.uuidString).m4a", in: testDirectory)
        try makeAudioFile(named: "\(inSubDirectory.uuidString).m4a", in: subDirectory)

        let found = RecordingRecoveryService.findOrphanedRecordings(
            in: [testDirectory, subDirectory], knownIDs: []
        )

        XCTAssertEqual(
            Set(found.map(\.id)), [inDocuments, inSubDirectory],
            "Documents 直下と VoiceMemos 配下の両方を走査すること"
        )
    }

    func testFindOrphanedRecordings_deduplicatesSameFileFoundInMultipleDirectories() throws {
        let id = UUID()
        try makeAudioFile(named: "\(id.uuidString).m4a", in: testDirectory)
        try makeAudioFile(named: "\(id.uuidString).m4a", in: subDirectory)

        let found = RecordingRecoveryService.findOrphanedRecordings(
            in: [testDirectory, subDirectory], knownIDs: []
        )

        XCTAssertEqual(found.count, 1, "同一 ID のファイルが複数箇所にあっても1件にまとめること")
    }

    func testFindOrphanedRecordings_supportsWavFiles() throws {
        let id = UUID()
        try makeAudioFile(named: "\(id.uuidString).wav", in: testDirectory)

        let found = RecordingRecoveryService.findOrphanedRecordings(
            in: [testDirectory], knownIDs: []
        )

        XCTAssertEqual(found.count, 1, "wav 録音も復元対象にすること")
    }

    func testFindOrphanedRecordings_ignoresNonAudioFiles() throws {
        try makeAudioFile(named: "Voice.sqlite", in: testDirectory)
        try makeAudioFile(named: "notes.txt", in: testDirectory)
        try makeAudioFile(named: "Voice.sqlite.corrupt-20260903-144100", in: testDirectory)

        let found = RecordingRecoveryService.findOrphanedRecordings(
            in: [testDirectory], knownIDs: []
        )

        XCTAssertTrue(found.isEmpty, "音声以外のファイルは復元対象にしないこと")
    }

    func testFindOrphanedRecordings_ignoresTooSmallFiles() throws {
        let id = UUID()
        try makeAudioFile(named: "\(id.uuidString).m4a", in: testDirectory, byteCount: 10)

        let found = RecordingRecoveryService.findOrphanedRecordings(
            in: [testDirectory], knownIDs: []
        )

        XCTAssertTrue(found.isEmpty, "書きかけ・空の録音ファイルは復元対象にしないこと")
    }

    func testFindOrphanedRecordings_ignoresMissingDirectory() {
        let missing = testDirectory.appendingPathComponent("DoesNotExist")

        let found = RecordingRecoveryService.findOrphanedRecordings(
            in: [missing], knownIDs: []
        )

        XCTAssertTrue(found.isEmpty, "存在しないディレクトリを渡してもクラッシュしないこと")
    }

    func testFindOrphanedRecordings_sortsByCreationDateAscending() throws {
        let older = Date(timeIntervalSince1970: 1_000_000)
        let newer = Date(timeIntervalSince1970: 2_000_000)
        let olderID = UUID()
        let newerID = UUID()
        try makeAudioFile(named: "\(newerID.uuidString).m4a", in: testDirectory, creationDate: newer)
        try makeAudioFile(named: "\(olderID.uuidString).m4a", in: testDirectory, creationDate: older)

        let found = RecordingRecoveryService.findOrphanedRecordings(
            in: [testDirectory], knownIDs: []
        )

        XCTAssertEqual(found.map(\.id), [olderID, newerID], "録音日時の昇順で返すこと")
    }

    func testFindOrphanedRecordings_capturesCreationDateAndFileSize() throws {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let id = UUID()
        try makeAudioFile(
            named: "\(id.uuidString).m4a", in: testDirectory, byteCount: 8192, creationDate: created
        )

        let found = RecordingRecoveryService.findOrphanedRecordings(
            in: [testDirectory], knownIDs: []
        )

        let recovered = try XCTUnwrap(found.first)
        XCTAssertEqual(recovered.createdAt.timeIntervalSince1970, created.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(recovered.fileSize, 8192, "録音日時とファイルサイズを取得すること")
    }

    // MARK: - ID の決定性（復元を繰り返しても重複しない）

    func testRecordingID_parsesUUIDFileName() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/\(id.uuidString).m4a")

        XCTAssertEqual(RecordingRecoveryService.recordingID(for: url), id)
    }

    func testRecordingID_isStableForNonUUIDFileName() {
        let url = URL(fileURLWithPath: "/tmp/interview-2026.m4a")

        let first = RecordingRecoveryService.recordingID(for: url)
        let second = RecordingRecoveryService.recordingID(for: url)

        XCTAssertEqual(first, second, "UUID でないファイル名でも毎回同じ ID になること")
    }

    func testRecordingID_differsBetweenDifferentFileNames() {
        let one = RecordingRecoveryService.recordingID(for: URL(fileURLWithPath: "/tmp/a.m4a"))
        let two = RecordingRecoveryService.recordingID(for: URL(fileURLWithPath: "/tmp/b.m4a"))

        XCTAssertNotEqual(one, two)
    }

    func testFindOrphanedRecordings_secondRunFindsNothingAfterRestore() throws {
        try makeAudioFile(named: "interview.m4a", in: testDirectory)

        let firstRun = RecordingRecoveryService.findOrphanedRecordings(
            in: [testDirectory], knownIDs: []
        )
        XCTAssertEqual(firstRun.count, 1)

        // 1回目で復元された ID が Core Data に入った状態を再現
        let restoredIDs = Set(firstRun.map(\.id))
        let secondRun = RecordingRecoveryService.findOrphanedRecordings(
            in: [testDirectory], knownIDs: restoredIDs
        )

        XCTAssertTrue(secondRun.isEmpty, "復元を2回実行しても重複登録されないこと")
    }

    // MARK: - タイトル

    func testRecoveredTitle_usesRecordingDate() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let title = RecordingRecoveryService.recoveredTitle(
            for: date, locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertFalse(title.isEmpty, "復元した録音には日時ベースのタイトルを付けること")
    }

    // MARK: - 対象ファイルの判定

    func testLooksLikeRecording_acceptsSupportedExtensions() {
        XCTAssertTrue(RecordingRecoveryService.looksLikeRecording(URL(fileURLWithPath: "/tmp/a.m4a")))
        XCTAssertTrue(RecordingRecoveryService.looksLikeRecording(URL(fileURLWithPath: "/tmp/a.WAV")))
    }

    func testLooksLikeRecording_acceptsExtensionlessUUIDFromCloudDownload() {
        // CloudUploader.downloadVoiceFile は拡張子なしの <UUID> で保存する。
        // これを弾くと、iCloud から戻した録音が次の消失時に復元できなくなる
        let url = URL(fileURLWithPath: "/tmp/\(UUID().uuidString)")

        XCTAssertTrue(RecordingRecoveryService.looksLikeRecording(url))
    }

    func testLooksLikeRecording_rejectsExtensionlessNonUUID() {
        // Documents 直下には無関係のファイルもあるため UUID 以外は拾わない
        XCTAssertFalse(RecordingRecoveryService.looksLikeRecording(URL(fileURLWithPath: "/tmp/README")))
    }

    func testLooksLikeRecording_rejectsOtherExtensions() {
        XCTAssertFalse(RecordingRecoveryService.looksLikeRecording(URL(fileURLWithPath: "/tmp/Voice.sqlite")))
        XCTAssertFalse(RecordingRecoveryService.looksLikeRecording(URL(fileURLWithPath: "/tmp/a.txt")))
    }

    func testFindOrphanedRecordings_findsExtensionlessCloudRestoredFile() throws {
        let id = UUID()
        let url = subDirectory.appendingPathComponent(id.uuidString)
        try Data(repeating: 0, count: 2048).write(to: url)

        let orphans = RecordingRecoveryService.findOrphanedRecordings(
            in: [subDirectory], knownIDs: []
        )

        XCTAssertEqual(orphans.count, 1)
        XCTAssertEqual(orphans.first?.id, id)
    }
}
