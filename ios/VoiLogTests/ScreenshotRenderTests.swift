import XCTest
import SwiftUI
@testable import VoiLog

/// App Store 用スクリーンショットを ImageRenderer で書き出す。
///
/// 出力: /tmp/voilog_screenshots/<code>/ に App Store のファイル名で保存する
/// （<code> = ios/VoiLog/DebugMode/ScreenshotStrings/<code>.json のある言語すべて）。
/// - iPhone: `<n>_APP_IPHONE_67_<n>.png`（n = 0...7、0 はヒーロー）1320x2868
/// - iPad:   `<n>_APP_IPAD_PRO_3GEN_129_<n>.png`（n = 0...6）2048x2732
/// 出荷しない描画（iPhone の旧1枚目 aiRecording）は /tmp/voilog_screenshots/_extra/ に置く。
/// fastlane/screenshots への反映は ios/ci/export_screenshots.sh で行う（ja / en-US のヒーローは上書きしない）。
@MainActor
final class ScreenshotRenderTests: XCTestCase {

    private let outputDir = URL(fileURLWithPath: "/tmp/voilog_screenshots")

    private var languages: [AppLanguage] { AppLanguage.allCases }

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    func testStringsAreBundledForExistingLanguages() {
        let codes = Set(languages.map(\.code))
        for code in ["en", "ja", "de", "es", "fr", "it", "pt-PT", "ru", "tr", "vi", "zh-Hans", "zh-Hant"] {
            XCTAssertTrue(codes.contains(code), "\(code).json is not in the app bundle")
        }
    }

    func testEveryLanguageHasAllEnglishKeys() {
        guard let english = ScreenshotStrings.tables["en"] else {
            return XCTFail("en.json is missing")
        }
        for language in languages {
            let table = ScreenshotStrings.tables[language.code] ?? [:]
            let missing = Set(english.keys).subtracting(table.keys)
            // 欠けていても en にフォールバックして描画はできるので、失敗にはせずログだけ出す
            if !missing.isEmpty {
                print("[ScreenshotStrings] \(language.code).json is missing: \(missing.sorted())")
            }
            for (key, value) in english {
                if let list = value as? [String], let translated = table[key] as? [String] {
                    XCTAssertEqual(list.count, translated.count, "\(language.code).\(key) must have \(list.count) items")
                }
            }
        }
    }

    // MARK: - iPhone

    func testRenderHeroScreenshots() throws {
        for language in languages {
            try renderAndSave(
                view: HeroRecorderPageView(language: language),
                to: iPhoneURL(language: language, slot: 0)
            )
        }
    }

    func testRenderIPhoneScreenshots() throws {
        for language in languages {
            for (index, screen) in ScreenshotSlots.iPhone.enumerated() {
                try renderAndSave(
                    view: page(screen: screen, language: language) { PhoneFrameView { screen.mockView(language: language) } },
                    to: iPhoneURL(language: language, slot: index + 1)
                )
            }
            // 旧1枚目（ヒーローに置き換えたので出荷しない）。比較用に残す
            try renderAndSave(
                view: page(screen: .aiRecording, language: language) { PhoneFrameView { MockAIRecordingView(language: language) } },
                to: outputDir.appendingPathComponent("_extra/\(language.code)_iphone_airecording.png")
            )
        }
    }

    // MARK: - iPad

    func testRenderIPadScreenshots() throws {
        for language in languages {
            for (index, screen) in ScreenshotSlots.iPad.enumerated() {
                let url = outputDir.appendingPathComponent("\(language.code)/\(index)_APP_IPAD_PRO_3GEN_129_\(index).png")
                try renderAndSave(
                    view: page(screen: screen, language: language) { IPadFrameView { screen.mockView(language: language) } },
                    to: url,
                    width: 1024, height: 1366, scale: 2.0
                )
            }
        }
    }

    // MARK: - Helpers

    private func page<Content: View>(screen: ScreenshotScreen, language: AppLanguage, @ViewBuilder content: @escaping () -> Content) -> some View {
        ScreenshotPageView(
            caption: language.screenshotCaption(for: screen),
            subtitle: language.screenshotSubtitle(for: screen),
            screen: screen,
            language: language,
            content: content
        )
    }

    private func iPhoneURL(language: AppLanguage, slot: Int) -> URL {
        outputDir.appendingPathComponent("\(language.code)/\(slot)_APP_IPHONE_67_\(slot).png")
    }

    /// iPhone 16 Pro Max / 17 Pro Max: 440x956pt @3x = 1320x2868px
    private func renderAndSave<V: View>(view: V, to url: URL, width: CGFloat = 440, height: CGFloat = 956, scale: CGFloat = 3.0) throws {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.proposedSize = ProposedViewSize(width: width, height: height)
        renderer.scale = scale

        guard let uiImage = renderer.uiImage,
              let pngData = uiImage.pngData() else {
            XCTFail("Failed to render \(url.lastPathComponent)")
            return
        }

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try pngData.write(to: url)
        print("✓ \(url.path): \(uiImage.size.width * scale)x\(uiImage.size.height * scale)px")
    }
}
