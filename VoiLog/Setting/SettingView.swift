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
    var samplingFrequency: Double
    var quantizationBitDepth:Int
    var numberOfChannels:Int
    var microphonesVolume:Double
}

enum SettingViewAction {
    case selectFileFormat(String)
    case samplingFrequency(Double)
    case quantizationBitDepth(Int)
    case numberOfChannels(Int)
    case microphonesVolume(Double)
}

extension SettingViewState {
    static let initial = SettingViewState(
        selectedFileFormat: UserDefaultsManager.shared.selectedFileFormat,
        samplingFrequency: UserDefaultsManager.shared.samplingFrequency,
        quantizationBitDepth: UserDefaultsManager.shared.quantizationBitDepth,
        numberOfChannels: UserDefaultsManager.shared.numberOfChannels,
        microphonesVolume: UserDefaultsManager.shared.microphonesVolume
    )
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
    case let .samplingFrequency(rate):
        state.samplingFrequency = rate
        UserDefaultsManager.shared.samplingFrequency = rate
        return .none
    case let .quantizationBitDepth(bit):
        state.quantizationBitDepth = bit
        UserDefaultsManager.shared.quantizationBitDepth = bit
        return .none
    case let .numberOfChannels(number):
        state.numberOfChannels = number
        UserDefaultsManager.shared.numberOfChannels = number
        return .none
    case let .microphonesVolume(volume):
        state.microphonesVolume = volume
        UserDefaultsManager.shared.microphonesVolume = volume
        return .none
    }
}

struct SettingView: View {
    let store: Store<SettingViewState, SettingViewAction>

    var body: some View {
        WithViewStore(self.store) { viewStore in
            List {
                // ...
                // ...
                Section(header: Text("音声設定")) {

                    NavigationLink(destination: FileFormatView(store: self.store)) {
                        HStack {
                            Text("ファイル形式")
                            Spacer()
                            Text("\(viewStore.selectedFileFormat)")
                        }
                    }

                    NavigationLink(destination: SamplingFrequencyView(store: self.store)) {
                        HStack {
                            Text("サンプリング周波数")
                            Spacer()
                            Text("\(String(viewStore.samplingFrequency))Hz")
                        }
                    }

                    NavigationLink(destination: QuantizationBitDepthView(store: self.store)) {
                        HStack {
                            Text("量子化ビット数")
                            Spacer()
                            Text("\(viewStore.quantizationBitDepth)bit")
                        }
                    }
#if DEBUG

                    NavigationLink(destination: NumberOfChannelsView(store: self.store)) {
                        HStack {
                            Text("チャネル")
                            Spacer()
                            Text("\(viewStore.numberOfChannels)")
                        }
                    }


#endif

                    NavigationLink(destination: MicrophonesVolumeView(store: self.store)) {
                        HStack {
                            Text("マイクの音量")
                            Spacer()
                            Text("\(Int(viewStore.microphonesVolume))")
                        }
                    }
                }
                Section(header: Text("")) {
                    NavigationLink(destination: AboutSimpleRecoder()) {
                        HStack {
                            Text("アプリについて")
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("設定")
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
            .navigationTitle("ファイル形式")
        }
    }
}


struct SamplingFrequencyView: View {
    let store: Store<SettingViewState, SettingViewAction>
    @Environment(\.presentationMode) var presentationMode // 追加

    var body: some View {
        WithViewStore(self.store) { viewStore in
            List {
                ForEach(Constants.SamplingFrequency.allCases, id: \.self) { rate in
                    Button(action: {
                        viewStore.send(.samplingFrequency(rate.rawValue))
                        self.presentationMode.wrappedValue.dismiss() // ボタンがクリックされたら画面を閉じる

                    }) {
                        HStack {
                            Text("\(rate.stringValue)")
                               Spacer()
                               if rate.rawValue == viewStore.samplingFrequency {
                                   Image(systemName: "checkmark")
                               }
                           }

                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("サンプリング周波数")
        }
    }
}

struct QuantizationBitDepthView: View {
    let store: Store<SettingViewState, SettingViewAction>
    @Environment(\.presentationMode) var presentationMode // 追加

    var body: some View {
        WithViewStore(self.store) { viewStore in
            List {
                ForEach(Constants.QuantizationBitDepth.allCases, id: \.self) { bit in
                    Button(action: {
                        viewStore.send(.quantizationBitDepth(bit.rawValue))
                        self.presentationMode.wrappedValue.dismiss() // ボタンがクリックされたら画面を閉じる

                    }) {
                        HStack {
                            Text("\(bit.stringValue)")
                               Spacer()
                            if bit.rawValue == viewStore.quantizationBitDepth {
                                   Image(systemName: "checkmark")
                               }
                           }

                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("量子化ビット数")
        }
    }
}

struct NumberOfChannelsView: View {
    let store: Store<SettingViewState, SettingViewAction>
    @Environment(\.presentationMode) var presentationMode // 追加

    var body: some View {
        WithViewStore(self.store) { viewStore in
            List {
                ForEach(Constants.NumberOfChannels.allCases, id: \.self) { number in
                    Button(action: {
                        viewStore.send(.numberOfChannels(number.rawValue))
                        self.presentationMode.wrappedValue.dismiss() // ボタンがクリックされたら画面を閉じる

                    }) {
                        HStack {
                            Text("\(number.rawValue)")
                               Spacer()
                            if number.rawValue == viewStore.numberOfChannels {
                                   Image(systemName: "checkmark")
                               }
                           }

                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("チャネル")
        }
    }
}

struct MicrophonesVolumeView: View {
    let store: Store<SettingViewState, SettingViewAction>
    @Environment(\.presentationMode) var presentationMode // 追加


    var body: some View {
        WithViewStore(self.store) { viewStore in

            List(Constants.MicrophonesVolume.allCases, id: \.self) { volumeOption in
                Button(action: {
                    viewStore.send(.microphonesVolume(volumeOption.rawValue))
                    self.presentationMode.wrappedValue.dismiss() // ボタンがクリックされたら画面を閉じる
                }) {
                    HStack {
                        Text("\(Int(volumeOption.rawValue))")
                        Spacer()
                        if volumeOption.rawValue == viewStore.microphonesVolume {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("マイクの音量")
        }
    }


}
