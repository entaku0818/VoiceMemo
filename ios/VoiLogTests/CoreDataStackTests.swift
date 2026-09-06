import XCTest
import CoreData
@testable import VoiLog

final class CoreDataStackTests: XCTestCase {

    // MARK: - saveIfStoreLoaded: stores 未ロード時

    func testSaveIfStoreLoaded_throwsStoreNotLoaded_whenNoPersistentStore() {
        // stores を一切ロードしていない container の viewContext で呼ぶと storeNotLoaded が投げられる
        let container = NSPersistentContainer(name: "Voice")
        // loadPersistentStores を呼ばない → persistentStores は空
        let context = container.viewContext

        XCTAssertThrowsError(try context.saveIfStoreLoaded()) { error in
            XCTAssertEqual(error as? CoreDataError, .storeNotLoaded,
                           "stores 未ロード時は CoreDataError.storeNotLoaded を throw すること")
        }
    }

    // MARK: - saveIfStoreLoaded: stores ロード済み時

    func testSaveIfStoreLoaded_doesNotThrow_whenInMemoryStoreLoaded() {
        let container = NSPersistentContainer(name: "Voice")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        let exp = expectation(description: "in-memory store loaded")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error, "in-memory store のロードは成功すること")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertNoThrow(try container.viewContext.saveIfStoreLoaded(),
                         "stores ロード済みの場合は throw しないこと")
    }

    // MARK: - CoreDataError: Equatable の確認

    func testCoreDataError_storeNotLoaded_isEquatable() {
        XCTAssertEqual(CoreDataError.storeNotLoaded, CoreDataError.storeNotLoaded)
    }

    // MARK: - ストア退避（「録音が全部消えた」報告の再発防止）
    //
    // 旧実装は loadPersistentStores のエラー種別を見ずに Voice.sqlite を削除しており、
    // SQLITE_AUTH(23) のような一時的なエラーでも全録音のメタデータが恒久的に失われていた。
    // 退避（リネーム）に置き換わっていること、二度と削除されないことを担保する。

    private func makeTempDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CoreDataStackTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @MainActor
    func testQuarantineStoreFiles_movesStoreInsteadOfDeletingIt() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Voice.sqlite")
        try Data("sqlite-payload".utf8).write(to: storeURL)

        let moved = try CoreDataStack.quarantineStoreFiles(storeURL: storeURL)

        XCTAssertEqual(moved.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path),
                       "元の位置からは退避されること")
        XCTAssertEqual(try Data(contentsOf: moved[0]), Data("sqlite-payload".utf8),
                       "ストアは削除ではなく中身を保ったままリネームされること")
    }

    @MainActor
    func testQuarantineStoreFiles_movesShmAndWalSidecars() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Voice.sqlite")
        // 実ファイル名はハイフン区切り。旧実装は "Voice.sqlite.wal" を消そうとして常に空振りしていた。
        try Data("main".utf8).write(to: storeURL)
        try Data("shm".utf8).write(to: directory.appendingPathComponent("Voice.sqlite-shm"))
        try Data("wal".utf8).write(to: directory.appendingPathComponent("Voice.sqlite-wal"))

        let moved = try CoreDataStack.quarantineStoreFiles(storeURL: storeURL)

        XCTAssertEqual(moved.count, 3, "-shm / -wal の sidecar も退避すること")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("Voice.sqlite-wal").path
        ), "ハイフン区切りの WAL を正しく扱うこと")
    }

    @MainActor
    func testQuarantineStoreFiles_toleratesMissingSidecars() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Voice.sqlite")
        try Data("main".utf8).write(to: storeURL)

        let moved = try CoreDataStack.quarantineStoreFiles(storeURL: storeURL)

        XCTAssertEqual(moved.count, 1, "sidecar が無くてもエラーにならないこと")
    }

    @MainActor
    func testQuarantineStoreFiles_doesNotOverwriteEarlierQuarantine() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Voice.sqlite")
        let timestamp = Date(timeIntervalSince1970: 1_756_910_460)

        try Data("first-failure".utf8).write(to: storeURL)
        let first = try CoreDataStack.quarantineStoreFiles(storeURL: storeURL, timestamp: timestamp)

        // 同一秒に2回目の失敗が起きても、1回目の退避データを壊さないこと
        try Data("second-failure".utf8).write(to: storeURL)
        let second = try CoreDataStack.quarantineStoreFiles(storeURL: storeURL, timestamp: timestamp)

        XCTAssertNotEqual(first[0], second[0])
        XCTAssertEqual(try Data(contentsOf: first[0]), Data("first-failure".utf8),
                       "先に退避したデータが上書きされないこと")
    }

    @MainActor
    func testQuarantinedStoreFiles_listsQuarantinedStores() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Voice.sqlite")
        try Data("payload".utf8).write(to: storeURL)
        try CoreDataStack.quarantineStoreFiles(storeURL: storeURL)

        let quarantined = CoreDataStack.quarantinedStoreFiles(storeURL: storeURL)

        XCTAssertEqual(quarantined.count, 1, "退避済みストアを一覧できること")
        XCTAssertTrue(quarantined[0].lastPathComponent.contains(".corrupt-"))
    }

    @MainActor
    func testQuarantinedStoreFiles_returnsEmptyWhenNothingQuarantined() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Voice.sqlite")
        try Data("payload".utf8).write(to: storeURL)

        XCTAssertTrue(CoreDataStack.quarantinedStoreFiles(storeURL: storeURL).isEmpty)
    }

    // MARK: - 失敗の記録（診断情報用）

    private func makeDefaults() throws -> UserDefaults {
        let name = "CoreDataStackTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return defaults
    }

    @MainActor
    func testLastStoreFailure_isNilBeforeAnyFailure() throws {
        let defaults = try makeDefaults()

        XCTAssertNil(CoreDataStack.lastStoreFailure(defaults: defaults))
    }

    @MainActor
    func testPersistStoreFailure_recordsDomainCodeAndPhase() throws {
        let defaults = try makeDefaults()
        let error = NSError(
            domain: "NSCocoaErrorDomain",
            code: 256,
            userInfo: ["NSSQLiteErrorDomain": 23]
        )

        CoreDataStack.persistStoreFailure(
            error,
            phase: "load",
            timestamp: Date(timeIntervalSince1970: 0),
            defaults: defaults
        )

        let recorded = try XCTUnwrap(CoreDataStack.lastStoreFailure(defaults: defaults))
        XCTAssertTrue(recorded.contains("NSCocoaErrorDomain(256)"))
        XCTAssertTrue(recorded.contains("sqlite=23"), "SQLITE_AUTH(23) 判別のため下位コードを残すこと")
        XCTAssertTrue(recorded.contains("phase=load"))
        XCTAssertTrue(recorded.contains("1970-01-01T00:00:00Z"))
    }

    @MainActor
    func testPersistStoreFailure_omitsSqliteCodeWhenAbsent() throws {
        let defaults = try makeDefaults()
        let error = NSError(domain: "NSCocoaErrorDomain", code: 134_030, userInfo: [:])

        CoreDataStack.persistStoreFailure(error, phase: "retry", defaults: defaults)

        let recorded = try XCTUnwrap(CoreDataStack.lastStoreFailure(defaults: defaults))
        XCTAssertFalse(recorded.contains("sqlite="))
        XCTAssertTrue(recorded.contains("phase=retry"))
    }

    @MainActor
    func testPersistStoreFailure_keepsOnlyTheMostRecentFailure() throws {
        let defaults = try makeDefaults()

        CoreDataStack.persistStoreFailure(
            NSError(domain: "First", code: 1), phase: "load", defaults: defaults
        )
        CoreDataStack.persistStoreFailure(
            NSError(domain: "Second", code: 2), phase: "load", defaults: defaults
        )

        let recorded = try XCTUnwrap(CoreDataStack.lastStoreFailure(defaults: defaults))
        XCTAssertTrue(recorded.contains("Second"))
        XCTAssertFalse(recorded.contains("First"))
    }
}
