import SwiftUI
import ComposableArchitecture
import AVFoundation

@Reducer
struct RecordingFeature {
  @ObservableState
  struct State: Equatable {
    var recordingState: RecordingState = .idle
    var duration: TimeInterval = 0
    var volumes: Float = -60
    var resultText: String = ""
    var tempTitle: String = ""
    var showTitleDialog: Bool = false
    var isLoading: Bool = false
    var audioPermission: AudioPermission = .notDetermined
    var waveFormHeights: [Float] = []
    
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

  enum Action: ViewAction, BindableAction {
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
      case titleDialogSaveButtonTapped
      case titleDialogCancelButtonTapped
      case showTitleDialog(Bool)
      case setTempTitle(String)
      case onAppear
    }
    
    enum DelegateAction: Equatable {
      case recordingCompleted(RecordingResult)
    }
  }
  
  struct RecordingResult: Equatable {
    let url: URL
    let duration: TimeInterval
    let title: String
    let date: Date
  }

  @Dependency(\.audioRecorder) var audioRecorder
  @Dependency(\.continuousClock) var clock
  @Dependency(\.uuid) var uuid

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
            let hasPermission = await audioRecorder.requestRecordPermission()
            await send(.permissionResponse(hasPermission))
          }
          
        case .stopButtonTapped:
          state.recordingState = .encoding
          return .run { [url = createRecordingURL()] send in
            await audioRecorder.stopRecording()
            await send(.view(.showTitleDialog(true)))
          }
          
        case .pauseResumeButtonTapped:
          if state.recordingState == .paused {
            state.recordingState = .recording
            return .run { _ in
              await audioRecorder.resumeRecording()
            }
          } else {
            state.recordingState = .paused
            return .run { _ in
              await audioRecorder.pauseRecording()
            }
          }
          
        case .titleDialogSaveButtonTapped:
          state.showTitleDialog = false
          let result = RecordingResult(
            url: createRecordingURL(),
            duration: state.duration,
            title: state.tempTitle.isEmpty ? "無題の録音" : state.tempTitle,
            date: Date()
          )
          state = State() // Reset state
          return .send(.delegate(.recordingCompleted(result)))
          
        case .titleDialogCancelButtonTapped:
          state.showTitleDialog = false
          state.tempTitle = ""
          return .none
          
        case let .showTitleDialog(show):
          state.showTitleDialog = show
          return .none
          
        case let .setTempTitle(title):
          state.tempTitle = title
          return .none
          
        case .onAppear:
          return .none
        }

      case let .permissionResponse(granted):
        state.audioPermission = granted ? .granted : .denied
        if granted {
          state.recordingState = .recording
          return startRecording(state: &state)
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
    let url = createRecordingURL()
    return .run { send in
      async let recording: Void = send(
        .audioRecorderDidFinish(
          TaskResult { try await audioRecorder.startRecording(url) }
        )
      )
      
      // Timer for duration updates
      async let durationUpdates: Void = {
        for await _ in clock.timer(interval: .milliseconds(100)) {
          if let currentTime = await audioRecorder.currentTime() {
            await send(.timerUpdated(currentTime))
          }
        }
      }()
      
      // Timer for volume updates
      async let volumeUpdates: Void = {
        for await _ in clock.timer(interval: .milliseconds(100)) {
          let volume = await audioRecorder.volumes()
          await send(.volumesUpdated(volume))
        }
      }()
      
      // Timer for result text updates
      async let textUpdates: Void = {
        for await _ in clock.timer(interval: .seconds(1)) {
          let text = await audioRecorder.resultText()
          await send(.resultTextUpdated(text))
        }
      }()
      
      _ = await (recording, durationUpdates, volumeUpdates, textUpdates)
    }
  }
  
  private func createRecordingURL() -> URL {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documentsPath.appendingPathComponent("\(uuid()).m4a")
  }
}

@ViewAction(for: RecordingFeature.self)
struct RecordingView: View {
  @Perception.Bindable var store: StoreOf<RecordingFeature>
  @State private var ringProgress: CGFloat = 0.0

