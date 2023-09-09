//
//  VoicyListView.swift
//  VoiceMemo
//
//  Created by 遠藤拓弥 on 4.9.2022.
//

import ComposableArchitecture
import Foundation
import SwiftUI

struct VoiceMemoState: Equatable, Identifiable {
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

enum VoiceMemoAction: Equatable {
  case audioPlayerClient(TaskResult<Bool>)
  case delete
  case playButtonTapped
  case timerUpdated(TimeInterval)
  case titleTextFieldChanged(String)
  case loadWaveformData
}

struct VoiceMemoEnvironment {
  var audioPlayer: AudioPlayerClient
  var mainRunLoop: AnySchedulerOf<RunLoop>
}

let voiceMemoReducer = Reducer<
  VoiceMemoState,
  VoiceMemoAction,
  VoiceMemoEnvironment
> { state, action, environment in
  enum PlayID {}

  switch action {
  case .audioPlayerClient:
      // 停止時の処理
      state.time = 0.0
    state.mode = .notPlaying
    return .cancel(id: PlayID.self)

  case .delete:
    return .cancel(id: PlayID.self)

  case .playButtonTapped:
    switch state.mode {
    case .notPlaying:
        print("audioPlayer:" + String(state.time))

        state.mode = .playing(progress: state.time)
        return .run { [url = state.url,time = state.time,duration = state.duration] send in
        let start = environment.mainRunLoop.now

        async let playAudio: Void = send(
            .audioPlayerClient(TaskResult { try await environment.audioPlayer.play(url, time) })
        )

        for try await tick in environment.mainRunLoop.timer(interval: 0.1) {

            let timer = time + tick.date.timeIntervalSince(start.date) > duration ? duration : time + tick.date.timeIntervalSince(start.date)
            await send(.timerUpdated(timer))
        }
      }
      .cancellable(id: PlayID.self, cancelInFlight: true)

    case .playing:
      state.mode = .notPlaying
      return .cancel(id: PlayID.self)
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
      if !state.waveformData.isEmpty { return .none }
      let waveformAnalyzer = WaveformAnalyzer(audioURL: state.url)
      let (newWaveformData, newTotalDuration) = waveformAnalyzer.analyze()
      state.waveformData = newWaveformData
      return .none
  }
}

struct VoiceMemoView: View {
  let store: Store<VoiceMemoState, VoiceMemoAction>
  @State private var showingModal = false

  var body: some View {
    WithViewStore(store) { viewStore in
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
                                        .foregroundColor(Color(.systemGray))
                                }
                                Spacer()
                            }

                            if viewStore.state.fileFormat.count > 0 {
                                HStack {
                                    Text(viewStore.state.fileFormat)
                                        .font(.caption)
                                        .foregroundColor(.black)

                                    Text(viewStore.state.samplingFrequency.formattedAsKHz())
                                        .font(.caption)
                                        .foregroundColor(.black)
                                    Text("/")
                                        .font(.caption)
                                        .foregroundColor(.black)
                                    Text(String(viewStore.state.quantizationBitDepth) + "bit")
                                        .font(.caption)
                                        .foregroundColor(.black)
                                    Text("/")
                                        .font(.caption)
                                        .foregroundColor(.black)
                                    Text(String(viewStore.state.numberOfChannels) + "ch")
                                        .font(.caption)
                                        .foregroundColor(.black)

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
    let store = Store(initialState: VoiceMemoState(
                        uuid: UUID(),
                        date: Date(),
                        duration: 180, time: 0,
                        mode: .notPlaying,
                        title: "Untitled",
                        url: URL(fileURLWithPath: ""),
                        text: "",
                        fileFormat: "WAV",
                        samplingFrequency: 44100.0,
                        quantizationBitDepth: 16,
                        numberOfChannels: 1
                    ),
                    reducer: voiceMemoReducer,
                    environment: VoiceMemoEnvironment(
                        audioPlayer: .mock,
                        mainRunLoop: .main
                    )
                )
    return VoiceMemoView(store: store)
  }
}
