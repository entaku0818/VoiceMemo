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

@Reducer
struct SettingReducer {
    enum Action {
        case selectFileFormat(String)
        case samplingFrequency(Double)
        case quantizationBitDepth(Int)
        case numberOfChannels(Int)
        case microphonesVolume(Double)
        case onAppear
        case startTutorial
        case delegate(DelegateAction)
        case showFeedbackForm
        case dismissFeedbackForm
        case toggleDailyReminder(Bool)
        case setDailyReminderTime(Date)
        case toggleTranscription(Bool)
        case showSupportDeveloperAlert
        case purchaseProduct
        case supported
        case dismissPurchaseConfirmAlert
        case dismissInfoAlert
        case restorePurchases
        case restoreResponse(Bool)
    }

    enum DelegateAction: Equatable {
        case startTutorialRequested
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
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
        case .showSupportDeveloperAlert:
            if state.developerSupported { return .none }
            state.showPurchaseConfirmAlert = true
            return .none
        case .dismissPurchaseConfirmAlert:
            state.showPurchaseConfirmAlert = false
            return .none
        case .purchaseProduct:
            state.showPurchaseConfirmAlert = false
            return .run { send in
                do {
                    try await PurchaseManager.shared.startOneTimePurchase()
                    await send(.supported)
                } catch {
                    AppLogger.purchase.error("Purchase failed: \(error)")
                }
            }
        case .supported:
            state.developerSupported = true
            state.showPurchaseSuccessAlert = true
            UserDefaultsManager.shared.hasSupportedDeveloper = true
            return .none
        case .onAppear:
            state.developerSupported = UserDefaultsManager.shared.hasSupportedDeveloper
            state.hasPurchasedPremium = UserDefaultsManager.shared.hasPurchasedProduct
            state.dailyReminderEnabled = UserDefaults.standard.bool(forKey: "DailyReminderEnabled")
            state.dailyReminderHour = UserDefaults.standard.object(forKey: "DailyReminderHour") as? Int ?? 9
            state.dailyReminderMinute = UserDefaults.standard.object(forKey: "DailyReminderMinute") as? Int ?? 0
            state.isTranscriptionEnabled = UserDefaultsManager.shared.isTranscriptionEnabled
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
                state.hasPurchasedPremium = true
                state.showRestoreSuccessAlert = true
            } else {
                state.showRestoreFailureAlert = true
            }
            return .none
        case .dismissInfoAlert:
            state.showPurchaseSuccessAlert = false
            state.showRestoreSuccessAlert = false
            state.showRestoreFailureAlert = false
            return .none
        case .startTutorial:
            return .send(.delegate(.startTutorialRequested))
        case .delegate:
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
        case let .toggleTranscription(enabled):
            state.isTranscriptionEnabled = enabled
            UserDefaultsManager.shared.isTranscriptionEnabled = enabled
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
    }

    @ObservableState
    struct State: Equatable {
        var selectedFileFormat: String
        var samplingFrequency: Double
        var quantizationBitDepth: Int
        var numberOfChannels: Int
        var microphonesVolume: Double
        var developerSupported: Bool
        var hasPurchasedPremium: Bool
        var showFeedbackSheet = false
        var dailyReminderEnabled = false
        var dailyReminderHour: Int = 9
        var dailyReminderMinute: Int = 0
        var isTranscriptionEnabled = UserDefaultsManager.shared.isTranscriptionEnabled
        var showPurchaseConfirmAlert = false
        var showPurchaseSuccessAlert = false
        var showRestoreSuccessAlert = false
        var showRestoreFailureAlert = false

        var dailyReminderDate: Date {
            var components = DateComponents()
            components.hour = dailyReminderHour
            components.minute = dailyReminderMinute
            return Calendar.current.date(from: components) ?? Date()
        }
    }
}

// MARK: - SettingView

struct SettingView: View {
    @Perception.Bindable var store: StoreOf<SettingReducer>
    @Environment(\.colorScheme) var colorScheme
    let admobUnitId: String

