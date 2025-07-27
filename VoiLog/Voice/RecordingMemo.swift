import ComposableArchitecture
import SwiftUI
import Photos

struct RecordingMemo: Reducer {
    struct State: Equatable {
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.uuid == rhs.uuid &&
                lhs.date == rhs.date &&
                lhs.duration == rhs.duration &&
                lhs.volumes == rhs.volumes &&
                lhs.resultText == rhs.resultText &&
                lhs.mode == rhs.mode &&
                lhs.fileFormat == rhs.fileFormat &&
                lhs.samplingFrequency == rhs.samplingFrequency &&
                lhs.quantizationBitDepth == rhs.quantizationBitDepth &&
                lhs.numberOfChannels == rhs.numberOfChannels &&
                lhs.url == rhs.url &&
                lhs.newUrl == rhs.newUrl &&
                lhs.startTime == rhs.startTime &&
                lhs.time == rhs.time
        }

        init(
            uuid: UUID = UUID(),
            date: Date,
            duration: TimeInterval,
            volumes: Float = -60,
            resultText: String = "",
            mode: Mode = .recording,
            fileFormat: String = "",
            samplingFrequency: Double,
            quantizationBitDepth: Int,
            numberOfChannels: Int,
            url: URL,
            startTime: TimeInterval,
            time: TimeInterval
        ) {
            self.uuid = uuid
            self.date = date
            self.duration = duration
            self.volumes = volumes
            self.resultText = resultText
            self.mode = mode
            self.fileFormat = fileFormat
            self.samplingFrequency = samplingFrequency
            self.quantizationBitDepth = quantizationBitDepth
            self.numberOfChannels = numberOfChannels
            self.url = url
            self.startTime = startTime
            self.time = time
        }

        init(from voiceMemoState: VoiceMemoReducer.State) {
            self.uuid = voiceMemoState.uuid
            self.date = voiceMemoState.date
            self.duration = voiceMemoState.duration
            self.volumes = -60
            self.resultText = voiceMemoState.text
            self.mode = .encoding
            self.fileFormat = ""
            self.samplingFrequency = voiceMemoState.samplingFrequency
            self.quantizationBitDepth = voiceMemoState.quantizationBitDepth
            self.numberOfChannels = voiceMemoState.numberOfChannels
            self.url = voiceMemoState.url
            self.newUrl = nil
            self.startTime = voiceMemoState.time
            self.time = voiceMemoState.time
        }

        var uuid: UUID
        var date: Date
        var duration: TimeInterval
        var volumes: Float
        var resultText: String
        var mode: Mode
        var fileFormat: String
        var samplingFrequency: Double
        var quantizationBitDepth: Int
        var numberOfChannels: Int
        var url: URL
        var newUrl: URL?
        var startTime: TimeInterval
        var time: TimeInterval
        var waveFormHeights: [Float] = []

