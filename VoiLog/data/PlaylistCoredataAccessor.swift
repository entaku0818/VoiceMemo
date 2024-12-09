//
//  File.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/10.
//

import Foundation
import CoreData
protocol PlaylistCoredataAccessorProtocol {
    func insert(playlist: PlaylistRepository.Playlist)
    func selectAllData() -> [PlaylistRepository.Playlist]
    func fetch(uuid: UUID) -> PlaylistRepository.Playlist?
    func delete(id: UUID)
    func update(playlist: PlaylistRepository.Playlist)
    func addVoice(playlistId: UUID, voice: VoiceMemoRepository.Voice)
    func removeVoice(playlistId: UUID, voiceId: UUID)
}

struct PlaylistRepository {
    struct Playlist {
        var title: String
        var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var voices: [VoiceMemoRepository.Voice]
    }
}

class PlaylistCoredataAccessor: NSObject, PlaylistCoredataAccessorProtocol {
    let container: NSPersistentContainer
    var managedContext: NSManagedObjectContext
    var entity: NSEntityDescription?
    var entityName: String = "Playlist"

    override init() {
        container = NSPersistentContainer(name: entityName)
        container.loadPersistentStores { (_, error) in
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

    func insert(playlist: PlaylistRepository.Playlist) {
        if let playlistEntity = NSManagedObject(entity: self.entity!, insertInto: managedContext) as? Playlist {
            playlistEntity.title = playlist.title
            playlistEntity.id = playlist.id
            playlistEntity.createdAt = playlist.createdAt
            playlistEntity.updatedAt = playlist.updatedAt
            playlistEntity.voices = NSSet(array: playlist.voices.compactMap { voice in
                let voiceEntity = Voice(context: managedContext)
                voiceEntity.id = voice.id
                voiceEntity.title = voice.title
                voiceEntity.url = voice.url
                voiceEntity.text = voice.text
                voiceEntity.createdAt = voice.createdAt
                voiceEntity.updatedAt = voice.updatedAt
                voiceEntity.duration = voice.duration
                voiceEntity.fileFormat = voice.fileFormat
                voiceEntity.samplingFrequency = voice.samplingFrequency
                voiceEntity.quantizationBitDepth = voice.quantizationBitDepth
                voiceEntity.numberOfChannels = voice.numberOfChannels
                return voiceEntity
            })

            do {
                try managedContext.save()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }

    func selectAllData() -> [PlaylistRepository.Playlist] {
        var playlists: [Playlist] = []
        let fetchRequest: NSFetchRequest<Playlist> = Playlist.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            playlists = try managedContext.fetch(fetchRequest)
        } catch let error {
            print(error.localizedDescription)
        }

        return playlists.map { convertToPlaylist($0) }
    }

    func fetch(uuid: UUID) -> PlaylistRepository.Playlist? {
        let fetchRequest: NSFetchRequest<Playlist> = Playlist.fetchRequest()
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)

        do {
            let results = try managedContext.fetch(fetchRequest)
            if let playlistEntity = results.first {
                return convertToPlaylist(playlistEntity)
            }
        } catch let error {
            print(error.localizedDescription)
        }
        return nil
    }

    func delete(id: UUID) {
        let fetchRequest: NSFetchRequest<Playlist> = Playlist.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let results = try managedContext.fetch(fetchRequest)
            for playlist in results {
                managedContext.delete(playlist)
            }
            try managedContext.save()
        } catch let error {
            print(error.localizedDescription)
        }
    }

    func update(playlist: PlaylistRepository.Playlist) {
        let fetchRequest: NSFetchRequest<Playlist> = Playlist.fetchRequest()
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = NSPredicate(format: "id == %@", playlist.id as CVarArg)

        do {
            let results = try managedContext.fetch(fetchRequest)
            if let playlistEntity = results.first {
                playlistEntity.title = playlist.title
                playlistEntity.updatedAt = playlist.updatedAt
                playlistEntity.voices = NSSet(array: playlist.voices.compactMap { voice in
                    let voiceEntity = Voice(context: managedContext)
                    voiceEntity.id = voice.id
                    voiceEntity.title = voice.title
                    voiceEntity.url = voice.url
                    voiceEntity.text = voice.text
                    voiceEntity.createdAt = voice.createdAt
                    voiceEntity.updatedAt = voice.updatedAt
                    voiceEntity.duration = voice.duration
                    voiceEntity.fileFormat = voice.fileFormat
                    voiceEntity.samplingFrequency = voice.samplingFrequency
                    voiceEntity.quantizationBitDepth = voice.quantizationBitDepth
                    voiceEntity.numberOfChannels = voice.numberOfChannels
                    return voiceEntity
                })
                try managedContext.save()
            }
        } catch let error {
            print(error.localizedDescription)
        }
    }

    func addVoice(playlistId: UUID, voice: VoiceMemoRepository.Voice) {
        let fetchRequest: NSFetchRequest<Playlist> = Playlist.fetchRequest()
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = NSPredicate(format: "id == %@", playlistId as CVarArg)

        do {
            let results = try managedContext.fetch(fetchRequest)
            if let playlistEntity = results.first {
                let voiceEntity = Voice(context: managedContext)
                voiceEntity.id = voice.id
                voiceEntity.title = voice.title
                voiceEntity.url = voice.url
                voiceEntity.text = voice.text
                voiceEntity.createdAt = voice.createdAt
                voiceEntity.updatedAt = voice.updatedAt
                voiceEntity.duration = voice.duration
                voiceEntity.fileFormat = voice.fileFormat
                voiceEntity.samplingFrequency = voice.samplingFrequency
                voiceEntity.quantizationBitDepth = voice.quantizationBitDepth
                voiceEntity.numberOfChannels = voice.numberOfChannels

                playlistEntity.addToVoices(voiceEntity)
                playlistEntity.updatedAt = Date()
                try managedContext.save()
            }
        } catch let error {
            print(error.localizedDescription)
        }
    }

    func removeVoice(playlistId: UUID, voiceId: UUID) {
        let fetchRequest: NSFetchRequest<Playlist> = Playlist.fetchRequest()
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = NSPredicate(format: "id == %@", playlistId as CVarArg)

        do {
            let results = try managedContext.fetch(fetchRequest)
            if let playlistEntity = results.first,
               let voices = playlistEntity.voices as? Set<Voice>,
               let voiceToRemove = voices.first(where: { $0.id == voiceId }) {
                playlistEntity.removeFromVoices(voiceToRemove)
                playlistEntity.updatedAt = Date()
                try managedContext.save()
            }
        } catch let error {
            print(error.localizedDescription)
        }
    }

    private func convertToPlaylist(_ entity: Playlist) -> PlaylistRepository.Playlist {
        let voices = (entity.voices as? Set<Voice>)?.map { voiceEntity in
            VoiceMemoRepository.Voice(
                title: voiceEntity.title ?? "",
                url: voiceEntity.url!,
                id: voiceEntity.id ?? UUID(),
                text: voiceEntity.text ?? "",
                createdAt: voiceEntity.createdAt ?? Date(),
                updatedAt: voiceEntity.updatedAt ?? Date(),
                duration: voiceEntity.duration,
                fileFormat: voiceEntity.fileFormat ?? "",
                samplingFrequency: voiceEntity.samplingFrequency,
                quantizationBitDepth: voiceEntity.quantizationBitDepth,
                numberOfChannels: voiceEntity.numberOfChannels,
                isCloud: voiceEntity.isCloud
            )
        } ?? []

        return PlaylistRepository.Playlist(
            title: entity.title ?? "",
            id: entity.id ?? UUID(),
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            voices: voices
        )
    }
}
