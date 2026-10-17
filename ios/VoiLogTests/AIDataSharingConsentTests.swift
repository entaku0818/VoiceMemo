import XCTest
import ComposableArchitecture
@testable import VoiLog

final class AIDataSharingConsentTests: XCTestCase {
    func testEveryLiveNetworkEntryRejectsLegacyConsent() async {
        await withDependencies {
            $0.userDefaults.bool = { $0 == "ai_data_sharing_consent_v1" }
        } operation: {
            let client = TranscriptionClient.liveValue
            let operations: [() async throws -> Void] = [
                { _ = try await client.uploadURL("token", "m4a") },
                { try await client.uploadAudio(URL(fileURLWithPath: "/missing"), "invalid-url", "audio/mp4") },
                { _ = try await client.transcribe("token", "blob", "en") },
                { _ = try await client.generateMinutes("token", "private text", "en") }
            ]
            for operation in operations {
                do {
                    try await operation()
                    XCTFail("Network entry must reject missing consent")
                } catch {
                    guard case .consentRequired = error as? TranscriptionError else {
                        XCTFail("Expected consentRequired before file/network access: \(error)")
                        continue
                    }
                }
            }
        }
    }

    func testConsentIsPurposeSpecific() throws {
        try withDependencies {
            $0.userDefaults.bool = { $0 == AIDataSharingConsent.transcriptionKey }
        } operation: {
            XCTAssertNoThrow(try AIDataSharingConsent.require(.transcription))
            XCTAssertThrowsError(try AIDataSharingConsent.require(.minutes))
        }
        try withDependencies {
            $0.userDefaults.bool = { $0 == AIDataSharingConsent.minutesKey }
        } operation: {
            XCTAssertNoThrow(try AIDataSharingConsent.require(.minutes))
            XCTAssertThrowsError(try AIDataSharingConsent.require(.transcription))
        }
    }
}
