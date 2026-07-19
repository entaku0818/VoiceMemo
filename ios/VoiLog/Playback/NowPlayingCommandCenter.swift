//
//  NowPlayingCommandCenter.swift
//  VoiLog
//
//  ロック画面/コントロールセンターの再生/一時停止操作（MPRemoteCommandCenter）を
//  PlaybackFeatureに伝える（issue #190）。
//

import ComposableArchitecture
import MediaPlayer

@MainActor
final class NowPlayingCommandCenter {
    static let shared = NowPlayingCommandCenter()

    private var isConfigured = false

    private init() {}

    func configure(store: StoreOf<VoiceAppFeature> = AppEnvironment.store) {
        guard !isConfigured else { return }
        isConfigured = true

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { _ in
            store.send(.playbackFeature(.nowPlayingCommand(.play)))
            return .success
        }
        commandCenter.pauseCommand.addTarget { _ in
            store.send(.playbackFeature(.nowPlayingCommand(.pause)))
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            store.send(.playbackFeature(.nowPlayingCommand(.togglePlayPause)))
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            store.send(.playbackFeature(.nowPlayingCommand(.seek(event.positionTime))))
            return .success
        }
    }
}
