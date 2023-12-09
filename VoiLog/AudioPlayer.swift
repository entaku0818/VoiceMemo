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
    var changeSpeed: @Sendable (AudioPlayerClient.PlaybackSpeed) async throws -> Bool
    var stop: @Sendable () async throws -> Bool
    var seek: @Sendable (_ time: TimeInterval) async throws -> Bool
    var getCurrentTime: @Sendable () async throws -> TimeInterval
    var setLooping: @Sendable (Bool) async throws -> Void
}


extension AudioPlayerClient{
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
        changeSpeed: { _ in
            try await Task.sleep(nanoseconds: NSEC_PER_SEC * 5)
            return true
        },
        stop: {
            return true
        },
        seek: { _ in
            return true
        },
        getCurrentTime: {
            return 60
        },
        setLooping: { _ in
            try await Task.sleep(nanoseconds: NSEC_PER_SEC * 1)
        }
    )

    static let testValue = Self(
        play: unimplemented("\(Self.self).play"),
        changeSpeed: unimplemented("\(Self.self).changeSpeed"),
        stop: unimplemented("\(Self.self).stop"),
        seek: unimplemented("\(Self.self).seek"),
        getCurrentTime: unimplemented("\(Self.self).getCurrentTime"),
        setLooping: unimplemented("\(Self.self).setLooping")
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
        let audioPlayer: AudioPlayer = AudioPlayer()
        return Self(
            play: { url, startTime, playSpeed, isLooping in
                await audioPlayer.setLooping(isLooping)
                return try await audioPlayer.play(url: url, startTime: startTime, rate: playSpeed)
            },
            changeSpeed: { playSpeed in
                return await audioPlayer.changePlaybackRate(to: playSpeed)
            },
            stop: {
                return await audioPlayer.stop()
            },
            seek: { time in
                return await audioPlayer.seek(to: time)
            },
            getCurrentTime: {
                return await audioPlayer.getCurrentTime()
            },
            setLooping: { isLooping in
                await audioPlayer.setLooping(isLooping)
            }
        )
    }
}


private actor AudioPlayer {
    var player: AVAudioPlayer?
    var delegate: Delegate?



    func play(url: URL, startTime: Double, rate: AudioPlayerClient.PlaybackSpeed) async throws -> Bool {

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
              let documentsPath = NSHomeDirectory() + "/Documents/" + url.lastPathComponent
              self.player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: documentsPath))
              guard let player = player else { return }
              player.delegate = delegate
              player.currentTime = startTime
              player.enableRate = true
              player.rate = rate.rawValue
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

    func changePlaybackRate(to rate: AudioPlayerClient.PlaybackSpeed) async -> Bool {
        guard let player = player else { return false}
        player.enableRate = true
        player.rate = rate.rawValue


        return true

    }



    func stop() async -> Bool {
        guard let player = player else { return false }
        player.stop()
        return true
    }

    func seek(to time: TimeInterval) async -> Bool {
        guard let player = player else { return false }

        let isPlaying = player.isPlaying
        player.currentTime = time

        // 再生中であれば、再生を続ける
        if isPlaying {
            player.play()
        }

        return true
    }

    func getCurrentTime() async -> TimeInterval {
        return player?.currentTime ?? 0
    }

    func setLooping(_ looping: Bool) async {
        player?.numberOfLoops = looping ? -1 : 0
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
