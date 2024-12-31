//
//  File.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/20.
//

import Foundation
import CoreData
import Dependencies
// MARK: - Repository Protocol
protocol PlaylistRepository {
    func create(name: String) async throws -> Playlist
    func fetchAll() async throws -> [Playlist]
    func fetch(by id: UUID) async throws -> PlaylistDetail?
    func update(_ playlist: Playlist, name: String) async throws -> Playlist
    func addVoice(voiceId: UUID, to playlist: Playlist) async throws -> Playlist
    func removeVoice(voiceId: UUID, from playlist: Playlist) async throws -> Playlist
    func delete(_ playlist: Playlist) async throws
    func deleteAll() async throws
}

// MARK: - Repository Error
enum PlaylistRepositoryError: LocalizedError {
    case notFound
    case failedToSave
    case voiceNotFound
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "指定されたプレイリストが見つかりませんでした"

        case .failedToSave:
            return "プレイリストの保存に失敗しました"

        case .voiceNotFound:
            return "指定された音声が見つかりませんでした"

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
            return entities.map(self.convertToPlaylist)
        }
    }

    private func checkVoiceExists(_ voiceId: UUID) async throws -> Bool {
        try await context.perform {
            let fetchRequest: NSFetchRequest<Voice> = Voice.fetchRequest()
            fetchRequest.fetchLimit = 1
            let predicate = NSPredicate(format: "id == %@", voiceId as CVarArg)
            fetchRequest.predicate = predicate

            let count = try self.context.count(for: fetchRequest)
            return count > 0
        }
    }

    func addVoice(voiceId: UUID, to playlist: Playlist) async throws -> Playlist {
        // まず音声の存在チェック
        guard try await checkVoiceExists(voiceId) else {
            throw PlaylistRepositoryError.voiceNotFound
        }

        return try await context.perform {
            let fetchRequest: NSFetchRequest<PlaylistEntity> = PlaylistEntity.fetchRequest()
            fetchRequest.fetchLimit = 1
            let predicate = NSPredicate(format: "id == %@", playlist.id as CVarArg)
            fetchRequest.predicate = predicate

            guard let playlistEntity = try self.context.fetch(fetchRequest).first else {
                throw PlaylistRepositoryError.notFound
            }

            var currentVoiceIds = playlistEntity.voiceIds ?? []
            if !currentVoiceIds.contains(voiceId) {
                currentVoiceIds.append(voiceId)
                playlistEntity.voiceIds = currentVoiceIds
                playlistEntity.updatedAt = Date()
                try self.context.save()
            }

            return self.convertToPlaylist(playlistEntity)
        }
    }

    func removeVoice(voiceId: UUID, from playlist: Playlist) async throws -> Playlist {
        // 音声の存在チェック
        guard try await checkVoiceExists(voiceId) else {
            throw PlaylistRepositoryError.voiceNotFound
        }

        return try await context.perform {
            let fetchRequest: NSFetchRequest<PlaylistEntity> = PlaylistEntity.fetchRequest()
            fetchRequest.fetchLimit = 1
            let predicate = NSPredicate(format: "id == %@", playlist.id as CVarArg)
            fetchRequest.predicate = predicate

            guard let playlistEntity = try self.context.fetch(fetchRequest).first else {
                throw PlaylistRepositoryError.notFound
            }

            if var currentVoiceIds = playlistEntity.voiceIds {
                currentVoiceIds.removeAll { $0 == voiceId }
                playlistEntity.voiceIds = currentVoiceIds
                playlistEntity.updatedAt = Date()
                try self.context.save()
            }

            return self.convertToPlaylist(playlistEntity)
        }
    }

    func fetch(by id: UUID) async throws -> PlaylistDetail? {
        try await context.perform {
            let request = PlaylistEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try self.context.fetch(request).first,
                  let playlistId = entity.id,
                  let name = entity.name,
                  let createdAt = entity.createdAt,
                  let updatedAt = entity.updatedAt
            else {
                return nil
            }

            // Voice情報の取得
            let voiceIds = entity.voiceIds ?? []
            let voices: [VoiceMemoRepository.Voice]
            if !voiceIds.isEmpty {
                let voiceRequest = Voice.fetchRequest()
                voiceRequest.predicate = NSPredicate(format: "id IN %@", voiceIds as CVarArg)
                let voiceEntities = try self.context.fetch(voiceRequest)
                voices = voiceEntities.compactMap { entity in
                    guard let id = entity.id,
                          let title = entity.title,
                          let text = entity.text,
                          let url = entity.url,
                          let fileFormat = entity.fileFormat,
                          let createdAt = entity.createdAt,
                          let updatedAt = entity.updatedAt
                    else {
                        return nil
                    }

                    return VoiceMemoRepository.Voice(
                        title: title,
                        url: url,
                        id: id,
                        text: text,
                        createdAt: createdAt,
                        updatedAt: updatedAt,
                        duration: entity.duration,
                        fileFormat: fileFormat,
                        samplingFrequency: entity.samplingFrequency,
                        quantizationBitDepth: entity.quantizationBitDepth,
                        numberOfChannels: entity.numberOfChannels,
                        isCloud: entity.isCloud
                    )
                }
            } else {
                voices = []
            }

            return PlaylistDetail(
                id: playlistId,
                name: name,
                voices: voices,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
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

enum PlaylistRepositoryKey: DependencyKey {
    static let liveValue: any PlaylistRepository = {
        let container = NSPersistentContainer(name: "Voice")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("CoreData store failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return CoreDataPlaylistRepository(context: container.viewContext)
    }()

    static let testValue:  any PlaylistRepository = PreviewPlaylistRepository()

    static let previewValue: any PlaylistRepository = PreviewPlaylistRepository()

}

extension DependencyValues {
    var playlistRepository: any PlaylistRepository {
        get { self[PlaylistRepositoryKey.self] }
        set { self[PlaylistRepositoryKey.self] = newValue }
    }
}
