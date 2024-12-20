//
//  AudioPlayer.swift
//  VoiceMemo
//
//  Created by 遠藤拓弥 on 4.9.2022.
//

@preconcurrency import AVFoundation
import ComposableArchitecture
import Dependencies
import Foundation
import XCTestDynamicOverlay

struct AudioPlayerClient {
    var play: @Sendable (URL, Double, AudioPlayerClient.PlaybackSpeed, Bool) async throws -> Bool
    var stop: @Sendable () async throws -> Bool
    var getCurrentTime: @Sendable () async throws -> TimeInterval
}

extension AudioPlayerClient {
    struct PlaybackInfo {
        var url: URL
        var position: Double
        var speed: AudioPlayerClient.PlaybackSpeed
    }
}

extension AudioPlayerClient: TestDependencyKey {
    static let previewValue = Self(
        play: { _, _, _, _ in
            try await Task.sleep(nanoseconds: NSEC_PER_SEC * 5)
            return true
        },
        stop: {
            return true
        },
        getCurrentTime: {
            return 60
        }
    )

    static let testValue = Self(
        play: unimplemented("\(Self.self).play"),
        stop: unimplemented("\(Self.self).stop"),
        getCurrentTime: unimplemented("\(Self.self).getCurrentTime")
    )
}
extension DependencyValues {
    var audioPlayer: AudioPlayerClient {
        get { self[AudioPlayerClient.self] }
        set { self[AudioPlayerClient.self] = newValue }
    }
}

extension AudioPlayerClient: DependencyKey {

    static var liveValue: Self {
        let audioPlayer = AudioPlayer()
        return Self(
            play: { url, startTime, playSpeed, isLooping in
                return try await audioPlayer.play(url: url, startTime: startTime, rate: playSpeed, isLooping: isLooping)
            },
            stop: {
                return await audioPlayer.stop()
            },
            getCurrentTime: {
                return await audioPlayer.getCurrentTime()
            }
        )
    }
}

private actor AudioPlayer {
    var player: AVAudioPlayer?
    var delegate: Delegate?

    func play(url: URL, startTime: Double, rate: AudioPlayerClient.PlaybackSpeed, isLooping: Bool) async throws -> Bool {

        // ファイルの存在チェック
        let documentsPath = NSHomeDirectory() + "/Documents/" + url.lastPathComponent
        let fileURL = URL(fileURLWithPath: documentsPath)

        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            throw NSError(domain: "FileNotFound", code: 404, userInfo: [NSLocalizedDescriptionKey: "The file does not exist."])
        }

        let stream = AsyncThrowingStream<Bool, Error> { continuation in
            do {
                self.delegate = try Delegate(didFinishPlaying: { [weak self] flag in
                    continuation.yield(flag)
                    continuation.finish()
                    try? AVAudioSession.sharedInstance().setActive(false)
                }, decodeErrorDidOccur: { error in
                    continuation.finish(throwing: error)
                    try? AVAudioSession.sharedInstance().setActive(false)
                })
                try AVAudioSession.sharedInstance().setActive(true)
                try AVAudioSession.sharedInstance().setCategory(.playback)
                self.player = try AVAudioPlayer(contentsOf: fileURL)
                guard let player = player else { return }
                player.delegate = delegate
                player.currentTime = startTime
                player.enableRate = true
                player.rate = rate.rawValue
                player.numberOfLoops = isLooping ? -1 : 0

                player.play()
            } catch {
                continuation.finish(throwing: error)
            }
        }

        for try await didFinish in stream {
            return didFinish
        }
        throw CancellationError()
    }

    func listFilesInDocumentsDirectory() -> [String] {
        let documentsPath = NSHomeDirectory() + "/Documents/"
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(atPath: documentsPath)
            return fileURLs
        } catch {
            print("Error while listing files in Documents directory: \(error)")
            return []
        }
    }

    func stop() async -> Bool {
        guard let player = player else { return false }
        player.stop()
        return true
    }

    func getCurrentTime() async -> TimeInterval {
        player?.currentTime ?? 0
    }
}

private final class Delegate: NSObject, AVAudioPlayerDelegate, Sendable {
    let didFinishPlaying: @Sendable (Bool) -> Void
    let decodeErrorDidOccur: @Sendable (Error?) -> Void

    init(
        didFinishPlaying: @escaping @Sendable (Bool) -> Void,
        decodeErrorDidOccur: @escaping @Sendable (Error?) -> Void
    ) throws {
        self.didFinishPlaying = didFinishPlaying
        self.decodeErrorDidOccur = decodeErrorDidOccur
        super.init()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.didFinishPlaying(flag)
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        self.decodeErrorDidOccur(error)
    }
}

extension AudioPlayerClient {
    enum PlaybackSpeed: Float, CaseIterable {
        case slowest = 0.5
        case slower = 0.75
        case normal = 1.0
        case faster = 1.25
        case fast = 1.5
        case fasterStill = 1.75
        case fastest = 2.0

        var description: String {
            switch self {
            case .slowest:
                return "0.5x"
            case .slower:
                return "0.75x"
            case .normal:
                return "1x (標準)"
            case .faster:
                return "1.25x"
            case .fast:
                return "1.5x"
            case .fasterStill:
                return "1.75x"
            case .fastest:
                return "2x"
            }
        }
    }
}

extension AudioPlayerClient.PlaybackSpeed {
    func next() -> AudioPlayerClient.PlaybackSpeed {
        let allCases = AudioPlayerClient.PlaybackSpeed.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else { return .normal }
        let nextIndex = allCases.index(after: currentIndex)
        return allCases.indices.contains(nextIndex) ? allCases[nextIndex] : allCases.first!
    }
}
