import SwiftUI
import ComposableArchitecture
import AVFoundation

@Reducer
struct RecordingFeature {
  enum CancelID { case recording }

  @ObservableState
  struct State: Equatable {
    var recordingState: RecordingState = .idle
    var duration: TimeInterval = 0
    var volumes: Float = -60
    var resultText: String = ""
    var tempTitle: String = ""
    var showTitleDialog = false
    var isLoading = false
    var audioPermission: AudioPermission = .notDetermined
    var waveFormHeights: [Float] = []
    var recordingId = UUID()
    // 録音開始時の設定を保持
    var recordingFileFormat: String = ""
    var recordingSamplingFrequency: Double = 44100.0
    var recordingBitDepth: Int = 16
    var recordingChannels: Int = 1

    enum RecordingState: Equatable {
      case idle
      case recording
      case paused
      case encoding
    }

    enum AudioPermission: Equatable {
      case notDetermined
      case granted
      case denied
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case view(View)
    case delegate(DelegateAction)

    // Internal actions
    case audioRecorderDidFinish(TaskResult<Bool>)
    case timerUpdated(TimeInterval)
    case volumesUpdated(Float)
    case resultTextUpdated(String)
    case waveFormHeightsUpdated([Float])
    case permissionResponse(Bool)

    enum View {
      case recordButtonTapped
      case stopButtonTapped
      case pauseResumeButtonTapped
      case saveWithTitle
      case skipTitle
      case onAppear
    }

    enum DelegateAction: Equatable {
      case recordingWillStart
      case recordingCompleted(RecordingResult)
    }
  }

  struct RecordingResult: Equatable {
    let url: URL
    let duration: TimeInterval
    let title: String
    let date: Date
  }

  @Dependency(\.longRecordingAudioClient) var longRecordingAudioClient
  @Dependency(\.continuousClock) var clock
  @Dependency(\.uuid) var uuid
  @Dependency(\.voiceMemoRepository) var voiceMemoRepository

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .view(viewAction):
        switch viewAction {
        case .recordButtonTapped:
          return .run { send in
            let hasPermission = await longRecordingAudioClient.requestRecordPermission()
            await send(.permissionResponse(hasPermission))
          }

        case .stopButtonTapped:
          state.recordingState = .encoding
          state.showTitleDialog = true
          return .run { _ in
            await longRecordingAudioClient.stopRecording()
          }
          .merge(with: .cancel(id: CancelID.recording))

        case .saveWithTitle:
          state.showTitleDialog = false
          // 録音開始時に保存した設定を使用
          let fileFormat = state.recordingFileFormat
          let recordingUrl = createRecordingURL(with: state.recordingId, fileFormat: fileFormat)
          let title = state.tempTitle.isEmpty ? "無題の録音" : state.tempTitle
          let recordingDate = Date()

          // データベースに保存
          let recordingVoice = VoiceMemoRepositoryClient.RecordingVoice(
            uuid: state.recordingId,
            date: recordingDate,
            duration: state.duration,
            resultText: state.resultText,
            title: title,
            fileFormat: fileFormat,
            samplingFrequency: state.recordingSamplingFrequency,
            quantizationBitDepth: state.recordingBitDepth,
            numberOfChannels: state.recordingChannels,
            url: recordingUrl
          )
          voiceMemoRepository.insert(recordingVoice)

          let result = RecordingResult(
            url: recordingUrl,
            duration: state.duration,
            title: title,
            date: recordingDate
          )
          state = State() // Reset state
          return .send(.delegate(.recordingCompleted(result)))

        case .skipTitle:
          state.showTitleDialog = false
          // 録音開始時に保存した設定を使用
          let fileFormat = state.recordingFileFormat
          let recordingUrl = createRecordingURL(with: state.recordingId, fileFormat: fileFormat)
          let title = "無題の録音"
          let recordingDate = Date()

          // データベースに保存
          let recordingVoice = VoiceMemoRepositoryClient.RecordingVoice(
            uuid: state.recordingId,
            date: recordingDate,
            duration: state.duration,
            resultText: state.resultText,
            title: title,
            fileFormat: fileFormat,
            samplingFrequency: state.recordingSamplingFrequency,
            quantizationBitDepth: state.recordingBitDepth,
            numberOfChannels: state.recordingChannels,
            url: recordingUrl
          )
          voiceMemoRepository.insert(recordingVoice)

          let result = RecordingResult(
            url: recordingUrl,
            duration: state.duration,
            title: title,
            date: recordingDate
          )
          state = State() // Reset state
          return .send(.delegate(.recordingCompleted(result)))

        case .pauseResumeButtonTapped:
          if state.recordingState == .paused {
            state.recordingState = .recording
            return .run { _ in
              await longRecordingAudioClient.resumeRecording()
            }
          } else {
            state.recordingState = .paused
            return .run { _ in
              await longRecordingAudioClient.pauseRecording()
            }
          }

        case .onAppear:
          return .none
        }

