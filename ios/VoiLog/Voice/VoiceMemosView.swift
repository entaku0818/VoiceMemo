import AVFoundation
import StoreKit
import ComposableArchitecture
import Foundation
import SwiftUI
import AppTrackingTransparency
import GoogleMobileAds

struct VoiceMemosView: View {
    let store: StoreOf<VoiceMemos>
    let admobUnitId: String
    let recordAdmobUnitId: String
    let playListAdmobUnitId: String

    @State private var isDeleteConfirmationPresented = false
    @State private var selectedIndex: Int?
    @State private var isRecordingNavigationAlertPresented = false

    func checkTrackingAuthorizationStatus() {
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .notDetermined:
            requestTrackingAuthorization()
        case .restricted: break
        case .denied: break
        case .authorized: break
        @unknown default: break
        }
    }

    func requestTrackingAuthorization() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .notDetermined: break
                case .restricted: break
                case .denied: break
                case .authorized: break
                @unknown default: break
                }
            }
        }
    }

    init(store: StoreOf<VoiceMemos>, admobUnitId: String, recordAdmobUnitId: String, playListAdmobUnitId: String) {
        self.store = store
        self.admobUnitId = admobUnitId
        self.recordAdmobUnitId = recordAdmobUnitId
        self.playListAdmobUnitId = playListAdmobUnitId
    }

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                NavigationView {
                    VStack {
                        VoiceMemoListView(
                            store: store,
                            admobUnitId: admobUnitId,
                            playListAdmobUnitId: playListAdmobUnitId,
                            isDeleteConfirmationPresented: $isDeleteConfirmationPresented,
                            selectedIndex: $selectedIndex,
                            isRecordingNavigationAlertPresented: $isRecordingNavigationAlertPresented
                        )

                        if viewStore.currentMode == .playback {
                            if let playingMemoID = viewStore.currentPlayingMemo {
                                ForEachStore(
                                    store.scope(state: \.voiceMemos, action: VoiceMemos.Action.voiceMemos)
                                ) { store in
                                    if store.withState({ $0.id == playingMemoID }) {
                                        PlayerView(store: store)
                                    }
                                }
                            }
                        } else if viewStore.currentMode == .recording {
                            IfLetStore(
                                store.scope(state: \.$recordingMemo, action: VoiceMemos.Action.recordingMemo)
                            ) { store in
                                RecordingMemoView(store: store)
                            } else: {
                                RecordButton(permission: viewStore.audioRecorderPermission) {
                                    viewStore.send(.recordButtonTapped, animation: .spring())
                                } settingsAction: {
                                    viewStore.send(.openSettingsButtonTapped)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(white: 0.95))
                        }

                        if !viewStore.hasPurchasedPremium {
                            AdmobBannerView(unitId: recordAdmobUnitId)
                                .frame(height: 50)
                        }
                    }
                    .navigationTitle("シンプル録音")
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            if viewStore.recordingMemo != nil {
                                HStack {
                                    Text("シンプル録音")
                                    Image(systemName: "record.circle")
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        ToolbarItem(placement: .navigationBarLeading) {
                                if !viewStore.hasPlayingMemo {
                                    Button(action: {
                                        if viewStore.recordingMemo != nil {
                                            isRecordingNavigationAlertPresented = true
                                        } else {
                                            viewStore.send(.toggleMode)
                                        }
                                    }) {
                                        Text(viewStore.currentMode == .playback ? "再生" : "録音")
                                    }
                            }
                        }

                        ToolbarItem(placement: .navigationBarTrailing) {
                            HStack {
                                if viewStore.syncStatus == .synced {
                                    Image(systemName: "checkmark.icloud.fill")
                                        .foregroundColor(.accentColor)
                                } else if viewStore.syncStatus == .syncing {
                                    Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                                        .foregroundColor(.accentColor)
                                } else {
                                    if viewStore.hasPurchasedPremium {
                                        Button {
                                            if viewStore.recordingMemo != nil {
                                                isRecordingNavigationAlertPresented = true
                                            } else {
                                                viewStore.send(.synciCloud)
                                            }
                                        } label: {
                                            Image(systemName: "exclamationmark.icloud.fill")
                                                .foregroundColor(.accentColor)
                                        }
                                    } else {
                                        let paywallView = PaywallView(purchaseManager: PurchaseManager.shared)
                                        NavigationLink(
                                            destination: paywallView,
                                            label: {
                                                Image(systemName: "exclamationmark.icloud.fill")
                                                    .foregroundColor(.accentColor)
                                            }
                                        )
                                        .allowsHitTesting(!viewStore.isRecording)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if viewStore.recordingMemo != nil {
                                                isRecordingNavigationAlertPresented = true
                                            }
                                        }
                                    }
                                }

                                Spacer().frame(width: 10)

                                let settingStore = Store(
                                    initialState: SettingReducer.State(
                                        selectedFileFormat: UserDefaultsManager.shared.selectedFileFormat,
                                        samplingFrequency: UserDefaultsManager.shared.samplingFrequency,
                                        quantizationBitDepth: UserDefaultsManager.shared.quantizationBitDepth,
                                        numberOfChannels: UserDefaultsManager.shared.numberOfChannels,
                                        microphonesVolume: UserDefaultsManager.shared.microphonesVolume,
                                        developerSupported: UserDefaultsManager.shared.hasSupportedDeveloper,
                                        hasPurchasedPremium: UserDefaultsManager.shared.hasPurchasedProduct
                                    )
                                ) {
                                    SettingReducer()
                                }

                                NavigationLink(
                                    destination: SettingView(store: settingStore, admobUnitId: admobUnitId),
                                    label: {
                                        Image(systemName: "gearshape.fill")
                                            .accentColor(.accentColor)
                                    }
                                )
                                .allowsHitTesting(!viewStore.isRecording)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if viewStore.recordingMemo != nil {
                                        isRecordingNavigationAlertPresented = true
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationViewStyle(.stack)
                .onAppear {
                    checkTrackingAuthorizationStatus()
                    viewStore.send(.onAppear)
                }

                if viewStore.showTutorial {
                    TutorialView(store: store)
                }

                if viewStore.showTitleDialog {
                    ZStack {
                        // 背景のオーバーレイ
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)

                        // ダイアログカード
                        VStack(spacing: 24) {
                            // ヘッダー部分
                            VStack(spacing: 8) {
                                Text("メモのタイトルを入力")
                                    .font(.headline)
                                    .fontWeight(.bold)

                                Text("このメモにわかりやすいタイトルをつけましょう")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }

                            // 入力フィールド
                            TextField("タイトル", text: viewStore.binding(
                                get: \.tempTitle,
                                send: { VoiceMemos.Action.setTempTitle($0) }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 4)
                            .submitLabel(.done)
                            .onSubmit {
                                if !viewStore.tempTitle.isEmpty {
                                    viewStore.send(.saveTitle)
                                }
                            }

                            // ボタンエリア
                            HStack(spacing: 16) {
                                Button(action: {
                                    viewStore.send(.showTitleDialog(false))
                                }) {
                                    Text("キャンセル")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .font(.subheadline)
                                }
                                .buttonStyle(.bordered)
                                .tint(.secondary)
                                .controlSize(.small)

                                Button(action: {
                                    viewStore.send(.saveTitle)
                                }) {
                                    Text("保存")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .controlSize(.small)
                                .disabled(viewStore.tempTitle.isEmpty)
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.systemBackground))
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 4)
                        .padding(.horizontal, 40)
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                if isRecordingNavigationAlertPresented {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)

                        VStack(spacing: 16) {
                            Text("録音中です")
                                .font(.headline)
                                .fontWeight(.bold)

                            Text("録音中は他の操作ができません。\n録音を停止してから操作してください。")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button(action: {
                                isRecordingNavigationAlertPresented = false
                            }) {
                                Text("録音を続ける")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemBackground))
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 4)
                        .padding(.horizontal, 40)
                    }
                }
            }
            .alert(isPresented: $isDeleteConfirmationPresented) {
                Alert(
                    title: Text("削除しますか？"),
                    message: Text("選択した音声を削除しますか？"),
                    primaryButton: .destructive(Text("削除")) {
                        if let index = selectedIndex {
                            let voiceMemoID = viewStore.voiceMemos[index].uuid
                            viewStore.send(.onDelete(uuid: voiceMemoID))
                            selectedIndex = nil
                        }
                    },
                    secondaryButton: .cancel {
                        selectedIndex = nil
                    }
                )
            }
            .fullScreenCover(
                isPresented: viewStore.binding(
                    get: \.isMailComposePresented,
                    send: VoiceMemos.Action.mailComposeDismissed
                )
            ) {
                MailComposeViewControllerWrapper(
                    isPresented: viewStore.binding(
                        get: \.isMailComposePresented,
                        send: VoiceMemos.Action.mailComposeDismissed
                    )
                )
            }

        }
    }
}

private struct VoiceMemoListView: View {
    let store: StoreOf<VoiceMemos>
    let admobUnitId: String
    let playListAdmobUnitId: String
    @Binding var isDeleteConfirmationPresented: Bool
    @Binding var selectedIndex: Int?
    @Binding var isRecordingNavigationAlertPresented: Bool

    var body: some View {
        WithViewStore(store, observe: { $0 }) { _ in
            List {
                PlaylistSection(
                    store: store,
                    playListAdmobUnitId: playListAdmobUnitId,
                    isRecordingNavigationAlertPresented: $isRecordingNavigationAlertPresented
                )

                VoiceMemoSection(
                    store: store,
                    admobUnitId: admobUnitId,
                    isDeleteConfirmationPresented: $isDeleteConfirmationPresented,
                    selectedIndex: $selectedIndex,
                    isRecordingNavigationAlertPresented: $isRecordingNavigationAlertPresented
                )
            }
        }
    }
}

private struct PlaylistSection: View {
    let store: StoreOf<VoiceMemos>
    let playListAdmobUnitId: String
    @Binding var isRecordingNavigationAlertPresented: Bool

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Section {
                let playlistStore = Store(
                    initialState: PlaylistListFeature.State()
                ) { PlaylistListFeature() }

                let destination = PlaylistListView(
                    store: playlistStore,
                    admobUnitId: playListAdmobUnitId
                )

                NavigationLink(
                    destination: destination,
                    label: {
                        Label("プレイリスト", systemImage: "music.note.list")
                    }
                )
                .disabled(viewStore.recordingMemo != nil)
                .simultaneousGesture(TapGesture().onEnded {
                    if viewStore.recordingMemo != nil {
                        isRecordingNavigationAlertPresented = true
                    }
                })
            }
        }
    }
}

