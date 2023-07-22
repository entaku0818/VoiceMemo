//
//  VoiceDetail.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 24.6.2023.
//

import SwiftUI
import ComposableArchitecture

struct VoiceMemoDetail: View {
  let store: Store<VoiceMemoState, VoiceMemoAction>
    @Environment(\.presentationMode) var presentationMode

  var body: some View {
      WithViewStore(store) { viewStore in
          let currentTime =
          viewStore.mode.progress.map { $0 * viewStore.duration } ?? viewStore.duration
          VStack {
              VStack{
                  HStack {
                      TextField(
                        "\(viewStore.date.formatted(date: .numeric, time: .shortened))",
                        text: viewStore.binding(get: \.title, send: { .titleTextFieldChanged($0) })
                      )

                      Spacer()

                      dateComponentsFormatter.string(from: currentTime).map {
                          Text($0)
                              .font(.footnote.monospacedDigit())
                              .foregroundColor(Color(.systemGray))
                      }

                      Button(action: { viewStore.send(.playButtonTapped) }) {
                          Image(systemName: viewStore.mode.isPlaying ? "stop.circle" : "play.circle")
                              .font(.system(size: 22))
                      }
                  }
                  .buttonStyle(.borderless)
                  .frame(maxHeight: .infinity, alignment: .center)
                  .padding(.horizontal)
                  .listRowBackground(viewStore.mode.isPlaying ? Color(.systemGray6) : .clear)
                  .listRowInsets(EdgeInsets())
                  .background(
                    Color(.systemGray5)
                        .frame(maxWidth: viewStore.mode.isPlaying ? .infinity : 0)
                        .animation(
                            viewStore.mode.isPlaying ? .linear(duration: viewStore.duration) : nil,
                            value: viewStore.mode.isPlaying
                        ),
                    alignment: .leading
                  )
              }.frame(minHeight: 50, maxHeight: 50)

              let recordingStore = Store(initialState: RecordingMemoState(
                date: Date(),
                url: URL(string: "https://www.pointfree.co/functions")!, duration: 0
              ), reducer: recordingMemoReducer, environment: RecordingMemoEnvironment(audioRecorder: .live, mainRunLoop: .main
                                                                                     )
              )
              AudioEditingView(store: recordingStore,audioURL: viewStore.url)

              ScrollView {
                  Text(viewStore.text)
              }.frame(minHeight: 50, maxHeight: 200)
                  .padding(16)
              Spacer()

          }
          .navigationBarBackButtonHidden(true)
          .navigationBarItems(leading: Button(action: {self.presentationMode.wrappedValue.dismiss()}){
              Image(systemName: "chevron.left").foregroundColor(Color.blue).font(Font.system(size:23, design: .serif)).padding(.leading,-6)
              Text("Back")
          })
      }
  }
}

//struct VoiceDetail_Previews: PreviewProvider {
//    static var previews: some View {
//        VoiceMemoDetail(store: <#Store<VoiceMemoState, VoiceMemoAction>#>)
//    }
//}
