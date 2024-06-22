//
//  VoiceMemoRepository.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/06/22.
//

import Foundation

import Foundation

class VoiceMemoRepository {

    private let coreDataAccessor: VoiceMemoCoredataAccessor
    private let cloudUploader: CloudUploader

    init(coreDataAccessor: VoiceMemoCoredataAccessor = VoiceMemoCoredataAccessor(), cloudUploader: CloudUploader = CloudUploader()) {
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
            duration: state.duration,
            fileFormat: state.fileFormat,
            samplingFrequency: state.samplingFrequency,
            quantizationBitDepth: Int16(state.quantizationBitDepth),
            numberOfChannels: Int16(state.numberOfChannels)
        )
        coreDataAccessor.insert(voice: voice)
    }

    func selectAllData() -> [VoiceMemoReducer.State] {
        return coreDataAccessor.selectAllData().map { voice in
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
                url: voice.url,
                resultText: voice.text
            )
        }
        return nil
    }

    func delete(id: UUID) {
        coreDataAccessor.delete(id: id)
    }

    func update(state: VoiceMemoReducer.State) {
        let voice = Voice(
            title: state.title,
            url: state.url,
            id: state.uuid,
            text: state.text,
            createdAt: state.date,
            duration: state.duration,
            fileFormat: state.fileFormat,
            samplingFrequency: state.samplingFrequency,
            quantizationBitDepth: Int16(state.quantizationBitDepth),
            numberOfChannels: Int16(state.numberOfChannels)
        )
        coreDataAccessor.update(voice: voice)
    }

    func updateTitle(uuid: UUID, newTitle: String) {
        coreDataAccessor.updateTitle(uuid: uuid, newTitle: newTitle)
    }

    func uploadToCloud(uuid: UUID) async -> Bool {
        if let voice = coreDataAccessor.fetch(uuid: uuid) {
            let result = await cloudUploader.saveVoice(voice: voice)
            if result{
                coreDataAccessor.update(voice: voice)
            }
            return true
        } else {
            return false
        }
    }   

    struct Voice {
        var title: String
        var url: URL
        var id: UUID
        var text: String
        var createdAt: Date
        var duration: Double
        var fileFormat: String
        var samplingFrequency: Double
        var quantizationBitDepth: Int16
        var numberOfChannels: Int16
    }
}