private struct VoiceMemoSection: View {
    let store: StoreOf<VoiceMemos>
    let admobUnitId: String
    @Binding var isDeleteConfirmationPresented: Bool
    @Binding var selectedIndex: Int?
    @Binding var isRecordingNavigationAlertPresented: Bool

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Section {
                ForEachStore(
                    store.scope(state: \.voiceMemos, action: VoiceMemos.Action.voiceMemos)
                ) {
                    VoiceMemoListItem(
                        store: $0,
                        admobUnitId: admobUnitId,
                        currentMode: viewStore.currentMode,
                        isRecording: .constant(viewStore.recordingMemo != nil),
                        isRecordingNavigationAlertPresented: $isRecordingNavigationAlertPresented
                    )
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        selectedIndex = index
                        isDeleteConfirmationPresented = true
                    }
                }
            }
        }
    }
}

struct RecordButton: View {
    let permission: VoiceMemos.State.RecorderPermission
    let action: () -> Void
    let settingsAction: () -> Void

    var body: some View {
        ZStack {
            Group {
                Circle()
                    .foregroundColor(Color(.label))
                    .frame(width: 74, height: 74)

                Button(action: self.action) {
                    RoundedRectangle(cornerRadius: 35)
                        .foregroundColor(Color(.systemRed))
                        .padding(2)
                }
                .frame(width: 70, height: 70)

            }
            .opacity(self.permission == .denied ? 0.1 : 1)

            if self.permission == .denied {
                VStack(spacing: 10) {
                    Text("Recording requires microphone access.")
                        .multilineTextAlignment(.center)
                    Button("Open Settings", action: self.settingsAction)
                }
                .frame(maxWidth: .infinity, maxHeight: 74)
            }
        }
    }
}

