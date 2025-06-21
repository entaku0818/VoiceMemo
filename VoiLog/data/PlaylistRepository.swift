//
//  PreviewPlaylistRepository.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/25.
//

import Foundation
import CoreData
import ComposableArchitecture

@DependencyClient
struct PlaylistRepository {
    var create: @Sendable (_ name: String) async throws -> Playlist = { _ in
        Playlist(id: UUID(), name: "", createdAt: .now, updatedAt: .now)
    }

    var fetchAll: @Sendable () async throws -> [Playlist] = {
        []
    }

    var fetch: @Sendable (_ id: UUID) async throws -> PlaylistDetail? = { _ in
        nil
    }

    var update: @Sendable (_ playlist: Playlist, _ name: String) async throws -> Playlist = { playlist, _ in
        playlist
    }

    var addVoice: @Sendable (_ voiceId: UUID, _ playlist: Playlist) async throws -> Playlist = { _, playlist in
        playlist
    }

    var removeVoice: @Sendable (_ voiceId: UUID, _ playlist: Playlist) async throws -> Playlist = { _, playlist in
        playlist
    }

    var delete: @Sendable (_ playlist: Playlist) async throws -> Void = { _ in }

    var deleteAll: @Sendable () async throws -> Void = { }
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

// MARK: - Preview/Test Value
extension PlaylistRepository: TestDependencyKey {
    static var previewValue: Self {
        Self(
            create: { name in
                Playlist(id: UUID(), name: name)
            },
            fetchAll: {
                []
            },
            fetch: { _ in nil },
            update: { playlist, name in
                Playlist(id: playlist.id, name: name)
            },
            addVoice: { _, playlist in playlist },
            removeVoice: { _, playlist in playlist },
            delete: { _ in },
            deleteAll: { }
        )
    }

    static let testValue = Self()
}

// MARK: - Live Value
extension PlaylistRepository: DependencyKey {
    static var liveValue: Self {
        let container = NSPersistentContainer(name: "Voice")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("CoreData store failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        let context = container.viewContext

        func checkVoiceExists(_ voiceId: UUID) async throws -> Bool {
            try await context.perform {
                let fetchRequest: NSFetchRequest<Voice> = Voice.fetchRequest()
                fetchRequest.fetchLimit = 1
                let predicate = NSPredicate(format: "id == %@", voiceId as CVarArg)
                fetchRequest.predicate = predicate

                let count = try context.count(for: fetchRequest)
                return count > 0
            }
        }

        return Self(
            create: { name in
                try await context.perform {
                    let entity = PlaylistEntity(context: context)
                    entity.id = UUID()
                    entity.name = name
                    entity.createdAt = Date()
                    entity.updatedAt = Date()

                    try context.save()
                    return Playlist(
                        id: entity.id!,
                        name: entity.name!,
                        createdAt: entity.createdAt!,
                        updatedAt: entity.updatedAt!
                    )
                }
            },

            fetchAll: {
                try await context.perform {
                    let request = PlaylistEntity.fetchRequest()
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \PlaylistEntity.createdAt, ascending: false)
                    ]
                    let entities = try context.fetch(request)
                    return entities.map { entity in
                        Playlist(
                            id: entity.id!,
                            name: entity.name!,
                            createdAt: entity.createdAt!,
                            updatedAt: entity.updatedAt!
                        )
                    }
                }
            },

            fetch: { id in
                try await context.perform {
                    let request = PlaylistEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    request.fetchLimit = 1

                    guard let entity = try context.fetch(request).first,
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
                        let voiceEntities = try context.fetch(voiceRequest)
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
            },

            update: { playlist, name in
                try await context.perform {
                    let request = PlaylistEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", playlist.id as CVarArg)

                    guard let entity = try context.fetch(request).first else {
                        throw PlaylistRepositoryError.notFound
                    }

                    entity.name = name
                    entity.updatedAt = Date()
                    try context.save()

                    return Playlist(
                        id: entity.id!,
                        name: entity.name!,
                        createdAt: entity.createdAt!,
                        updatedAt: entity.updatedAt!
                    )
                }
            },

            addVoice: { voiceId, playlist in
                guard try await checkVoiceExists(voiceId) else {
                    throw PlaylistRepositoryError.voiceNotFound
                }

                return try await context.perform {
                    let fetchRequest: NSFetchRequest<PlaylistEntity> = PlaylistEntity.fetchRequest()
                    fetchRequest.fetchLimit = 1
                    let predicate = NSPredicate(format: "id == %@", playlist.id as CVarArg)
                    fetchRequest.predicate = predicate

                    guard let playlistEntity = try context.fetch(fetchRequest).first else {
                        throw PlaylistRepositoryError.notFound
                    }

                    var currentVoiceIds = playlistEntity.voiceIds ?? []
                    if !currentVoiceIds.contains(voiceId) {
                        currentVoiceIds.append(voiceId)
                        playlistEntity.voiceIds = currentVoiceIds
                        playlistEntity.updatedAt = Date()
                        try context.save()
                    }

                    return Playlist(
                        id: playlistEntity.id!,
                        name: playlistEntity.name!,
                        createdAt: playlistEntity.createdAt!,
                        updatedAt: playlistEntity.updatedAt!
                    )
                }
            },

            removeVoice: { voiceId, playlist in
                guard try await checkVoiceExists(voiceId) else {
                    throw PlaylistRepositoryError.voiceNotFound
                }

                return try await context.perform {
                    let fetchRequest: NSFetchRequest<PlaylistEntity> = PlaylistEntity.fetchRequest()
                    fetchRequest.fetchLimit = 1
                    let predicate = NSPredicate(format: "id == %@", playlist.id as CVarArg)
                    fetchRequest.predicate = predicate

                    guard let playlistEntity = try context.fetch(fetchRequest).first else {
                        throw PlaylistRepositoryError.notFound
                    }

                    if var currentVoiceIds = playlistEntity.voiceIds {
                        currentVoiceIds.removeAll { $0 == voiceId }
                        playlistEntity.voiceIds = currentVoiceIds
                        playlistEntity.updatedAt = Date()
                        try context.save()
                    }

                    return Playlist(
                        id: playlistEntity.id!,
                        name: playlistEntity.name!,
                        createdAt: playlistEntity.createdAt!,
                        updatedAt: playlistEntity.updatedAt!
                    )
                }
            },

            delete: { playlist in
                try await context.perform {
                    let request = PlaylistEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", playlist.id as CVarArg)

                    guard let entity = try context.fetch(request).first else {
                        throw PlaylistRepositoryError.notFound
                    }

                    context.delete(entity)
                    try context.save()
                }
            },

            deleteAll: {
                try await context.perform {
                    let request: NSFetchRequest<NSFetchRequestResult> = PlaylistEntity.fetchRequest()
                    let batchDelete = NSBatchDeleteRequest(fetchRequest: request)
                    try context.execute(batchDelete)
                    try context.save()
                }
            }
        )
    }
}

extension DependencyValues {
    var playlistRepository: PlaylistRepository {
        get { self[PlaylistRepository.self] }
        set { self[PlaylistRepository.self] = newValue }
    }
}
