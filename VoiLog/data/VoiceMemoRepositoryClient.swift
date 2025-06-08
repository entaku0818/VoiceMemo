//
//  VoiceMemoRepositoryClient.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2025/06/08.
//

import Foundation
import Dependencies
import CoreData

// MARK: - VoiceMemoRepository Client
struct VoiceMemoRepositoryClient {
    // MARK: - Recording Voice Model
    struct RecordingVoice: Equatable {
        var uuid: UUID
        var date: Date
        var duration: Double
        var resultText: String
        var fileFormat: String
        var samplingFrequency: Double
        var quantizationBitDepth: Int
        var numberOfChannels: Int
        var url: URL
    }
    
    // MARK: - VoiceMemo Voice Model
    struct VoiceMemoVoice: Equatable {
        var uuid: UUID
        var date: Date
        var duration: Double
        var title: String
        var url: URL
        var text: String
        var fileFormat: String
        var samplingFrequency: Double
        var quantizationBitDepth: Int
        var numberOfChannels: Int
    }

    var insert: (RecordingVoice) -> Void
    var selectAllData: () -> [VoiceMemoVoice]
    var fetch: (UUID) -> RecordingVoice?
    var delete: (UUID) -> Void
    var update: (VoiceMemoVoice) -> Void
    var updateTitle: (UUID, String) -> Void
    var syncToCloud: () async -> Bool
    var checkForDifferences: () async -> Bool
}

// MARK: - Dependency Key
private enum VoiceMemoRepositoryClientKey: DependencyKey {
    static let liveValue: VoiceMemoRepositoryClient = {
        // CoreData setup
        let container = NSPersistentContainer(name: "Voice")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        let managedContext = container.viewContext
        let entity = NSEntityDescription.entity(forEntityName: "Voice", in: managedContext)
        
        return VoiceMemoRepositoryClient(
            insert: { recordingVoice in
                if let voiceEntity = NSManagedObject(entity: entity!, insertInto: managedContext) as? VoiLog.Voice {
                    voiceEntity.title = ""
                    voiceEntity.url = recordingVoice.url
                    voiceEntity.id = recordingVoice.uuid
                    voiceEntity.text = recordingVoice.resultText
                    voiceEntity.createdAt = recordingVoice.date
                    voiceEntity.updatedAt = Date()
                    voiceEntity.duration = recordingVoice.duration
                    voiceEntity.fileFormat = recordingVoice.fileFormat
                    voiceEntity.samplingFrequency = recordingVoice.samplingFrequency
                    voiceEntity.quantizationBitDepth = Int16(recordingVoice.quantizationBitDepth)
                    voiceEntity.numberOfChannels = Int16(recordingVoice.numberOfChannels)
                    voiceEntity.isCloud = false
                    do {
                        try managedContext.save()
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            },
            selectAllData: {
                var memoGroups: [VoiLog.Voice] = []
                let fetchRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()

                let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
                fetchRequest.sortDescriptors = [sortDescriptor]

                do {
                    memoGroups = try managedContext.fetch(fetchRequest)
                } catch {
                    print(error.localizedDescription)
                }

                return memoGroups.map { voiceEntity in
                    VoiceMemoRepositoryClient.VoiceMemoVoice(
                        uuid: voiceEntity.id ?? UUID(),
                        date: voiceEntity.createdAt ?? Date(),
                        duration: voiceEntity.duration,
                        title: voiceEntity.title ?? "",
                        url: voiceEntity.url!,
                        text: voiceEntity.text ?? "",
                        fileFormat: voiceEntity.fileFormat ?? "",
                        samplingFrequency: voiceEntity.samplingFrequency,
                        quantizationBitDepth: Int(voiceEntity.quantizationBitDepth),
                        numberOfChannels: Int(voiceEntity.numberOfChannels)
                    )
                }
            },
            fetch: { uuid in
                let fetchRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()
                fetchRequest.fetchLimit = 1
                let predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                fetchRequest.predicate = predicate

                do {
                    let results = try managedContext.fetch(fetchRequest)
                    if let voiceEntity = results.first {
                        return VoiceMemoRepositoryClient.RecordingVoice(
                            uuid: voiceEntity.id ?? UUID(),
                            date: voiceEntity.createdAt ?? Date(),
                            duration: voiceEntity.duration,
                            resultText: voiceEntity.text ?? "",
                            fileFormat: voiceEntity.fileFormat ?? "",
                            samplingFrequency: voiceEntity.samplingFrequency,
                            quantizationBitDepth: Int(voiceEntity.quantizationBitDepth),
                            numberOfChannels: Int(voiceEntity.numberOfChannels),
                            url: voiceEntity.url!
                        )
                    }
                } catch {
                    print(error.localizedDescription)
                }
                return nil
            },
            delete: { id in
                let fetchRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()
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
                // TODO: クラウドからも削除
            },
            update: { voiceMemoVoice in
                let fetchRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()
                fetchRequest.fetchLimit = 1
                let predicate = NSPredicate(format: "id == %@", voiceMemoVoice.uuid as CVarArg)
                fetchRequest.predicate = predicate

                do {
                    let results = try managedContext.fetch(fetchRequest)
                    if let voiceEntity = results.first {
                        voiceEntity.title = voiceMemoVoice.title
                        voiceEntity.url = voiceMemoVoice.url
                        voiceEntity.text = voiceMemoVoice.text
                        voiceEntity.createdAt = voiceMemoVoice.date
                        voiceEntity.updatedAt = Date()
                        voiceEntity.duration = voiceMemoVoice.duration
                        voiceEntity.fileFormat = voiceMemoVoice.fileFormat
                        voiceEntity.samplingFrequency = voiceMemoVoice.samplingFrequency
                        voiceEntity.quantizationBitDepth = Int16(voiceMemoVoice.quantizationBitDepth)
                        voiceEntity.numberOfChannels = Int16(voiceMemoVoice.numberOfChannels)

                        try managedContext.save()
                    }
                } catch {
                    print(error.localizedDescription)
                }
            },
            updateTitle: { uuid, newTitle in
                let fetchRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()
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
            },
            syncToCloud: {
                // TODO: クラウド同期実装
                return true
            },
            checkForDifferences: {
                // TODO: 差分チェック実装
                return false
            }
        )
    }()
    
    static let previewValue: VoiceMemoRepositoryClient = VoiceMemoRepositoryClient(
        insert: { _ in },
        selectAllData: { [] },
        fetch: { _ in nil },
        delete: { _ in },
        update: { _ in },
        updateTitle: { _, _ in },
        syncToCloud: { true },
        checkForDifferences: { false }
    )
    
    static let testValue: VoiceMemoRepositoryClient = previewValue
}

extension DependencyValues {
    var voiceMemoRepository: VoiceMemoRepositoryClient {
        get { self[VoiceMemoRepositoryClientKey.self] }
        set { self[VoiceMemoRepositoryClientKey.self] = newValue }
    }
} 