

import Foundation
@testable import VoiLog

class MockCloudUploader: CloudUploaderProtocol {
    
    var savedVoice: VoiceMemoRepository.Voice?
    var fetchedVoices: [VoiceMemoRepository.Voice] = []

    func saveVoice(voice: VoiceMemoRepository.Voice) async -> Bool {
        self.savedVoice = voice
        return true
    }

    func fetchAllVoices() async -> [VoiceMemoRepository.Voice] {
        return fetchedVoices
    }

    func deleteVoice(id: UUID) async -> Bool {
        return true
    }
}
