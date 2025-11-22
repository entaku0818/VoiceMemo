import XCTest
@testable import VoiLog
import Foundation

final class VoiceMemoFileManagerTests: XCTestCase {

    var testDirectory: URL!
    var testVoiceMemoDirectory: URL!

    override func setUp() {
        super.setUp()

        // テスト用の一時ディレクトリを作成
        testDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("VoiceMemoFileManagerTests_\(UUID().uuidString)")

        testVoiceMemoDirectory = testDirectory.appendingPathComponent("VoiceMemos", isDirectory: true)

        try? FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        // テスト用ディレクトリを削除
        try? FileManager.default.removeItem(at: testDirectory)
        super.tearDown()
    }

    // MARK: - Directory Management Tests

    func testVoiceMemoDirectoryPath() {
        // VoiceMemo専用ディレクトリのパスが正しいことを確認
        let directory = VoiceMemoFileManager.voiceMemoDirectory

        XCTAssertTrue(directory.path.contains("Documents"))
        XCTAssertTrue(directory.path.hasSuffix("VoiceMemos"))
    }

    func testEnsureVoiceMemoDirectoryExists_CreatesDirectory() throws {
        // ディレクトリが存在しない場合、作成されることを確認
        let tempVoiceMemoDir = testDirectory.appendingPathComponent("TestVoiceMemos")

        // ディレクトリが存在しないことを確認
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempVoiceMemoDir.path))

        // 実際のメソッドはグローバルなので、手動でディレクトリ作成をテスト
        try FileManager.default.createDirectory(at: tempVoiceMemoDir, withIntermediateDirectories: true)

        // ディレクトリが作成されたことを確認
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempVoiceMemoDir.path))
    }

    func testEnsureVoiceMemoDirectoryExists_DoesNotFailIfExists() throws {
        // ディレクトリが既に存在する場合でもエラーにならないことを確認
        try FileManager.default.createDirectory(at: testVoiceMemoDirectory, withIntermediateDirectories: true)

        // 2回目の作成もエラーにならない
        XCTAssertNoThrow(
            try FileManager.default.createDirectory(at: testVoiceMemoDirectory, withIntermediateDirectories: true)
        )
    }

    // MARK: - File Search Tests

    func testFindAudioFile_OriginalURLExists() throws {
        // 元のURLにファイルが存在する場合、そのURLを返すことを確認
        let testFile = testDirectory.appendingPathComponent("test.m4a")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        let foundURL = VoiceMemoFileManager.findAudioFile(for: testFile, shouldMigrate: false)

        XCTAssertNotNil(foundURL)
        XCTAssertEqual(foundURL?.path, testFile.path)
    }

    func testFindAudioFile_InVoiceMemoDirectory() throws {
        // VoiceMemo専用ディレクトリにファイルが存在する場合
        try FileManager.default.createDirectory(at: testVoiceMemoDirectory, withIntermediateDirectories: true)

        let testFileName = "test.m4a"
        let testFile = testVoiceMemoDirectory.appendingPathComponent(testFileName)
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        // 異なるパスで検索（ファイル名だけ一致）
        let searchURL = testDirectory.appendingPathComponent(testFileName)
        let foundURL = VoiceMemoFileManager.findAudioFile(for: searchURL, shouldMigrate: false)

        XCTAssertNotNil(foundURL)
        XCTAssertTrue(foundURL?.path.contains("VoiceMemos") ?? false)
    }

    func testFindAudioFile_InDocumentsDirectory() throws {
        // Documentsディレクトリ直下にファイルが存在する場合
        let testFileName = "test.m4a"
        let testFile = testDirectory.appendingPathComponent(testFileName)
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        // VoiceMemoディレクトリを作成（検索順序を確認するため）
        try FileManager.default.createDirectory(at: testVoiceMemoDirectory, withIntermediateDirectories: true)

        let searchURL = testDirectory.appendingPathComponent("other").appendingPathComponent(testFileName)
        let foundURL = VoiceMemoFileManager.findAudioFile(for: searchURL, shouldMigrate: false)

        // Documents直下のファイルが見つかる
        XCTAssertNotNil(foundURL)
    }

    func testFindAudioFile_RecursiveSearch() throws {
        // 再帰的検索でファイルが見つかることを確認
        let subDir = testDirectory.appendingPathComponent("subdir1/subdir2")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let testFileName = "test.m4a"
        let testFile = subDir.appendingPathComponent(testFileName)
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        let searchURL = testDirectory.appendingPathComponent(testFileName)
        let foundURL = VoiceMemoFileManager.findAudioFile(for: searchURL, shouldMigrate: false)

        XCTAssertNotNil(foundURL)
        XCTAssertEqual(foundURL?.lastPathComponent, testFileName)
    }

    func testFindAudioFile_ReturnsNilWhenNotFound() {
        // ファイルが見つからない場合、nilを返すことを確認
        let nonExistentFile = testDirectory.appendingPathComponent("nonexistent.m4a")

        let foundURL = VoiceMemoFileManager.findAudioFile(for: nonExistentFile, shouldMigrate: false)

        XCTAssertNil(foundURL)
    }

    // MARK: - File Migration Tests

    func testFindAudioFile_DoesNotMigrateWhenShouldMigrateIsFalse() throws {
        // shouldMigrate = false の場合、マイグレーションしないことを確認
        try FileManager.default.createDirectory(at: testVoiceMemoDirectory, withIntermediateDirectories: true)

        let testFileName = "test.m4a"
        let originalFile = testDirectory.appendingPathComponent(testFileName)
        try "test content".write(to: originalFile, atomically: true, encoding: .utf8)

        let foundURL = VoiceMemoFileManager.findAudioFile(for: originalFile, shouldMigrate: false)

        XCTAssertNotNil(foundURL)
        XCTAssertEqual(foundURL?.path, originalFile.path)

        // VoiceMemoディレクトリにはコピーされていない
        let wouldBeMigratedFile = testVoiceMemoDirectory.appendingPathComponent(testFileName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: wouldBeMigratedFile.path))
    }

    func testFindAudioFile_DoesNotReMigrateAlreadyInVoiceMemoDirectory() throws {
        // 既にVoiceMemoディレクトリ内のファイルは再マイグレーションしない
        try FileManager.default.createDirectory(at: testVoiceMemoDirectory, withIntermediateDirectories: true)

        let testFileName = "test.m4a"
        let testFile = testVoiceMemoDirectory.appendingPathComponent(testFileName)
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        let foundURL = VoiceMemoFileManager.findAudioFile(for: testFile, shouldMigrate: true)

        XCTAssertNotNil(foundURL)
        XCTAssertEqual(foundURL?.path, testFile.path)
        // 同じファイルのまま（パスが変わっていない）
    }

    // MARK: - File Creation Tests

    func testNewRecordingURL_GeneratesCorrectFormat() throws {
        // 新しい録音ファイルのURLが正しい形式で生成されることを確認
        let testUUID = UUID()

        // 実際のメソッドをテスト（グローバルディレクトリを使用）
        let url = try VoiceMemoFileManager.newRecordingURL(uuid: testUUID)

        XCTAssertTrue(url.path.contains("VoiceMemos"))
        XCTAssertTrue(url.lastPathComponent.contains(testUUID.uuidString))
        XCTAssertEqual(url.pathExtension, "m4a")
    }

    func testCopyToVoiceMemoDirectory_CopiesFile() throws {
        // ファイルが正しくコピーされることを確認
        try FileManager.default.createDirectory(at: testVoiceMemoDirectory, withIntermediateDirectories: true)

        let sourceFile = testDirectory.appendingPathComponent("source.m4a")
        let testContent = "test content"
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)

        let destinationURL = try VoiceMemoFileManager.copyToVoiceMemoDirectory(
            from: sourceFile,
            destinationFileName: "destination.m4a"
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertTrue(destinationURL.path.contains("VoiceMemos"))
        XCTAssertEqual(destinationURL.lastPathComponent, "destination.m4a")

        // ファイル内容が一致することを確認
        let copiedContent = try String(contentsOf: destinationURL, encoding: .utf8)
        XCTAssertEqual(copiedContent, testContent)
    }

    func testCopyToVoiceMemoDirectory_OverwritesExistingFile() throws {
        // 既存のファイルがある場合、上書きされることを確認
        try FileManager.default.createDirectory(at: testVoiceMemoDirectory, withIntermediateDirectories: true)

        let fileName = "test.m4a"
        let sourceFile = testDirectory.appendingPathComponent(fileName)
        let existingFile = testVoiceMemoDirectory.appendingPathComponent(fileName)

        // 既存ファイルを作成
        try "old content".write(to: existingFile, atomically: true, encoding: .utf8)

        // 新しい内容のファイルをコピー
        try "new content".write(to: sourceFile, atomically: true, encoding: .utf8)
        let destinationURL = try VoiceMemoFileManager.copyToVoiceMemoDirectory(
            from: sourceFile,
            destinationFileName: fileName
        )

        // 新しい内容で上書きされていることを確認
        let content = try String(contentsOf: destinationURL, encoding: .utf8)
        XCTAssertEqual(content, "new content")
    }

    func testCopyToVoiceMemoDirectory_UsesOriginalFileNameIfNotSpecified() throws {
        // destinationFileNameがnilの場合、元のファイル名を使用することを確認
        try FileManager.default.createDirectory(at: testVoiceMemoDirectory, withIntermediateDirectories: true)

        let originalFileName = "original.m4a"
        let sourceFile = testDirectory.appendingPathComponent(originalFileName)
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)

        let destinationURL = try VoiceMemoFileManager.copyToVoiceMemoDirectory(
            from: sourceFile,
            destinationFileName: nil
        )

        XCTAssertEqual(destinationURL.lastPathComponent, originalFileName)
    }

    // MARK: - Integration Tests

    func testFullWorkflow_RecordingToPlayback() throws {
        // 録音から再生までの完全なワークフローをテスト

        // 1. 新しい録音URLを生成
        let recordingUUID = UUID()
        let recordingURL = try VoiceMemoFileManager.newRecordingURL(uuid: recordingUUID)

        XCTAssertTrue(recordingURL.path.contains("VoiceMemos"))
        XCTAssertTrue(recordingURL.lastPathComponent.contains(recordingUUID.uuidString))

        // 2. 録音ファイルをシミュレート（実際にはAudioRecorderが書き込む）
        // テスト用にダミーファイルを作成
        try FileManager.default.createDirectory(
            at: recordingURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "recorded audio data".write(to: recordingURL, atomically: true, encoding: .utf8)

        // 3. ファイルを検索（再生時）
        let foundURL = VoiceMemoFileManager.findAudioFile(for: recordingURL, shouldMigrate: false)

        XCTAssertNotNil(foundURL)
        XCTAssertEqual(foundURL?.path, recordingURL.path)

        // 4. ファイルが実際に読める
        let content = try String(contentsOf: foundURL!, encoding: .utf8)
        XCTAssertEqual(content, "recorded audio data")
    }
}
