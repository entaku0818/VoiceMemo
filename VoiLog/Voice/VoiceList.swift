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

    enum RecorderPermission {
      case allowed
      case denied
      case undetermined
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

          // 初回起動時
          if let installDate = installDate {
              let currentDate = Date()
              if let interval = Calendar.current.dateComponents([.day], from: installDate, to: currentDate).day {
                  if interval >= 7 && reviewCount == 0 {
                      if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
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
              let voiceRepository = VoiceMemoRepository()
              voiceRepository.delete(id: uuid)
            return .none

          case .openSettingsButtonTapped:
            return .run { _ in
              await self.openSettings()
            }

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
                    numberOfChannels: recordingMemo.numberOfChannels
                ),
              at: 0
            )
              let voiceRepository = VoiceMemoRepository()
              voiceRepository.insert(state: recordingMemo)
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
        date: self.date.now,
        url: self.documentsDirectory()
          .appendingPathComponent(self.uuid().uuidString)
          .appendingPathExtension("m4a"), 
        duration: 0
      )

    }
}





struct VoiceMemosView: View {
    let store: StoreOf<VoiceMemos>

    enum AlertType {
        case deleted
        case appInterview
        case mail
    }
    @State private var isDeleteConfirmationPresented = false


    @State private var selectedIndex: Int?

    init(store:  StoreOf<VoiceMemos>) {
        self.store = store
    }

  var body: some View {
          WithViewStore(self.store, observe: { $0 }) { viewStore in
          NavigationView {
            VStack {
              List {
                ForEachStore(
                    self.store.scope(state: \.voiceMemos, action: VoiceMemos.Action.voiceMemos)
                ) {
                  VoiceMemoView(store: $0)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        // インデックスを保存して確認アラートを表示
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
            }
            .onAppear{
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
                            selectedIndex = nil // インデックスをリセット
                        }
                    },
                    secondaryButton: .cancel() {
                        selectedIndex = nil // インデックスをリセット
                    }
                )
            }
            .sheet(
              isPresented: viewStore.binding(
                get: \.isMailComposePresented,
                send: VoiceMemos.Action.mailComposeDismissed // Use the new action here
              )
            ) {
              MailComposeViewControllerWrapper(
                isPresented: viewStore.binding(
                  get: \.isMailComposePresented,
                  send: VoiceMemos.Action.mailComposeDismissed // And also here
                )
              )
            }
            .navigationTitle("シンプル録音")
            .toolbar {

                ToolbarItem(placement: .navigationBarTrailing) {

                    if viewStore.recordingMemo == nil {
                        // Initial state
                        let initialState = SettingReducer.State(
                            selectedFileFormat: UserDefaultsManager.shared.selectedFileFormat,  // Default or previously saved value
                            samplingFrequency: UserDefaultsManager.shared.samplingFrequency,            // Default or previously saved value
                            quantizationBitDepth: UserDefaultsManager.shared.quantizationBitDepth,            // Default or previously saved value
                            numberOfChannels: UserDefaultsManager.shared.numberOfChannels,                 // Default or previously saved value
                            microphonesVolume: UserDefaultsManager.shared.microphonesVolume,
                            developerSupported: UserDefaultsManager.shared.hasSupportedDeveloper
                // Default or previously saved value
                        )

                        // Creating the store
                        let store = Store(initialState: initialState) {
                            SettingReducer()
                        }

                        // Initializing the view
                        let settingView = SettingView(store: store)

                        NavigationLink(destination:settingView) {
                            Image(systemName: "gearshape.fill")
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
        case .restricted:  break
        case .denied:  break
        case .authorized:  break
        @unknown default:  break
            fatalError()
        }
    }


    func requestTrackingAuthorization() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .notDetermined: break
                case .restricted:  break
                case .denied:  break
                case .authorized:  break
                @unknown default:  break
                    fatalError()
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
                duration: 5, time: 0,
              mode: .notPlaying,
              title: "Functions",
                url: URL(string: "https://www.pointfree.co/functions")!, text: "",
                fileFormat: "",
                samplingFrequency: 0.0,
                quantizationBitDepth: 0,
                numberOfChannels: 0
            ),
            VoiceMemoReducer.State(
                uuid: UUID(),
                date: Date(),
                duration: 5, time: 0,
              mode: .notPlaying,
              title: "",
              url: URL(string: "https://www.pointfree.co/untitled")!,
              text: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\naaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                fileFormat: "",
                samplingFrequency: 0.0,
                quantizationBitDepth: 0,
                numberOfChannels: 0
            )
          ]
        )
      ) {
        VoiceMemos()
      }
    )
  }
}



