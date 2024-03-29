//
//  File.swift
//  VoiceMemo
//
//  Created by 遠藤拓弥 on 24.9.2022.
//

import Foundation
import CoreData

class VoiceMemoRepository: NSObject {

    static let shared = VoiceMemoRepository()

    let container: NSPersistentContainer
    var managedContext: NSManagedObjectContext
    var entity: NSEntityDescription?

    var entityName: String = "Voice"

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
                Logger.shared.logError("VoiceMemoRepository:" + error.localizedDescription)
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true

        self.managedContext = container.viewContext
        if let localEntity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext) {
            self.entity = localEntity
        }
    }

    func insert(state: RecordingMemo.State) {
        if let voice = NSManagedObject(entity: self.entity!, insertInto: managedContext) as? Voice {

            voice.title = ""
            voice.url = state.url
            voice.id = state.uuid
            voice.text = state.resultText
            voice.createdAt = state.date
            voice.duration = state.duration
            voice.fileFormat = state.fileFormat
            voice.samplingFrequency = state.samplingFrequency ?? 0
            voice.quantizationBitDepth = Int16(state.quantizationBitDepth ?? 0)
            voice.numberOfChannels = Int16(state.numberOfChannels ?? 0)



            do {
                try managedContext.save()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }

    func selectAllData() -> [VoiceMemoReducer.State] {
        var memoGroups: [Voice] = []

        let fetchRequest: NSFetchRequest<Voice> = Voice.fetchRequest()

        do {
            memoGroups = try managedContext.fetch(fetchRequest)
        } catch let error {
            print(error.localizedDescription)
            Logger.shared.logError("selectAllData:" + error.localizedDescription)
        }
        let voiceMemoStates = memoGroups.map { voiceMemo in
            VoiceMemoReducer.State(
                uuid: voiceMemo.id ?? UUID(),
                date: voiceMemo.createdAt ?? Date(),
                duration: voiceMemo.duration,
                time: 0,
                title: voiceMemo.title ?? "",
                url: voiceMemo.url!,
                text: voiceMemo.text ?? "",
                fileFormat: voiceMemo.fileFormat ?? "",
                samplingFrequency: voiceMemo.samplingFrequency ,
                quantizationBitDepth: Int(voiceMemo.quantizationBitDepth ),
                numberOfChannels: Int(voiceMemo.numberOfChannels )

            )
        }
        return voiceMemoStates
    }

    func fetch(uuid: UUID) -> RecordingMemo.State? {
        var recordingMemo: RecordingMemo.State?

        let fetchRequest: NSFetchRequest<Voice> = Voice.fetchRequest()
        fetchRequest.fetchLimit = 1

        // Configure the fetch request with a predicate to match the specified UUID
        let predicate = NSPredicate(format: "uuid == %@", uuid as CVarArg)
        fetchRequest.predicate = predicate

        do {
            let results = try managedContext.fetch(fetchRequest)
            if let voice = results.first {
                // Construct your RecordingMemoState object based on the retrieved Voice object
                recordingMemo = RecordingMemo.State(
                    uuid: voice.id ?? UUID(),
                    date: voice.createdAt ?? Date(),
                    duration: voice.duration,
                    url: voice.url!,
                    resultText: voice.text ?? ""
                )
            }
        } catch let error {
            print(error.localizedDescription)
            Logger.shared.logError("fetch:" + error.localizedDescription)
        }

        return recordingMemo
    }

    func delete(id: UUID) {
        let fetchRequest: NSFetchRequest<Voice> = Voice.fetchRequest()
        // 条件指定
        fetchRequest.predicate = NSPredicate(format: "id = %@", id as CVarArg)

        do {
            let myResults = try managedContext.fetch(fetchRequest)
            for myData in myResults {
                managedContext.delete(myData)
            }

            try managedContext.save()
        } catch let error as NSError {
            print("\(error), \(error.userInfo)")
            Logger.shared.logError("delete:" + "\(error.localizedDescription), \(error.userInfo)")

        }
    }

    func update(state: VoiceMemoReducer.State) {
        let fetchRequest: NSFetchRequest<Voice> = Voice.fetchRequest()
        fetchRequest.fetchLimit = 1

        // Configure the fetch request with a predicate to match the specified UUID
        let predicate = NSPredicate(format: "id == %@", state.uuid as CVarArg)
        fetchRequest.predicate = predicate

        do {
            let results = try managedContext.fetch(fetchRequest)
            if let voice = results.first {
                // Update the existing Voice object with the new data
                voice.title = state.title
                voice.url = state.url
                voice.text = state.text
                voice.createdAt = state.date
                voice.duration = state.duration

                try managedContext.save()
            }
        } catch let error {
            print(error.localizedDescription)
            Logger.shared.logError("update:" + error.localizedDescription)
        }
    }


    func updateTitle(uuid: UUID, newTitle: String) {
        let fetchRequest: NSFetchRequest<Voice> = Voice.fetchRequest()
        fetchRequest.fetchLimit = 1

        // UUIDに基づいて特定のVoiceオブジェクトを検索
        let predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        fetchRequest.predicate = predicate

        do {
            let results = try managedContext.fetch(fetchRequest)
            if let voice = results.first {
                // 新しいタイトルで更新
                voice.title = newTitle

                try managedContext.save()
            }
        } catch let error {
            print(error.localizedDescription)
            Logger.shared.logError("updateTitle:" + error.localizedDescription)
        }
    }

}
