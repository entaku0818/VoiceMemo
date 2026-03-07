//
//  SwiftUIView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 22.10.2022.
//

import SwiftUI
import ComposableArchitecture
import StoreKit
import os.log

struct SettingReducer: Reducer {
    @CasePathable
    enum Action: Equatable {
        case alert(PresentationAction<AlertAction>)
        case selectFileFormat(String)
        case samplingFrequency(Double)
        case quantizationBitDepth(Int)
        case numberOfChannels(Int)
        case microphonesVolume(Double)
        case supported
        case onAppear
        case startTutorial
        case delegate(DelegateAction)
        case feedbackFeature(FeedbackFeature.Action)
        case showFeedbackForm
        case dismissFeedbackForm
        case toggleDailyReminder(Bool)
        case setDailyReminderTime(Date)
        case restorePurchases
        case restoreResponse(Bool)
    }

    enum DelegateAction: Equatable {
        case startTutorialRequested
    }

    enum AlertAction: Equatable {
        case isPurchaseAlertPresented
        case purchaseProduct
        case restoreResult
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
            return .run { send in
                do {
                    try await PurchaseManager.shared.startOneTimePurchase()
                    await send(.supported)
                } catch {
                    AppLogger.purchase.error("Purchase failed: \(error)")
                }
            }

        case .alert(.presented(.restoreResult)):
            return .none

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
        case .onAppear:
            state.developerSupported = UserDefaultsManager.shared.hasSupportedDeveloper
            state.hasPurchasedPremium = UserDefaultsManager.shared.hasPurchasedProduct
            state.dailyReminderEnabled = UserDefaults.standard.bool(forKey: "DailyReminderEnabled")
            state.dailyReminderHour = UserDefaults.standard.object(forKey: "DailyReminderHour") as? Int ?? 9
            state.dailyReminderMinute = UserDefaults.standard.object(forKey: "DailyReminderMinute") as? Int ?? 0

            return .none
        case .restorePurchases:
            return .run { send in
                do {
                    try await PurchaseManager.shared.restorePurchases()
                    await send(.restoreResponse(true))
                } catch {
                    await send(.restoreResponse(false))
                }
            }

        case let .restoreResponse(success):
            if success {
                state.alert = AlertState(
                    title: TextState("購入を復元しました"),
                    message: TextState("プレミアム機能が利用可能になりました。"),
                    dismissButton: .default(TextState("OK"), action: .send(.restoreResult))
                )
                state.hasPurchasedPremium = true
            } else {
                state.alert = AlertState(
                    title: TextState("復元に失敗しました"),
                    message: TextState("購入履歴が見つかりませんでした。"),
                    dismissButton: .default(TextState("OK"), action: .send(.restoreResult))
                )
            }
            return .none

        case .startTutorial:
            return .send(.delegate(.startTutorialRequested))
        case .delegate:
            return .none
        case .feedbackFeature:
            return .none
        case .showFeedbackForm:
            state.showFeedbackSheet = true
            return .none
        case .dismissFeedbackForm:
            state.showFeedbackSheet = false
            return .none
        case let .toggleDailyReminder(enabled):
            state.dailyReminderEnabled = enabled
            UserDefaults.standard.set(enabled, forKey: "DailyReminderEnabled")
            if enabled {
                NotificationScheduler.shared.scheduleDailyReminder(
                    hour: state.dailyReminderHour,
                    minute: state.dailyReminderMinute
                )
            } else {
                NotificationScheduler.shared.cancelDailyReminder()
            }
            return .none
        case let .setDailyReminderTime(date):
            let hour = Calendar.current.component(.hour, from: date)
            let minute = Calendar.current.component(.minute, from: date)
            state.dailyReminderHour = hour
            state.dailyReminderMinute = minute
            UserDefaults.standard.set(hour, forKey: "DailyReminderHour")
            UserDefaults.standard.set(minute, forKey: "DailyReminderMinute")
            if state.dailyReminderEnabled {
                NotificationScheduler.shared.scheduleDailyReminder(hour: hour, minute: minute)
            }
            return .none
        }
    }

    var body: some ReducerOf<Self> {
        Reduce(self.reduce)
        Scope(state: \.feedbackState, action: \.feedbackFeature) {
            FeedbackFeature()
        }
    }

    struct State: Equatable {
        @PresentationState var alert: AlertState<AlertAction>?
        var selectedFileFormat: String
        var samplingFrequency: Double
        var quantizationBitDepth: Int
        var numberOfChannels: Int
        var microphonesVolume: Double
        var developerSupported: Bool
        var hasPurchasedPremium: Bool
        var feedbackState = FeedbackFeature.State()
        var showFeedbackSheet = false
        var dailyReminderEnabled = false
        var dailyReminderHour: Int = 9
        var dailyReminderMinute: Int = 0
    }

}

