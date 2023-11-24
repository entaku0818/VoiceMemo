//
//  VoiceDetail.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 24.6.2023.
//

import SwiftUI
import ComposableArchitecture

    struct VoiceMemoDetail: View {
        let store: StoreOf<VoiceMemoReducer>

        @Environment(\.presentationMode) var presentationMode

      var body: some View {
          WithViewStore(self.store, observe: { $0 }) { viewStore in

              VStack {
                  TextField(
                      "名称未設定", // プレースホルダーのテキストを指定
                      text: viewStore.binding(
                        get: \.title,
                        send: VoiceMemoReducer.Action.titleTextFieldChanged)
                  ).font(.system(size: 18))
                      .padding()
                      .overlay(
                          RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 0.5)
                      ).padding()
                  HStack{

                      if let formattedDate = formatDateTime(viewStore.date) {
                          Text(formattedDate)
                              .font(.footnote.monospacedDigit())
                              .foregroundColor(Color(.systemGray))
                      }
                      Spacer()

                      dateComponentsFormatter.string(from: viewStore.time == 0 ? viewStore.duration : viewStore.time).map {
                          Text($0)
                              .font(.footnote.monospacedDigit())
                              .foregroundColor(Color(.systemGray))
                      }
                      Button(action: { viewStore.send(.playButtonTapped) }) {
                          Image(systemName: viewStore.mode.isPlaying ? "stop.circle" : "play.circle")
                              .font(.system(size: 36))
                      }


                  }.padding()

                  HStack{
                      Spacer()
                      Button(action: { viewStore.send(.onTapPlaySpeed) }) {
                          Text(viewStore.playSpeed.description)
                              .font(.system(size: 16))
                      }
                  }.padding()

                  ProgressView(value: viewStore.time / viewStore.duration)
                      .frame(height: 10)
                      .progressViewStyle(.linear)
                      .accentColor(Color.gray)
                      .padding()





                  ScrollView {
                      Text(viewStore.text)
                  }.frame(minHeight: 50, maxHeight: 200)
                      .padding(16)
                  Spacer()

              }
              .navigationBarItems(trailing:
                    Button(action: {
                        // シェアするコンテンツを設定
                        let textToShare = viewStore.title
                        var itemsToShare: [Any] = [textToShare]
                        let inputDocumentsPath = NSHomeDirectory() + "/Documents/" + viewStore.url.lastPathComponent

                        let audioFileURL = NSURL(fileURLWithPath: inputDocumentsPath)

                        itemsToShare.append(audioFileURL)


                        // UIActivityViewControllerを表示
                        let activityViewController = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
                        UIApplication.shared.windows.first?.rootViewController?.present(activityViewController, animated: true, completion: nil)
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
              )
          }
      }

        func formatDateTime(_ date: Date) -> String? {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .medium
            dateFormatter.locale = Locale.autoupdatingCurrent // Set to the default locale of the user's device
            return dateFormatter.string(from: date)
        }

    }

struct VoiceDetail_Previews: PreviewProvider {
    static var previews: some View {

        VoiceMemoDetail(
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
