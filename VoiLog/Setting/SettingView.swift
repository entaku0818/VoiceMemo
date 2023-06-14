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
            Section(header: Text("録音設定")) {
                //            NavigationLink(destination: QuestionSettingView()) {
                                HStack {
                                    Text("ファイル形式")
                                    Spacer()
                                    Text("WAV")

                                }
                //            }

                            Button("Crash") {
                                fatalError("Crash was triggered")
                            }
                            HStack {
                                Text("サンプリング周波数")
                                Spacer()
                                Text("44,100Hz")
                            }
                            HStack {
                                Text("量子化ビット数")
                                Spacer()
                                Text("16bit")
                            }
                            HStack {
                                Text("チャネル")
                                Spacer()
                                Text("モノラル")

                            }
                            HStack {
                                Text("マイク音量の設定")
                                Spacer()
                                Text("1")
                            }
            }

        }
        .listStyle(GroupedListStyle())
        .navigationTitle("setting")
    }
}

struct QuestionSettingView: View {
    var body: some View {
        // 質問の設定の詳細ビューのコードを記述
        Text("Question Setting View")
    }
}

struct NotificationSettingView: View {
    var body: some View {
        // 通知の設定の詳細ビューのコードを記述
        Text("Notification Setting View")
    }
}

