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

    func testRenderAIRecordingScreenshots() throws {
        for (language, code) in languages {
            let view = ScreenshotPageView(
                caption: language.screenshotCaption(for: .aiRecording),
                subtitle: language.screenshotSubtitle(for: .aiRecording),
                screen: .aiRecording,
                language: language
            ) {
                PhoneFrameView { MockAIRecordingView(language: language) }
            }
            try renderAndSave(view: view, filename: "\(code)_00_airecording.png")
        }
    }

    func testRenderPlaybackListScreenshots() throws {
        for (language, code) in languages {
            let view = ScreenshotPageView(
                caption: language.screenshotCaption(for: .playbackList),
                subtitle: language.screenshotSubtitle(for: .playbackList),
                screen: .playbackList,
                language: language
            ) {
                PhoneFrameView { MockPlaybackListView(language: language) }
            }
            try renderAndSave(view: view, filename: "\(code)_01_playbacklist.png")
        }
    }

    func testRenderTimestampedTranscriptionScreenshots() throws {
        for (language, code) in languages {
            let view = ScreenshotPageView(
                caption: language.screenshotCaption(for: .timestampedTranscription),
                subtitle: language.screenshotSubtitle(for: .timestampedTranscription),
                screen: .timestampedTranscription,
                language: language
            ) {
                PhoneFrameView { MockTimestampedTranscriptionView(language: language) }
            }
            try renderAndSave(view: view, filename: "\(code)_06_transcription.png")
        }
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

    func testRenderWaveformEditorScreenshots() throws {
        for (language, code) in languages {
            let view = ScreenshotPageView(
                caption: language.screenshotCaption(for: .waveformEditor),
                subtitle: language.screenshotSubtitle(for: .waveformEditor),
                screen: .waveformEditor,
                language: language
            ) {
                PhoneFrameView { MockWaveformEditorView(language: language) }
            }
            try renderAndSave(view: view, filename: "\(code)_03_waveformeditor.png")
        }
    }

    func testRenderBackgroundRecordingScreenshots() throws {
        for (language, code) in languages {
            let view = ScreenshotPageView(
                caption: language.screenshotCaption(for: .backgroundRecording),
                subtitle: language.screenshotSubtitle(for: .backgroundRecording),
                screen: .backgroundRecording,
                language: language
            ) {
                PhoneFrameView { MockBackgroundRecordingView(language: language) }
            }
            try renderAndSave(view: view, filename: "\(code)_04_backgroundrecording.png")
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

    func testRenderAITranscriptionScreenshots() throws {
        for (language, code) in languages {
            let view = ScreenshotPageView(
                caption: language.screenshotCaption(for: .aiTranscription),
                subtitle: language.screenshotSubtitle(for: .aiTranscription),
                screen: .aiTranscription,
                language: language
            ) {
                PhoneFrameView { MockAITranscriptionView(language: language) }
            }
            try renderAndSave(view: view, filename: "\(code)_07_aitranscription.png")
        }
    }

    // MARK: - iPad Screenshots

    func testRenderIPadScreenshots() throws {
        let screens: [(ScreenshotScreen, String)] = [
            (.aiRecording,              "00_airecording"),
            (.useCase,                  "02_usecase"),
            (.backgroundRecording,      "04_backgroundrecording"),
            (.timestampedTranscription, "06_transcription"),
            (.waveformEditor,           "03_waveformeditor"),
            (.playlist,                 "05_playlist"),
            (.playbackList,             "01_playbacklist"),
        ]
        for (language, code) in languages {
            for (screen, index) in screens {
                let view = ScreenshotPageView(
                    caption: language.screenshotCaption(for: screen),
                    subtitle: language.screenshotSubtitle(for: screen),
                    screen: screen,
                    language: language
                ) {
                    PhoneFrameView { MockAIRecordingView(language: language) }
                }
                try renderAndSave(view: view, filename: "\(code)_ipad_\(index).png", width: 1024, height: 1366, scale: 2.0)
            }
        }
    }

    private func renderAndSave<V: View>(view: V, filename: String, width: CGFloat = 430, height: CGFloat = 932, scale: CGFloat = 3.0) throws {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.proposedSize = ProposedViewSize(width: width, height: height)
        renderer.scale = scale

        guard let uiImage = renderer.uiImage,
              let pngData = uiImage.pngData() else {
            XCTFail("Failed to render \(filename)")
            return
        }

        let fileURL = outputDir.appendingPathComponent(filename)
        try pngData.write(to: fileURL)
        print("✓ \(filename): \(uiImage.size.width * scale)x\(uiImage.size.height * scale)px → \(fileURL.path)")
    }

    private func renderAndSave<V: View>(view: V, filename: String) throws {
        // iPhone 16 Pro Max: 440x956 logical pts @ 3x = 1320x2868px (APP_IPHONE_69)
        try renderAndSave(view: view, filename: filename, width: 440, height: 956, scale: 3.0)
    }
}
