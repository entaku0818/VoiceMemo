//
//  MockVoiceMemoCoredataAccessor.swift
//  VoiLogTests
//
//  Created by 遠藤拓弥 on 2024/06/22.
//

import Foundation
@testable import VoiLog


class MockVoiceMemoCoredataAccessor: VoiceMemoCoredataAccessorProtocol {
    
    var insertedVoice: VoiceMemoRepository.Voice?
    var fetchedVoice: VoiceMemoRepository.Voice?
    var updatedVoice: VoiceMemoRepository.Voice?
    var fetchedVoices: [VoiceMemoRepository.Voice] = []

    var deletedId: UUID?
    var updatedTitle: (uuid: UUID, newTitle: String)?

    func insert(voice: VoiLog.VoiceMemoRepository.Voice, isCloud: Bool) {
        insertedVoice = voice
    }

    func selectAllData() -> [VoiceMemoRepository.Voice] {
        return fetchedVoices
    }

    func fetch(uuid: UUID) -> VoiceMemoRepository.Voice? {
        return fetchedVoice
    }

    func delete(id: UUID) {
        deletedId = id
    }

    func update(voice: VoiceMemoRepository.Voice) {
        updatedVoice = voice
    }

    func updateTitle(uuid: UUID, newTitle: String) {
        updatedTitle = (uuid, newTitle)
    }
}
