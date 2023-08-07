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
              TextField(
                  "名称未設定", // プレースホルダーのテキストを指定
                  text: viewStore.binding(get: \.title, send: { .titleTextFieldChanged($0) })
              ).font(.system(size: 18))
                  .padding()
                  .overlay(
                      RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 0.5)
                  ).padding()
              HStack{
                  Spacer()
                  dateComponentsFormatter.string(from: currentTime).map {
                      Text($0)
                          .font(.footnote.monospacedDigit())
                          .foregroundColor(Color(.systemGray))
                  }
                  Button(action: { viewStore.send(.playButtonTapped) }) {
                      Image(systemName: viewStore.mode.isPlaying ? "stop.circle" : "play.circle")
                          .font(.system(size: 36))
                  }



              }.padding()

              let recordingStore = Store(initialState: RecordingMemoState(from: viewStore.state), reducer: recordingMemoReducer, environment: RecordingMemoEnvironment(audioRecorder: .live, mainRunLoop: .main
                                                                                     )
              )
              AudioEditingView(store: store,audioURL: viewStore.url)

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

struct VoiceDetail_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store(initialState: VoiceMemoState(
                            uuid: UUID(),
                            date: Date(),
                            duration: 180,
                            time: 0,
                            mode: .notPlaying,
                            title: "",
                            url: URL(fileURLWithPath: ""),
                            text: ""
                        ),
                        reducer: voiceMemoReducer,
                        environment: VoiceMemoEnvironment(
                            audioPlayer: .mock,
                            mainRunLoop: .main
                        )
                    )
        VoiceMemoDetail(store: store)
    }
}