struct SettingView: View {
    let store: StoreOf<SettingReducer>
    @Environment(\.colorScheme) var colorScheme
    let admobUnitId: String

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in

            VStack {
                if !viewStore.hasPurchasedPremium {

                    NavigationLink(destination: PaywallView(purchaseManager: PurchaseManager.shared)) {
                        HStack {
                            Image(systemName: "music.mic.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .purple)
                            VStack(alignment: .leading) {
                                Text("1ヶ月無料！")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("プレミアムサービス")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Text("詳細をタップ")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                        }.padding()
                        .background(
                            Rectangle()
                                .fill(Color.black)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(colorScheme == .dark ? Color.white : Color.clear, lineWidth: 1)
                                )

                        )
                        .padding(.horizontal, 20)

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

                    }
                    Section(header: Text("")) {
                        Button(action: {
                            viewStore.send(.startTutorial)
                        }) {
                            HStack {
                                Text("チュートリアルを再開")
                                    .foregroundColor(Color("Black"))
                                Spacer()
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(.blue)
                            }
                        }

                        NavigationLink(destination: AboutSimpleRecoder()) {
                            HStack {
                                Text("アプリについて")
                                Spacer()

                            }
                        }

                        Button {
                            store.send(.showFeedbackForm)
                        } label: {
                            HStack {
                                Text("フィードバック")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                                    if viewStore.developerSupported {
                                        Text("購入済")
                                            .foregroundColor(Color("Black"))
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)

                                    }

                                }
                            }
                        }

                    }
                    Section(header: Text("購入")) {
                        Button(action: {
                            viewStore.send(.restorePurchases)
                        }) {
                            HStack {
                                Text("購入を復元")
                                    .foregroundColor(Color("Black"))
                                Spacer()
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    Section(header: Text("通知設定")) {
                        Toggle("毎日のリマインダー", isOn: Binding(
                            get: { viewStore.dailyReminderEnabled },
                            set: { viewStore.send(.toggleDailyReminder($0)) }
                        ))
                        if viewStore.dailyReminderEnabled {
                            DatePicker(
                                "時刻",
                                selection: Binding(
                                    get: {
                                        var components = DateComponents()
                                        components.hour = viewStore.dailyReminderHour
                                        components.minute = viewStore.dailyReminderMinute
                                        return Calendar.current.date(from: components) ?? Date()
                                    },
                                    set: { viewStore.send(.setDailyReminderTime($0)) }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }

                    #if DEBUG
                    Section(header: Text("デバッグ")) {
                        NavigationLink(destination: ErrorLogsView()) {
                            Text("エラーログを見る")
                        }
                        NavigationLink(destination: AdDebugView()) {
                            Text("広告テスト")
                        }
                        NavigationLink(destination: ScreenshotPreviewView()) {
                            Text("スクリーンショットプレビュー")
                        }
                    }
                    #endif
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
            .alert(store: self.store.scope(state: \.$alert, action: SettingReducer.Action.alert))
            .listStyle(GroupedListStyle())
            .fullScreenCover(isPresented: Binding(
                get: { viewStore.showFeedbackSheet },
                set: { if !$0 { viewStore.send(.dismissFeedbackForm) } }
            )) {
                FeedbackFormView(store: self.store.scope(state: \.feedbackState, action: \.feedbackFeature))
            }

            if !viewStore.hasPurchasedPremium {
                AdmobBannerView(unitId: admobUnitId).frame(width: .infinity, height: 50)
            }
        }
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
                developerSupported: false, hasPurchasedPremium: false
            )
        ) {
            SettingReducer()
        }, admobUnitId: ""
        )
        .preferredColorScheme(.light)
    }
}
