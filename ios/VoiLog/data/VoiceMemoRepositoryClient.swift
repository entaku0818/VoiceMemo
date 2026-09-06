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
        var timestampedText: String?
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
        var timestampedText: String?
        var aiTranscriptionText: String = ""
        var aiMeetingMinutesText: String = ""
        var fileFormat: String
        var samplingFrequency: Double
        var quantizationBitDepth: Int
        var numberOfChannels: Int
        var tags: [String] = []
    }

    var insert: @MainActor (RecordingVoice) -> Void
    var selectAllData: @MainActor () -> [VoiceMemoVoice]
    var fetch: @MainActor (UUID) -> RecordingVoice?
    var delete: @MainActor (UUID) -> Void
    var update: @MainActor (VoiceMemoVoice) -> Void
    var updateTitle: @MainActor (UUID, String) -> Void
    var updateTags: @MainActor (UUID, [String]) -> Void
    var updateMeetingMinutes: @MainActor (UUID, String) -> Void
    var syncToCloud: @MainActor () async -> Bool
    var checkForDifferences: @MainActor () async -> Bool
    /// Documents 配下に残っているがCore Dataに行が無い音声ファイルを一覧へ復帰させる。
    /// - Returns: 復元した件数
    var restoreOrphanedRecordings: @MainActor () async -> Int

    /// iCloud(CloudKit) 上にあってCore Dataに行が無い録音を、実体ごと引き戻す。
    /// 端末からファイルが消えている場合や機種変更後は、こちらでしか戻せない。
    var restoreFromCloud: @MainActor () async -> CloudRestoreResult = { CloudRestoreResult() }

    /// 消失時の状況スナップショットを集める（Crashlytics 送信・問い合わせ添付用）
    var collectRecoveryDiagnostics: @MainActor () async -> RecoveryDiagnostics = { .empty }

    // MARK: - Cloud Restore Result
    struct CloudRestoreResult: Equatable {
        var restoredCount: Int = 0
        /// iCloud のレコード一覧を取得できたか。未ログイン・圏外・権限なしなら false
        var isCloudAvailable = false
        /// iCloud 上に存在した録音の総数
        var cloudRecordCount: Int = 0
    }
}

