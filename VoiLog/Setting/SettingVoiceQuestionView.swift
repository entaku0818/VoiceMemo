//
//  SwiftUIView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 22.10.2022.
//

import SwiftUI

struct SettingVoiceQuestionView: View {
    @State private var text = """
    
"""
    var body: some View {
        VStack{
            TextField("質問", text: $text)
            Spacer()
        }.navigationTitle("質問の設定")
    }
}

struct SettingVoiceQuestionView_Previews: PreviewProvider {
    static var previews: some View {
        SettingVoiceQuestionView()
    }
}
