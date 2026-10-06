import XCTest
import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import VoiLog

/// App Store 用スクリーンショットを ImageRenderer で書き出す。
///
/// 出力: /tmp/voilog_screenshots/<code>/ に App Store のファイル名で保存する
/// （<code> = ios/VoiLog/DebugMode/ScreenshotStrings/<code>.json のある言語すべて）。
/// - iPhone: `<n>_APP_IPHONE_67_<n>.png`（n = 0...7、0 はヒーロー）1320x2868
/// - iPad:   `<n>_APP_IPAD_PRO_3GEN_129_<n>.png`（n = 0...6）2048x2732
/// どれもアルファなし（App Store Connect はアルファ付き PNG を受け付けないことがある）。
/// 全ページ承認済みヒーローと同じデザイン（PromoScreenshotPageView.swift）で描く。
/// 出荷しない描画（iPhone の旧1枚目 aiRecording）は /tmp/voilog_screenshots/_extra/ に置く。
/// fastlane/screenshots への反映は ios/ci/export_screenshots.sh で行う（ja / en-US のヒーローは上書きしない）。
///
/// 一部の言語だけ描くとき: `TEST_RUNNER_SCREENSHOT_LANGS=ja,en xcodebuild test ...`
@MainActor
final class ScreenshotRenderTests: XCTestCase {

    private let outputDir = URL(fileURLWithPath: "/tmp/voilog_screenshots")

    private var languages: [AppLanguage] {
        let all = AppLanguage.allCases
        guard let filter = ProcessInfo.processInfo.environment["SCREENSHOT_LANGS"], !filter.isEmpty else {
            return all
        }
        let codes = Set(filter.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
        return all.filter { codes.contains($0.code) }
    }

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    func testStringsAreBundledForExistingLanguages() {
        let codes = Set(AppLanguage.allCases.map(\.code))
        for code in ["en", "ja", "de", "es", "fr", "it", "pt-PT", "ru", "tr", "vi", "zh-Hans", "zh-Hant"] {
            XCTAssertTrue(codes.contains(code), "\(code).json is not in the app bundle")
        }
    }

    func testEveryLanguageHasAllEnglishKeys() {
        guard let english = ScreenshotStrings.tables["en"] else {
            return XCTFail("en.json is missing")
        }
        for language in AppLanguage.allCases {
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

    /// 出荷するページの見出し2行とチップ3つは、英語へのフォールバックではなく各言語で翻訳されていること
    func testEveryLanguageHasPromoTextsForShippedPages() {
        let screens = Set(ScreenshotSlots.iPhone + ScreenshotSlots.iPad)
        for language in AppLanguage.allCases {
            let table = ScreenshotStrings.tables[language.code] ?? [:]
            for screen in screens {
                for suffix in ["line1", "line2"] {
                    let text = table["promo_\(screen.rawValue)_\(suffix)"] as? String ?? ""
                    XCTAssertFalse(text.isEmpty, "\(language.code): promo_\(screen.rawValue)_\(suffix) is missing")
                }
                let chips = table["promo_\(screen.rawValue)_chips"] as? [String] ?? []
                XCTAssertEqual(chips.count, 3, "\(language.code): promo_\(screen.rawValue)_chips must have 3 items")
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
                    view: PromoScreenshotPageView(screen: screen, language: language),
                    to: iPhoneURL(language: language, slot: index + 1)
                )
            }
            // 旧1枚目（ヒーローに置き換えたので出荷しない）。比較用に残す
            try renderAndSave(
                view: PromoScreenshotPageView(screen: .aiRecording, language: language),
                to: outputDir.appendingPathComponent("_extra/\(language.code)_iphone_airecording.png")
            )
        }
    }

    // MARK: - iPad

    func testRenderIPadScreenshots() throws {
        let size = PromoMetrics.iPad.canvasSize
        for language in languages {
            for (index, screen) in ScreenshotSlots.iPad.enumerated() {
                let url = outputDir.appendingPathComponent("\(language.code)/\(index)_APP_IPAD_PRO_3GEN_129_\(index).png")
                try renderAndSave(
                    view: PromoScreenshotPageView(screen: screen, language: language, device: .iPad),
                    to: url,
                    width: size.width, height: size.height, scale: 2.0
                )
            }
        }
    }

    // MARK: - Helpers

    private func iPhoneURL(language: AppLanguage, slot: Int) -> URL {
        outputDir.appendingPathComponent("\(language.code)/\(slot)_APP_IPHONE_67_\(slot).png")
    }

    /// iPhone 16 Pro Max / 17 Pro Max: 440x956pt @3x = 1320x2868px
    private func renderAndSave<V: View>(view: V, to url: URL, width: CGFloat = 440, height: CGFloat = 956, scale: CGFloat = 3.0) throws {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.proposedSize = ProposedViewSize(width: width, height: height)
        renderer.scale = scale

        guard let uiImage = renderer.uiImage,
              let pngData = Self.opaquePNG(uiImage) else {
            XCTFail("Failed to render \(url.lastPathComponent)")
            return
        }

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try pngData.write(to: url)
        print("✓ \(url.path): \(uiImage.size.width * scale)x\(uiImage.size.height * scale)px")
    }

    /// 白で塗ってから描き直し、アルファチャンネルのない（RGB の）PNG にする。
    /// UIImage.pngData() は不透明な画像でも RGBA で書き出すため、noneSkipLast の CGContext と ImageIO を使う
    private static func opaquePNG(_ image: UIImage) -> Data? {
        guard let source = image.cgImage else { return nil }
        let width = source.width
        let height = source.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)
        context.draw(source, in: rect)
        guard let opaque = context.makeImage() else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, opaque, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
