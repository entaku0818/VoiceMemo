import AVFoundation
import StoreKit
import ComposableArchitecture
import Foundation
import SwiftUI
import AppTrackingTransparency
import GoogleMobileAds




struct VoiceMemos: Reducer {
  struct State: Equatable {
    @PresentationState var alert: AlertState<AlertAction>?
    var audioRecorderPermission = RecorderPermission.undetermined
    @PresentationState var recordingMemo: RecordingMemo.State?
    var voiceMemos: IdentifiedArrayOf<VoiceMemoReducer.State> = []
    var isMailComposePresented: Bool = false
      var syncStatus: SyncStatus = .notSynced
      var hasPurchasedPremium: Bool = false


    enum RecorderPermission {
      case allowed
      case denied
      case undetermined
    }
      enum SyncStatus {
        case synced
          case syncing
        case notSynced
        case cantUseCloud
      }

  }

  enum Action: Equatable {
    case alert(PresentationAction<AlertAction>)
    case onAppear
    case onDelete(uuid: UUID)
    case openSettingsButtonTapped
    case recordButtonTapped
    case recordPermissionResponse(Bool)
    case recordingMemo(PresentationAction<RecordingMemo.Action>)
    case voiceMemos(id: VoiceMemoReducer.State.ID, action: VoiceMemoReducer.Action)
    case mailComposeDismissed
      case synciCloud
      case syncSuccess
      case syncFailure
  }

  enum AlertAction: Equatable {
      case onAddReview
      case onGoodReview
      case onBadReview
      case onMailTap
  }