        enum Mode {
            case recording
            case pause
            case encoding
        }
    }

    enum Action: Equatable {
        case audioRecorderDidFinish(TaskResult<Bool>)
        case fetchRecordingMemo(UUID)
        case delegate(DelegateAction)
        case finalRecordingTime(TimeInterval)
        case task
        case timerUpdated(TimeInterval)
        case getVolumes
        case getResultText
        case updateVolumes(Float)
        case getWaveFormHeights
        case updateWaveFormHeights([Float])
        case updateResultText(String)
        case stopButtonTapped
        case togglePauseResume
    }

    enum DelegateAction: Equatable {
        case didFinish(TaskResult<State>)
    }

    struct Failed: Equatable, Error {}

    @Dependency(\.audioRecorder) var audioRecorder
    @Dependency(\.continuousClock) var clock

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .audioRecorderDidFinish(.success(true)):
            return .send(.delegate(.didFinish(.success(state))))

        case .audioRecorderDidFinish(.success(false)):
            return .run { send in
                await self.audioRecorder.pauseRecording()
                await send(.delegate(.didFinish(.failure(Failed()))))
            }
        case let .audioRecorderDidFinish(.failure(error)):
            return .run { send in
                await self.audioRecorder.pauseRecording()
                await send(.delegate(.didFinish(.failure(error))))
            }

        case .delegate:
            return .none

        case let .finalRecordingTime(duration):
            state.duration = duration
            return .none

        case .stopButtonTapped:
            state.mode = .encoding
            state.fileFormat = UserDefaultsManager.shared.selectedFileFormat
            state.samplingFrequency = UserDefaultsManager.shared.samplingFrequency
            state.quantizationBitDepth = UserDefaultsManager.shared.quantizationBitDepth
            state.numberOfChannels = UserDefaultsManager.shared.numberOfChannels
            return .run { send in
                if let currentTime = await self.audioRecorder.currentTime() {
                    await send(.finalRecordingTime(currentTime))
                }
                await self.audioRecorder.stopRecording()
                RollbarLogger.shared.logInfo("record stop")
            }

        case .togglePauseResume:
            if state.mode == .pause {
                state.mode = .recording
                return .run { _ in
                    await self.audioRecorder.resumeRecording()
                    RollbarLogger.shared.logInfo("record resumed")
                }
            } else {
                state.mode = .pause
                return .run { _ in
                    await self.audioRecorder.pauseRecording()
                    RollbarLogger.shared.logInfo("record paused")
                }
            }

        case .task:
            let url = state.url
            return .run { send in
                async let startRecording: Void = send(
                    .audioRecorderDidFinish(
                        TaskResult { try await audioRecorder.startRecording(url) }
                    )
                )
                RollbarLogger.shared.logInfo("record start")

                // Timer for other periodic updates
                async let generalUpdates: Void = {
                    for await _ in self.clock.timer(interval: .seconds(1)) {
                        await send(.getResultText)
                    }
                }()

                // Timer for volume updates
                async let volumeUpdates: Void = {
                    for await _ in self.clock.timer(interval: .milliseconds(100)) {
                        await send(.getVolumes)
                    }
                }()

                // Timer for waveform height updates
                async let currentTimeUpdates: Void = {
                    for await _ in self.clock.timer(interval: .milliseconds(500)) {
                        if let currentTime = await self.audioRecorder.currentTime() {
                            await send(.timerUpdated(currentTime))
                        }
                    }
                }()

                _ = await (startRecording, generalUpdates, volumeUpdates, currentTimeUpdates)
            }

        case let .timerUpdated(currentTime):
            state.duration = currentTime
            return .none

        case let .updateVolumes(volumes):
            state.volumes = volumes
            return .none

        case let .updateResultText(text):
            state.resultText = text
            return .none

        case .getVolumes:
            return .run { send in
                let volume = await audioRecorder.volumes()
                UserDefaultsManager.shared.logError(String(format: "RecordingMemo - Volume: %.2f dB", volume))
                await send(.updateVolumes(volume))
            }

        case .getResultText:
            return .run { send in
                let text = await audioRecorder.resultText()
                await send(.updateResultText(text))
            }

        case let .fetchRecordingMemo(uuid):
            let voiceMemoRepository = VoiceMemoRepository(coreDataAccessor: VoiceMemoCoredataAccessor(), cloudUploader: CloudUploader())
            if let recordingmemo = voiceMemoRepository.fetch(uuid: uuid) {
                state = recordingmemo
            }
            return .none
        case .getWaveFormHeights:
            return .run { send in
                let heights = await audioRecorder.waveFormHeights()
                await send(.updateWaveFormHeights(heights))
            }

        case let .updateWaveFormHeights(heights):
            state.waveFormHeights = heights
            return .none
        }
    }

}

struct RecordingMemoView: View {
    let store: StoreOf<RecordingMemo>
    @State var value: CGFloat = 0.0
    @State var bottomID = UUID()
    @State private var showModal = false

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in

