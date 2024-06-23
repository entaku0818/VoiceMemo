//
//  CloudUploader.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/06/22.
//
import CloudKit
protocol CloudUploaderProtocol {
    func saveVoice(voice: VoiceMemoRepository.Voice) async -> Bool
    func fetchAllVoices() async -> [VoiceMemoRepository.Voice]
}

class CloudUploader: CloudUploaderProtocol {
    let container: CKContainer
    let database: CKDatabase

    init() {
        container = CKContainer(identifier: "iCloud.com.entaku.VoiLog")
        database = container.privateCloudDatabase
    }

    func saveVoice(voice: VoiceMemoRepository.Voice) async -> Bool {
        let record = CKRecord(recordType: "Voice")

        // 音声ファイルのCKAssetを作成
        let inputDocumentsPath = NSHomeDirectory() + "/Documents/" + voice.url.lastPathComponent

        let asset = CKAsset(fileURL: URL(fileURLWithPath: inputDocumentsPath))
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
            return false
        }
    }

    func fetchAllVoices() async -> [VoiceMemoRepository.Voice] {
        let query = CKQuery(recordType: "Voice", predicate: NSPredicate(value: true))

        do {
            let (matchedRecords, _) = try await database.records(matching: query)
            return matchedRecords.compactMap { recordTuple in
                let record = try? recordTuple.1.get()
                if let record = record,
                   let url = (record["file"] as? CKAsset)?.fileURL,
                   let title = record["title"] as? String,
                   let idString = record["id"] as? String,
                   let id = UUID(uuidString: idString),
                   let text = record["text"] as? String,
                   let createdAt = record["createdAt"] as? Date,
                   let duration = record["duration"] as? Double,
                   let fileFormat = record["fileFormat"] as? String,
                   let samplingFrequency = record["samplingFrequency"] as? Double,
                   let quantizationBitDepth = record["quantizationBitDepth"] as? Int,
                   let numberOfChannels = record["numberOfChannels"] as? Int {
                    return VoiceMemoRepository.Voice(
                        title:title,
                        url: url,
                        id: id,
                        text: text,
                        createdAt: createdAt,
                        duration: duration,
                        fileFormat: fileFormat,
                        samplingFrequency: samplingFrequency,
                        quantizationBitDepth: Int16(quantizationBitDepth),
                        numberOfChannels: Int16(numberOfChannels), 
                        isCloud: true
                    )
                }
                return nil
            }
        } catch {
            print("Error fetching voice records from CloudKit: \(error.localizedDescription)")
            return []
        }
    }
}


