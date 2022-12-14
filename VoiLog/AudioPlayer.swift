//
//  AudioPlayer.swift
//  VoiceMemo
//
//  Created by 遠藤拓弥 on 4.9.2022.
//

@preconcurrency import AVFoundation
import ComposableArchitecture

struct AudioPlayerClient {
  var play: @Sendable (URL) async throws -> Bool
}

extension AudioPlayerClient {
  static let live = Self { url in
    let stream = AsyncThrowingStream<Bool, Error> { continuation in
      do {
        let delegate = try Delegate(
          url: url,
          didFinishPlaying: { successful in
            continuation.yield(successful)
            continuation.finish()
          },
          decodeErrorDidOccur: { error in
            continuation.finish(throwing: error)
              debugPrint(error?.localizedDescription)
          }
        )

        delegate.player.play()
        continuation.onTermination = { _ in
          delegate.player.stop()
        }
      } catch {
        continuation.finish(throwing: error)
          debugPrint(error.localizedDescription)
      }
    }
    return try await stream.first(where: { _ in true }) ?? false
  }
}

private final class Delegate: NSObject, AVAudioPlayerDelegate, Sendable {
  let didFinishPlaying: @Sendable (Bool) -> Void
  let decodeErrorDidOccur: @Sendable (Error?) -> Void
  let player: AVAudioPlayer

  init(
    url: URL,
    didFinishPlaying: @escaping @Sendable (Bool) -> Void,
    decodeErrorDidOccur: @escaping @Sendable (Error?) -> Void
  ) throws {
    try AVAudioSession.sharedInstance().setActive(true)
    try AVAudioSession.sharedInstance().setCategory(.playback)
    self.didFinishPlaying = didFinishPlaying
    self.decodeErrorDidOccur = decodeErrorDidOccur
    let documentsPath = NSHomeDirectory() + "/Documents/" + url.lastPathComponent

    self.player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: documentsPath))
    super.init()
    self.player.delegate = self
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    self.didFinishPlaying(flag)
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    self.decodeErrorDidOccur(error)
  }
}
