import AVFoundation
import StoreKit
import ComposableArchitecture
import Foundation
import SwiftUI
import AppTrackingTransparency
import GoogleMobileAds


struct VoiceMemosState: Equatable {
  var alert: AlertState<VoiceMemosAction>?
  var audioRecorderPermission = RecorderPermission.undetermined
  var recordingMemo: RecordingMemoState?
  var voiceMemos: IdentifiedArrayOf<VoiceMemoState> = []

  enum RecorderPermission {
    case allowed
    case denied
    case undetermined
  }
}

enum VoiceMemosAction: Equatable {
  case alertDismissed
  case openSettingsButtonTapped
  case recordButtonTapped
  case recordPermissionResponse(Bool)
  case recordingMemo(RecordingMemoAction)
  case voiceMemo(id: VoiceMemoState.ID, action: VoiceMemoAction)
}

struct VoiceMemosEnvironment {
  var audioPlayer: AudioPlayerClient
  var audioRecorder: AudioRecorderClient
  var mainRunLoop: AnySchedulerOf<RunLoop>
  var openSettings: @Sendable () async -> Void
  var temporaryDirectory: @Sendable () -> URL
  var uuid: @Sendable () -> UUID
}

let voiceMemosReducer = Reducer<VoiceMemosState, VoiceMemosAction, VoiceMemosEnvironment>.combine(
  recordingMemoReducer
    .optional()
    .pullback(
      state: \.recordingMemo,
      action: /VoiceMemosAction.recordingMemo,
      environment: {
        RecordingMemoEnvironment(audioRecorder: $0.audioRecorder, mainRunLoop: $0.mainRunLoop)
      }
    ),
  voiceMemoReducer
    .forEach(
      state: \.voiceMemos,
      action: /VoiceMemosAction.voiceMemo(id:action:),
      environment: {
        VoiceMemoEnvironment(audioPlayer: $0.audioPlayer, mainRunLoop: $0.mainRunLoop)
      }
    ),
  Reducer { state, action, environment in
    switch action {
    case .alertDismissed:
      state.alert = nil
      return .none

    case .openSettingsButtonTapped:
      return .fireAndForget {
        await environment.openSettings()
      }

    case .recordButtonTapped:
      switch state.audioRecorderPermission {
      case .undetermined:
        return .task {
          await .recordPermissionResponse(environment.audioRecorder.requestRecordPermission())
        }

      case .denied:
        state.alert = AlertState(title: TextState("Permission is required to record voice memos."))
        return .none

      case .allowed:
          state.recordingMemo = RecordingMemoState.init(
            date: environment.mainRunLoop.now.date,
            url: environment.temporaryDirectory()
                .appendingPathComponent(environment.uuid().uuidString)
                .appendingPathExtension("m4a"),
            duration: 0
          )
        return .none
      }

    case let .recordingMemo(.delegate(.didFinish(.success(recordingMemo)))):
      state.recordingMemo = nil

      let voiceRepository = VoiceMemoRepository()
        voiceRepository.insert(state: recordingMemo)
          state.voiceMemos.insert(
            VoiceMemoState(
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
      return .none

    case .recordingMemo(.delegate(.didFinish(.failure))):
      state.alert = AlertState(title: TextState("Voice memo recording failed."))
      state.recordingMemo = nil
      return .none

    case .recordingMemo:
      return .none

    case let .recordPermissionResponse(permission):
      state.audioRecorderPermission = permission ? .allowed : .denied
      if permission {
        state.recordingMemo = RecordingMemoState(
          date: environment.mainRunLoop.now.date,
           url: environment.temporaryDirectory()
            .appendingPathComponent(environment.uuid().uuidString)
            .appendingPathExtension("m4a"),
          duration: 0
        )
        return .none
      } else {
        state.alert = AlertState(title: TextState("Permission is required to record voice memos."))
        return .none
      }

    case .voiceMemo(id: _, action: .audioPlayerClient(.failure)):
      state.alert = AlertState(title: TextState("Voice memo playback failed."))
      return .none

    case let .voiceMemo(id: id, action: .delete):
        if let uuid = state.voiceMemos[id: id]?.uuid {
            VoiceMemoRepository.shared.delete(id: uuid)
        }
      state.voiceMemos.remove(id: id)

      return .none

    case let .voiceMemo(id: tappedId, action: .playButtonTapped):
      for id in state.voiceMemos.ids where id != tappedId {
        state.voiceMemos[id: id]?.mode = .notPlaying
      }
      return .none

    case .voiceMemo:
      return .none
    }
  }
)

struct VoiceMemosView: View {
  let store: Store<VoiceMemosState, VoiceMemosAction>

    @State private var isDeleteConfirmationPresented = false
    @State private var selectedIndex: Int?

    init(store: Store<VoiceMemosState, VoiceMemosAction>) {
        self.store = store
    }

  var body: some View {
    WithViewStore(self.store) { viewStore in
      NavigationView {
        VStack {
          List {
            ForEachStore(
              self.store.scope(state: \.voiceMemos, action: { .voiceMemo(id: $0, action: $1) })
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
          AdmobBannerView().frame(width: .infinity, height: 50)

          IfLetStore(
            self.store.scope(state: \.recordingMemo, action: { .recordingMemo($0) })
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
            requestReview()
        }
        .alert(
          self.store.scope(state: \.alert),
          dismiss: .alertDismissed
        )
        .navigationTitle("シンプル録音")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {

                if viewStore.recordingMemo == nil {
                    NavigationLink(destination: SettingView(store: Store(initialState: SettingViewState.initial,
                        reducer: settingViewReducer,
                        environment: SettingViewEnvironment()))) {
                        Image(systemName: "gearshape.fill")
                    }
                }

            }


        }
      }
      .alert(isPresented: $isDeleteConfirmationPresented) {
           Alert(
               title: Text("削除しますか？"),
               message: Text("選択した音声を削除しますか？"),
               primaryButton: .destructive(Text("削除")) {
                   if let index = selectedIndex {
                       viewStore.send(.voiceMemo(id: viewStore.voiceMemos[index].id, action: .delete))
                       selectedIndex = nil // インデックスをリセット
                   }
               },
               secondaryButton: .cancel() {
                   selectedIndex = nil // インデックスをリセット
               }
           )
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

    func requestReview() {
        let installDate = UserDefaultsManager.shared.installDate
        let reviewCount = UserDefaultsManager.shared.reviewRequestCount

        // 初回起動時
        if let installDate = installDate {
            let currentDate = Date()
            if let interval = Calendar.current.dateComponents([.day], from: installDate, to: currentDate).day {
                if interval >= 7 && reviewCount == 0 {
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                        UserDefaultsManager.shared.reviewRequestCount = reviewCount + 1
                    }
                }
            }
        }else{
            UserDefaultsManager.shared.installDate = Date()

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
  let permission: VoiceMemosState.RecorderPermission
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
        initialState: VoiceMemosState(
          voiceMemos: [
            VoiceMemoState(
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
            VoiceMemoState(
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
        ),
        reducer: voiceMemosReducer,
        environment: VoiceMemosEnvironment(
          // NB: AVAudioRecorder and AVAudioPlayer doesn't work in previews, so use mocks
          //     that simulate their behavior in previews.
          audioPlayer: .mock,
          audioRecorder: .mock,
          mainRunLoop: .main,
          openSettings: {},
          temporaryDirectory: { URL(fileURLWithPath: NSTemporaryDirectory()) },
          uuid: { UUID() }
        )
      )
    ).environment(\.locale, Locale(identifier: "ja_JP"))

  }
}

extension AudioPlayerClient {
  static let mock = Self(
    play: { _,_  in
      try await Task.sleep(nanoseconds: NSEC_PER_SEC * 5)
      return true
    }
  )
}
