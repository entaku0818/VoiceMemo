import XCTest

final class AIConsentUITests: XCTestCase {
    func testJapaneseConsentOnIPad() { verifyConsent(language: "ja", minutesLabel: "議事録") }
    func testEnglishConsentOnIPad() { verifyConsent(language: "en", minutesLabel: "Minutes") }

    private func verifyConsent(language: String, minutesLabel: String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ai-consent-ui-test", "-AppleLanguages", "(\(language))", "-AppleLocale", language]
        app.launch()
        XCTAssertTrue(app.segmentedControls.buttons["AI"].waitForExistence(timeout: 15))
        app.segmentedControls.buttons["AI"].tap()
        let start = app.buttons["aiTranscription.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        checkAndCaptureSheet(app, language: language, purpose: "audio")
        app.buttons["aiConsent.decline"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["CONSENT_AUDIO_SUCCESS"].exists)
        start.tap()
        XCTAssertTrue(app.buttons["aiConsent.accept"].waitForExistence(timeout: 5))
        app.buttons["aiConsent.accept"].tap()
        XCTAssertTrue(app.staticTexts["CONSENT_AUDIO_SUCCESS"].waitForExistence(timeout: 5))

        // Audio consent must not suppress the text consent sheet.
        app.segmentedControls.buttons[minutesLabel].tap()
        let generate = app.buttons["aiMinutes.start"]
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        generate.tap()
        checkAndCaptureSheet(app, language: language, purpose: "minutes")
        app.buttons["aiConsent.decline"].tap()
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["CONSENT_MINUTES_SUCCESS"].exists)
        generate.tap()
        XCTAssertTrue(app.buttons["aiConsent.accept"].waitForExistence(timeout: 5))
        app.buttons["aiConsent.accept"].tap()
        XCTAssertTrue(app.staticTexts["CONSENT_MINUTES_SUCCESS"].waitForExistence(timeout: 5))
    }

    private func checkAndCaptureSheet(_ app: XCUIApplication, language: String, purpose: String) {
        XCTAssertTrue(app.buttons["aiConsent.accept"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["aiConsent.accept"].isHittable)
        XCTAssertTrue(app.buttons["aiConsent.decline"].isHittable)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Gemini API")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Google Cloud")).firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "iPad-\(language)-\(purpose)-consent"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
