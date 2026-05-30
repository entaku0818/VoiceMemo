//
//  AppIconScreenshotTests.swift
//  VoiLogUITests
//
//  Created by Claude on 2026.05.25.
//

import XCTest

final class AppIconScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func test_captureAppIconSettingView() throws {
        // Wait for app to load
        sleep(2)

        // Tap the 設定 tab
        let settingsTab = app.tabBars.buttons["設定"]
        if settingsTab.exists {
            settingsTab.tap()
        } else {
            // Try by index (4th tab)
            app.tabBars.buttons.element(boundBy: 3).tap()
        }

        sleep(1)

        // Take screenshot of settings screen
        let settingsScreenshot = XCTAttachment(screenshot: app.screenshot())
        settingsScreenshot.name = "settings_screen"
        settingsScreenshot.lifetime = .keepAlways
        add(settingsScreenshot)

        // Scroll down or tap the アイコンカスタマイズ row
        let iconCustomizeCell = app.cells.containing(.staticText, identifier: "アイコンカスタマイズ").firstMatch
        if iconCustomizeCell.exists {
            iconCustomizeCell.tap()
        } else {
            // Try finding by text
            let iconText = app.staticTexts["アイコンカスタマイズ"]
            if iconText.exists {
                iconText.tap()
            }
        }

        sleep(1)

        // Take screenshot of icon customization view
        let iconViewScreenshot = XCTAttachment(screenshot: app.screenshot())
        iconViewScreenshot.name = "app_icon_setting_view"
        iconViewScreenshot.lifetime = .keepAlways
        add(iconViewScreenshot)
    }
}
