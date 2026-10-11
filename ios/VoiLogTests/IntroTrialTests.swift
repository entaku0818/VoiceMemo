import XCTest
@testable import VoiLog

/// 課金画面のトライアル表示の切り替え（issue #232）
final class IntroTrialTests: XCTestCase {

    // MARK: - IntroTrial.make

    func testWeekFreeTrial_eligible_isSevenDays() {
        XCTAssertEqual(IntroTrial.make(isFreeTrial: true, unit: .week, value: 1, eligibility: .eligible), .days(7))
    }

    func testDayFreeTrial_eligible_usesDays() {
        XCTAssertEqual(IntroTrial.make(isFreeTrial: true, unit: .day, value: 3, eligibility: .eligible), .days(3))
    }

    func testMonthOrYearFreeTrial_doesNotConvertToDays() {
        XCTAssertEqual(IntroTrial.make(isFreeTrial: true, unit: .month, value: 1, eligibility: .eligible), .unspecifiedLength)
        XCTAssertEqual(IntroTrial.make(isFreeTrial: true, unit: .year, value: 1, eligibility: .eligible), .unspecifiedLength)
    }

    func testNotShown_whenUserIsNotEligible() {
        // 過去にトライアルを使った人・判定できない人にはトライアル表記を出さない
        for eligibility: IntroTrial.Eligibility in [.ineligible, .unknown, .noIntroOfferExists] {
            XCTAssertNil(IntroTrial.make(isFreeTrial: true, unit: .week, value: 1, eligibility: eligibility), "\(eligibility)")
        }
    }

    func testNotShown_forPaidIntroOffer() {
        // 「最初の1か月¥100」のような有料のお試し価格は「無料」と表示しない
        XCTAssertNil(IntroTrial.make(isFreeTrial: false, unit: .month, value: 1, eligibility: .eligible))
    }

    func testNotShown_whenPeriodIsUnknownOrZero() {
        XCTAssertNil(IntroTrial.make(isFreeTrial: true, unit: nil, value: 1, eligibility: .eligible))
        XCTAssertNil(IntroTrial.make(isFreeTrial: true, unit: .day, value: 0, eligibility: .eligible))
    }

    // MARK: - PaywallCopy

    func testCtaTitle_withTrial_mentionsDays_andDiffersFromNoTrial() {
        let withTrial = PaywallCopy.ctaTitle(isAnnual: true, trial: .days(7))
        let withoutTrial = PaywallCopy.ctaTitle(isAnnual: true, trial: nil)
        XCTAssertTrue(withTrial.contains("7"), withTrial)
        XCTAssertFalse(withoutTrial.contains("7"), withoutTrial)
        XCTAssertNotEqual(withTrial, withoutTrial)
    }

    func testCtaTitle_withoutTrial_differsByPlan() {
        XCTAssertNotEqual(
            PaywallCopy.ctaTitle(isAnnual: true, trial: nil),
            PaywallCopy.ctaTitle(isAnnual: false, trial: nil)
        )
    }

    func testCtaTitle_usesTrialLengthFromStoreKit() {
        XCTAssertTrue(PaywallCopy.ctaTitle(isAnnual: false, trial: .days(14)).contains("14"))
    }

    func testTrialBadge_isNilWithoutTrial() {
        XCTAssertNil(PaywallCopy.trialBadge(nil))
        XCTAssertEqual(PaywallCopy.trialBadge(.days(7))?.contains("7"), true)
        XCTAssertNotNil(PaywallCopy.trialBadge(.unspecifiedLength))
    }

    func testDisclosure_containsPrice_andDiffersWithTrial() {
        let withTrial = PaywallCopy.disclosure(price: "¥9,000", isAnnual: true, trial: .days(7))
        let withoutTrial = PaywallCopy.disclosure(price: "¥9,000", isAnnual: true, trial: nil)
        XCTAssertTrue(withTrial.contains("¥9,000"), withTrial)
        XCTAssertTrue(withoutTrial.contains("¥9,000"), withoutTrial)
        XCTAssertNotEqual(withTrial, withoutTrial)
    }

    func testDisclosure_fallsBackWhenPriceIsMissing() {
        let text = PaywallCopy.disclosure(price: "", isAnnual: false, trial: nil)
        XCTAssertFalse(text.contains("%@"), text)
        XCTAssertFalse(text.isEmpty)
    }

    // MARK: - 課金画面の外のボタン（issue #233）

    func testEntryButton_withTrial_isSameAsAnnualTrialCta() {
        XCTAssertEqual(
            PaywallCopy.entryButtonTitle(annualTrial: .days(7)),
            PaywallCopy.ctaTitle(isAnnual: true, trial: .days(7))
        )
    }

    func testEntryButton_withoutTrial_doesNotMentionFree() {
        let title = PaywallCopy.entryButtonTitle(annualTrial: nil)
        XCTAssertNotEqual(title, PaywallCopy.entryButtonTitle(annualTrial: .days(7)))
        XCTAssertNotEqual(title, PaywallCopy.entryButtonTitle(annualTrial: .unspecifiedLength))
        XCTAssertFalse(title.contains("無料"), title)
        XCTAssertFalse(title.contains("7"), title)
    }

    // MARK: - 英語の文言（ja/en 必須）

    func testEnglishTrialStrings() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let english = try XCTUnwrap(Bundle(path: path))
        let cta = String(format: english.localizedString(forKey: "%lld日間無料で試す", value: nil, table: "Premium"), 7)
        XCTAssertEqual(cta, "Try Free for 7 Days")
        let disclosure = String(
            format: english.localizedString(
                forKey: "無料トライアル終了後、%@で自動的に課金されます。更新日の24時間前までにAppleのサブスクリプション設定からいつでもキャンセルできます。",
                value: nil,
                table: "Premium"
            ),
            "$59.99/ year"
        )
        XCTAssertTrue(disclosure.hasPrefix("After the free trial ends, you will be charged $59.99/ year automatically."), disclosure)
        XCTAssertEqual(english.localizedString(forKey: "プレミアムプランを見る", value: nil, table: "Premium"), "See Premium Plans")
    }
}
