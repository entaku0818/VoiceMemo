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
}
