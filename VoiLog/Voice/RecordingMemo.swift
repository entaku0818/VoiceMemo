import ComposableArchitecture
import SwiftUI
import Photos

import ActivityKit


struct RecordingMemo: Reducer {
    struct State: Equatable {
        static func == (lhs: State, rhs: State) -> Bool {
                 return lhs.uuid == rhs.uuid &&
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
            volumes: [Float] = [],
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
            self.volumes = []
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
        var volumes: [Float]
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
        var currentActivity: Activity<recordActivityAttributes>? = nil


        enum Mode {
            case recording
            case encoding
        }
    }

  enum Action: Equatable {
      case audioRecorderDidFinish(TaskResult<Bool>)
      case fetchRecordingMemo(UUID)
      case delegate(DelegateAction)
      case finalRecordingTime(TimeInterval)
      case task
      case timerUpdated
      case getVolumes
      case getResultText
      case updateVolumes([Float])
      case updateResultText(String)
      case stopButtonTapped

  }

  enum DelegateAction: Equatable {
    case didFinish(TaskResult<State>)
  }

  struct Failed: Equatable, Error {}

  @Dependency(\.audioRecorder) var audioRecorder
  @Dependency(\.continuousClock) var clock

    func startLiveActivity() -> Activity<recordActivityAttributes>? {
        let attributes = recordActivityAttributes(name: "Recording Activity")
        let initialContentState = recordActivityAttributes.ContentState(emoji: "🔴", recordingTime: 0)
        let activityContent = ActivityContent(state: initialContentState, staleDate: Date().addingTimeInterval(60))

        do {
            let activity = try Activity<recordActivityAttributes>.request(attributes: attributes, content: activityContent, pushType: nil)
            print("Activity started: \(activity.id)")
            return activity
        } catch {
            print("Failed to start activity: \(error.localizedDescription)")
            return nil
        }
    }

    func stopLiveActivity(activity: Activity<recordActivityAttributes>?) {
        guard let activity = activity else {
            print("No active recording to stop")
            return
        }

        let finalContentState = recordActivityAttributes.ContentState(emoji: "⏹️", recordingTime: 0)
        let finalActivityContent = ActivityContent(state: finalContentState, staleDate: Date())

        Task {
            await activity.end(finalActivityContent, dismissalPolicy: .immediate)
            print("Activity ended: \(activity.id)")
        }
    }


    func updateLiveActivity(activity: Activity<recordActivityAttributes>?, duration: TimeInterval) {
        guard let activity = activity else {
            print("No active recording to update")
            return
        }

        let contentState = recordActivityAttributes.ContentState(emoji: "⏹️", recordingTime: duration)
        Task {
            await activity.update(using: contentState)
            print("Activity updated: \(activity.id)")
        }

    }



    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .audioRecorderDidFinish(.success(true)):
            return .send(.delegate(.didFinish(.success(state))))

        case .audioRecorderDidFinish(.success(false)):
            return .send(.delegate(.didFinish(.failure(Failed()))))

        case let .audioRecorderDidFinish(.failure(error)):
            return .send(.delegate(.didFinish(.failure(error))))

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
            let activity = state.currentActivity
            state.currentActivity = nil
            return .run { send in
                if let currentTime = await self.audioRecorder.currentTime() {
                    await send(.finalRecordingTime(currentTime))
                }
                await self.audioRecorder.stopRecording()
                Logger.shared.logInfo("record stop")
                stopLiveActivity(activity: activity)
            }

        case .task:
            let url = state.url
            let activity = startLiveActivity()
            state.currentActivity = activity

            return .run { send in
                async let startRecording: Void = send(
                    .audioRecorderDidFinish(
                        TaskResult { try await audioRecorder.startRecording(url) }
                    )
                )
                Logger.shared.logInfo("record start")

                for await _ in self.clock.timer(interval: .seconds(1)) {
                    await send(.timerUpdated)
                    await send(.getVolumes)
                    await send(.getResultText)
                }
            }

        case .timerUpdated:
            state.duration += 1
            updateLiveActivity(activity: state.currentActivity, duration: state.duration)

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
                await send(.updateVolumes(volume))
            }

        case .getResultText:
            return .run { send in
                let text = await audioRecorder.resultText()
                await send(.updateResultText(text))
            }

        case let .fetchRecordingMemo(uuid):
            let voiceMemoRepository: VoiceMemoRepository = VoiceMemoRepository(coreDataAccessor: VoiceMemoCoredataAccessor(), cloudUploader: CloudUploader())
            if let recordingmemo = voiceMemoRepository.fetch(uuid: uuid) {
                state = recordingmemo
            }
            return .none
        }
    }
}