struct VoiceMemos_Previews: PreviewProvider {
    static var previews: some View {
            VoiceMemosView(
                store: Store(
                    initialState: VoiceMemos.State(
                        voiceMemos: [
                            VoiceMemoReducer.State(
                                uuid: UUID(),
                                date: Date(),
                                duration: 5,
                                time: 0,
                                mode: .notPlaying,
                                title: "Functions",
                                url: URL(string: "https://www.pointfree.co/functions")!,
                                text: "",
                                fileFormat: "",
                                samplingFrequency: 0.0,
                                quantizationBitDepth: 0,
                                numberOfChannels: 0,
                                hasPurchasedPremium: false
                            ),
                            VoiceMemoReducer.State(
                                uuid: UUID(),
                                date: Date(),
                                duration: 5,
                                time: 0,
                                mode: .notPlaying,
                                title: "",
                                url: URL(string: "https://www.pointfree.co/untitled")!,
                                text: """
                                    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
                                    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
                                    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
                                    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
                                    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
                                    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
                                    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
                                    """,
                                fileFormat: "",
                                samplingFrequency: 0.0,
                                quantizationBitDepth: 0,
                                numberOfChannels: 0,
                                hasPurchasedPremium: false
                            )
                        ] + (1...30).map { index in
                            VoiceMemoReducer.State(
                                uuid: UUID(),
                                date: Date().addingTimeInterval(TimeInterval(index * -60)),
                                duration: Double.random(in: 5...300),
                                time: 0,
                                mode: .notPlaying,
                                title: "Memo \(index)",
                                url: URL(string: "https://www.example.com/memo\(index)")!,
                                text: "Sample text for memo \(index)",
                                fileFormat: "m4a",
                                samplingFrequency: Double.random(in: 44100...48000),
                                quantizationBitDepth: 16,
                                numberOfChannels: Int.random(in: 1...2),
                                hasPurchasedPremium: Bool.random()
                            )
                        }
                    )
                ) {
                    VoiceMemos()
                },
                admobUnitId: "",
                recordAdmobUnitId: "", playListAdmobUnitId: ""
            )

    }
}
