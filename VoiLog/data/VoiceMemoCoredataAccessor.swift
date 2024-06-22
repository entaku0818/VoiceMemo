import Foundation
import CoreData

class VoiceMemoCoredataAccessor: NSObject {

    let container: NSPersistentContainer
    var managedContext: NSManagedObjectContext
    var entity: NSEntityDescription?

    var entityName: String = "Voice"

    override init() {
        container = NSPersistentContainer(name: entityName)
        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        self.managedContext = container.viewContext
        if let localEntity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext) {
            self.entity = localEntity
        }
    }

    func insert(voice: VoiceMemoRepository.Voice) {
        if let voiceEntity = NSManagedObject(entity: self.entity!, insertInto: managedContext) as? Voice {
            voiceEntity.title = voice.title
            voiceEntity.url = voice.url
            voiceEntity.id = voice.id
            voiceEntity.text = voice.text
            voiceEntity.createdAt = voice.createdAt
            voiceEntity.duration = voice.duration
            voiceEntity.fileFormat = voice.fileFormat
            voiceEntity.samplingFrequency = voice.samplingFrequency
            voiceEntity.quantizationBitDepth = voice.quantizationBitDepth
            voiceEntity.numberOfChannels = voice.numberOfChannels

            do {
                try managedContext.save()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }

    func selectAllData() -> [VoiceMemoRepository.Voice] {
        var memoGroups: [Voice] = []
        let fetchRequest: NSFetchRequest<Voice> = Voice.fetchRequest()

        do {
            memoGroups = try managedContext.fetch(fetchRequest)
        } catch let error {
            print(error.localizedDescription)
        }

        return memoGroups.map { voiceEntity in
            VoiceMemoRepository.Voice(
                title: voiceEntity.title ?? "",
                url: voiceEntity.url!,
                id: voiceEntity.id ?? UUID(),
                text: voiceEntity.text ?? "",
                createdAt: voiceEntity.createdAt ?? Date(),
                duration: voiceEntity.duration,
                fileFormat: voiceEntity.fileFormat ?? "",
                samplingFrequency: voiceEntity.samplingFrequency,
                quantizationBitDepth: voiceEntity.quantizationBitDepth,
                numberOfChannels: voiceEntity.numberOfChannels
            )
        }
    }

    func fetch(uuid: UUID) -> VoiceMemoRepository.Voice? {
        let fetchRequest: NSFetchRequest<Voice> = Voice.fetchRequest()
        fetchRequest.fetchLimit = 1
        let predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        fetchRequest.predicate = predicate

        do {
            let results = try managedContext.fetch(fetchRequest)
            if let voiceEntity = results.first {
                return VoiceMemoRepository.Voice(
                    title: voiceEntity.title ?? "",
                    url: voiceEntity.url!,
                    id: voiceEntity.id ?? UUID(),
                    text: voiceEntity.text ?? "",
                    createdAt: voiceEntity.createdAt ?? Date(),
                    duration: voiceEntity.duration,
                    fileFormat: voiceEntity.fileFormat ?? "",
                    samplingFrequency: voiceEntity.samplingFrequency,
                    quantizationBitDepth: voiceEntity.quantizationBitDepth,
                    numberOfChannels: voiceEntity.numberOfChannels
                )
            }
        } catch let error {
            print(error.localizedDescription)
        }
        return nil
    }

    func delete(id: UUID) {
        let fetchRequest: NSFetchRequest<Voice> = Voice.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let myResults = try managedContext.fetch(fetchRequest)
            for myData in myResults {
                managedContext.delete(myData)
            }
            try managedContext.save()
        } catch let error as NSError {
            print("\(error), \(error.userInfo)")
        }
    }

    func update(voice: VoiceMemoRepository.Voice) {
        let fetchRequest: NSFetchRequest<Voice> = Voice.fetchRequest()
        fetchRequest.fetchLimit = 1
        let predicate = NSPredicate(format: "id == %@", voice.id as CVarArg)
        fetchRequest.predicate = predicate

        do {
            let results = try managedContext.fetch(fetchRequest)
            if let voiceEntity = results.first {
                voiceEntity.title = voice.title
                voiceEntity.url = voice.url
                voiceEntity.text = voice.text
                voiceEntity.createdAt = voice.createdAt
                voiceEntity.duration = voice.duration
                voiceEntity.fileFormat = voice.fileFormat
                voiceEntity.samplingFrequency = voice.samplingFrequency
                voiceEntity.quantizationBitDepth = voice.quantizationBitDepth
                voiceEntity.numberOfChannels = voice.numberOfChannels

                try managedContext.save()
            }
        } catch let error {
            print(error.localizedDescription)
        }
    }

    func updateTitle(uuid: UUID, newTitle: String) {
        let fetchRequest: NSFetchRequest<Voice> = Voice.fetchRequest()
        fetchRequest.fetchLimit = 1
        let predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        fetchRequest.predicate = predicate

        do {
            let results = try managedContext.fetch(fetchRequest)
            if let voiceEntity = results.first {
                voiceEntity.title = newTitle
                try managedContext.save()
            }
        } catch let error {
            print(error.localizedDescription)
        }
    }
}
