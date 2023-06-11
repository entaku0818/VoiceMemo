//
//  SwiftUIView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 22.10.2022.
//

import SwiftUI
import ComposableArchitecture

struct SettingView: View {
    var body: some View {
        List {
            NavigationLink {
                SettingVoiceQuestionView(store:
                    Store(initialState: SettingVoiceQuestionViewState(text: ""),
                          reducer:
                            SettingVoiceQuestionReducer
                        .debug(), environment: SettingVoiceQuestionEnvironment()
                          ))
                
            } label: {
                Text("質問の設定")
            }
            Button("Crash") {
                  fatalError("Crash was triggered")
            }
            NavigationLink {
                SettingNotification(
                    store: Store(initialState:
                                    NotificationViewState(text: ""),
                                 reducer: NotificationReducer.debug(),
                                 environment: NotificationEnvironment()
                         ))
            } label: {
                Text("通知の設定")
            }
        }.navigationTitle("setting")
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}
