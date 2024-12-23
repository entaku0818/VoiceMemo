//
//  File.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/20.
//

import Foundation
import CoreData
// MARK: - Repository Protocol
protocol PlaylistRepository {
    func create(name: String) async throws -> Playlist
    func fetchAll() async throws -> [Playlist]
    func fetch(by id: UUID) async throws -> Playlist?
    func update(_ playlist: Playlist, name: String) async throws -> Playlist
    func delete(_ playlist: Playlist) async throws
    func deleteAll() async throws
}

// MARK: - Repository Error
enum PlaylistRepositoryError: LocalizedError {
    case notFound
    case failedToSave
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "指定されたプレイリストが見つかりませんでした"
        case .failedToSave:
            return "プレイリストの保存に失敗しました"
        case .unknown(let error):
            return "予期せぬエラーが発生しました: \(error.localizedDescription)"
        }
    }
}

// MARK: - Core Data Repository Implementation
final class CoreDataPlaylistRepository: PlaylistRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    private func convertToPlaylist(_ entity: PlaylistEntity) -> Playlist {
        Playlist(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date()
        )
    }

    // MARK: - Create
    func create(name: String) async throws -> Playlist {
        try await context.perform {
            let entity = PlaylistEntity(context: self.context)
            entity.id = UUID()
            entity.name = name
            entity.createdAt = Date()
            entity.updatedAt = Date()

            try self.context.save()
            return self.convertToPlaylist(entity)
        }
    }

    // MARK: - Read
    func fetchAll() async throws -> [Playlist] {
        try await context.perform {
            let request = PlaylistEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \PlaylistEntity.createdAt, ascending: false)
            ]
            let entities = try self.context.fetch(request)
            return IdentifiedArrayOf(
                uniqueElements: entities.map(self.convertToPlaylist)
            )
        }
    }

    func fetch(by id: UUID) async throws -> Playlist? {
        try await context.perform {
            let request = PlaylistEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let entity = try self.context.fetch(request).first else {
                return nil
            }
            return self.convertToPlaylist(entity)
        }
    }

    // MARK: - Update
    func update(_ playlist: Playlist, name: String) async throws -> Playlist {
        try await context.perform {
            let request = PlaylistEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", playlist.id as CVarArg)

            guard let entity = try self.context.fetch(request).first else {
                throw PlaylistRepositoryError.notFound
            }

            entity.name = name
            entity.updatedAt = Date()
            try self.context.save()

            return self.convertToPlaylist(entity)
        }
    }

    // MARK: - Delete
    func delete(_ playlist: Playlist) async throws {
        try await context.perform {
            let request = PlaylistEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", playlist.id as CVarArg)

            guard let entity = try self.context.fetch(request).first else {
                throw PlaylistRepositoryError.notFound
            }

            self.context.delete(entity)
            try self.context.save()
        }
    }

    func deleteAll() async throws {
        try await context.perform {
            let request: NSFetchRequest<NSFetchRequestResult> = PlaylistEntity.fetchRequest()
            let batchDelete = NSBatchDeleteRequest(fetchRequest: request)
            try self.context.execute(batchDelete)
            try self.context.save()
        }
    }
}
