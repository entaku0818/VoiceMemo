//
//  VoiceMemoRepository.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/06/22.
//

import Foundation

@MainActor
class VoiceMemoRepository {

    private let coreDataAccessor: VoiceMemoCoredataAccessorProtocol
    private let cloudUploader: CloudUploaderProtocol

    init(coreDataAccessor: VoiceMemoCoredataAccessorProtocol, cloudUploader: CloudUploaderProtocol) {
        self.coreDataAccessor = coreDataAccessor
        self.cloudUploader = cloudUploader
    }

    func insert(state: RecordingMemo.State) {
        let voice = Voice(
            title: "",
            url: state.url,
            id: state.uuid,
            text: state.resultText,
            createdAt: state.date,
            updatedAt: Date(),
            duration: state.duration,
            fileFormat: state.fileFormat,
            samplingFrequency: state.samplingFrequency,
            quantizationBitDepth: Int16(state.quantizationBitDepth),
            numberOfChannels: Int16(state.numberOfChannels),
            isCloud: false
        )
        coreDataAccessor.insert(voice: voice, isCloud: false)
    }

    func selectAllData() -> [VoiceMemoReducer.State] {
        coreDataAccessor.selectAllData().map { voice in
            VoiceMemoReducer.State(
                uuid: voice.id,
                date: voice.createdAt,
                duration: voice.duration,
                time: 0,
                title: voice.title,
                url: voice.url,
                text: voice.text,
                fileFormat: voice.fileFormat,
                samplingFrequency: voice.samplingFrequency,
                quantizationBitDepth: Int(voice.quantizationBitDepth),
                numberOfChannels: Int(voice.numberOfChannels),
                hasPurchasedPremium: UserDefaultsManager.shared.hasPurchasedProduct
            )
        }
    }

    func fetch(uuid: UUID) -> RecordingMemo.State? {
        if let voice = coreDataAccessor.fetch(uuid: uuid) {
            return RecordingMemo.State(
                uuid: voice.id,
                date: voice.createdAt,
                duration: voice.duration,
                volumes: 0.0,
                resultText: voice.text,
                mode: .encoding,
                fileFormat: voice.fileFormat,
                samplingFrequency: voice.samplingFrequency,
                quantizationBitDepth: Int(voice.quantizationBitDepth),
                numberOfChannels: Int(voice.numberOfChannels),
                url: voice.url,
                startTime: 0,
                time: 0
            )
        }

        return nil
    }

    func delete(id: UUID) {
        coreDataAccessor.delete(id: id)
        // クラウドからも削除
        Task {
            _ = await cloudUploader.deleteVoice(id: id)
        }
    }
    func update(state: VoiceMemoReducer.State) {
        let voice = Voice(
            title: state.title,
            url: state.url,
            id: state.uuid,
            text: state.text,
            createdAt: state.date,
            updatedAt: Date(),
            duration: state.duration,
            fileFormat: state.fileFormat,
            samplingFrequency: state.samplingFrequency,
            quantizationBitDepth: Int16(state.quantizationBitDepth),
            numberOfChannels: Int16(state.numberOfChannels),
            isCloud: false
        )
        coreDataAccessor.update(voice: voice)
    }

    func updateTitle(uuid: UUID, newTitle: String) {
        coreDataAccessor.updateTitle(uuid: uuid, newTitle: newTitle)
    }
    func syncToCloud() async -> Bool {
        // ローカルの音声データを全て取得
        let localVoices = coreDataAccessor.selectAllData()
        let localVoiceIds = Set(localVoices.map { $0.id })

        // クラウド上の音声データを全て取得
        let cloudVoices = await cloudUploader.fetchAllVoices()
        let cloudVoiceIds = Set(cloudVoices.map { $0.id })

        // アップロードが必要な音声データを特定
        let voicesToUpload = localVoices.filter { !cloudVoiceIds.contains($0.id) }

        // ダウンロードが必要な音声データを特定
        let voicesToDownload = cloudVoices.filter { !localVoiceIds.contains($0.id) }

        // 同期の結果を追跡
        var allUploadsSucceeded = true

        // ローカルのみの音声データをクラウドにアップロード
        for voice in voicesToUpload {
            let success = await cloudUploader.saveVoice(voice: voice)
            if success {
                var updatedVoice = voice
                updatedVoice.isCloud = true
                coreDataAccessor.update(voice: updatedVoice)
            } else {
                allUploadsSucceeded = false
            }
        }

        // クラウドのみの音声データをローカルデータベースにダウンロード
        for voice in voicesToDownload {
            let result = await cloudUploader.downloadVoiceFile(id: voice.id)
            if result {
                coreDataAccessor.insert(voice: voice, isCloud: true)
            }
        }

        // updatedAtを比較して新しい方で上書き
        for localVoice in localVoices {
            if let cloudVoice = cloudVoices.first(where: { $0.id == localVoice.id }) {
                if cloudVoice.updatedAt > localVoice.updatedAt {
                    coreDataAccessor.update(voice: cloudVoice)
                } else if localVoice.updatedAt > cloudVoice.updatedAt {
                    let success = await cloudUploader.saveVoice(voice: localVoice)
                    if !success {
                        allUploadsSucceeded = false
                    }
                }
            }
        }

        return allUploadsSucceeded
    }

    func checkForDifferences() async -> Bool {
        // ローカルの音声データを全て取得
        let localVoices = coreDataAccessor.selectAllData()
        let localVoiceIds = Set(localVoices.map { $0.id })

        // クラウド上の音声データを全て取得
        let cloudVoices = await cloudUploader.fetchAllVoices()
        let cloudVoiceIds = Set(cloudVoices.map { $0.id })

        // 差分を検出
        var hasDifferences = false

        for localVoice in localVoices {
            if let cloudVoice = cloudVoices.first(where: { $0.id == localVoice.id }) {
                if cloudVoice.updatedAt != localVoice.updatedAt {
                    hasDifferences = true
                    break
                }
            } else {
                hasDifferences = true
                break
            }
        }

        if !hasDifferences {
            for cloudVoice in cloudVoices {
                if !localVoiceIds.contains(cloudVoice.id) {
                    hasDifferences = true
                    break
                }
            }
        }

        return hasDifferences
    }

    struct Voice: Equatable {
        var title: String
        var url: URL
        var id: UUID
        var text: String
        var createdAt: Date
        var updatedAt: Date
        var duration: Double
        var fileFormat: String
        var samplingFrequency: Double
        var quantizationBitDepth: Int16
        var numberOfChannels: Int16
        var isCloud: Bool
    }
}
