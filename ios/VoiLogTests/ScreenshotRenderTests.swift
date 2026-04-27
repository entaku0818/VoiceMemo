import XCTest
import SwiftUI
@testable import VoiLog

@MainActor
final class ScreenshotRenderTests: XCTestCase {

    private let outputDir = URL(fileURLWithPath: "/tmp/voilog_screenshots")

    private let languages: [(AppLanguage, String)] = [
        (.japanese,          "ja"),
        (.english,           "en"),
        (.german,            "de"),
        (.spanish,           "es"),
        (.french,            "fr"),
        (.italian,           "it"),
        (.portuguese,        "pt"),
        (.russian,           "ru"),
        (.turkish,           "tr"),
        (.vietnamese,        "vi"),
        (.chineseSimplified, "zh_hans"),
        (.chineseTraditional,"zh_hant"),
    ]

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    func testRenderPlaylistScreenshots() throws {
        for (language, code) in languages {
            let view = ScreenshotPageView(
                caption: language.screenshotCaption(for: .playlist),
                subtitle: language.screenshotSubtitle(for: .playlist),
                screen: .playlist,
                language: language
            ) {
                PhoneFrameView { MockPlaylistView(language: language) }
            }
            try renderAndSave(view: view, filename: "\(code)_05_playlist.png")
        }
    }

    func testRenderUseCaseScreenshots() throws {
        for (language, code) in languages {
            let view = ScreenshotPageView(
                caption: language.screenshotCaption(for: .useCase),
                subtitle: language.screenshotSubtitle(for: .useCase),
                screen: .useCase,
                language: language
            ) {
                PhoneFrameView { MockUseCaseView(language: language) }
            }
            try renderAndSave(view: view, filename: "\(code)_02_usecase.png")
        }
    }

    private func renderAndSave<V: View>(view: V, filename: String) throws {
        // iPhone 15 Plus: 430x932 logical pts @ 3x = 1290x2796px
        let renderer = ImageRenderer(content: view.frame(width: 430, height: 932))
        renderer.proposedSize = ProposedViewSize(width: 430, height: 932)
        renderer.scale = 3.0

        guard let uiImage = renderer.uiImage,
              let pngData = uiImage.pngData() else {
            XCTFail("Failed to render \(filename)")
            return
        }

        let fileURL = outputDir.appendingPathComponent(filename)
        try pngData.write(to: fileURL)
        print("✓ \(filename): \(uiImage.size.width * 3)x\(uiImage.size.height * 3)px → \(fileURL.path)")
    }
}
