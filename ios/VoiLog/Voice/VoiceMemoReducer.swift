//
//  VoicyListView.swift
//  VoiceMemo
//
//  Created by 遠藤拓弥 on 4.9.2022.
//

import ComposableArchitecture
import Foundation
import SwiftUI

struct VoiceMemoReducer: Reducer {
    enum Action: Equatable {
        case audioPlayerClient(TaskResult<Bool>, PlaybackMode)
        case delegate(Delegate)
        case delete
        case playButtonTapped
        case timerUpdated(TimeInterval)
        case titleTextFieldChanged(String)
        case loadWaveformData
        case onTapPlaySpeed
        case skipBy(TimeInterval)
        case toggleLoop
        case onAppear

        enum Delegate: Equatable {
            case playbackStarted
            case playbackFailed
            case playbackInProgress(TimeInterval)
            case playbackComplete
        }

        enum PlaybackMode: Equatable {
            case automatic
            case manual
        }
    }

    private enum CancelID { case play }
    @Dependency(\.audioPlayer) var audioPlayer
    @Dependency(\.continuousClock) var clock

    private func playAudioEffect(
        url: URL,
        time: TimeInterval,
        playSpeed: AudioPlayerClient.PlaybackSpeed,
        isLoop: Bool
    ) -> Effect<Action> {
        .run { [audioPlayer, clock] send in
            await send(.delegate(.playbackStarted))
            let timerTask = Task {
                for await _ in clock.timer(interval: .milliseconds(100)) {
                    let currentTime = try await audioPlayer.getCurrentTime()
                    await send(.timerUpdated(currentTime))
                }
            }

            do {
                let didComplete = try await audioPlayer.play(url, time, playSpeed, isLoop)

                // Cancel the timer task when playback completes
                timerTask.cancel()

                if didComplete {
                    await send(.delegate(.playbackComplete))
                }
                await send(.audioPlayerClient(.success(didComplete), .automatic))
            } catch {
                await send(.delegate(.playbackFailed))
                await send(.audioPlayerClient(.failure(error), .automatic))
                timerTask.cancel()
            }
        }
        .cancellable(id: CancelID.play, cancelInFlight: true)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        enum PlayID {}
        switch action {
        case let .audioPlayerClient(_, playbackMode):
            state.mode = .notPlaying

            switch playbackMode {
            case .automatic:
                state.time = 0
            case .manual:
                if Int(state.duration) <= Int(state.time) {
                    state.time = 0
                }
            }
            return .cancel(id: CancelID.play)

        case .delete:
            return .cancel(id: CancelID.play)

        case .playButtonTapped:
            switch state.mode {
            case .notPlaying:
                state.mode = .playing(progress: state.time / state.duration)

                return playAudioEffect(
                    url: state.url,
                    time: state.time,
                    playSpeed: state.playSpeed,
                    isLoop: state.isLooping
                )

            case .playing:
                state.mode = .notPlaying
                return .run { send in
                    async let stopAudio: Void = send(
                        .audioPlayerClient(
                            TaskResult { try await self.audioPlayer.stop() },
                            .manual
                        )
                    )
                    await stopAudio
                }
                .cancellable(id: CancelID.play, cancelInFlight: true)
            }

        case let .timerUpdated(time):
            switch state.mode {
            case .notPlaying:
                break
            case .playing:
                let progress = time / state.duration
                state.mode = .playing(progress: progress)
                state.time = time
            }
            return .none

        case let .titleTextFieldChanged(text):
            state.title = text
            MainActor.assumeIsolated {
                let voiceMemoRepository = VoiceMemoRepository(
                    coreDataAccessor: VoiceMemoCoredataAccessor(),
                    cloudUploader: CloudUploader()
                )
                voiceMemoRepository.update(state: state)
            }
            return .none

        case .loadWaveformData:
            return .none

        case .delegate:
            return .none

        case .onTapPlaySpeed:
            state.playSpeed = state.playSpeed.next()

            switch state.mode {
            case .notPlaying:
                return .none
            case .playing:
                return playAudioEffect(
                    url: state.url,
                    time: state.time,
                    playSpeed: state.playSpeed,
                    isLoop: state.isLooping
                )
            }

        case let .skipBy(seconds):
            let newTime = max(min(state.time + TimeInterval(seconds), state.duration), 0)
            state.time = newTime
            switch state.mode {
            case .notPlaying:
                return .none
            case .playing:
                return playAudioEffect(
                    url: state.url,
                    time: state.time,
                    playSpeed: state.playSpeed,
                    isLoop: state.isLooping
                )
            }

        case .toggleLoop:
            state.isLooping.toggle()
            switch state.mode {
            case .notPlaying:
                return .none
            case .playing:
                return playAudioEffect(
                    url: state.url,
                    time: state.time,
                    playSpeed: state.playSpeed,
                    isLoop: state.isLooping
                )
            }

        case .onAppear:
            state.hasPurchasedPremium = UserDefaultsManager.shared.hasPurchasedProduct
            return .none

        }
    }

    struct State: Equatable, Identifiable {
        var uuid: UUID
        var date: Date
        var duration: TimeInterval
        var time: TimeInterval
        var mode = Mode.notPlaying
        var title = ""
        var url: URL
        var text: String
        var fileFormat: String
        var samplingFrequency: Double
        var quantizationBitDepth: Int
        var numberOfChannels: Int
        var playSpeed: AudioPlayerClient.PlaybackSpeed = .normal
        var isLooping = false
        var waveformData: [Float] = []
        var hasPurchasedPremium: Bool
        var isRecording = false

        var id: URL { self.url }

        enum Mode: Equatable {
            case notPlaying
            case playing(progress: Double)

            var isPlaying: Bool {
                if case .playing = self { return true }
                return false
            }
        }
    }
}
