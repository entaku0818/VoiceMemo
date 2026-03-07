import AVFoundation
import SwiftUI

enum AudioExporter {

    enum Format {
        case m4a
        case wav

        var fileExtension: String {
            switch self {
            case .m4a: return "m4a"
            case .wav: return "wav"
            }
        }
    }

    static func convert(from url: URL, to format: Format) async throws -> URL {
        if url.pathExtension.lowercased() == format.fileExtension {
            return url
        }
        switch format {
        case .m4a: return try await exportM4A(from: url)
        case .wav: return try await exportWAV(from: url)
        }
    }

    // MARK: - Private

    private static func exportM4A(from url: URL) async throws -> URL {
        let outputURL = tempURL(for: url, ext: "m4a")
        let asset = AVURLAsset(url: url)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ExportError.sessionCreationFailed
        }
        try await session.export(to: outputURL, as: .m4a)
        return outputURL
    }

    private static func exportWAV(from url: URL) async throws -> URL {
        let outputURL = tempURL(for: url, ext: "wav")
        let sourceFile = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sourceFile.processingFormat.sampleRate,
            channels: sourceFile.processingFormat.channelCount,
            interleaved: false
        )!
        let destFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)
        let buffer = AVAudioPCMBuffer(
            pcmFormat: sourceFile.processingFormat,
            frameCapacity: AVAudioFrameCount(sourceFile.length)
        )!
        try sourceFile.read(into: buffer)
        try destFile.write(from: buffer)
        return outputURL
    }

    private static func tempURL(for url: URL, ext: String) -> URL {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(url.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(ext)
        try? FileManager.default.removeItem(at: output)
        return output
    }

    enum ExportError: LocalizedError {
        case sessionCreationFailed

        var errorDescription: String? {
            "エクスポートセッションの作成に失敗しました"
        }
    }
}

#if canImport(UIKit)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
