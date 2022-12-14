import ComposableArchitecture
import SwiftUI
import Photos

struct RecordingMemoFailed: Equatable, Error {}

struct RecordingMemoState: Equatable {
  var uuid = UUID()
  var date: Date
  var duration: TimeInterval = 0
  var volumes: [Float] = []
  var resultText: String = ""
    var images:[PHAsset] = []
  var mode: Mode = .recording
  var url: URL
    var themaText:String = ThemaRepository.shared.select()

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
  case photos
  case timerUpdated
    case getVolumes
    case getResultText
  case updateVolumes(Float)
    case updateResultText(String)
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
        await send(.getVolumes)
          await send(.getResultText)
      }
    }

  case .timerUpdated:
    state.duration += 1
    return .none
  case let .updateVolumes(volume):
    state.volumes.append(volume)
    return .none
  case let .updateResultText(text):
    state.resultText = text
    return .none
  case .getVolumes:
    return .run { send in
        let volume = await environment.audioRecorder.volumes()
        await send(.updateVolumes(volume))
    }
  case .getResultText:
      return .run { send in
          let text = await environment.audioRecorder.resultText()
          await send(.updateResultText(text))
      }
  case .photos:

      
      return .none
  }

}

struct RecordingMemoView: View {
  let store: Store<RecordingMemoState, RecordingMemoAction>
    @State var value: CGFloat = 0.0
    @State var bottomID = UUID()

  var body: some View {
  
        ScrollView {
            VStack(spacing: 12) {
                WithViewStore(self.store) { viewStore in
                    Text(viewStore.themaText)
                        .font(.largeTitle)
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
                    
                }
                VStack{
                    Text("?????????????????????????????????")
                    CarouselView()
                }.frame(height: 300)

//                VStack {
//                    ScrollViewReader { reader in
//                        ScrollView(.horizontal, showsIndicators: false) {
//                            HStack(spacing: 2) {
//
//                                ForEach(viewStore.volumes, id: \.self) { volume in
//                                    let height: CGFloat = CGFloat(volume * 50) + 1
//                                    Rectangle()
//                                        .fill(Color.pink)               // ?????????????????????????????????View?????????
//                                        .frame(width: 3, height: height)
//                                }
//                                Button("") {
//                                }.id(bottomID)
//                            }
//
//                        }.onChange(of: viewStore.volumes) { _ in
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                                reader.scrollTo(bottomID)
//                            }
//
//                        }.frame(width: UIScreen.main.bounds.width / 2, height: 60, alignment: .leading)
//                        .padding(.trailing, UIScreen.main.bounds.width / 2)
//                    }
//                    ScrollView {
//                        Text(viewStore.resultText)
//                            .foregroundColor(.black)
//                            .fixedSize(horizontal: false, vertical: true)
//                    }.frame(height: 100)
//
//
//                }
                WithViewStore(self.store) { viewStore in
                    
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
                        
                    }.task {
                        await viewStore.send(.task).finish()
                    }
                    
                }
            }
      
    }.navigationBarTitle("Recording", displayMode: .inline)
  }
}

struct RecordingMemoView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingMemoView(store: Store(initialState: RecordingMemoState(
            date: Date(),
            duration: 5,
            images: [], mode: .recording,
            url: URL(string: "https://www.pointfree.co/functions")!,
            themaText: "??????????????????????????????"
            
        ), reducer: recordingMemoReducer, environment: RecordingMemoEnvironment(audioRecorder: .mock, mainRunLoop: .main

          )
        ))
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
      let resultText = String("?????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n??????????????????????????????????????????/n?????????????????????")

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
                        lineCap: .square, // ????????????????????????????????????????????????.round
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
  var examples:[UIImage] = []
   
   let itemPadding: CGFloat = 20
   
    init(){
        var photoAssets: Array! = [PHAsset]()
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 100 // ???????????????????????????????????????
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d",
                                              PHAssetMediaType.image.rawValue,
                                              PHAssetMediaType.video.rawValue) // image???video????????????
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets: PHFetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var images:[UIImage] = []
        assets.enumerateObjects({ (asset, index, stop) -> Void in
            let manager = PHImageManager()
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isSynchronous = true
            options.isNetworkAccessAllowed = true
            manager.requestImage(for: asset,
                                    targetSize: CGSize(width: 200, height: 200),
                                    contentMode: .aspectFill,
                                    options: options,
                                 resultHandler: { (image, _) in
                if let image = image {
                    images.append(image)
                }
            })
        })
        examples = images
    }
   
   var body: some View {
       GeometryReader { bodyView in
           LazyHStack(spacing: itemPadding) {
               ForEach(examples.indices, id: \.self) { index in
                   // ????????????????????????View
                   Image(uiImage: examples[index])
                       .frame(width: bodyView.size.width * 0.8, height: 200)
                       .padding(.leading, index == 0 ? bodyView.size.width * 0.1 : 0)
               }
           }
           .offset(x: self.dragOffset)
           .offset(x: -CGFloat(self.currentIndex) * (bodyView.size.width * 0.8 + itemPadding))
           .gesture(
               DragGesture()
                   .updating(self.$dragOffset, body: { (value, state, _) in
                       // ????????????????????????????????????????????????????????????????????????????????????1/5?????????????????????????????????
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
                       // ?????????????????????????????????????????????
                       if abs(value.translation.width) > bodyView.size.width * 0.3 {
                           newIndex = value.translation.width > 0 ? self.currentIndex - 1 : self.currentIndex + 1
                       }
                       
                       // ??????????????????????????????????????????????????????????????????
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
