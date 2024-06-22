//
//  CloudUploader.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/06/22.
//
import CloudKit

class CloudUploader {
    let container: CKContainer
    let database: CKDatabase

    init() {
        container = CKContainer(identifier: "iCloud.com.entaku.VoiLog")
        database = container.privateCloudDatabase
    }

    func saveVoice(voice: VoiceMemoRepository.Voice) async -> Bool {
        let record = CKRecord(recordType: "Voice")

        // 音声ファイルのCKAssetを作成
        let asset = CKAsset(fileURL: voice.url)
        record["file"] = asset

        // メタデータをCKRecordに設定
        record["title"] = voice.title as CKRecordValue
        record["id"] = voice.id.uuidString as CKRecordValue
        record["text"] = voice.text as CKRecordValue
        record["createdAt"] = voice.createdAt as CKRecordValue
        record["duration"] = voice.duration as CKRecordValue
        record["fileFormat"] = voice.fileFormat as CKRecordValue
        record["samplingFrequency"] = voice.samplingFrequency as CKRecordValue
        record["quantizationBitDepth"] = voice.quantizationBitDepth as CKRecordValue
        record["numberOfChannels"] = voice.numberOfChannels as CKRecordValue

        do {
            let _ = try await database.save(record)
            return true
        } catch {
            print("Error saving voice record to CloudKit: \(error.localizedDescription)")
            print("Container Identifier: \(container.containerIdentifier ?? "None")")
            print("Record: \(record)")
            return false
        }
    }
}