  @Dependency(\.audioRecorder.requestRecordPermission) var requestRecordPermission
  @Dependency(\.date) var date
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.temporaryDirectory) var temporaryDirectory
  @Dependency(\.uuid) var uuid

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {

            case .onAppear:

              let installDate = UserDefaultsManager.shared.installDate
              let reviewCount = UserDefaultsManager.shared.reviewRequestCount

              state.hasPurchasedPremium = UserDefaultsManager.shared.hasPurchasedProduct

              // 初回起動時
              if let installDate = installDate {
                  let currentDate = Date()
                  if let interval = Calendar.current.dateComponents([.day], from: installDate, to: currentDate).day {
                      if interval >= 7 && reviewCount == 0 {
                          if UIApplication.shared.connectedScenes.first is UIWindowScene {
                                state.alert = AlertState {
                                    TextState("シンプル録音について")
                                } actions: {
                                    ButtonState(action: .send(.onGoodReview)) {
                                        TextState("はい")
                                    }
                                    ButtonState(action: .send(.onBadReview)) {
                                        TextState("いいえ、フィードバックを送信")
                                    }
                                } message: {
                                    TextState(
                                        "シンプル録音に満足していますか？"
                                    )
                                }
                              UserDefaultsManager.shared.reviewRequestCount = reviewCount + 1
                          }
                      }
                  }
              }else{
                  UserDefaultsManager.shared.installDate = Date()
              }


              return .none

          case let .onDelete(uuid):
            state.voiceMemos.removeAll { $0.uuid == uuid }
          let voiceMemoRepository: VoiceMemoRepository = VoiceMemoRepository(coreDataAccessor: VoiceMemoCoredataAccessor(), cloudUploader: CloudUploader())
          voiceMemoRepository.delete(id: uuid)
            return .none

          case .openSettingsButtonTapped:
            return .run { _ in
              await self.openSettings()
            }
      case .synciCloud:
          state.syncStatus = .syncing
          return .run { send in
              let voiceMemoRepository: VoiceMemoRepository = VoiceMemoRepository(coreDataAccessor: VoiceMemoCoredataAccessor(), cloudUploader: CloudUploader())
              let result = await voiceMemoRepository.syncToCloud()
              if result {
                  await send(.syncSuccess)
              } else {
                  await send(.syncFailure)
              }
          }

      case .syncSuccess:
          let voiceMemoRepository: VoiceMemoRepository = VoiceMemoRepository(coreDataAccessor: VoiceMemoCoredataAccessor(), cloudUploader: CloudUploader())
          state.voiceMemos = IdentifiedArrayOf(uniqueElements:  voiceMemoRepository.selectAllData())
          state.syncStatus = .synced
          return .none

      case .syncFailure:
          state.syncStatus = .notSynced
          return .none


          case .recordButtonTapped:
            switch state.audioRecorderPermission {
            case .undetermined:
              return .run { send in
                await send(.recordPermissionResponse(self.requestRecordPermission()))
              }

            case .denied:
              state.alert = AlertState { TextState("Permission is required to record voice memos.") }
              return .none

            case .allowed:

              state.recordingMemo = newRecordingMemo
              return .none
            }

          case let .recordingMemo(.presented(.delegate(.didFinish(.success(recordingMemo))))):
            state.recordingMemo = nil
            state.voiceMemos.insert(
                VoiceMemoReducer.State(

                    uuid: recordingMemo.uuid,
                    date: recordingMemo.date,
                    duration: recordingMemo.duration, time: 0,
                    url: recordingMemo.url,
                    text: recordingMemo.resultText,
                    fileFormat: recordingMemo.fileFormat,
                    samplingFrequency: recordingMemo.samplingFrequency,
                    quantizationBitDepth: recordingMemo.quantizationBitDepth,
                    numberOfChannels: recordingMemo.numberOfChannels,
                    hasPurchasedPremium: UserDefaultsManager.shared.hasPurchasedProduct
                ),
              at: 0
            )
          let voiceMemoRepository: VoiceMemoRepository = VoiceMemoRepository(coreDataAccessor: VoiceMemoCoredataAccessor(), cloudUploader: CloudUploader())
          voiceMemoRepository.insert(state: recordingMemo)

            return .none

          case .recordingMemo(.presented(.delegate(.didFinish(.failure)))):
            state.alert = AlertState { TextState("Voice memo recording failed.") }
            state.recordingMemo = nil

            return .none

          case .recordingMemo:
            return .none

          case let .recordPermissionResponse(permission):
            state.audioRecorderPermission = permission ? .allowed : .denied
            if permission {
              state.recordingMemo = newRecordingMemo
              return .none
            } else {
              state.alert = AlertState { TextState("Permission is required to record voice memos.") }
              return .none
            }

          case let .voiceMemos(id: id, action: .delegate(delegateAction)):
            switch delegateAction {
            case .playbackFailed:
              state.alert = AlertState { TextState("Voice memo playback failed.") }
              return .none
            case .playbackStarted:
              for memoID in state.voiceMemos.ids where memoID != id {
                state.voiceMemos[id: memoID]?.mode = .notPlaying
              }
              return .none
            }

          case .voiceMemos:
            return .none
          case .alert(.presented(.onAddReview)):


                  if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                      SKStoreReviewController.requestReview(in: scene)
                  }
                  return .none
          case .alert(.presented(.onGoodReview)):

                  state.alert = AlertState(
                    title: TextState("シンプル録音について"),
                    message: TextState("ご利用ありがとうございます！次の画面でアプリの評価をお願いします。"),
                    dismissButton: .default(TextState("OK"),
                                                             action: .send(.onAddReview))
                  )
                  return .none
          case .alert(.presented(.onBadReview)):

                  state.alert = AlertState(
                    title: TextState("ご不便かけて申し訳ありません"),
                    message: TextState("次の画面のメールにて詳細に状況を教えてください。"),
                    dismissButton: .default(TextState("OK"),
                    action: .send(.onMailTap))
                  )
                  return .none

          case .alert(.presented(.onMailTap)):

              state.alert = nil
              state.isMailComposePresented.toggle()
              return .none
          case .alert(.dismiss):
              return .none

          case .mailComposeDismissed:
              state.isMailComposePresented = false
              return .none
          }
    }
    .ifLet(\.$alert, action: /Action.alert)
    .ifLet(\.$recordingMemo, action: /Action.recordingMemo) {
      RecordingMemo()
    }
    .forEach(\.voiceMemos, action: /Action.voiceMemos) {
        VoiceMemoReducer()
    }


  }

    func documentsDirectory() -> URL {
      let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
      return paths[0]
    }

    private var newRecordingMemo: RecordingMemo.State {
        RecordingMemo.State(
            uuid: UUID(),
            date: self.date.now,
            duration: 0,
            volumes: 0.0,
            resultText: "",
            mode: .recording,
            fileFormat: "m4a",
            samplingFrequency: 44100,
            quantizationBitDepth: 16,
            numberOfChannels: 2,
            url: self.documentsDirectory()
                .appendingPathComponent(self.uuid().uuidString)
                .appendingPathExtension("m4a"),
            startTime: 0,
            time: 0
        )
    }


 

}





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
                            VoiceMemoListItem(store: $0, admobUnitId: admobUnitId)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                selectedIndex = index
                                isDeleteConfirmationPresented = true
                            }
                        }
                    }

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

                    AdmobBannerView(unitId: recordAdmobUnitId)
                        .frame(height: 50)
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
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if viewStore.recordingMemo == nil {
                            let initialState = SettingReducer.State(
                                selectedFileFormat: UserDefaultsManager.shared.selectedFileFormat,
                                samplingFrequency: UserDefaultsManager.shared.samplingFrequency,
                                quantizationBitDepth: UserDefaultsManager.shared.quantizationBitDepth,
                                numberOfChannels: UserDefaultsManager.shared.numberOfChannels,
                                microphonesVolume: UserDefaultsManager.shared.microphonesVolume,
                                developerSupported: UserDefaultsManager.shared.hasSupportedDeveloper,
                                hasPurchasedPremium: UserDefaultsManager.shared.hasPurchasedProduct
                            )

                            let store = Store(initialState: initialState) {
                                SettingReducer()
                            }

                            let settingView = SettingView(store: store, admobUnitId: admobUnitId)


                            HStack {
                                if viewStore.syncStatus == .synced {
                                    Image(systemName: "checkmark.icloud.fill")
                                        .foregroundColor(.accentColor)
                                } else if viewStore.syncStatus == .syncing {
                                    Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                                        .foregroundColor(.accentColor)
                                } else {
                                    if viewStore.hasPurchasedPremium{
                                        Button {
                                            viewStore.send(.synciCloud)
                                        } label: {
                                            Image(systemName: "exclamationmark.icloud.fill")
                                                .foregroundColor(.accentColor)
                                        }
                                    }else{
                                        NavigationLink(destination: PaywallView(iapManager: IAPManager())) {
                                            Image(systemName: "exclamationmark.icloud.fill")
                                                .foregroundColor(.accentColor)

                                        }
                                    }

                                }
                                Spacer().frame(width: 10)
                                NavigationLink(destination: settingView) {
                                    Image(systemName: "gearshape.fill")
                                        .accentColor(.accentColor)
                                }
                            }


                        }
                    }
                }
            }
            .navigationViewStyle(.stack)
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




