//
//  VoiceMemoRepositoryClient.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2025/06/08.
//

import Foundation
import Dependencies
import CoreData
import CloudKit
import os.log

// MARK: - VoiceMemoRepository Client
struct VoiceMemoRepositoryClient {
    // MARK: - Recording Voice Model
    struct RecordingVoice: Equatable {
        var uuid: UUID
        var date: Date
        var duration: Double
        var resultText: String
        var title: String
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
    @MainActor
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

        // CloudKit setup
        let cloudContainer = CKContainer(identifier: "iCloud.com.entaku.VoiLog")
        let database = cloudContainer.privateCloudDatabase

        return VoiceMemoRepositoryClient(
            insert: { recordingVoice in
                if let voiceEntity = NSManagedObject(entity: entity!, insertInto: managedContext) as? VoiLog.Voice {
                    voiceEntity.title = recordingVoice.title
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
                        AppLogger.data.error("Repository insert failed: \(error.localizedDescription)")
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
                    AppLogger.data.error("Repository selectAllData failed: \(error.localizedDescription)")
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
                            title: voiceEntity.title ?? "",
                            fileFormat: voiceEntity.fileFormat ?? "",
                            samplingFrequency: voiceEntity.samplingFrequency,
                            quantizationBitDepth: Int(voiceEntity.quantizationBitDepth),
                            numberOfChannels: Int(voiceEntity.numberOfChannels),
                            url: voiceEntity.url!
                        )
                    }
                } catch {
                    AppLogger.data.error("Repository fetch failed: \(error.localizedDescription)")
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
                    AppLogger.data.error("Repository delete failed: \(error), \(error.userInfo)")
                }

