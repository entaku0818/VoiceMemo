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

struct VoiceMemoListItem: View {
    let store: StoreOf<VoiceMemoReducer>
    @State private var showingModal = false
    let admobUnitId: String
    let currentMode: VoiceMemos.State.Mode
    @Binding var isRecording: Bool
    @Binding var isRecordingNavigationAlertPresented: Bool

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter
    }()

    private let dateComponentsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            let currentTime = viewStore.duration

            Group {
                if !isRecording {
                    NavigationLink {
                        VoiceMemoDetail(store: store, admobUnitId: admobUnitId)
                    } label: {
                        listItemContent(viewStore: viewStore, currentTime: currentTime)
                    }
                } else {
                    listItemContent(viewStore: viewStore, currentTime: currentTime)
                        .onTapGesture {
                            isRecordingNavigationAlertPresented = true
                        }
                }
            }
            .buttonStyle(.borderless)
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.horizontal)
            .listRowInsets(EdgeInsets())
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private func listItemContent(viewStore: ViewStoreOf<VoiceMemoReducer>, currentTime: TimeInterval) -> some View {
        HStack {
            VStack(spacing: 5) {
                HStack {
                    if !viewStore.title.isEmpty {
                        Text(viewStore.title)
                            .font(.headline)
                    } else {
                        Text("名称未設定")
                            .font(.headline)
                    }
                    Spacer()
                }

                if !viewStore.state.fileFormat.isEmpty {
                    HStack(spacing: 0) {
                        Text(dateFormatter.string(from: viewStore.date))
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Spacer()
                        Text(viewStore.state.fileFormat)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Spacer()
                        Text(viewStore.state.samplingFrequency.formattedAsKHz())
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text("/")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(String(viewStore.state.quantizationBitDepth) + "bit")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text("/")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(String(viewStore.state.numberOfChannels) + "ch")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }

            dateComponentsFormatter.string(from: currentTime).map {
                Text($0)
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(Color(.systemGray))
            }

            if currentMode == .playback {
                Button(action: {
                    viewStore.send(.playButtonTapped)
                }) {
                    Image(systemName: viewStore.mode.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct VoiceMemoListItem_Previews: PreviewProvider {
    static var previews: some View {
        VoiceMemoListItem(
            store: Store(
                initialState: VoiceMemoReducer.State(
                    uuid: UUID(),
                    date: Date(),
                    duration: 180,
                    time: 0,
                    mode: .notPlaying,
                    title: "Sample Memo",
                    url: URL(fileURLWithPath: "/path/to/memo.m4a"),
                    text: "This is a sample voice memo.",
                    fileFormat: "m4a",
                    samplingFrequency: 44100.0,
                    quantizationBitDepth: 16,
                    numberOfChannels: 2,
                    hasPurchasedPremium: false
                )
            ) {
                VoiceMemoReducer()
            },
            admobUnitId: "",
            currentMode: .playback, isRecording: .constant(false),
            isRecordingNavigationAlertPresented: .constant(false)
        ).padding()
    }
}