struct RecordingMemoView: View {
    let store: StoreOf<RecordingMemo>
    @State var value: CGFloat = 0.0
    @State var bottomID = UUID()

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
          VStack {
              ScrollViewReader { reader in
                  ScrollView(.horizontal, showsIndicators: false) {
                      HStack(spacing: 2) {

                          ForEach(viewStore.volumes, id: \.self) { volume in
                              let height: CGFloat = CGFloat(volume * 50) + 1
                              Rectangle()
                                  .fill(Color.pink)               // 図形の塗りつぶしに使うViewを指定
                                  .frame(width: 3, height: height)
                          }
                          Button("") {
                          }.id(bottomID)
                      }

                  }.onChange(of: viewStore.volumes) { _ in
                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                          reader.scrollTo(bottomID)
                      }

                  }.frame(width: UIScreen.main.bounds.width / 2, height: 60, alignment: .leading)
                  .padding(.trailing, UIScreen.main.bounds.width / 2)
              }
              Text(viewStore.resultText)
                  .foregroundColor(.black)
                  .fixedSize(horizontal: false, vertical: true)

          }

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
      let volumes = ActorIsolated([Float(1.0),Float(1.0)])
      let resultText = String("進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。進捗ダメです。/n進捗ダメです。")

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
      }, volumes: {
          return await volumes.value
      }, resultText: {
          return  resultText
      }, insertAudio: { _,_,_  in
          await isRecording.setValue(true)
          while await isRecording.value {
            try await Task.sleep(nanoseconds: NSEC_PER_SEC)
            await currentTime.withValue { $0 += 1 }
          }
          return true
      }
    )
  }
}

struct RingProgressView: View {

    var value: CGFloat
    var lineWidth: CGFloat = 6.0
    var outerRingColor: Color = Color.black.opacity(0.08)
    var innerRingColor: Color = Color.orange

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: self.lineWidth)
                .foregroundColor(self.outerRingColor)
            Circle()
                .trim(from: 0.0, to: CGFloat(min(self.value, 1.0)))
                .stroke(
                    style: StrokeStyle(
                        lineWidth: self.lineWidth,
                        lineCap: .square, // プログレスの角を丸くしたい場合は.round
                        lineJoin: .round
                    )
                )
                .foregroundColor(self.innerRingColor)
                .rotationEffect(.degrees(-90.0))
        }
        .padding(.all, self.lineWidth / 2)
    }
}




struct CarouselView: View {
   
   @State private var currentIndex = 0
   @GestureState private var dragOffset: CGFloat = 0
    @State  var examples:[UIImage] = [UIImage(systemName: "house.fill")!]
   
   let itemPadding: CGFloat = 20
   
    init(images:[UIImage]){
        _examples = State(initialValue: images)
    }
   
   var body: some View {
       GeometryReader { bodyView in
           LazyHStack(spacing: itemPadding) {
               ForEach(examples.indices, id: \.self) { index in
                   // カルーセル対象のView
                   Image(uiImage: examples[index])
                       .frame(width: bodyView.size.width * 0.8, height: 200)
                       .background(Color.gray)
                       .padding(.leading, index == 0 ? bodyView.size.width * 0.1 : 0)
               }
           }
           .offset(x: self.dragOffset)
           .offset(x: -CGFloat(self.currentIndex) * (bodyView.size.width * 0.8 + itemPadding))
           .gesture(
               DragGesture()
                   .updating(self.$dragOffset, body: { (value, state, _) in
                       // 先頭・末尾ではスクロールする必要がないので、画面サイズの1/5までドラッグで制御する
                       if self.currentIndex == 0, value.translation.width > 0 {
                           state = value.translation.width / 5
                       } else if self.currentIndex == (self.examples.count - 1), value.translation.width < 0 {
                           state = value.translation.width / 5
                       } else {
                           state = value.translation.width
                       }
                   })
                   .onEnded({ value in
                       var newIndex = self.currentIndex
                       // ドラッグ幅からページングを判定
                       if abs(value.translation.width) > bodyView.size.width * 0.3 {
                           newIndex = value.translation.width > 0 ? self.currentIndex - 1 : self.currentIndex + 1
                       }
                       
                       // 最小ページ、最大ページを超えないようチェック
                       if newIndex < 0 {
                           newIndex = 0
                       } else if newIndex > (self.examples.count - 1) {
                           newIndex = self.examples.count - 1
                       }
                       
                       self.currentIndex = newIndex
                   })
           )
       }
       .animation(.interpolatingSpring(mass: 0.6, stiffness: 150, damping: 80, initialVelocity: 0.1))
   }
}