    var body: some View {
        VStack {
            if !store.hasPurchasedPremium {
                PremiumBannerView(colorScheme: colorScheme)
            }

            List {
                audioSettingsSection
                generalSection
                purchaseSection
                notificationSection
                transcriptionSection
                DeveloperAppsSectionView()

                #if DEBUG
                debugSection
                #endif
            }
        }
        .onAppear { store.send(.onAppear) }
        .listStyle(GroupedListStyle())
        .fullScreenCover(isPresented: Binding(
            get: { store.showFeedbackSheet },
            set: { if !$0 { store.send(.dismissFeedbackForm) } }
        )) {
            FeedbackFormView()
        }
        .alert(String(localized: "開発者を支援する"), isPresented: Binding(
            get: { store.showPurchaseConfirmAlert },
            set: { if !$0 { store.send(.dismissPurchaseConfirmAlert) } }
        )) {
            Button(String(localized: "次へ")) { store.send(.purchaseProduct) }
            Button("キャンセル", role: .cancel) { store.send(.dismissPurchaseConfirmAlert) }
        } message: {
            Text(String(localized: "ご支援いただける場合は次の画面で購入お願いいたします。開発費用に利用させていただきます。"))
        }
        .alert(String(localized: "サポートありがとうございます！"), isPresented: Binding(
            get: { store.showPurchaseSuccessAlert },
            set: { if !$0 { store.send(.dismissInfoAlert) } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(String(localized: "いただいたサポートは開発費用として大切に利用させていただきます。"))
        }
        .alert(String(localized: "購入を復元しました"), isPresented: Binding(
            get: { store.showRestoreSuccessAlert },
            set: { if !$0 { store.send(.dismissInfoAlert) } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(String(localized: "プレミアム機能が利用可能になりました。"))
        }
        .alert(String(localized: "復元に失敗しました"), isPresented: Binding(
            get: { store.showRestoreFailureAlert },
            set: { if !$0 { store.send(.dismissInfoAlert) } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(String(localized: "購入履歴が見つかりませんでした。"))
        }

        if !store.hasPurchasedPremium {
            AdmobBannerView(unitId: admobUnitId).frame(width: .infinity, height: 50)
        }
    }

    @ViewBuilder
    private var audioSettingsSection: some View {
        Section(header: Text(String(localized: "音声設定"))) {
            NavigationLink(destination: FileFormatView(store: store)) {
                HStack {
                    Text(String(localized: "ファイル形式"))
                    Spacer()
                    Text(store.selectedFileFormat)
                }
            }

            NavigationLink(destination: SamplingFrequencyView(store: store)) {
                HStack {
                    Text(String(localized: "サンプリング周波数"))
                    Spacer()
                    Text("\(String(store.samplingFrequency))Hz")
                }
            }

            NavigationLink(destination: QuantizationBitDepthView(store: store)) {
                HStack {
                    Text(String(localized: "量子化ビット数"))
                    Spacer()
                    Text("\(store.quantizationBitDepth)bit")
                }
            }

            #if DEBUG
            NavigationLink(destination: NumberOfChannelsView(store: store)) {
                HStack {
                    Text(String(localized: "チャネル"))
                    Spacer()
                    Text("\(store.numberOfChannels)")
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private var generalSection: some View {
        Section(header: Text("")) {
            Button {
                store.send(.startTutorial)
            } label: {
                HStack {
                    Text(String(localized: "チュートリアルを再開"))
                        .foregroundColor(Color("Black"))
                    Spacer()
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.blue)
                }
            }

            NavigationLink(destination: AboutSimpleRecoder()) {
                Text(String(localized: "アプリについて"))
            }

            Button {
                store.send(.showFeedbackForm)
            } label: {
                HStack {
                    Text(String(localized: "フィードバック"))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button {
                store.send(.showSupportDeveloperAlert)
            } label: {
                HStack {
                    Text(String(localized: "開発者を支援する"))
                        .foregroundColor(Color("Black"))
                    Spacer()
                    if store.developerSupported {
                        Text(String(localized: "購入済"))
                            .foregroundColor(Color("Black"))
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var purchaseSection: some View {
        Section(header: Text(String(localized: "購入"))) {
            Button {
                store.send(.restorePurchases)
            } label: {
                HStack {
                    Text(String(localized: "購入を復元"))
                        .foregroundColor(Color("Black"))
                    Spacer()
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.blue)
                }
            }
        }
    }

    @ViewBuilder
    private var notificationSection: some View {
        Section(header: Text(String(localized: "通知設定"))) {
            Toggle(String(localized: "毎日のリマインダー"), isOn: Binding(
                get: { store.dailyReminderEnabled },
                set: { store.send(.toggleDailyReminder($0)) }
            ))
            if store.dailyReminderEnabled {
                DatePicker(
                    String(localized: "時刻"),
                    selection: Binding(
                        get: { store.dailyReminderDate },
                        set: { store.send(.setDailyReminderTime($0)) }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
        }
    }

    @ViewBuilder
    private var transcriptionSection: some View {
        Section(header: Text(String(localized: "文字起こし"))) {
            Toggle(String(localized: "文字起こし"), isOn: Binding(
                get: { store.isTranscriptionEnabled },
                set: { store.send(.toggleTranscription($0)) }
            ))
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section(header: Text(String(localized: "デバッグ"))) {
            NavigationLink(destination: ErrorLogsView()) {
                Text(String(localized: "エラーログを見る"))
            }
            NavigationLink(destination: AdDebugView()) {
                Text(String(localized: "広告テスト"))
            }
            NavigationLink(destination: ScreenshotPreviewView()) {
                Text(String(localized: "スクリーンショットプレビュー"))
            }
        }
    }
    #endif
}

// MARK: - PremiumBannerView

private struct PremiumBannerView: View {
    let colorScheme: ColorScheme

    var body: some View {
        NavigationLink(destination: PaywallView(purchaseManager: PurchaseManager.shared)) {
            HStack {
                Image(systemName: "music.mic.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .purple)
                VStack(alignment: .leading) {
                    Text(String(localized: "1ヶ月無料！"))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(String(localized: "プレミアムサービス"))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                Spacer()
                Text(String(localized: "詳細をタップ"))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding()
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
}

// MARK: - SelectionListView

private struct SelectionListView<Item: CaseIterable & Hashable>: View {
    let title: String
    let items: [Item]
    let itemLabel: (Item) -> String
    let isSelected: (Item) -> Bool
    let onSelect: (Item) -> Void

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        List {
            ForEach(items, id: \.self) { item in
                Button {
                    onSelect(item)
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    HStack {
                        Text(itemLabel(item))
                        Spacer()
                        if isSelected(item) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationTitle(title)
    }
}

// MARK: - Audio Setting Selection Views

struct FileFormatView: View {
    let store: StoreOf<SettingReducer>

    var body: some View {
        SelectionListView(
            title: String(localized: "ファイル形式"),
            items: Array(Constants.FileFormat.allCases),
            itemLabel: { $0.rawValue },
            isSelected: { $0.rawValue == store.selectedFileFormat },
            onSelect: { store.send(.selectFileFormat($0.rawValue)) }
        )
    }
}

struct SamplingFrequencyView: View {
    let store: StoreOf<SettingReducer>

    var body: some View {
        SelectionListView(
            title: String(localized: "サンプリング周波数"),
            items: Array(Constants.SamplingFrequency.allCases),
            itemLabel: { $0.stringValue },
            isSelected: { $0.rawValue == store.samplingFrequency },
            onSelect: { store.send(.samplingFrequency($0.rawValue)) }
        )
    }
}

struct QuantizationBitDepthView: View {
    let store: StoreOf<SettingReducer>

    var body: some View {
        SelectionListView(
            title: String(localized: "量子化ビット数"),
            items: Array(Constants.QuantizationBitDepth.allCases),
            itemLabel: { $0.stringValue },
            isSelected: { $0.rawValue == store.quantizationBitDepth },
            onSelect: { store.send(.quantizationBitDepth($0.rawValue)) }
        )
    }
}

struct NumberOfChannelsView: View {
    let store: StoreOf<SettingReducer>

    var body: some View {
        SelectionListView(
            title: String(localized: "チャネル"),
            items: Array(Constants.NumberOfChannels.allCases),
            itemLabel: { "\($0.rawValue)" },
            isSelected: { $0.rawValue == store.numberOfChannels },
            onSelect: { store.send(.numberOfChannels($0.rawValue)) }
        )
    }
}

struct MicrophonesVolumeView: View {
    let store: StoreOf<SettingReducer>

    var body: some View {
        SelectionListView(
            title: String(localized: "マイクの音量"),
            items: Array(Constants.MicrophonesVolume.allCases),
            itemLabel: { "\(Int($0.rawValue))" },
            isSelected: { $0.rawValue == store.microphonesVolume },
            onSelect: { store.send(.microphonesVolume($0.rawValue)) }
        )
    }
}

// MARK: - Preview

#Preview {
    SettingView(
        store: Store(
            initialState: SettingReducer.State(
                selectedFileFormat: "WAV",
                samplingFrequency: 44100.0,
                quantizationBitDepth: 16,
                numberOfChannels: 2,
                microphonesVolume: 75.0,
                developerSupported: false,
                hasPurchasedPremium: false
            )
        ) {
            SettingReducer()
        },
        admobUnitId: ""
    )
    .preferredColorScheme(.light)
}
