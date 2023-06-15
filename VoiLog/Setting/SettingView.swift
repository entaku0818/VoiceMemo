//
//  SwiftUIView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 22.10.2022.
//

import SwiftUI
import ComposableArchitecture
struct SettingViewState: Equatable {
    var selectedFileFormat: String
}

enum SettingViewAction {
    case selectFileFormat(String)
}

extension SettingViewState {
    static let initial = SettingViewState(selectedFileFormat: UserDefaultsManager.shared.selectedFileFormat)
}

struct SettingViewEnvironment {
    // ここに必要な依存関係や外部サービスを記述します
}

let settingViewReducer = Reducer<SettingViewState, SettingViewAction, SettingViewEnvironment> { state, action, _ in
    switch action {
    case let .selectFileFormat(fileFormat):
        state.selectedFileFormat = fileFormat
        UserDefaultsManager.shared.selectedFileFormat = fileFormat
        return .none
    }
}

struct SettingView: View {
    let store: Store<SettingViewState, SettingViewAction>

    var body: some View {
        WithViewStore(self.store) { viewStore in
            List {
                // ...

                NavigationLink(destination: FileFormatView(store: self.store)) {
                    HStack {
                        Text("ファイル形式")
                        Spacer()
                        Text("\(viewStore.selectedFileFormat)")
                    }
                }

            #if DEBUG

            #endif

            }
            .listStyle(GroupedListStyle())
            .navigationTitle("setting")
        }
    }
}

struct FileFormatView: View {
    let store: Store<SettingViewState, SettingViewAction>
    @Environment(\.presentationMode) var presentationMode // 追加

    var body: some View {
        WithViewStore(self.store) { viewStore in
            List {
                ForEach(Constants.FileFormat.allCases, id: \.self) { format in
                    Button(action: {
                        viewStore.send(.selectFileFormat(format.rawValue))
                        self.presentationMode.wrappedValue.dismiss() // ボタンがクリックされたら画面を閉じる

                    }) {
                        HStack {
                               Text("\(format.rawValue)")
                               Spacer()
                               if format.rawValue == viewStore.selectedFileFormat {
                                   Image(systemName: "checkmark")
                               }
                           }

                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("File Format")
        }
    }
}


