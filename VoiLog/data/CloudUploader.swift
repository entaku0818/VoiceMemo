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
    func deleteVoice(id: UUID) async -> Bool
    func downloadVoiceFile(id: UUID) async -> Bool
}
class CloudUploader: CloudUploaderProtocol {
    let container: CKContainer
    let database: CKDatabase

    init() {
        container = CKContainer(identifier: "iCloud.com.entaku.VoiLog")
        database = container.privateCloudDatabase
    }

    func saveVoice(voice: VoiceMemoRepository.Voice) async -> Bool {
        let recordID = CKRecord.ID(recordName: voice.id.uuidString)
        do {
            let record = try await database.record(for: recordID)
            return await updateRecord(record: record, with: voice)
        } catch {
            // レコードが存在しない場合、新規作成
            let newRecord = CKRecord(recordType: "Voice", recordID: recordID)
            return await updateRecord(record: newRecord, with: voice)
        }
    }

    private func updateRecord(record: CKRecord, with voice: VoiceMemoRepository.Voice) async -> Bool {
        // 音声ファイルのCKAssetを作成
        let inputDocumentsPath = NSHomeDirectory() + "/Documents/" + voice.url.lastPathComponent
        let asset = CKAsset(fileURL: URL(fileURLWithPath: inputDocumentsPath))
        record["file"] = asset

        // メタデータをCKRecordに設定
        record["title"] = voice.title as CKRecordValue
        record["id"] = voice.id.uuidString as CKRecordValue
        record["text"] = voice.text as CKRecordValue
        record["createdAt"] = voice.createdAt as CKRecordValue
        record["updatedAt"] = voice.updatedAt as CKRecordValue
        record["duration"] = voice.duration as CKRecordValue
        record["fileFormat"] = voice.fileFormat as CKRecordValue
        record["samplingFrequency"] = voice.samplingFrequency as CKRecordValue
        record["quantizationBitDepth"] = voice.quantizationBitDepth as CKRecordValue
        record["numberOfChannels"] = voice.numberOfChannels as CKRecordValue

        do {
            _ = try await database.save(record)
            return true
        } catch {
            print("Error saving voice record to CloudKit: \(error)")
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
                   let numberOfChannels = record["numberOfChannels"] as? Int {
                    let inputDocumentsPath = NSHomeDirectory() + "/Documents/" + id.uuidString
                    let fileURL = URL(fileURLWithPath: inputDocumentsPath)

                    return VoiceMemoRepository.Voice(
                        title: title,
                        url: fileURL,
                        id: id,
                        text: text,
                        createdAt: createdAt,
                        updatedAt: updatedAt,
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

    func deleteVoice(id: UUID) async -> Bool {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        return await withCheckedContinuation { continuation in
            database.delete(withRecordID: recordID) { _, error in
                if let error = error {
                    print("Error deleting voice record from CloudKit: \(error)")
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: true)
                }
            }
        }
    }

    func downloadVoiceFile(id: UUID) async -> Bool {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        do {
            let record = try await database.record(for: recordID)
            if let asset = record["file"] as? CKAsset,
               let fileURL = asset.fileURL {
                // ドキュメントフォルダに保存するためのパスを作成
                let documentsPath = NSHomeDirectory() + "/Documents/" + id.uuidString
                let destinationURL = URL(fileURLWithPath: documentsPath)

                // ファイルをコピー
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: fileURL, to: destinationURL)

                    return true
                } catch {
                    print("Error copying file to Documents: \(error)")
                    return false
                }
            } else {
                print("No asset found for the given record ID.")
                return false
            }
        } catch {
            print("Error fetching voice record from CloudKit: \(error)")
            return false
        }
    }

}
