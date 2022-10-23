//
//  SwiftUIView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 22.10.2022.
//

import SwiftUI

struct SettingNotification: View {
    @State private var text = """
    
"""
    var body: some View {
        VStack{
            TextField("", text: $text)
            Spacer()
        }.navigationTitle("通知の設定")
    }
}

struct SettingNotification_Previews: PreviewProvider {
    static var previews: some View {
        SettingNotification()
    }
}
