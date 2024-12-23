import XCTest
import CoreData
@testable import VoiLog

final class PlaylistRepositoryTests: XCTestCase {
    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext!
    private var repository: CoreDataPlaylistRepository!

    override func setUp() async throws {
        try await super.setUp()

        // In-memory storeの設定
        let mom = NSManagedObjectModel.mergedModel(from: [Bundle(for: type(of: self))])!
        container = NSPersistentContainer(name: "VoiLog", managedObjectModel: mom)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        await container.loadPersistentStores { description, error in
            XCTAssertNil(error)
        }

        context = container.viewContext
        repository = CoreDataPlaylistRepository(context: context)
    }

    override func tearDown() async throws {
        try await super.tearDown()
        container = nil
        context = nil
        repository = nil
    }

    // MARK: - Create Tests

    func test_create_playlist_success() async throws {
        let name = "テストプレイリスト"
        let playlist = try await repository.create(name: name)

        XCTAssertEqual(playlist.name, name)
        XCTAssertNotNil(playlist.id)
        XCTAssertNotNil(playlist.createdAt)
        XCTAssertNotNil(playlist.updatedAt)
    }

    // MARK: - Read Tests

    func test_fetchAll_returns_empty_array_when_no_playlists() async throws {
        let playlists = try await repository.fetchAll()
        XCTAssertTrue(playlists.isEmpty)
    }

    func test_fetchAll_returns_all_playlists() async throws {
        // 準備
        let playlist1 = try await repository.create(name: "プレイリスト1")
        let playlist2 = try await repository.create(name: "プレイリスト2")

        // 実行
        let playlists = try await repository.fetchAll()

        // 検証
        XCTAssertEqual(playlists.count, 2)
        XCTAssertTrue(playlists.contains { $0.id == playlist1.id })
        XCTAssertTrue(playlists.contains { $0.id == playlist2.id })
    }

    func test_fetch_by_id_returns_playlist() async throws {
        // 準備
        let created = try await repository.create(name: "テスト")

        // 実行
        let fetched = try await repository.fetch(by: created.id)

        // 検証
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, created.id)
        XCTAssertEqual(fetched?.name, created.name)
    }

    // MARK: - Update Tests

    func test_update_playlist_name() async throws {
        // 準備
        let playlist = try await repository.create(name: "古い名前")
        let newName = "新しい名前"

        // 実行
        let updated = try await repository.update(playlist, name: newName)

        // 検証
        XCTAssertEqual(updated.name, newName)

        // データベースの永続化を確認
        let fetched = try await repository.fetch(by: playlist.id)
        XCTAssertEqual(fetched?.name, newName)
    }

    // MARK: - Delete Tests

    func test_delete_playlist() async throws {
        // 準備
        let playlist = try await repository.create(name: "削除対象")

        // 実行
        try await repository.delete(playlist)

        // 検証
        let fetched = try await repository.fetch(by: playlist.id)
        XCTAssertNil(fetched)
    }


    // MARK: - Voice Management Tests


    func test_addVoice_throws_error_for_nonexistent_voice() async throws {
        // 準備
        let playlist = try await repository.create(name: "テスト")
        let nonexistentVoiceId = UUID()

        // 実行と検証
        do {
            _ = try await repository.addVoice(voiceId: nonexistentVoiceId, to: playlist)
            XCTFail("存在しない音声を追加できてはいけない")
        } catch PlaylistRepositoryError.voiceNotFound {
            // 期待される動作
        } catch {
            XCTFail("予期しないエラー: \(error)")
        }
    }


}
