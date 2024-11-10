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


        enum Delegate {
            case playbackStarted
            case playbackFailed
        }

        enum PlaybackMode {
            case automatic
            case manual
        }
    }

    private enum CancelID { case play }
    @Dependency(\.audioPlayer) var audioPlayer
    @Dependency(\.continuousClock) var clock

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        enum PlayID {}
        switch action {
        case let .audioPlayerClient(_, playbackMode):
            state.mode = .notPlaying

            switch playbackMode {
            case .automatic:
                state.time = 0
            case .manual:
                if Int(state.duration) <= Int(state.time){
                    state.time = 0
                }
            }

            return .cancel(id: CancelID.play)

        case .delete:
            return .cancel(id: CancelID.play)

        case .playButtonTapped:
            switch state.mode {
            case .notPlaying:
                print("audioPlayer:" + String(state.time))

                state.mode = .playing(progress: state.time / state.duration)

                return .run { [
                        url = state.url,
                        time = state.time,
                        playSpeed = state.playSpeed,
                        isLoop = state.isLooping
                ] send in
                    await send(.delegate(.playbackStarted))

                    async let playAudio: Void = send(
                        .audioPlayerClient(TaskResult { try await self.audioPlayer.play(url, time, playSpeed, isLoop) }, .automatic)
                    )

                    for await _ in self.clock.timer(interval: .milliseconds(500)) {
                        let time = try await self.audioPlayer.getCurrentTime()
                        await send(.timerUpdated(time))
                    }

                    await playAudio
                }
                .cancellable(id: CancelID.play, cancelInFlight: true)


            case .playing:
                state.mode = .notPlaying
                return .run { send in

                    async let stopAudio: Void = send(
                        .audioPlayerClient(TaskResult { try await self.audioPlayer.stop() }, .manual)
                    )
                    await stopAudio

                }
                .cancellable(id: CancelID.play, cancelInFlight: true)
            }

        case let .timerUpdated(time):
            switch state.mode {
            case .notPlaying:
                break
            case let .playing(progress: progress):
                
                state.mode = .playing(progress: time / state.duration)
                state.time = time
            }
            return .none

        case let .titleTextFieldChanged(text):
            state.title = text
            let voiceMemoRepository = VoiceMemoRepository(coreDataAccessor: VoiceMemoCoredataAccessor(), cloudUploader: CloudUploader())
            voiceMemoRepository.update(state: state)
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
                return .run { [url = state.url,time = state.time,playSpeed = state.playSpeed,isLoop = state.isLooping ] send in
                    await send(.delegate(.playbackStarted))

                    async let playAudio: Void = send(
                        .audioPlayerClient(TaskResult { try await self.audioPlayer.play(url, time, playSpeed, isLoop) }, .automatic)
                    )

                    for await _ in self.clock.timer(interval: .milliseconds(500)) {
                        let time = try await self.audioPlayer.getCurrentTime()
                        await send(.timerUpdated(time))
                    }

                    await playAudio
                }
                .cancellable(id: CancelID.play, cancelInFlight: true)
            }

        case let .skipBy(seconds):
            let newTime = max(min(state.time + TimeInterval(seconds), state.duration), 0)
            state.time = newTime
            switch state.mode {
            case .notPlaying:
                return .none
            case .playing:
                return .run { [url = state.url,playSpeed = state.playSpeed,isLoop = state.isLooping ] send in
                    await send(.delegate(.playbackStarted))

                    async let playAudio: Void = send(
                        .audioPlayerClient(TaskResult { try await self.audioPlayer.play(url, newTime, playSpeed, isLoop) }, .automatic)
                    )

                    for await _ in self.clock.timer(interval: .milliseconds(500)) {
                        let time = try await self.audioPlayer.getCurrentTime()
                        await send(.timerUpdated(time))
                    }

                    await playAudio
                }
                .cancellable(id: CancelID.play, cancelInFlight: true)
            }

        case .toggleLoop:
            state.isLooping.toggle() // Toggle the loop state
            switch state.mode {
            case .notPlaying:
                return .none
            case .playing:
                return .run { [url = state.url,time = state.time,playSpeed = state.playSpeed,isLoop = state.isLooping ] send in
                    await send(.delegate(.playbackStarted))

                    async let playAudio: Void = send(
                        .audioPlayerClient(TaskResult { try await self.audioPlayer.play(url, time, playSpeed, isLoop) }, .automatic)
                    )

                    for await _ in self.clock.timer(interval: .milliseconds(500)) {
                        let time = try await self.audioPlayer.getCurrentTime()
                        await send(.timerUpdated(time))
                    }

                    await playAudio
                }
                .cancellable(id: CancelID.play, cancelInFlight: true)
            }
        case .onAppear:
            state.hasPurchasedPremium = UserDefaultsManager.shared.hasPurchasedProduct
            return .none

        }
    }


    struct State: Equatable, Identifiable {
        var uuid: UUID
        var date: Date

        /// 音声のトータル時間
        var duration: TimeInterval
        /// 再生時間
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
        var isLooping: Bool = false



        var waveformData: [Float] = []

        var id: URL { self.url }

        enum Mode: Equatable {
            case notPlaying
            case playing(progress: Double)

            var isPlaying: Bool {
                if case .playing = self { return true }
                return false
            }
        }
        var hasPurchasedPremium:Bool
    }

}
struct VoiceMemoListItem: View {
    let store: StoreOf<VoiceMemoReducer>
    @State private var showingModal = false
    let admobUnitId: String

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
            NavigationLink {
                VoiceMemoDetail(store: store, admobUnitId: admobUnitId)
            } label: {
                HStack {
                    Button(action: {
                        viewStore.send(.playButtonTapped)
                    }) {
                        Image(systemName: viewStore.mode.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)

                    VStack(spacing: 5) {
                        HStack {
                            if viewStore.title.count > 0 {
                                Text(viewStore.title)
                                    .font(.headline)
                            } else {
                                Text("名称未設定")
                                    .font(.headline)
                            }
                            Spacer()
                        }

                        if viewStore.state.fileFormat.count > 0 {
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
                }
            }
            .buttonStyle(.borderless)
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.horizontal)
            .listRowInsets(EdgeInsets())
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
            admobUnitId: ""
        ).padding()
    }
}
