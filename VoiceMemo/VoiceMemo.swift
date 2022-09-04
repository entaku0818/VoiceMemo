import ComposableArchitecture
import SwiftUI

struct RecordingMemoFailed: Equatable, Error {}

struct RecordingMemoState: Equatable {
  var date: Date
  var duration: TimeInterval = 0
  var mode: Mode = .recording
  var url: URL

  enum Mode {
    case recording
    case encoding
  }
}

enum RecordingMemoAction: Equatable {
  case audioRecorderDidFinish(TaskResult<Bool>)
  case delegate(DelegateAction)
  case finalRecordingTime(TimeInterval)
  case task
  case timerUpdated
  case stopButtonTapped

  enum DelegateAction: Equatable {
    case didFinish(TaskResult<RecordingMemoState>)
  }
}

struct RecordingMemoEnvironment {
  var audioRecorder: AudioRecorderClient
  var mainRunLoop: AnySchedulerOf<RunLoop>
}

let recordingMemoReducer = Reducer<
  RecordingMemoState,
  RecordingMemoAction,
  RecordingMemoEnvironment
> { state, action, environment in
  switch action {
  case .audioRecorderDidFinish(.success(true)):
    return .task { [state] in .delegate(.didFinish(.success(state))) }

  case .audioRecorderDidFinish(.success(false)):
    return .task { .delegate(.didFinish(.failure(RecordingMemoFailed()))) }

  case let .audioRecorderDidFinish(.failure(error)):
    return .task { .delegate(.didFinish(.failure(error))) }

  case .delegate:
    return .none

  case let .finalRecordingTime(duration):
    state.duration = duration
    return .none

  case .stopButtonTapped:
    state.mode = .encoding
    return .run { send in
      if let currentTime = await environment.audioRecorder.currentTime() {
        await send(.finalRecordingTime(currentTime))
      }
      await environment.audioRecorder.stopRecording()
    }

  case .task:
    return .run { [url = state.url] send in
      async let startRecording: Void = send(
        .audioRecorderDidFinish(
          TaskResult { try await environment.audioRecorder.startRecording(url) }
        )
      )

      for await _ in environment.mainRunLoop.timer(interval: .seconds(1)) {
        await send(.timerUpdated)
      }
    }

  case .timerUpdated:
    state.duration += 1
    return .none
  }
}

struct RecordingMemoView: View {
  let store: Store<RecordingMemoState, RecordingMemoAction>
    @State var value: CGFloat = 0.0
    
  var body: some View {
    WithViewStore(self.store) { viewStore in

       
      VStack(spacing: 12) {
          ZStack{
              RingProgressView(value: value)
                  .frame(width: 150, height: 150)
                  .onAppear {
                      withAnimation(.linear(duration: 5)) {
                          self.value = 1.0
                      }
                  }
              VStack(spacing: 12) {
                  Text("Recording")
                      .font(.title)
                      .colorMultiply(Color(Int(viewStore.duration).isMultiple(of: 2) ? .systemRed : .label))
                      .animation(.easeInOut(duration: 0.5), value: viewStore.duration)
                  if let formattedDuration = dateComponentsFormatter.string(from: viewStore.duration) {
                      Text(formattedDuration)
                          .font(.body.monospacedDigit().bold())
                          .foregroundColor(.black)
                  }
                  
              }
          }

          scrollView()


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
    }.navigationBarTitle("ChildView", displayMode: .inline)
  }
}

struct RecordingMemoView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingMemoView(store: Store(initialState: RecordingMemoState(
            date: Date(),
            duration: 5,
            mode: .recording,
            url: URL(string: "https://www.pointfree.co/functions")!
        ), reducer: recordingMemoReducer, environment: RecordingMemoEnvironment(audioRecorder: .mock, mainRunLoop: .main
          
          )
        ))
    }
}




let dateComponentsFormatter: DateComponentsFormatter = {
  let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.minute, .second,.nanosecond]
  formatter.zeroFormattingBehavior = .pad
  return formatter
}()

extension AudioRecorderClient {
  static var mock: Self {
    let isRecording = ActorIsolated(false)
    let currentTime = ActorIsolated(0.0)

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