      case let .permissionResponse(granted):
        state.audioPermission = granted ? .granted : .denied
        if granted {
          state.recordingState = .recording
          state.recordingId = uuid() // 新しい録音IDを生成
          return .merge(
            .send(.delegate(.recordingWillStart)),
            startRecording(state: &state)
          )
        }
        return .none

      case .audioRecorderDidFinish(.success(true)):
        return .none

      case .audioRecorderDidFinish(.success(false)):
        state.recordingState = .idle
        return .none

      case let .audioRecorderDidFinish(.failure(error)):
        state.recordingState = .idle
        return .none

      case let .timerUpdated(time):
        state.duration = time
        return .none

      case let .volumesUpdated(volume):
        state.volumes = volume
        return .none

      case let .resultTextUpdated(text):
        state.resultText = text
        return .none

      case let .waveFormHeightsUpdated(heights):
        state.waveFormHeights = heights
        return .none

      case .delegate:
        return .none
      }
    }
  }

  private func startRecording(state: inout State) -> Effect<Action> {
    // 録音開始時の設定をStateに保存
    let fileFormat = UserDefaultsManager.shared.selectedFileFormat
    let samplingFrequency = UserDefaultsManager.shared.samplingFrequency
    let bitDepth = UserDefaultsManager.shared.quantizationBitDepth
    let channels = UserDefaultsManager.shared.numberOfChannels

    state.recordingFileFormat = fileFormat
    state.recordingSamplingFrequency = samplingFrequency
    state.recordingBitDepth = bitDepth
    state.recordingChannels = channels

    let url = createRecordingURL(with: state.recordingId, fileFormat: fileFormat)
    let audioFileFormat: RecordingConfiguration.AudioFileFormat = fileFormat.uppercased() == "WAV" ? .wav : .m4a
    let configuration = RecordingConfiguration(
      fileFormat: audioFileFormat,
      quality: .high,
      sampleRate: samplingFrequency,
      numberOfChannels: channels
    )

    // 録音時間を初期化
    state.duration = 0

    return .run { send in
      async let recording: Void = send(
        .audioRecorderDidFinish(
          TaskResult { try await longRecordingAudioClient.startRecording(url, configuration) }
        )
      )

      // Timer for duration updates
      async let durationUpdates: Void = {
        for await _ in clock.timer(interval: .milliseconds(100)) {
          let state = await longRecordingAudioClient.recordingState()
          // 録音中のみ更新（一時停止中は更新しない）
          switch state {
          case .recording:
            let currentTime = await longRecordingAudioClient.currentTime()
            await send(.timerUpdated(currentTime))
          case .paused:
            // 一時停止中は時間を更新しない
            break
          default:
            break
          }
        }
      }()

      // Timer for volume updates
      async let volumeUpdates: Void = {
        for await _ in clock.timer(interval: .milliseconds(100)) {
          let state = await longRecordingAudioClient.recordingState()
          // 録音中のみ音量を更新
          switch state {
          case .recording:
            let volume = await longRecordingAudioClient.audioLevel()
            await send(.volumesUpdated(volume))
          case .paused:
            // 一時停止中は音量を更新しない
            break
          default:
            break
          }
        }
      }()

      _ = await (recording, durationUpdates, volumeUpdates)
    }
    .cancellable(id: CancelID.recording)
  }

  private func createRecordingURL(with id: UUID, fileFormat: String) -> URL {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let fileExtension = fileFormat.uppercased() == "WAV" ? "wav" : "m4a"
    return documentsPath.appendingPathComponent("\(id.uuidString).\(fileExtension)")
  }
}

