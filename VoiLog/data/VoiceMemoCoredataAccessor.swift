import Foundation
import Dependencies
import CoreData

@MainActor
protocol VoiceMemoCoredataAccessorProtocol {
    func insert(voice: VoiceMemoRepository.Voice, isCloud: Bool)
    func selectAllData() -> [VoiceMemoRepository.Voice]
    func fetch(uuid: UUID) -> VoiceMemoRepository.Voice?
    func delete(id: UUID)
    func update(voice: VoiceMemoRepository.Voice)
    func updateTitle(uuid: UUID, newTitle: String)
}

@MainActor
class VoiceMemoCoredataAccessor: NSObject, VoiceMemoCoredataAccessorProtocol {

    let container: NSPersistentContainer
    var managedContext: NSManagedObjectContext
    var entity: NSEntityDescription?

    var entityName: String = "Voice"

    override init() {
        container = NSPersistentContainer(name: entityName)
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

    func insert(voice: VoiceMemoRepository.Voice, isCloud: Bool) {
        guard let entity = self.entity else { return }
        if let voiceEntity = NSManagedObject(entity: entity, insertInto: managedContext) as? Voice {
            voiceEntity.title = voice.title
            voiceEntity.url = voice.url
            voiceEntity.id = voice.id
            voiceEntity.text = voice.text
            voiceEntity.createdAt = voice.createdAt
            voiceEntity.updatedAt = voice.updatedAt
            voiceEntity.duration = voice.duration
            voiceEntity.fileFormat = voice.fileFormat
            voiceEntity.samplingFrequency = voice.samplingFrequency
            voiceEntity.quantizationBitDepth = voice.quantizationBitDepth
            voiceEntity.numberOfChannels = voice.numberOfChannels
            voiceEntity.isCloud = isCloud
            do {
                try managedContext.save()
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    func selectAllData() -> [VoiceMemoRepository.Voice] {
        var memoGroups: [Voice] = []
        let fetchRequest: NSFetchRequest<Voice> = Voice.fetchRequest()

        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            memoGroups = try managedContext.fetch(fetchRequest)
        } catch {
            print(error.localizedDescription)
        }

        return memoGroups.map { voiceEntity in
            VoiceMemoRepository.Voice(
                title: voiceEntity.title ?? "",
                url: voiceEntity.url ?? URL(fileURLWithPath: ""),
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
                    url: voiceEntity.url ?? URL(fileURLWithPath: ""),
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
            }
        } catch {
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
                voiceEntity.updatedAt = voice.updatedAt
                voiceEntity.duration = voice.duration
                voiceEntity.fileFormat = voice.fileFormat
                voiceEntity.samplingFrequency = voice.samplingFrequency
                voiceEntity.quantizationBitDepth = voice.quantizationBitDepth
                voiceEntity.numberOfChannels = voice.numberOfChannels

                try managedContext.save()
            }
        } catch {
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
                voiceEntity.updatedAt = Date()
                try managedContext.save()
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}

private enum VoiceMemoCoredataAccessorKey: DependencyKey {
    static let liveValue: VoiceMemoCoredataAccessorProtocol = VoiceMemoCoredataAccessor()

    static var previewValue: VoiceMemoCoredataAccessorProtocol = VoiceMemoCoredataAccessor()
    static var testValue: VoiceMemoCoredataAccessorProtocol = VoiceMemoCoredataAccessor()
}

extension DependencyValues {
    var voiceMemoCoredataAccessor: VoiceMemoCoredataAccessorProtocol {
        get { self[VoiceMemoCoredataAccessorKey.self] }
        set { self[VoiceMemoCoredataAccessorKey.self] = newValue }
    }
}
