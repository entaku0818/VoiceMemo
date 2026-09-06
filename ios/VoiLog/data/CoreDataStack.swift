//
//  CoreDataStack.swift
//  VoiLog
//
//  Created by Claude on 2025/01/14.
//

import Foundation
import CoreData
import FirebaseCore
import FirebaseCrashlytics

/// Shared Core Data stack to ensure thread safety and prevent multiple container instances.
/// All Core Data operations should use this singleton to avoid crashes from concurrent access.
@MainActor
final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer
    let viewContext: NSManagedObjectContext

    private init() {
        container = NSPersistentContainer(name: "Voice")
        container.loadPersistentStores { storeDescription, loadError in
            guard let loadError = loadError as NSError? else { return }
            // ストアが開けなかった場合、以前はファイルを削除していたが、
            // SQLITE_AUTH(23) のような「一時的に読めないだけ」のエラーでも
            // 全録音のメタデータが恒久的に失われていた。削除はせず退避する。
            // 実体の音声ファイルは Documents 配下に残るため、
            // RecordingRecoveryService で一覧へ復帰できる。
            if let storeURL = storeDescription.url {
                let moved = (try? Self.quarantineStoreFiles(storeURL: storeURL)) ?? []
                AppLogger.data.error(
                    "Persistent store unavailable (code \(loadError.code)), quarantined \(moved.count) file(s)"
                )
            }
            Self.reportStoreFailure(loadError, phase: "load")
        }
        // Retry after quarantining the unreadable store
        if container.persistentStoreCoordinator.persistentStores.isEmpty {
            container.loadPersistentStores { _, retryError in
                if let retryError = retryError as NSError? {
                    // Log but do not crash — app will degrade gracefully
                    AppLogger.data.error("Persistent store unavailable after retry: \(retryError)")
                    Self.reportStoreFailure(retryError, phase: "retry")
                }
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        viewContext = container.viewContext
    }

    /// Entity description for Voice entity
    var voiceEntity: NSEntityDescription? {
        NSEntityDescription.entity(forEntityName: "Voice", in: viewContext)
    }

    // MARK: - Store quarantine

    /// SQLite ストア本体と sidecar (`-shm` / `-wal`) を退避先にリネームする。
    ///
    /// 旧実装は `appendingPathExtension("wal")` で `Voice.sqlite.wal` を消そうとしていたが、
    /// 実ファイル名は `Voice.sqlite-wal`（ハイフン）なので常に空振りしていた。
    /// ここではハイフン付きの正しい名前を扱う。
    ///
    /// - Returns: 実際に退避したファイルの退避後 URL
    @discardableResult
    static func quarantineStoreFiles(
        storeURL: URL,
        timestamp: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> [URL] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let suffix = ".corrupt-" + formatter.string(from: timestamp)

        var movedURLs: [URL] = []
        for sidecar in ["", "-shm", "-wal"] {
            let source = URL(fileURLWithPath: storeURL.path + sidecar)
            guard fileManager.fileExists(atPath: source.path) else { continue }

            var destination = URL(fileURLWithPath: source.path + suffix)
            // 同一秒に複数回失敗しても上書きしない（退避したデータを消さない）
            var attempt = 1
            while fileManager.fileExists(atPath: destination.path) {
                destination = URL(fileURLWithPath: source.path + suffix + "-\(attempt)")
                attempt += 1
            }

            try fileManager.moveItem(at: source, to: destination)
            movedURLs.append(destination)
        }
        return movedURLs
    }

    /// 退避済みストアファイルを列挙する（サポート調査・復元検討用）
    static func quarantinedStoreFiles(
        storeURL: URL,
        fileManager: FileManager = .default
    ) -> [URL] {
        let directory = storeURL.deletingLastPathComponent()
        let prefix = storeURL.lastPathComponent
        let contents = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        return contents
            .filter { $0.hasPrefix(prefix) && $0.contains(".corrupt-") }
            .sorted()
            .map { directory.appendingPathComponent($0) }
    }

    /// ストア読み込み失敗を Crashlytics の非致命ログとして記録する。
    /// 旧実装ではこの経路が完全に無記録だったため、全消失が起きても検知できなかった。
    private static func reportStoreFailure(_ error: NSError, phase: String) {
        guard FirebaseApp.app() != nil else { return }
        let reported = NSError(
            domain: "CoreDataStoreLoadFailure",
            code: error.code,
            userInfo: [
                NSLocalizedDescriptionKey: error.localizedDescription,
                "phase": phase,
                "underlyingDomain": error.domain,
                "sqliteError": (error.userInfo["NSSQLiteErrorDomain"] as? Int).map(String.init) ?? "none"
            ]
        )
        Crashlytics.crashlytics().record(error: reported)
    }
}

enum CoreDataError: Error, Equatable {
    case storeNotLoaded
}

extension NSManagedObjectContext {
    /// persistent stores が未ロードの場合は ObjC 例外ではなく Swift Error を投げる。
    /// stores 未ロード時の save() は Swift do/catch で捕捉不可な FATAL クラッシュになるため必ずこちらを使う。
    func saveIfStoreLoaded() throws {
        guard let coordinator = persistentStoreCoordinator,
              !coordinator.persistentStores.isEmpty else {
            throw CoreDataError.storeNotLoaded
        }
        try save()
    }
}