            VStack(spacing: 12) {

                ZStack {
                    RingProgressView(value: value)
                        .frame(width: 150, height: 150)
                        .onAppear {
                            withAnimation(.linear(duration: 600)) {
                                self.value = 1.0
                            }
                        }
                    VStack(spacing: 12) {

                        Text("Recording")
                            .font(.title)
                            .colorMultiply(Color(Int(viewStore.duration).isMultiple(of: 2) ? .systemRed : .label))
                            .animation(.easeInOut(duration: 1), value: viewStore.duration)
                        if let formattedDuration = dateComponentsFormatter.string(from: viewStore.duration) {
                            Text(formattedDuration)
                                .font(.body.monospacedDigit().bold())
                                .foregroundColor(.black)
                        }

                    }
                }
                //          VStack {
                //              ScrollViewReader { reader in
                //                  ScrollView(.horizontal, showsIndicators: false) {
                //                      HStack(spacing: 2) {
                //
                //                          ForEach(viewStore.waveFormHeights, id: \.self) { volume in
                //                              let height: CGFloat = CGFloat(volume * 50) + 1
                //                              Rectangle()
                //                                  .fill(Color.pink)               // 図形の塗りつぶしに使うViewを指定
                //                                  .frame(width: 3, height: height)
                //                          }
                //                          Button("") {
                //                          }.id(bottomID)
                //                      }
                //
                //                  }.onChange(of: viewStore.waveFormHeights) { _ in
                //                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                //                          reader.scrollTo(bottomID)
                //                      }
                //
                //                  }.frame(width: UIScreen.main.bounds.width / 2, height: 60, alignment: .leading)
                //                  .padding(.trailing, UIScreen.main.bounds.width / 2)
                //              }
                //
                //
                //          }

                AudioLevelView(audioLevel: viewStore.volumes)
                    .frame(height: 20)
                    .padding()

                VStack(alignment: .center) {
                    Text(viewStore.resultText)
                        .lineLimit(3)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    if !viewStore.resultText.isEmpty {
                        Button(action: {
                            showModal.toggle()
                        }) {
                            Text("Read More")
                                .foregroundColor(.blue)
                                .underline()
                        }
                    }
                }
                .sheet(isPresented: $showModal) {
                    VStack {
                        ScrollView {
                            Text(viewStore.resultText)
                                .padding()
                        }
                        Button("Close") {
                            showModal.toggle()
                        }
                        .padding()
                    }
                }

                HStack {
                    ZStack {
                        Circle()
                            .foregroundColor(Color(.label))
                            .frame(width: 74, height: 74)

                        Button(action: { viewStore.send(.stopButtonTapped, animation: .default) }) {
                            RoundedRectangle(cornerRadius: 4)
                                .foregroundColor(Color(.systemRed))
                                .padding(17)
                        }
                        .frame(width: 70, height: 70)
                    }
                    Spacer().frame(width: 24)
                    Button(action: { viewStore.send(.togglePauseResume, animation: .default) }) {
                        Image(systemName: viewStore.mode == .pause ? "play.fill" : "pause.fill")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                            .padding(24)
                            .background(Color.black)
                            .clipShape(Circle())
                    }
                }

            }
            .task {
                await viewStore.send(.task).finish()
            }
        }.navigationBarTitle("Recording", displayMode: .inline)
    }

}

struct RecordingMemoView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingMemoView(
            store: Store(
                initialState: RecordingMemo.State(
                    date: Date(),
                    duration: 5,
                    samplingFrequency: 44100,
                    quantizationBitDepth: 16,
                    numberOfChannels: 2,
                    url: URL(string: "https://www.pointfree.co/functions")!,
                    startTime: 0,
                    time: 0
                )
            ) {
                RecordingMemo()
            }
        )
    }
}

let dateComponentsFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.minute, .second, .nanosecond]
    formatter.zeroFormattingBehavior = .pad
    return formatter
}()

extension AudioRecorderClient {
    static var mock: Self {
        let isRecording = ActorIsolated(false)
        let currentTime = ActorIsolated(0.0)
        let volumes = ActorIsolated(Float(1.0))
        let resultText = """
        進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。\n進捗ダメです。
        """

        return Self(
            currentTime: { await currentTime.value },
            requestRecordPermission: { true },
            startRecording: { _ in
                await isRecording.setValue(true)
                while await isRecording.value {
                    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
                    await currentTime.withValue { $0 += 1 }
                }
                return true
            },
            stopRecording: {
                await isRecording.setValue(false)
                await currentTime.setValue(0)
            },
            pauseRecording: {
                await isRecording.setValue(false)
            },
            resumeRecording: {
                await isRecording.setValue(true)
            },
            volumes: {
                await volumes.value
            }, waveFormHeights: {
                [0.1]
            },
            resultText: {
                resultText
            }
        )
    }
}
