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

  var id: URL { self.url }

  enum Mode: Equatable {
    case notPlaying
    case playing(progress: Double)

    var isPlaying: Bool {
      if case .playing = self { return true }
      return false
    }

    var progress: Double? {
      if case let .playing(progress) = self { return progress }
      return nil
    }
  }
}

enum VoiceMemoAction: Equatable {
  case audioPlayerClient(TaskResult<Bool>)
  case delete
  case playButtonTapped
  case timerUpdated(TimeInterval)
  case titleTextFieldChanged(String)
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
    state.mode = .notPlaying
    return .cancel(id: PlayID.self)

  case .delete:
    return .cancel(id: PlayID.self)

  case .playButtonTapped:
    switch state.mode {
    case .notPlaying:
      state.mode = .playing(progress: 0)

      return .run { [url = state.url] send in
        let start = environment.mainRunLoop.now

        async let playAudio: Void = send(
          .audioPlayerClient(TaskResult { try await environment.audioPlayer.play(url) })
        )

        for try await tick in environment.mainRunLoop.timer(interval: 0.1) {
          await send(.timerUpdated(tick.date.timeIntervalSince(start.date)))
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
    return .none
  }
}

struct VoiceMemoView: View {
  let store: Store<VoiceMemoState, VoiceMemoAction>
  @State private var showingModal = false

  var body: some View {
    WithViewStore(store) { viewStore in
            let currentTime =
              viewStore.mode.progress.map { $0 * viewStore.duration } ?? viewStore.duration
            NavigationLink {
                VoiceMemoDetail(store: store)
            } label: {
                HStack {
                  Text(
                    "Untitled, \(viewStore.date.formatted(date: .numeric, time: .shortened))"
                  )

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
                        text: ""
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
