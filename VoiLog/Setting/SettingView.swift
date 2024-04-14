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
        case supported
    }

    enum AlertAction: Equatable {
        case isPurchaseAlertPresented
        case purchaseProduct
        
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
        case .alert(.presented(.purchaseProduct)):
            let productID = "developerSupport"
            // IAPManagerの共有インスタンスを使用して購入を開始する
            return .run { send in
                do {
                    try await IAPManager.shared.startPurchase(productID: productID)
                    await send(.supported)
                } catch let error {
                    print(error)
                }
            }

        case .alert(.presented(.isPurchaseAlertPresented)):
            if state.developerSupported {return .none}
            state.alert = AlertState(
              title: TextState("開発者を支援する"),
              message: TextState("ご支援いただける場合は次の画面で購入お願いいたします。開発費用に利用させていただきます。"),
              dismissButton: .default(TextState("次へ"),
              action: .send(.purchaseProduct))
            )
            return .none
        case .supported:
            state.alert = AlertState(
              title: TextState("サポートありがとうございます！"),
              message: TextState("いただいたサポートは開発費用として大切に利用させていただきます。"),
              dismissButton: .default(TextState("次へ")
            ))
            state.developerSupported = true
            UserDefaultsManager.shared.hasSupportedDeveloper = true

                return .none
        case .alert(.dismiss):
            state.alert = nil
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
        var developerSupported:Bool


    }

}



struct SettingView: View {
    let store: StoreOf<SettingReducer>


    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            
            VStack {

                HStack{
                    NavigationLink(destination: PaywallView()) {
                        HStack{
                            Image(systemName: "music.mic.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white,.purple)
                            VStack(alignment: .leading){
                                Text("プレミアムサービス 1ヶ月無料！")
                                    .fontWeight(.bold)
                                      .foregroundColor(.white)

                                HStack{
                                    Text("->詳しくはこちら")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Spacer()
                                }

                            }

                        }.padding()
                        .background(
                            Rectangle()
                                .fill(Color.black)
                                .cornerRadius(15)

                        )
                        .padding(.horizontal,20)

                    }
                }


                List {

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
                            Button(action: {
                                viewStore.send(.alert(.presented(.isPurchaseAlertPresented)))
                            }) {
                                HStack {
                                    Text("開発者を支援する")
                                        .foregroundColor(Color("Black"))

                                    Spacer()
                                    if viewStore.developerSupported{
                                        Text("購入済")
                                            .foregroundColor(Color("Black"))
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)

                                    }


                                }
                            }
                        }

                    }
                }
            }
            .alert(store: self.store.scope(state: \.$alert, action: SettingReducer.Action.alert))
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




struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView(store: Store(
            initialState: SettingReducer.State(
                alert: nil,
                selectedFileFormat: "WAV",
                samplingFrequency: 44100.0,
                quantizationBitDepth: 16,
                numberOfChannels: 2,
                microphonesVolume: 75.0,
                developerSupported: false
            )
        ){
            SettingReducer()
        }
        )
        .preferredColorScheme(.light)
    }
}