                // CloudKitからも削除
                Task {
                    let recordID = CKRecord.ID(recordName: id.uuidString)
                    do {
                        try await database.deleteRecord(withID: recordID)
                    } catch {
                        AppLogger.sync.error("Error deleting voice record from CloudKit: \(error)")
                    }
                }
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
                    AppLogger.data.error("Repository update failed: \(error.localizedDescription)")
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
                    AppLogger.data.error("Repository updateTitle failed: \(error.localizedDescription)")
                }
            },
            syncToCloud: {
                // ローカルデータを取得
                var localVoices: [VoiLog.Voice] = []
                let fetchRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()

                do {
                    localVoices = try managedContext.fetch(fetchRequest)
                } catch {
                    AppLogger.sync.error("Error fetching local voices: \(error)")
                    return false
                }

                // 各ローカルボイスをCloudKitに同期
                for voiceEntity in localVoices {
                    guard let voiceId = voiceEntity.id,
                          let voiceUrl = voiceEntity.url else { continue }

                    let recordID = CKRecord.ID(recordName: voiceId.uuidString)

                    do {
                        // 既存レコードを取得または新規作成
                        let record: CKRecord
                        do {
                            record = try await database.record(for: recordID)
                        } catch {
                            // レコードが存在しない場合、新規作成
                            record = CKRecord(recordType: "Voice", recordID: recordID)
                        }

                        // 音声ファイルのCKAssetを作成
                        let inputDocumentsPath = NSHomeDirectory() + "/Documents/" + voiceUrl.lastPathComponent
                        let asset = CKAsset(fileURL: URL(fileURLWithPath: inputDocumentsPath))
                        record["file"] = asset

                        // メタデータをCKRecordに設定
                        record["title"] = (voiceEntity.title ?? "") as CKRecordValue
                        record["id"] = voiceId.uuidString as CKRecordValue
                        record["text"] = (voiceEntity.text ?? "") as CKRecordValue
                        record["createdAt"] = (voiceEntity.createdAt ?? Date()) as CKRecordValue
                        record["updatedAt"] = (voiceEntity.updatedAt ?? Date()) as CKRecordValue
                        record["duration"] = voiceEntity.duration as CKRecordValue
                        record["fileFormat"] = (voiceEntity.fileFormat ?? "") as CKRecordValue
                        record["samplingFrequency"] = voiceEntity.samplingFrequency as CKRecordValue
                        record["quantizationBitDepth"] = voiceEntity.quantizationBitDepth as CKRecordValue
                        record["numberOfChannels"] = voiceEntity.numberOfChannels as CKRecordValue

                        // CloudKitに保存
                        _ = try await database.save(record)

                        // ローカルでisCloudフラグを更新
                        voiceEntity.isCloud = true

                    } catch {
                        AppLogger.sync.error("Error syncing voice \(voiceId) to CloudKit: \(error)")
                        return false
                    }
                }

                // ローカルの変更を保存
                do {
                    try managedContext.save()
                    return true
                } catch {
                    AppLogger.sync.error("Error saving local changes after sync: \(error)")
                    return false
                }
            },
            checkForDifferences: {
                // CloudKitからすべてのボイスを取得
                let query = CKQuery(recordType: "Voice", predicate: NSPredicate(value: true))

                do {
                    let (matchedRecords, _) = try await database.records(matching: query)

                    let cloudVoices = matchedRecords.compactMap { recordTuple -> VoiceMemoRepositoryClient.VoiceMemoVoice? in
                        guard let record = try? recordTuple.1.get(),
                              let title = record["title"] as? String,
                              let idString = record["id"] as? String,
                              let id = UUID(uuidString: idString),
                              let text = record["text"] as? String,
                              let createdAt = record["createdAt"] as? Date,
                              let updatedAt = record["updatedAt"] as? Date,
                              let duration = record["duration"] as? Double,
                              let fileFormat = record["fileFormat"] as? String,
                              let samplingFrequency = record["samplingFrequency"] as? Double,
                              let quantizationBitDepth = record["quantizationBitDepth"] as? Int,
                              let numberOfChannels = record["numberOfChannels"] as? Int else {
                            return nil
                        }

                        let inputDocumentsPath = NSHomeDirectory() + "/Documents/" + id.uuidString + ".m4a"
                        let fileURL = URL(fileURLWithPath: inputDocumentsPath)

                        return VoiceMemoRepositoryClient.VoiceMemoVoice(
                            uuid: id,
                            date: createdAt,
                            duration: duration,
                            title: title,
                            url: fileURL,
                            text: text,
                            fileFormat: fileFormat,
                            samplingFrequency: samplingFrequency,
                            quantizationBitDepth: quantizationBitDepth,
                            numberOfChannels: numberOfChannels
                        )
                    }

                    // ローカルデータを取得
                    var localVoices: [VoiLog.Voice] = []
                    let fetchRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()

                    do {
                        localVoices = try managedContext.fetch(fetchRequest)
                    } catch {
                        AppLogger.sync.error("Error fetching local voices: \(error)")
                        return false
                    }

                    let localVoiceIds = Set(localVoices.compactMap { $0.id })
                    let cloudVoiceIds = Set(cloudVoices.map { $0.uuid })

                    // CloudKitにあってローカルにないボイスをダウンロード
                    let voicesToDownload = cloudVoiceIds.subtracting(localVoiceIds)
                    for voiceId in voicesToDownload {
                        if let cloudVoice = cloudVoices.first(where: { $0.uuid == voiceId }) {
                            // ファイルをダウンロード
                            let recordID = CKRecord.ID(recordName: voiceId.uuidString)
                            do {
                                let record = try await database.record(for: recordID)
                                if let asset = record["file"] as? CKAsset,
                                   let fileURL = asset.fileURL {
                                    let documentsPath = NSHomeDirectory() + "/Documents/" + voiceId.uuidString + ".m4a"
                                    let destinationURL = URL(fileURLWithPath: documentsPath)

                                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                                        try FileManager.default.removeItem(at: destinationURL)
                                    }
                                    try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                                }
                            } catch {
                                AppLogger.sync.error("Error downloading voice file \(voiceId): \(error)")
                                continue
                            }

                            // ローカルデータベースに追加
                            if let voiceEntity = NSManagedObject(entity: entity!, insertInto: managedContext) as? VoiLog.Voice {
                                voiceEntity.title = cloudVoice.title
                                voiceEntity.url = cloudVoice.url
                                voiceEntity.id = cloudVoice.uuid
                                voiceEntity.text = cloudVoice.text
                                voiceEntity.createdAt = cloudVoice.date
                                voiceEntity.updatedAt = Date()
                                voiceEntity.duration = cloudVoice.duration
                                voiceEntity.fileFormat = cloudVoice.fileFormat
                                voiceEntity.samplingFrequency = cloudVoice.samplingFrequency
                                voiceEntity.quantizationBitDepth = Int16(cloudVoice.quantizationBitDepth)
                                voiceEntity.numberOfChannels = Int16(cloudVoice.numberOfChannels)
                                voiceEntity.isCloud = true
                            }
                        }
                    }

                    // 変更を保存
                    do {
                        try managedContext.save()
                        return !voicesToDownload.isEmpty
                    } catch {
                        AppLogger.sync.error("Error saving downloaded voices: \(error)")
                        return false
                    }

                } catch {
                    AppLogger.sync.error("Error fetching voice records from CloudKit: \(error)")
                    return false
                }
            }
        )
    }()

    @MainActor
    static let previewValue = VoiceMemoRepositoryClient(
        insert: { _ in },
        selectAllData: { [] },
        fetch: { _ in nil },
        delete: { _ in },
        update: { _ in },
        updateTitle: { _, _ in },
        syncToCloud: { true },
        checkForDifferences: { false }
    )

    @MainActor
    static let testValue: VoiceMemoRepositoryClient = previewValue
}

extension DependencyValues {
    var voiceMemoRepository: VoiceMemoRepositoryClient {
        get { self[VoiceMemoRepositoryClientKey.self] }
        set { self[VoiceMemoRepositoryClientKey.self] = newValue }
    }
}
