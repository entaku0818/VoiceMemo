//
//  SwiftUIView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 22.10.2022.
//

import SwiftUI

struct SettingView: View {
    var body: some View {
        List {
            NavigationLink {
                SettingVoiceQuestionView()
            } label: {
                Text("質問の設定")
            }
            NavigationLink {
                
            } label: {
                Text("通知の時間")
            }
        }.navigationTitle("setting")
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}
