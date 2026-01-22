import Foundation
import Dependencies
import CoreData
import os.log
import FirebaseCrashlytics

@MainActor
protocol VoiceMemoCoredataAccessorProtocol {
    func insert(voice: VoiceMemoRepository.Voice, isCloud: Bool)
    func selectAllData() -> [VoiceMemoRepository.Voice]
    func fetch(uuid: UUID) -> VoiceMemoRepository.Voice?
    func delete(id: UUID)
    func update(voice: VoiceMemoRepository.Voice)
    func updateTitle(uuid: UUID, newTitle: String)
    func removeDuplicates() -> Int
}

@MainActor
class VoiceMemoCoredataAccessor: NSObject, VoiceMemoCoredataAccessorProtocol {

    var managedContext: NSManagedObjectContext
    var entity: NSEntityDescription?

    var entityName: String = "Voice"

    override init() {
        // Use shared CoreDataStack to prevent multiple container instances
        self.managedContext = CoreDataStack.shared.viewContext
        self.entity = CoreDataStack.shared.voiceEntity
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
                AppLogger.data.error("CoreData insert failed: \(error.localizedDescription)")
                Crashlytics.crashlytics().log("CoreData insert failed: \(error.localizedDescription)")
                Crashlytics.crashlytics().record(error: error)
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
            AppLogger.data.error("CoreData selectAllData failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().log("CoreData selectAllData failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
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
            AppLogger.data.error("CoreData fetch failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().log("CoreData fetch failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
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
            AppLogger.data.error("CoreData delete failed: \(error), \(error.userInfo)")
            Crashlytics.crashlytics().log("CoreData delete failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
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
            AppLogger.data.error("CoreData update failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().log("CoreData update failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
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
            AppLogger.data.error("CoreData updateTitle failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().log("CoreData updateTitle failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
        }
    }

    /// 重複レコードを削除し、削除した件数を返す
    func removeDuplicates() -> Int {
        let fetchRequest: NSFetchRequest<Voice> = Voice.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        do {
            let allRecords = try managedContext.fetch(fetchRequest)
            var seenIds = Set<UUID>()
            var duplicatesToDelete: [Voice] = []

            for record in allRecords {
                guard let recordId = record.id else { continue }
                if seenIds.contains(recordId) {
                    // 重複 - 削除対象に追加
                    duplicatesToDelete.append(record)
                } else {
                    seenIds.insert(recordId)
                }
            }

            // 重複を削除
            for duplicate in duplicatesToDelete {
                managedContext.delete(duplicate)
            }

            if !duplicatesToDelete.isEmpty {
                try managedContext.save()
                AppLogger.data.info("Removed \(duplicatesToDelete.count) duplicate records")
            }

            return duplicatesToDelete.count
        } catch {
            AppLogger.data.error("Error removing duplicates: \(error.localizedDescription)")
            Crashlytics.crashlytics().log("CoreData removeDuplicates failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
            return 0
        }
    }
}

private enum VoiceMemoCoredataAccessorKey: DependencyKey {
    @MainActor
    static let liveValue: VoiceMemoCoredataAccessorProtocol = VoiceMemoCoredataAccessor()

    @MainActor
    static var previewValue: VoiceMemoCoredataAccessorProtocol = VoiceMemoCoredataAccessor()
    @MainActor
    static var testValue: VoiceMemoCoredataAccessorProtocol = VoiceMemoCoredataAccessor()
}

extension DependencyValues {
    var voiceMemoCoredataAccessor: VoiceMemoCoredataAccessorProtocol {
        get { self[VoiceMemoCoredataAccessorKey.self] }
        set { self[VoiceMemoCoredataAccessorKey.self] = newValue }
    }
}
