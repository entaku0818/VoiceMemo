//
//  File.swift
//  VoiceMemo
//
//  Created by 遠藤拓弥 on 24.9.2022.
//

import Foundation
import CoreData

class PlaylistRepository: NSObject {

    static let shared = VoiceMemoRepository()

    let container: NSPersistentContainer
    var managedContext: NSManagedObjectContext
    var entity: NSEntityDescription?

    var entityName: String = "Playlist"

    override init() {

        container = NSPersistentContainer(name: entityName)
        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
                Logger.shared.logError(entityName + error.localizedDescription)
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true

        self.managedContext = container.viewContext
        if let localEntity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext) {
            self.entity = localEntity
        }
    }

    func insert(name:String) {
        if let playlist = NSManagedObject(entity: self.entity!, insertInto: managedContext) as? Playlist {

            playlist.id = UUID()
            playlist.name = name



            do {
                try managedContext.save()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }

    func insert(playlistId: UUID, voiceId: UUID) {
        if let playlistVoice = NSEntityDescription.insertNewObject(forEntityName: "PlaylistVoice", into: managedContext) as? PlaylistVoice {
            playlistVoice.playlistId = playlistId
            playlistVoice.voiceId = voiceId

            do {
                try managedContext.save()
            } catch {
                print("Error inserting PlaylistVoice: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchAllPlaylistVoices() -> [PlaylistVoice]? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PlaylistVoice")

        do {
            let results = try managedContext.fetch(fetchRequest) as? [PlaylistVoice]
            return results
        } catch {
            print("Error fetching PlaylistVoices: \(error.localizedDescription)")
            return nil
        }
    }
}