// MARK: - Dependency Key
private enum VoiceMemoRepositoryClientKey: DependencyKey {
    @MainActor
    static let liveValue: VoiceMemoRepositoryClient = {
        // Use shared CoreData stack to prevent multiple container instances
        let managedContext = CoreDataStack.shared.viewContext
        let entity = CoreDataStack.shared.voiceEntity

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
                    voiceEntity.timestampedText = recordingVoice.timestampedText
                    voiceEntity.createdAt = recordingVoice.date
                    voiceEntity.updatedAt = Date()
                    voiceEntity.duration = recordingVoice.duration
                    voiceEntity.fileFormat = recordingVoice.fileFormat
                    voiceEntity.samplingFrequency = recordingVoice.samplingFrequency
                    voiceEntity.quantizationBitDepth = Int16(recordingVoice.quantizationBitDepth)
                    voiceEntity.numberOfChannels = Int16(recordingVoice.numberOfChannels)
                    voiceEntity.isCloud = false
                    do {
                        try managedContext.saveIfStoreLoaded()
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
                        timestampedText: voiceEntity.timestampedText,
                        aiTranscriptionText: voiceEntity.aiTranscriptionText ?? "",
                        aiMeetingMinutesText: voiceEntity.aiMeetingMinutesText ?? "",
                        fileFormat: voiceEntity.fileFormat ?? "",
                        samplingFrequency: voiceEntity.samplingFrequency,
                        quantizationBitDepth: Int(voiceEntity.quantizationBitDepth),
                        numberOfChannels: Int(voiceEntity.numberOfChannels),
                        tags: Self.decodeTags(voiceEntity.tags)
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
                            timestampedText: voiceEntity.timestampedText,
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
                    try managedContext.saveIfStoreLoaded()
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
                        voiceEntity.timestampedText = voiceMemoVoice.timestampedText
                        voiceEntity.aiTranscriptionText = voiceMemoVoice.aiTranscriptionText.isEmpty ? nil : voiceMemoVoice.aiTranscriptionText
                        voiceEntity.aiMeetingMinutesText = voiceMemoVoice.aiMeetingMinutesText.isEmpty ? nil : voiceMemoVoice.aiMeetingMinutesText
                        voiceEntity.createdAt = voiceMemoVoice.date
                        voiceEntity.updatedAt = Date()
                        voiceEntity.duration = voiceMemoVoice.duration
                        voiceEntity.fileFormat = voiceMemoVoice.fileFormat
                        voiceEntity.samplingFrequency = voiceMemoVoice.samplingFrequency
                        voiceEntity.quantizationBitDepth = Int16(voiceMemoVoice.quantizationBitDepth)
                        voiceEntity.numberOfChannels = Int16(voiceMemoVoice.numberOfChannels)

                        try managedContext.saveIfStoreLoaded()
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
                        try managedContext.saveIfStoreLoaded()
                    }
                } catch {
                    AppLogger.data.error("Repository updateTitle failed: \(error.localizedDescription)")
                }
            },
            updateTags: { uuid, tags in
                let fetchRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()
                fetchRequest.fetchLimit = 1
                fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                do {
                    let results = try managedContext.fetch(fetchRequest)
                    if let voiceEntity = results.first {
                        voiceEntity.tags = Self.encodeTags(tags)
                        voiceEntity.updatedAt = Date()
                        try managedContext.saveIfStoreLoaded()
                    }
                } catch {
                    AppLogger.data.error("Repository updateTags failed: \(error.localizedDescription)")
                }
            },
            updateMeetingMinutes: { uuid, text in
                let fetchRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()
                fetchRequest.fetchLimit = 1
                fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                do {
                    let results = try managedContext.fetch(fetchRequest)
                    if let voiceEntity = results.first {
                        voiceEntity.aiMeetingMinutesText = text.isEmpty ? nil : text
                        voiceEntity.updatedAt = Date()
                        try managedContext.saveIfStoreLoaded()
                    }
                } catch {
                    AppLogger.data.error("Repository updateMeetingMinutes failed: \(error.localizedDescription)")
                }
            },
            syncToCloud: {
                // THREAD SAFETY FIX: Extract data as value types BEFORE async operations
                // to avoid accessing NSManagedObject after await suspension points.

                struct VoiceData {
                    let id: UUID
                    let url: URL
                    let title: String
                    let text: String
                    let createdAt: Date
                    let updatedAt: Date
                    let duration: Double
                    let fileFormat: String
                    let samplingFrequency: Double
                    let quantizationBitDepth: Int16
                    let numberOfChannels: Int16
                }

                // Step 1: Fetch and convert to value types on MainActor
                var voiceDataList: [VoiceData] = []
                let fetchRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()

                do {
                    let localVoices = try managedContext.fetch(fetchRequest)
                    voiceDataList = localVoices.compactMap { voiceEntity -> VoiceData? in
                        guard let id = voiceEntity.id,
                              let url = voiceEntity.url else { return nil }
                        return VoiceData(
                            id: id,
                            url: url,
                            title: voiceEntity.title ?? "",
                            text: voiceEntity.text ?? "",
                            createdAt: voiceEntity.createdAt ?? Date(),
                            updatedAt: voiceEntity.updatedAt ?? Date(),
                            duration: voiceEntity.duration,
                            fileFormat: voiceEntity.fileFormat ?? "",
                            samplingFrequency: voiceEntity.samplingFrequency,
                            quantizationBitDepth: voiceEntity.quantizationBitDepth,
                            numberOfChannels: voiceEntity.numberOfChannels
                        )
                    }
                } catch {
                    AppLogger.sync.error("Error fetching local voices: \(error)")
                    return false
                }

                // Step 2: Sync each voice to CloudKit (using value types, not NSManagedObjects)
                var syncedIds: [UUID] = []
                for voiceData in voiceDataList {
                    let recordID = CKRecord.ID(recordName: voiceData.id.uuidString)

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
                        let inputDocumentsPath = NSHomeDirectory() + "/Documents/" + voiceData.url.lastPathComponent
                        let asset = CKAsset(fileURL: URL(fileURLWithPath: inputDocumentsPath))
                        record["file"] = asset

                        // メタデータをCKRecordに設定 (using value types)
                        record["title"] = voiceData.title as CKRecordValue
                        record["id"] = voiceData.id.uuidString as CKRecordValue
                        record["text"] = voiceData.text as CKRecordValue
                        record["createdAt"] = voiceData.createdAt as CKRecordValue
                        record["updatedAt"] = voiceData.updatedAt as CKRecordValue
                        record["duration"] = voiceData.duration as CKRecordValue
                        record["fileFormat"] = voiceData.fileFormat as CKRecordValue
                        record["samplingFrequency"] = voiceData.samplingFrequency as CKRecordValue
                        record["quantizationBitDepth"] = voiceData.quantizationBitDepth as CKRecordValue
                        record["numberOfChannels"] = voiceData.numberOfChannels as CKRecordValue

                        // CloudKitに保存
                        _ = try await database.save(record)

                        // Track successfully synced IDs
                        syncedIds.append(voiceData.id)

                    } catch {
                        AppLogger.sync.error("Error syncing voice \(voiceData.id) to CloudKit: \(error)")
                        return false
                    }
                }

                // Step 3: Update isCloud flag on MainActor (re-fetch entities by ID)
                for syncedId in syncedIds {
                    let updateRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()
                    updateRequest.predicate = NSPredicate(format: "id == %@", syncedId as CVarArg)
                    updateRequest.fetchLimit = 1

                    do {
                        if let voiceEntity = try managedContext.fetch(updateRequest).first {
                            voiceEntity.isCloud = true
                        }
                    } catch {
                        AppLogger.sync.error("Error updating isCloud for \(syncedId): \(error)")
                    }
                }

                // Step 4: Save all changes
                do {
                    try managedContext.saveIfStoreLoaded()
                    return true
                } catch {
                    AppLogger.sync.error("Error saving local changes after sync: \(error)")
                    return false
                }
            },
            checkForDifferences: {
                // THREAD SAFETY FIX: Extract local voice IDs as value types BEFORE async operations
                // to avoid accessing NSManagedObject after await suspension points.
                // This prevents "garbage pointer" crashes (Rollbar #91).

                // Step 1: Fetch local data and convert to value types BEFORE any await
                let localVoiceIds: Set<UUID>
                let fetchRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()

                do {
                    let localVoices = try managedContext.fetch(fetchRequest)
                    localVoiceIds = Set(localVoices.compactMap { $0.id })
                } catch {
                    AppLogger.sync.error("Error fetching local voices: \(error)")
                    return false
                }

                // Step 2: Now safe to perform async CloudKit operations
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

                    // localVoiceIds is already extracted as Set<UUID> before await
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
                        try managedContext.saveIfStoreLoaded()
                        return !voicesToDownload.isEmpty
                    } catch {
                        AppLogger.sync.error("Error saving downloaded voices: \(error)")
                        return false
                    }

                } catch {
                    AppLogger.sync.error("Error fetching voice records from CloudKit: \(error)")
                    return false
                }
            },
            restoreOrphanedRecordings: {
                // Core Data に登録済みの ID を集める
                let fetchRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()
                let existing = (try? managedContext.fetch(fetchRequest)) ?? []
                let knownIDs = Set(existing.compactMap(\.id))

                let orphans = RecordingRecoveryService.findOrphanedRecordings(
                    in: RecordingRecoveryService.defaultSearchDirectories(),
                    knownIDs: knownIDs
                )
                guard !orphans.isEmpty else { return 0 }

                @Dependency(\.userDefaults) var userDefaults
                var restoredCount = 0

                for orphan in orphans {
                    let duration = await RecordingRecoveryService.duration(of: orphan.url)
                    guard let voiceEntity = NSManagedObject(
                        entity: entity!, insertInto: managedContext
                    ) as? VoiLog.Voice else { continue }

                    voiceEntity.id = orphan.id
                    voiceEntity.url = orphan.url
                    voiceEntity.title = RecordingRecoveryService.recoveredTitle(for: orphan.createdAt)
                    voiceEntity.text = ""
                    voiceEntity.createdAt = orphan.createdAt
                    voiceEntity.updatedAt = Date()
                    voiceEntity.duration = duration
                    voiceEntity.fileFormat = orphan.url.pathExtension.uppercased()
                    voiceEntity.samplingFrequency = userDefaults.samplingFrequency()
                    voiceEntity.quantizationBitDepth = Int16(userDefaults.quantizationBitDepth())
                    voiceEntity.numberOfChannels = Int16(userDefaults.numberOfChannels())
                    voiceEntity.isCloud = false
                    restoredCount += 1
                }

                do {
                    try managedContext.saveIfStoreLoaded()
                    AppLogger.data.info("Restored \(restoredCount) orphaned recording(s)")
                    return restoredCount
                } catch {
                    managedContext.rollback()
                    AppLogger.data.error("Failed to restore orphaned recordings: \(error.localizedDescription)")
                    return 0
                }
            },
            restoreFromCloud: {
                let isAvailable = await isCloudAccountAvailable(container: cloudContainer)
                guard isAvailable else {
                    AppLogger.sync.info("Cloud restore skipped: iCloud account unavailable")
                    return VoiceMemoRepositoryClient.CloudRestoreResult()
                }

                let uploader = CloudUploader()
                let cloudVoices = await uploader.fetchAllVoices()

                let fetchRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()
                let existing = (try? managedContext.fetch(fetchRequest)) ?? []
                let knownIDs = Set(existing.compactMap(\.id))
                let missing = cloudVoices.filter { !knownIDs.contains($0.id) }

                var restoredCount = 0
                for voice in missing {
                    // 実体を Documents に引き戻せたものだけ一覧に載せる。
                    // ダウンロードに失敗した行を作ると「開けない録音」が並ぶことになる
                    guard await uploader.downloadVoiceFile(id: voice.id) else {
                        AppLogger.sync.error("Cloud restore failed to download \(voice.id.uuidString)")
                        continue
                    }
                    guard let voiceEntity = NSManagedObject(
                        entity: entity!, insertInto: managedContext
                    ) as? VoiLog.Voice else { continue }

                    voiceEntity.id = voice.id
                    voiceEntity.url = voice.url
                    voiceEntity.title = voice.title
                    voiceEntity.text = voice.text
                    voiceEntity.createdAt = voice.createdAt
                    voiceEntity.updatedAt = Date()
                    voiceEntity.duration = voice.duration
                    voiceEntity.fileFormat = voice.fileFormat
                    voiceEntity.samplingFrequency = voice.samplingFrequency
                    voiceEntity.quantizationBitDepth = voice.quantizationBitDepth
                    voiceEntity.numberOfChannels = voice.numberOfChannels
                    voiceEntity.isCloud = true
                    restoredCount += 1
                }

                guard restoredCount > 0 else {
                    return VoiceMemoRepositoryClient.CloudRestoreResult(
                        restoredCount: 0,
                        isCloudAvailable: true,
                        cloudRecordCount: cloudVoices.count
                    )
                }

                do {
                    try managedContext.saveIfStoreLoaded()
                    AppLogger.sync.info("Restored \(restoredCount) recording(s) from iCloud")
                    return VoiceMemoRepositoryClient.CloudRestoreResult(
                        restoredCount: restoredCount,
                        isCloudAvailable: true,
                        cloudRecordCount: cloudVoices.count
                    )
                } catch {
                    managedContext.rollback()
                    AppLogger.sync.error("Failed to restore from iCloud: \(error.localizedDescription)")
                    return VoiceMemoRepositoryClient.CloudRestoreResult(
                        restoredCount: 0,
                        isCloudAvailable: true,
                        cloudRecordCount: cloudVoices.count
                    )
                }
            },
            collectRecoveryDiagnostics: {
                let fetchRequest: NSFetchRequest<VoiLog.Voice> = VoiLog.Voice.fetchRequest()
                let existing = (try? managedContext.fetch(fetchRequest)) ?? []
                let knownIDs = Set(existing.compactMap(\.id))
                let directories = RecordingRecoveryService.defaultSearchDirectories()

                var diagnostics = RecoveryDiagnostics()
                let info = Bundle.main.infoDictionary
                diagnostics.appVersion = info?["CFBundleShortVersionString"] as? String ?? "unknown"
                diagnostics.buildNumber = info?["CFBundleVersion"] as? String ?? "unknown"
                diagnostics.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
                diagnostics.deviceModel = RecoveryDiagnostics.deviceModelIdentifier()
                diagnostics.freeDiskBytes = RecoveryDiagnostics.freeDiskBytes()
                diagnostics.coreDataRowCount = existing.count
                diagnostics.audio = RecoveryDiagnostics.audioState(in: directories)
                diagnostics.orphanCount = RecordingRecoveryService.findOrphanedRecordings(
                    in: directories,
                    knownIDs: knownIDs
                ).count
                diagnostics.lastStoreFailure = CoreDataStack.lastStoreFailure()

                if let storeURL = CoreDataStack.shared.container
                    .persistentStoreDescriptions.first?.url {
                    diagnostics.store = RecoveryDiagnostics.storeState(storeURL: storeURL)
                }

                // iCloud は通信するので、アカウントが使えるときだけ数える
                if await isCloudAccountAvailable(container: cloudContainer) {
                    diagnostics.cloudRecordCount = await CloudUploader().fetchAllVoices().count
                }

                return diagnostics
            }
        )
    }()

    static func decodeTags(_ json: String?) -> [String] {
        guard let json, let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return arr
    }

    static func encodeTags(_ tags: [String]) -> String {
        (try? String(data: JSONEncoder().encode(tags), encoding: .utf8)) ?? "[]"
    }

    @MainActor
    static let previewValue = VoiceMemoRepositoryClient(
        insert: { _ in },
        selectAllData: { [] },
        fetch: { _ in nil },
        delete: { _ in },
        update: { _ in },
        updateTitle: { _, _ in },
        updateTags: { _, _ in },
        updateMeetingMinutes: { _, _ in },
        syncToCloud: { true },
        checkForDifferences: { false },
        restoreOrphanedRecordings: { 0 }
    )

    @MainActor
    static let testValue: VoiceMemoRepositoryClient = previewValue
}

/// iCloud アカウントが使える状態か。
///
/// `CloudUploader.fetchAllVoices()` は取得に失敗しても空配列を返すため、
/// 「本当に0件」と「取得できなかった」を区別するのにアカウント状態を使う。
private func isCloudAccountAvailable(container: CKContainer) async -> Bool {
    do {
        return try await container.accountStatus() == .available
    } catch {
        AppLogger.sync.error("Failed to read iCloud account status: \(error.localizedDescription)")
        return false
    }
}

extension DependencyValues {
    var voiceMemoRepository: VoiceMemoRepositoryClient {
        get { self[VoiceMemoRepositoryClientKey.self] }
        set { self[VoiceMemoRepositoryClientKey.self] = newValue }
    }
}
