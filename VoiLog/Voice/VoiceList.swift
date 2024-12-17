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

   enum AlertType {
       case deleted
       case appInterview
       case mail
   }
   @State private var isDeleteConfirmationPresented = false
   @State private var selectedIndex: Int?

   init(store:  StoreOf<VoiceMemos>, admobUnitId:String, recordAdmobUnitId:String) {
       self.store = store
       self.admobUnitId = admobUnitId
       self.recordAdmobUnitId = recordAdmobUnitId
   }

   var body: some View {
       WithViewStore(self.store, observe: { $0 }) { viewStore in
           NavigationView {
               VStack {
                   List {
                       ForEachStore(
                           self.store.scope(state: \.voiceMemos, action: VoiceMemos.Action.voiceMemos)
                       ) {
                           VoiceMemoListItem(store: $0, admobUnitId: admobUnitId, currentMode: viewStore.currentMode)
                       }
                       .onDelete { indexSet in
                           for index in indexSet {
                               selectedIndex = index
                               isDeleteConfirmationPresented = true
                           }
                       }
                   }
                   if viewStore.currentMode == .playback {
                       if let playingMemoID = viewStore.currentPlayingMemo {
                             ForEachStore(
                                 self.store.scope(state: \.voiceMemos, action: VoiceMemos.Action.voiceMemos),
                                 content: { store in
                                     if store.withState({ $0.id == playingMemoID }) {
                                         PlayerView(store: store)
                                     }
                                 }
                             )
                       }
                   }else if viewStore.currentMode == .recording {
                       IfLetStore(
                           self.store.scope(state: \.$recordingMemo, action: VoiceMemos.Action.recordingMemo)
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
                       .background(Color.init(white: 0.95))
                   }



                   if !viewStore.hasPurchasedPremium{
                       AdmobBannerView(unitId: recordAdmobUnitId)
                           .frame(height: 50)
                   }
               }
               .onAppear {
                   checkTrackingAuthorizationStatus()
                   viewStore.send(.onAppear)
               }
               .alert(store: self.store.scope(state: \.$alert, action: VoiceMemos.Action.alert))
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
                       secondaryButton: .cancel() {
                           selectedIndex = nil
                       }
                   )
               }
               .sheet(
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
               .navigationTitle("シンプル録音")
               .toolbar {
                   ToolbarItem(placement: .navigationBarLeading) {

                       if !viewStore.hasPlayingMemo {
                           Button(action: {
                               viewStore.send(.toggleMode)
                           }) {
                               Text(viewStore.currentMode == .playback ? "再生" : "録音")
                           }
                       }
                   }
                   ToolbarItem(placement: .navigationBarTrailing) {
                       if viewStore.recordingMemo == nil {
                           makeToolbarContent(viewStore: viewStore)
                       }
                   }
               }
           }
           .navigationViewStyle(.stack)
       }
   }

   private func makeToolbarContent(viewStore: ViewStore<VoiceMemos.State, VoiceMemos.Action>) -> some View {
       let initialState = SettingReducer.State(
           selectedFileFormat: UserDefaultsManager.shared.selectedFileFormat,
           samplingFrequency: UserDefaultsManager.shared.samplingFrequency,
           quantizationBitDepth: UserDefaultsManager.shared.quantizationBitDepth,
           numberOfChannels: UserDefaultsManager.shared.numberOfChannels,
           microphonesVolume: UserDefaultsManager.shared.microphonesVolume,
           developerSupported: UserDefaultsManager.shared.hasSupportedDeveloper,
           hasPurchasedPremium: UserDefaultsManager.shared.hasPurchasedProduct
       )

       let settingStore = Store(initialState: initialState) {
           SettingReducer()
       }

       return HStack {
           makeSyncStatusView(viewStore: viewStore)
           Spacer().frame(width: 10)
           NavigationLink(destination: SettingView(store: settingStore, admobUnitId: admobUnitId)) {
               Image(systemName: "gearshape.fill")
                   .accentColor(.accentColor)
           }
       }
   }

    private func makeSyncStatusView(viewStore: ViewStore<VoiceMemos.State, VoiceMemos.Action>) -> some View {
        Group {
            if viewStore.syncStatus == .synced {
                Image(systemName: "checkmark.icloud.fill")
                    .foregroundColor(.accentColor)
            } else if viewStore.syncStatus == .syncing {
                Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                    .foregroundColor(.accentColor)
            } else {
                if viewStore.hasPurchasedPremium {
                    Button {
                        viewStore.send(.synciCloud)
                    } label: {
                        Image(systemName: "exclamationmark.icloud.fill")
                            .foregroundColor(.accentColor)
                    }
                } else {
                    NavigationLink(destination: PaywallView(purchaseManager: PurchaseManager.shared)) {
                        Image(systemName: "exclamationmark.icloud.fill")
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
    }

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
                            text: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\naaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
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
            recordAdmobUnitId: ""
        )
    }
}