  var body: some View {
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
      .onAppear {
        send(.onAppear)
      }
      .overlay {
        if store.showTitleDialog {
          titleDialogOverlay
        }
      }
    }
  }
  
  private var recordingStatusView: some View {
    VStack(spacing: 16) {
      ZStack {
        // Progress Ring
        if store.recordingState == .recording {
          RingProgressView(value: ringProgress)
            .frame(width: 200, height: 200)
            .onAppear {
              withAnimation(.linear(duration: 600).repeatForever(autoreverses: false)) {
                ringProgress = 1.0
              }
            }
        }
        
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
  }
  
  private var audioVisualizationView: some View {
    VStack(spacing: 12) {
      // Audio Level Meter
      AudioLevelView(audioLevel: store.volumes)
        .frame(height: 20)
      
      // Waveform (if available)
      if !store.waveFormHeights.isEmpty {
        WaveformView(heights: store.waveFormHeights)
          .frame(height: 60)
      }
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
  
  private var titleDialogOverlay: some View {
    ZStack {
      Color.black.opacity(0.4)
        .ignoresSafeArea()
      
      VStack(spacing: 20) {
        Text("録音完了")
          .font(.headline)
          .fontWeight(.bold)
        
        Text("この録音にタイトルをつけますか？")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
        
        TextField("タイトル", text: $store.tempTitle)
          .textFieldStyle(.roundedBorder)
          .submitLabel(.done)
          .onSubmit {
            send(.titleDialogSaveButtonTapped)
          }
        
        HStack(spacing: 16) {
          Button("スキップ") {
            send(.titleDialogCancelButtonTapped)
          }
          .buttonStyle(.bordered)
          
          Button("保存") {
            send(.titleDialogSaveButtonTapped)
          }
          .buttonStyle(.borderedProminent)
        }
      }
      .padding(24)
      .background(Color(.systemBackground))
      .cornerRadius(16)
      .shadow(radius: 10)
      .padding(.horizontal, 40)
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

// MARK: - Supporting Views

struct RingProgressView: View {
  var value: CGFloat
  var lineWidth: CGFloat = 8.0
  var outerRingColor = Color.black.opacity(0.1)
  var innerRingColor = Color.red

  var body: some View {
    ZStack {
      Circle()
        .stroke(lineWidth: lineWidth)
        .foregroundColor(outerRingColor)
      
      Circle()
        .trim(from: 0.0, to: CGFloat(min(value, 1.0)))
        .stroke(
          style: StrokeStyle(
            lineWidth: lineWidth,
            lineCap: .round,
            lineJoin: .round
          )
        )
        .foregroundColor(innerRingColor)
        .rotationEffect(.degrees(-90.0))
    }
    .padding(.all, lineWidth / 2)
  }
}

struct AudioLevelView: View {
  let audioLevel: Float
  
  var body: some View {
    GeometryReader { geometry in
      let normalizedLevel = max(0, min(1, (audioLevel + 60) / 60)) // -60dB to 0dB range
      let width = geometry.size.width * CGFloat(normalizedLevel)
      
      ZStack(alignment: .leading) {
        Rectangle()
          .fill(Color(.systemGray5))
        
        Rectangle()
          .fill(LinearGradient(
            colors: [.green, .yellow, .red],
            startPoint: .leading,
            endPoint: .trailing
          ))
          .frame(width: width)
      }
    }
    .cornerRadius(4)
  }
}

struct WaveformView: View {
  let heights: [Float]
  
  var body: some View {
    HStack(spacing: 2) {
      ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
        Rectangle()
          .fill(Color.blue)
          .frame(width: 3, height: CGFloat(height * 50) + 1)
      }
    }
  }
}

private let dateComponentsFormatter: DateComponentsFormatter = {
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = [.minute, .second]
  formatter.zeroFormattingBehavior = .pad
  return formatter
}()

#Preview {
  RecordingView(
    store: Store(initialState: RecordingFeature.State()) {
      RecordingFeature()
    }
  )
} 