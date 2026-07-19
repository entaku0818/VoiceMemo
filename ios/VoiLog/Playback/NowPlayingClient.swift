//
//  NowPlayingClient.swift
//  VoiLog
//
//  ロック画面/コントロールセンターの再生情報表示（issue #190）。
//  MPNowPlayingInfoCenterはiOS 4以来の安定APIで、Xcode 27 beta(iOS 27 SDK)専用の
//  新しい `NowPlaying` フレームワークは現行の安定版Xcodeではビルドできないため使わない。
//

import ComposableArchitecture
import Foundation
import MediaPlayer

struct NowPlayingInfo: Equatable, Sendable {
    var title: String
    var duration: TimeInterval
    var elapsedTime: TimeInterval
    var isPlaying: Bool
}

struct NowPlayingClient {
    /// `nil` を渡すとロック画面/コントロールセンターの再生情報を消去する。
    var update: @Sendable (NowPlayingInfo?) -> Void
}

extension NowPlayingClient: TestDependencyKey {
    static let previewValue = Self(update: { _ in })
    static let testValue = Self(update: unimplemented("\(Self.self).update"))
}

extension DependencyValues {
    var nowPlayingClient: NowPlayingClient {
        get { self[NowPlayingClient.self] }
        set { self[NowPlayingClient.self] = newValue }
    }
}

extension NowPlayingClient: DependencyKey {
    static let liveValue = Self(update: { info in
        guard let info else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: info.title,
            MPMediaItemPropertyPlaybackDuration: info.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: info.elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: info.isPlaying ? 1.0 : 0.0
        ]
    })
}
