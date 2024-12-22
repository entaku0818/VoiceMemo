//
//  File.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/20.
//

import Foundation
// MARK: - Playlist Model
struct Playlist: Identifiable {
    let id: UUID
    var name: String
    var voices: [VoiceMemoRepository.Voice]
    let createdAt: Date
    var updatedAt: Date
}

// MARK: - Protocol
protocol PlaylistCoredataAccessorProtocol {
    func createPlaylist(name: String) -> UUID
    func addVoiceToPlaylist(playlistId: UUID, voice: VoiceMemoRepository.Voice)
    func removeVoiceFromPlaylist(playlistId: UUID, voiceId: UUID)
    func deletePlaylist(id: UUID)
    func getAllPlaylists() -> [Playlist]
    func getPlaylist(id: UUID) -> Playlist?
    func updatePlaylistName(id: UUID, newName: String)
}

class PlaylistCoredataAccessor: NSObject, PlaylistCoredataAccessorProtocol {

    let container: NSPersistentContainer
    var managedContext: NSManagedObjectContext
    var entity: NSEntityDescription?

    var entityName: String = "Playlist"

    override init() {
        container = NSPersistentContainer(name: "Voice") // 既存のコンテナを使用
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        self.managedContext = container.viewContext
        if let localEntity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext) {
            self.entity = localEntity
        }
    }

    func createPlaylist(name: String) -> UUID {
        let playlistId = UUID()
        if let playlistEntity = NSManagedObject(entity: self.entity!, insertInto: managedContext) as? PlaylistEntity {
            playlistEntity.id = playlistId
            playlistEntity.name = name
            playlistEntity.createdAt = Date()
            playlistEntity.updatedAt = Date()

            do {
                try managedContext.save()
            } catch {
                print(error.localizedDescription)
            }
        }
        return playlistId
    }

    func addVoiceToPlaylist(playlistId: UUID, voice: VoiceMemoRepository.Voice) {
        let fetchRequest: NSFetchRequest<PlaylistEntity> = PlaylistEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", playlistId as CVarArg)

        do {
            if let playlist = try managedContext.fetch(fetchRequest).first {
                let voiceRef = VoiceReference(context: managedContext)
                voiceRef.voiceId = voice.id
                voiceRef.addedAt = Date()
                voiceRef.playlist = playlist

                try managedContext.save()
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    func removeVoiceFromPlaylist(playlistId: UUID, voiceId: UUID) {
        let fetchRequest: NSFetchRequest<VoiceReference> = VoiceReference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "playlist.id == %@ AND voiceId == %@",
                                           playlistId as CVarArg,
                                           voiceId as CVarArg)

        do {
            let results = try managedContext.fetch(fetchRequest)
            for voiceRef in results {
                managedContext.delete(voiceRef)
            }
            try managedContext.save()
        } catch {
            print(error.localizedDescription)
        }
    }

    func deletePlaylist(id: UUID) {
        let fetchRequest: NSFetchRequest<PlaylistEntity> = PlaylistEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let results = try managedContext.fetch(fetchRequest)
            for playlist in results {
                managedContext.delete(playlist)
            }
            try managedContext.save()
        } catch {
            print(error.localizedDescription)
        }
    }

    func getAllPlaylists() -> [Playlist] {
        var playlists: [PlaylistEntity] = []
        let fetchRequest: NSFetchRequest<PlaylistEntity> = PlaylistEntity.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            playlists = try managedContext.fetch(fetchRequest)
        } catch {
            print(error.localizedDescription)
        }

        return playlists.compactMap { playlistEntity in
            guard let id = playlistEntity.id else { return nil }

            // Get associated voices
            let voices = getVoicesForPlaylist(playlistId: id)

            return Playlist(
                id: id,
                name: playlistEntity.name ?? "",
                voices: voices,
                createdAt: playlistEntity.createdAt ?? Date(),
                updatedAt: playlistEntity.updatedAt ?? Date()
            )
        }
    }

    func getPlaylist(id: UUID) -> Playlist? {
        let fetchRequest: NSFetchRequest<PlaylistEntity> = PlaylistEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            if let playlistEntity = try managedContext.fetch(fetchRequest).first {
                let voices = getVoicesForPlaylist(playlistId: id)

                return Playlist(
                    id: id,
                    name: playlistEntity.name ?? "",
                    voices: voices,
                    createdAt: playlistEntity.createdAt ?? Date(),
                    updatedAt: playlistEntity.updatedAt ?? Date()
                )
            }
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }

    private func getVoicesForPlaylist(playlistId: UUID) -> [VoiceMemoRepository.Voice] {
        let fetchRequest: NSFetchRequest<VoiceReference> = VoiceReference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "playlist.id == %@", playlistId as CVarArg)
        let sortDescriptor = NSSortDescriptor(key: "addedAt", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            let voiceRefs = try managedContext.fetch(fetchRequest)
            let voiceAccessor = VoiceMemoCoredataAccessor()

            return voiceRefs.compactMap { voiceRef in
                guard let voiceId = voiceRef.voiceId else { return nil }
                return voiceAccessor.fetch(uuid: voiceId)
            }
        } catch {
            print(error.localizedDescription)
        }
        return []
    }

    func updatePlaylistName(id: UUID, newName: String) {
        let fetchRequest: NSFetchRequest<PlaylistEntity> = PlaylistEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            if let playlist = try managedContext.fetch(fetchRequest).first {
                playlist.name = newName
                playlist.updatedAt = Date()
                try managedContext.save()
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}
