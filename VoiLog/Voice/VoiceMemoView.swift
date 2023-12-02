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

                return .run { [url = state.url,time = state.time,playSpeed = state.playSpeed] send in
                    await send(.delegate(.playbackStarted))

                    async let playAudio: Void = send(
                        .audioPlayerClient(TaskResult { try await self.audioPlayer.play(url, time, playSpeed) }, .automatic)
                    )

                    for await _ in self.clock.timer(interval: .milliseconds(500)) {
                        let time = try await self.audioPlayer.getCurrentTime()
                        await send(.timerUpdated(time))
                        print("playAudio\(time)")
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
            let voiceMemoRepository = VoiceMemoRepository()
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
                break
            case .playing:
                return .run { [url = state.url,time = state.time,playSpeed = state.playSpeed] send in
                    await send(.delegate(.playbackStarted))

                    async let playAudio: Void = send(
                        .audioPlayerClient(TaskResult { try await self.audioPlayer.play(url, time, playSpeed) }, .automatic)
                    )

                    for await _ in self.clock.timer(interval: .milliseconds(500)) {
                        let time = try await self.audioPlayer.getCurrentTime()
                        await send(.timerUpdated(time))
                        print("playAudio\(time)")
                    }

                    await playAudio
                }
                .cancellable(id: CancelID.play, cancelInFlight: true)
            }
            return .none
        case let .skipBy(seconds):
            let newTime = max(min(state.time + TimeInterval(seconds), state.duration), 0)
            state.time = newTime
            return .run { send in
                async let skipAudio: Void = send(
                    .audioPlayerClient(TaskResult { try await self.audioPlayer.seek(newTime) }, .manual)
                )
                await skipAudio
            }
            .cancellable(id: CancelID.play, cancelInFlight: true)
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
    }

}


struct VoiceMemoView: View {
    let store: StoreOf<VoiceMemoReducer>
  @State private var showingModal = false

  var body: some View {
      WithViewStore(self.store, observe: { $0 }) { viewStore in
        let currentTime = viewStore.duration
            NavigationLink {
                VoiceMemoDetail(store: store)
            } label: {
                    HStack {

                        VStack {
                            HStack {
                                if viewStore.title.count > 0 {
                                    Text(viewStore.title)
                                        .font(.headline) // Adjust the font size and style as needed
                                        .foregroundColor(.black) // Set text color
                                } else {
                                    Text("名称未設定")
                                        .font(.headline) // Adjust the font size and style as needed
                                        .foregroundColor(.black)
                                }
                                Spacer()
                            }

                            if viewStore.state.fileFormat.count > 0 {
                                HStack {
                                    Text(viewStore.state.fileFormat)
                                        .font(.caption)
                                        .foregroundColor(.gray)

                                    Text(viewStore.state.samplingFrequency.formattedAsKHz())
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("/")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(String(viewStore.state.quantizationBitDepth) + "bit")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("/")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(String(viewStore.state.numberOfChannels) + "ch")
                                        .font(.caption)
                                        .foregroundColor(.gray)

                                    Spacer()
                                }
                            }
                        }



                        Spacer()

                        dateComponentsFormatter.string(from: currentTime).map {
                            Text($0)
                                .font(.footnote.monospacedDigit())
                                .foregroundColor(Color(.systemGray))
                        }

                        Image(systemName: viewStore.mode.isPlaying ? "stop.circle" : "play.circle")
                            .font(.system(size: 22))
                            .foregroundColor(Color.accentColor)
                    }



            }
            .buttonStyle(.borderless)
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.horizontal)
            .listRowInsets(EdgeInsets())



    }
  }
}


struct VoiceMemoView_Previews: PreviewProvider {
  static var previews: some View {
      return VoiceMemoView(
        store: Store(
          initialState: VoiceMemoReducer.State(
              uuid: UUID(),
              date: Date(),
              duration: 180,
              time: 0,
              mode: .notPlaying,
              title: "",
              url: URL(fileURLWithPath: ""),
              text: "",
              fileFormat: "",
              samplingFrequency: 0.0,
              quantizationBitDepth: 0,
              numberOfChannels: 0
          )
        ) {
            VoiceMemoReducer()
        }
      )

  }
}
