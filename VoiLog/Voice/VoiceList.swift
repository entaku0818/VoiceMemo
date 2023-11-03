import AVFoundation
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

    enum RecorderPermission {
      case allowed
      case denied
      case undetermined
    }
  }

  enum Action: Equatable {
    case alert(PresentationAction<AlertAction>)
    case onDelete(IndexSet)
    case openSettingsButtonTapped
    case recordButtonTapped
    case recordPermissionResponse(Bool)
    case recordingMemo(PresentationAction<RecordingMemo.Action>)
    case voiceMemos(id: VoiceMemoReducer.State.ID, action: VoiceMemoReducer.Action)
  }

  enum AlertAction: Equatable {}

  @Dependency(\.audioRecorder.requestRecordPermission) var requestRecordPermission
  @Dependency(\.date) var date
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.temporaryDirectory) var temporaryDirectory
  @Dependency(\.uuid) var uuid

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .alert:
        return .none

      case let .onDelete(indexSet):
        state.voiceMemos.remove(atOffsets: indexSet)
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
                  viewStore.send(.voiceMemos(id: viewStore.voiceMemos[index].id, action: .delete))
              }
            }
          }
          AdmobBannerView().frame(width: .infinity, height: 50)

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
        }
        .alert(store: self.store.scope(state: \.$alert, action: VoiceMemos.Action.alert))
        .navigationTitle("シンプル録音")
        .toolbar {

            ToolbarItem(placement: .navigationBarTrailing) {

                if viewStore.recordingMemo == nil {
                    // Initial state
                    let initialState = SettingReducer.State(
                        selectedFileFormat: Constants.defaultFileFormat.rawValue,  // Default or previously saved value
                        samplingFrequency: Constants.defaultSamplingFrequency.rawValue,            // Default or previously saved value
                        quantizationBitDepth: Constants.defaultQuantizationBitDepth.rawValue,            // Default or previously saved value
                        numberOfChannels: Constants.defaultNumberOfChannels.rawValue,                 // Default or previously saved value
                        microphonesVolume: Constants.defaultMicrophonesVolume.rawValue                // Default or previously saved value
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


extension AudioPlayerClient {
  static let mock = Self(
    play: { _,_  in
      try await Task.sleep(nanoseconds: NSEC_PER_SEC * 5)
      return true
    }
  )
}
