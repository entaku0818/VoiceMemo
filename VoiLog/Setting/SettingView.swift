//
//  SwiftUIView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 22.10.2022.
//

import SwiftUI
import ComposableArchitecture

struct SettingView: View {
    @State private var selectedFileFormat: String = UserDefaultsManager.shared.selectedFileFormat

    var body: some View {
        List {
            Section(header: Text("録音設定")) {
                        NavigationLink(destination: FileFormatView()) {
                               HStack {
                                   Text("ファイル形式")
                                   Spacer()
                                   Text("\(selectedFileFormat)")
                               }
                           }

                NavigationLink(destination: FileFormatView()) {

                    HStack {
                        Text("サンプリング周波数")
                        Spacer()
                        Text("44,100Hz")
                    }
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
                Button("Crash") {
                    fatalError("Crash was triggered")
                }
            }

        }
        .listStyle(GroupedListStyle())
        .navigationTitle("setting")
    }
}

struct FileFormatView: View {
    @State private var selectedFileFormat: String = UserDefaultsManager.shared.selectedFileFormat

    var body: some View {
        List {
            ForEach(Constants.FileFormat.allCases, id: \.self) { format in
                Button(action: {
                    self.selectFileFormat(format)
                }) {
                    Text("\(format.rawValue)")
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationTitle("File Format")
    }

    func selectFileFormat(_ fileFormat: Constants.FileFormat) {
        selectedFileFormat = fileFormat.rawValue
        UserDefaultsManager.shared.selectedFileFormat = fileFormat.rawValue
    }
}



