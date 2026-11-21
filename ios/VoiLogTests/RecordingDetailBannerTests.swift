import XCTest
@testable import VoiLog

@MainActor
final class RecordingDetailBannerTests: XCTestCase {
    private let dedicatedUnit = "ca-app-pub-1234567890123456/1234567890"
    private let recordingUnit = "ca-app-pub-1234567890123456/0987654321"

    func testFreeUserUsesDedicatedUnitWhenConfigured() {
        XCTAssertEqual(
            VoiceMemoDetailView.bannerUnitId(configured: dedicatedUnit, fallback: recordingUnit, isPremium: false),
            dedicatedUnit
        )
    }

    func testFreeUserUsesRecordingUnitWhenDedicatedSettingIsMissing() {
        for configured in [nil, "", "$(RECORD_DETAIL_ADMOB_KEY)"] {
            XCTAssertEqual(
                VoiceMemoDetailView.bannerUnitId(configured: configured, fallback: recordingUnit, isPremium: false),
                recordingUnit
            )
        }
    }

    func testFreeUserHasNoBannerWhenNeitherUnitIsAvailable() {
        XCTAssertNil(VoiceMemoDetailView.bannerUnitId(configured: "", fallback: nil, isPremium: false))
    }

    func testPremiumUserHasNoBannerEvenWhenBothUnitsAreConfigured() {
        XCTAssertNil(VoiceMemoDetailView.bannerUnitId(configured: dedicatedUnit, fallback: recordingUnit, isPremium: true))
    }
}
