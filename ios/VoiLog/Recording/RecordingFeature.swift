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
    // プリセット
    var selectedPreset: RecordingPreset = .memo
    var noiseCancellationEnabled = true
    var autoGainControlEnabled = true
    // タイムスタンプ付き文字起こし
    var timestampedSegments: [TimestampedSegment] = []

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
    case transcriptionCompleted(UUID, String?)

    enum View {
      case recordButtonTapped
      case stopButtonTapped
      case pauseResumeButtonTapped
      case saveWithTitle
      case skipTitle
      case onAppear
      case presetSelected(RecordingPreset)
      case noiseCancellationToggled(Bool)
      case autoGainControlToggled(Bool)
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
  @Dependency(\.liveActivityClient) var liveActivityClient

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
            await liveActivityClient.endActivity()
          }
          .merge(with: .cancel(id: CancelID.recording))

        case .saveWithTitle:
          state.showTitleDialog = false
          // 録音開始時に保存した設定を使用
          let fileFormat = state.recordingFileFormat
          let recordingUrl = createRecordingURL(with: state.recordingId, fileFormat: fileFormat)
          let title = state.tempTitle.isEmpty ? String(localized: "無題の録音") : state.tempTitle
          let recordingDate = Date()
          let recordingId = state.recordingId

          // タイムスタンプ付き文字起こしをJSON化
          let segments = state.timestampedSegments
          let resultText = state.resultText
          let timestampedText: String?
          if !segments.isEmpty {
            let transcription = TimestampedTranscription(segments: segments, fullText: resultText)
            timestampedText = transcription.toJSON()
          } else {
            timestampedText = nil
          }

          // データベースに保存
          let recordingVoice = VoiceMemoRepositoryClient.RecordingVoice(
            uuid: recordingId,
            date: recordingDate,
            duration: state.duration,
            resultText: resultText,
            timestampedText: timestampedText,
            title: title,
            fileFormat: fileFormat,
            samplingFrequency: state.recordingSamplingFrequency,
            quantizationBitDepth: state.recordingBitDepth,
            numberOfChannels: state.recordingChannels,
            url: recordingUrl
          )
          MainActor.assumeIsolated { voiceMemoRepository.insert(recordingVoice) }

          let result = RecordingResult(
            url: recordingUrl,
            duration: state.duration,
            title: title,
            date: recordingDate
          )
          state = State() // Reset state
          return .merge(
            .send(.delegate(.recordingCompleted(result))),
            .run { [timestampedText] send in
              guard timestampedText == nil else { return }
              if let (text, segs) = await longRecordingAudioClient.recognizeAudio(recordingUrl) {
                let transcription = TimestampedTranscription(segments: segs, fullText: text)
                await send(.transcriptionCompleted(recordingId, transcription.toJSON()))
              }
            }
          )

        case .skipTitle:
          state.showTitleDialog = false
          // 録音開始時に保存した設定を使用
          let fileFormat = state.recordingFileFormat
          let recordingUrl = createRecordingURL(with: state.recordingId, fileFormat: fileFormat)
          let title = String(localized: "無題の録音")
          let recordingDate = Date()
          let recordingId = state.recordingId

          // タイムスタンプ付き文字起こしをJSON化
          let segments = state.timestampedSegments
          let resultText = state.resultText
          let timestampedText: String?
          if !segments.isEmpty {
            let transcription = TimestampedTranscription(segments: segments, fullText: resultText)
            timestampedText = transcription.toJSON()
          } else {
            timestampedText = nil
          }

          // データベースに保存
          let recordingVoice = VoiceMemoRepositoryClient.RecordingVoice(
            uuid: recordingId,
            date: recordingDate,
            duration: state.duration,
            resultText: resultText,
            timestampedText: timestampedText,
            title: title,
            fileFormat: fileFormat,
            samplingFrequency: state.recordingSamplingFrequency,
            quantizationBitDepth: state.recordingBitDepth,
            numberOfChannels: state.recordingChannels,
            url: recordingUrl
          )
          MainActor.assumeIsolated { voiceMemoRepository.insert(recordingVoice) }

          let result = RecordingResult(
            url: recordingUrl,
            duration: state.duration,
            title: title,
            date: recordingDate
          )
          state = State() // Reset state
          return .merge(
            .send(.delegate(.recordingCompleted(result))),
            .run { [timestampedText] send in
              guard timestampedText == nil else { return }
              if let (text, segs) = await longRecordingAudioClient.recognizeAudio(recordingUrl) {
                let transcription = TimestampedTranscription(segments: segs, fullText: text)
                await send(.transcriptionCompleted(recordingId, transcription.toJSON()))
              }
            }
          )

        case .pauseResumeButtonTapped:
          if state.recordingState == .paused {
            state.recordingState = .recording
            let duration = state.duration
            return .run { _ in
              await longRecordingAudioClient.resumeRecording()
              await liveActivityClient.updateActivity(duration, false)
            }
          } else {
            state.recordingState = .paused
            let duration = state.duration
            return .run { _ in
              await longRecordingAudioClient.pauseRecording()
              await liveActivityClient.updateActivity(duration, true)
            }
          }

        case .onAppear:
          let preset = RecordingPreset(rawValue: UserDefaultsManager.shared.selectedRecordingPreset) ?? .memo
          state.selectedPreset = preset
          if preset != .custom {
            state.noiseCancellationEnabled = preset.noiseCancellationEnabled
            state.autoGainControlEnabled = preset.autoGainControlEnabled
          } else {
            state.noiseCancellationEnabled = UserDefaultsManager.shared.noiseCancellationEnabled
            state.autoGainControlEnabled = UserDefaultsManager.shared.autoGainControlEnabled
          }
          return .none

        case let .presetSelected(preset):
          state.selectedPreset = preset
          UserDefaultsManager.shared.selectedRecordingPreset = preset.rawValue
          if preset != .custom {
            state.noiseCancellationEnabled = preset.noiseCancellationEnabled
            state.autoGainControlEnabled = preset.autoGainControlEnabled
          }
          return .none

        case let .noiseCancellationToggled(enabled):
          state.noiseCancellationEnabled = enabled
          state.selectedPreset = .custom
          UserDefaultsManager.shared.noiseCancellationEnabled = enabled
          UserDefaultsManager.shared.selectedRecordingPreset = RecordingPreset.custom.rawValue
          return .none

        case let .autoGainControlToggled(enabled):
          state.autoGainControlEnabled = enabled
          state.selectedPreset = .custom
          UserDefaultsManager.shared.autoGainControlEnabled = enabled
          UserDefaultsManager.shared.selectedRecordingPreset = RecordingPreset.custom.rawValue
          return .none
        }

      case let .permissionResponse(granted):
        state.audioPermission = granted ? .granted : .denied
        if granted {
          state.recordingState = .recording
          state.recordingId = uuid() // 新しい録音IDを生成
          return .merge(
            .send(.delegate(.recordingWillStart)),
            startRecording(state: &state),
            .run { _ in
              await liveActivityClient.startActivity()
            }
          )
        }
        return .none

      case .audioRecorderDidFinish(.success(true)):
        return .none

      case .audioRecorderDidFinish(.success(false)):
        state.recordingState = .idle
        return .run { _ in await liveActivityClient.endActivity() }

      case .audioRecorderDidFinish(.failure):
        state.recordingState = .idle
        return .run { _ in await liveActivityClient.endActivity() }

      case let .timerUpdated(time):
        let previousSecond = Int(state.duration)
        state.duration = time
        let currentSecond = Int(time)
        // Only update Live Activity once per second to avoid excessive updates
        guard currentSecond != previousSecond else { return .none }
        let isPaused = state.recordingState == .paused
        return .run { _ in
          await liveActivityClient.updateActivity(time, isPaused)
        }

      case let .volumesUpdated(volume):
        state.volumes = volume
        return .none

      case let .resultTextUpdated(text):
        state.resultText = text
        return .none

      case let .waveFormHeightsUpdated(heights):
        state.waveFormHeights = heights
        return .none

      case let .transcriptionCompleted(id, json):
        // Update DB record with transcription result
        if let json = json {
          MainActor.assumeIsolated {
            if let voice = voiceMemoRepository.fetch(id) {
              let fullText = TimestampedTranscription.fromJSON(json)?.fullText ?? voice.resultText
              let updated = VoiceMemoRepositoryClient.VoiceMemoVoice(
                uuid: voice.uuid,
                date: voice.date,
                duration: voice.duration,
                title: voice.title,
                url: voice.url,
                text: fullText,
                timestampedText: json,
                fileFormat: voice.fileFormat,
                samplingFrequency: voice.samplingFrequency,
                quantizationBitDepth: voice.quantizationBitDepth,
                numberOfChannels: voice.numberOfChannels
              )
              voiceMemoRepository.update(updated)
            }
          }
        }
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
      numberOfChannels: channels,
      noiseCancellationEnabled: state.noiseCancellationEnabled,
      autoGainControlEnabled: state.autoGainControlEnabled
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
  @State private var showAudioSettings = false

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
        .navigationTitle(String(localized: "録音"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
          send(.onAppear)
        }
        .alert(String(localized: "録音完了"), isPresented: $store.showTitleDialog) {
          TextField(String(localized: "タイトル"), text: $store.tempTitle)
          Button(String(localized: "保存")) {
            send(.saveWithTitle)
          }
          Button(String(localized: "スキップ"), role: .cancel) {
            send(.skipTitle)
          }
        } message: {
          Text(String(localized: "この録音にタイトルをつけますか？"))
        }
      }
    }
  }

  private var presetSelectorView: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(RecordingPreset.allCases, id: \.self) { preset in
          Button {
            send(.presetSelected(preset))
          } label: {
            VStack(spacing: 4) {
              Text(preset.icon)
                .font(.title2)
              Text(preset.displayName)
                .font(.caption2)
                .fontWeight(store.selectedPreset == preset ? .bold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(store.selectedPreset == preset ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
            .foregroundColor(store.selectedPreset == preset ? .accentColor : .primary)
            .cornerRadius(12)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(store.selectedPreset == preset ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
          }
        }
      }
      .padding(.horizontal)
    }
  }

  private var audioSettingsSheet: some View {
    NavigationStack {
      List {
        Section(String(localized: "プリセット")) {
          ForEach(RecordingPreset.allCases, id: \.self) { preset in
            Button {
              send(.presetSelected(preset))
            } label: {
              HStack(spacing: 12) {
                Text(preset.icon)
                  .font(.title3)
                  .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                  Text(preset.displayName)
                    .foregroundColor(.primary)
                    .fontWeight(store.selectedPreset == preset ? .semibold : .regular)
                  Text(preset.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                }
                Spacer()
                if store.selectedPreset == preset {
                  Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .fontWeight(.semibold)
                }
              }
            }
          }
        }

        Section(String(localized: "詳細")) {
          HStack {
            Text(String(localized: "フォーマット"))
            Spacer()
            Text(store.selectedPreset.fileFormat.uppercased())
              .foregroundColor(.secondary)
          }

          HStack {
            Text(String(localized: "サンプルレート"))
            Spacer()
            Text(store.selectedPreset.sampleRate >= 1000
              ? String(format: "%.0f kHz", store.selectedPreset.sampleRate / 1000)
              : String(format: "%.0f Hz", store.selectedPreset.sampleRate))
              .foregroundColor(.secondary)
          }
        }

        Section {
          Toggle(String(localized: "ノイズキャンセリング"), isOn: Binding(
            get: { store.noiseCancellationEnabled },
            set: { send(.noiseCancellationToggled($0)) }
          ))
          .disabled(store.selectedPreset != .custom)

          Toggle(String(localized: "音量の自動調整"), isOn: Binding(
            get: { store.autoGainControlEnabled },
            set: { send(.autoGainControlToggled($0)) }
          ))
          .disabled(store.selectedPreset != .custom)
        } footer: {
          if store.selectedPreset != .custom {
            Text(String(localized: "トグルを変更するには「カスタム」を選択してください"))
          }
        }
      }
      .navigationTitle(store.selectedPreset.settingsTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "完了")) { showAudioSettings = false }
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
      Text(String(localized: "音声認識結果"))
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
        recordButton
          .overlay(alignment: .trailing) {
            Button {
              showAudioSettings = true
            } label: {
              Image(systemName: "gearshape")
                .font(.title2)
                .foregroundColor(.secondary)
                .frame(width: 44, height: 44)
                .background(Color(.systemGray6))
                .clipShape(Circle())
            }
            .sheet(isPresented: $showAudioSettings) {
              audioSettingsSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .offset(x: 64)
          }
          .frame(maxWidth: .infinity)
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
      return String(localized: "録音準備完了")
    case .recording:
      return String(localized: "録音中")
    case .paused:
      return String(localized: "一時停止中")
    case .encoding:
      return String(localized: "保存中...")
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