struct RecordingView: View {
  @Perception.Bindable var store: StoreOf<RecordingFeature>
  @State private var ringProgress: CGFloat = 0.0

  private func send(_ action: RecordingFeature.Action.View) {
    store.send(.view(action))
  }

  var body: some View {
    WithPerceptionTracking {
      NavigationStack {
        VStack(spacing: 24) {

          // Recording Status and Timer
          recordingStatusView

          // Audio Level Visualization
          if store.recordingState == .recording || store.recordingState == .paused {
            audioVisualizationView
          }

          // Transcription Text
          if !store.resultText.isEmpty {
            transcriptionView
          }

          Spacer()

          // Control Buttons
          controlButtonsView
        }
        .padding()
        .navigationTitle("録音")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
          send(.onAppear)
        }
        .alert("録音完了", isPresented: $store.showTitleDialog) {
          TextField("タイトル", text: $store.tempTitle)
          Button("保存") {
            send(.saveWithTitle)
          }
          Button("スキップ", role: .cancel) {
            send(.skipTitle)
          }
        } message: {
          Text("この録音にタイトルをつけますか？")
        }
      }
    }
  }

  private var recordingStatusView: some View {
    VStack(spacing: 16) {
      VStack(spacing: 8) {
        // Recording Status Text
        Text(recordingStatusText)
          .font(.title2)
          .fontWeight(.bold)
          .foregroundColor(recordingStatusColor)
          .animation(.easeInOut(duration: 1), value: store.duration)

        // Duration
        if let formattedDuration = dateComponentsFormatter.string(from: store.duration) {
          Text(formattedDuration)
            .font(.title.monospacedDigit())
            .fontWeight(.bold)
        }
      }
    }
  }

  private var audioVisualizationView: some View {
    VStack(spacing: 12) {
      // Audio Level Meter
      AudioLevelView(audioLevel: store.volumes)
        .frame(height: 20)

    }
    .padding(.horizontal)
  }

  private var transcriptionView: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("音声認識結果")
        .font(.headline)
        .foregroundColor(.secondary)

      ScrollView {
        Text(store.resultText)
          .font(.body)
          .padding()
          .background(Color(.systemGray6))
          .cornerRadius(12)
      }
      .frame(maxHeight: 120)
    }
    .padding(.horizontal)
  }

  private var controlButtonsView: some View {
    HStack(spacing: 32) {
      if store.recordingState == .idle {
        // Record Button
        recordButton
      } else {
        // Stop Button
        stopButton

        // Pause/Resume Button
        pauseResumeButton
      }
    }
  }

  private var recordButton: some View {
    Button {
      send(.recordButtonTapped)
    } label: {
      ZStack {
        Circle()
          .fill(Color.red)
          .frame(width: 80, height: 80)

        Circle()
          .fill(Color.white)
          .frame(width: 30, height: 30)
      }
    }
    .disabled(store.audioPermission == .denied)
    .opacity(store.audioPermission == .denied ? 0.3 : 1.0)
  }

  private var stopButton: some View {
    Button {
      send(.stopButtonTapped)
    } label: {
      ZStack {
        Circle()
          .fill(Color(.systemGray))
          .frame(width: 70, height: 70)

        RoundedRectangle(cornerRadius: 4)
          .fill(Color.red)
          .frame(width: 25, height: 25)
      }
    }
  }

  private var pauseResumeButton: some View {
    Button {
      send(.pauseResumeButtonTapped)
    } label: {
      ZStack {
        Circle()
          .fill(Color(.systemGray2))
          .frame(width: 60, height: 60)

        Image(systemName: store.recordingState == .paused ? "play.fill" : "pause.fill")
          .font(.title2)
          .foregroundColor(.white)
      }
    }
  }

  private var recordingStatusText: String {
    switch store.recordingState {
    case .idle:
      return "録音準備完了"
    case .recording:
      return "録音中"
    case .paused:
      return "一時停止中"
    case .encoding:
      return "保存中..."
    }
  }

  private var recordingStatusColor: Color {
    switch store.recordingState {
    case .idle:
      return .primary
    case .recording:
      return .red
    case .paused:
      return .orange
    case .encoding:
      return .blue
    }
  }
}

#Preview {
  RecordingView(
    store: Store(initialState: RecordingFeature.State()) {
      RecordingFeature()
    }
  )
}
