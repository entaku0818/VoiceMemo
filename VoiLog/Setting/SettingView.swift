//
//  SwiftUIView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 22.10.2022.
//

import SwiftUI
import ComposableArchitecture
import StoreKit

struct SettingReducer: Reducer {
    enum Action: Equatable {
        case alert(PresentationAction<AlertAction>)
        case selectFileFormat(String)
        case samplingFrequency(Double)
        case quantizationBitDepth(Int)
        case numberOfChannels(Int)
        case microphonesVolume(Double)
        case showPurchaseOptions
        case purchaseProduct
    }

    enum AlertAction: Equatable {
        case isPurchaseErrorAlertPresented
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
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
        case .showPurchaseOptions:
            state.isPurchaseAlertPresented = true
            return .none
        case .purchaseProduct:
            let productID = "developerSupport"
            // IAPManagerの共有インスタンスを使用して購入を開始する
            return .run { send in
                do {
                    try await IAPManager.shared.startPurchase(productID: productID)
                } catch let error {
                    print(error)
                }
            }

        case .alert(.presented(.isPurchaseErrorAlertPresented)):

                state.alert = AlertState(
                  title: TextState(""),
                  message: TextState("ご利用ありがとうございます！次の画面でアプリの評価をお願いします。"),
                  dismissButton: .default(TextState("OK"))
                )
                return .none
        case .alert(.dismiss):
            return .none
        }
    }

    struct State: Equatable {
        @PresentationState var alert: AlertState<AlertAction>?
        var selectedFileFormat: String
        var samplingFrequency: Double
        var quantizationBitDepth:Int
        var numberOfChannels:Int
        var microphonesVolume:Double

        var isPurchaseAlertPresented: Bool = false

    }

}



struct SettingView: View {
    let store: StoreOf<SettingReducer>


    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            List {
                // ...
                //
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
                        HStack {
                            Button("開発者を支援する") {
                                viewStore.send(.showPurchaseOptions)
                            }
                            Spacer()
                        }
                    }
                }
                .alert(isPresented: viewStore.binding(get: \.isPurchaseAlertPresented, send: .purchaseProduct)) {
                    Alert(
                        title: Text("開発者を支援する"),
                        message: Text("開発者を支援するためのオプションを選択してください。"),
                        primaryButton: .default(Text("購入"), action: {
                            viewStore.send(.purchaseProduct)
                        }),
                        secondaryButton: .cancel()
                    )
                }
                .listStyle(GroupedListStyle())

            AdmobBannerView().frame(width: .infinity, height: 50)
        }
        .navigationTitle("設定")
    }

}

struct FileFormatView: View {
    let store: StoreOf<SettingReducer>
    @Environment(\.presentationMode) var presentationMode // 追加

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
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
    let store: StoreOf<SettingReducer>
    @Environment(\.presentationMode) var presentationMode // 追加

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
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
    let store: StoreOf<SettingReducer>
    @Environment(\.presentationMode) var presentationMode // 追加

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
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
    let store: StoreOf<SettingReducer>
    @Environment(\.presentationMode) var presentationMode // 追加

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
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
    let store: StoreOf<SettingReducer>
    @Environment(\.presentationMode) var presentationMode // 追加


    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in

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
