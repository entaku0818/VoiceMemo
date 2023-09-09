//
//  AudioEditingView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 25.6.2023.
//


import SwiftUI
import AVFoundation
import Accelerate
import ComposableArchitecture



struct AudioEditingView: View {
    let store: Store<VoiceMemoState, VoiceMemoAction>


    var audioURL: URL?

    @State private var trimStart: Double = 0.0
    @State private var trimEnd: Double = 10.0
    @State private var editmode: Bool = false

    @State private var rightOffsetX: CGFloat = 0
    @State private var leftOffsetX: CGFloat = 0

    @State private var showAlert = false
    @State private var alertMessage = ""



    init(store: Store<VoiceMemoState, VoiceMemoAction>,audioURL: URL?) {
        self.audioURL = audioURL
        self.store = store
    }

    init(store: Store<VoiceMemoState, VoiceMemoAction>,audioURL: URL?, waveformData: [Float]) {
        self.store = store
        self.audioURL = audioURL
    }

    var body: some View {
        
        WithViewStore(store) { viewStore in
            VStack {
                ScrollViewReader { scrollViewProxy in

                    GeometryReader { geometry in
                            ZStack(alignment: .bottom) {
                                // 背景
                                Rectangle()
                                    .fill(Color.gray)

                                VStack{
                                    Spacer()
                                    ScrollView(.horizontal, showsIndicators: false) {

                                        HStack(spacing: 2) {
                                            Spacer().frame(width: geometry.size.width / 2)
                                            ForEach(Array(viewStore.waveformData.enumerated()), id: \.offset) { index, volume in
                                                let height: CGFloat = CGFloat(volume * 30)
                                                Rectangle()
                                                    .fill(Color.pink)
                                                    .frame(width: 3, height: height)
                                                    .id(index)
                                            }
                                            Spacer().frame(width:  geometry.size.width / 2)
                                        }
                                        .onChange(of: viewStore.time) { _ in
                                            DispatchQueue.main.async {
                                                let waveformDatalength = CGFloat(viewStore.waveformData.count)
                                                let targetOffset = Int((viewStore.time / viewStore.duration) * waveformDatalength)
                                                withAnimation(.easeInOut(duration: 0.1)) {

                                                    scrollViewProxy.scrollTo(targetOffset, anchor: .center)
                                                }
                                            }
                                        }
                                    }

                                    Spacer()
                                }

                                // 基準線
                                Path { path in
                                    let height = geometry.size.height
                                    let centerY = height / 2.0

                                    path.move(to: CGPoint(x: 0, y: centerY))
                                    path.addLine(to: CGPoint(x: geometry.size.width, y: centerY))
                                }
                                .stroke(Color.white, lineWidth: 1)
                            }
//                            #if DEBUG
//                            ZStack(alignment: .center) {
//                                // 背景
//                                Rectangle()
//                                    .fill(Color.gray)
//
//
//                                ScrollView(.horizontal, showsIndicators: false) {
//                                    GeometryReader { geometry in
//                                        LazyHStack(alignment: .center, spacing: 1) {
//                                            ForEach(Array(waveformData.enumerated()), id: \.offset) { index, volume in
//                                                let height: CGFloat = CGFloat(volume * 10) + 1
//                                                let percent = waveformData.count / 200
//                                                if percent == 0 {
//                                                    Rectangle()
//                                                        .fill(Color.pink)
//                                                        .frame(width:1, height: height)
//                                                        .id(index)
//                                                }else if index % percent == 0 {
//                                                    Rectangle()
//                                                        .fill(Color.pink)
//                                                        .frame(width:1, height: height)
//                                                        .id(index)
//                                                }
//                                            }
//                                        }
//                                    }
//                                }
//
//                                HStack{
//                                    GeometryReader { geometry in
//                                        ZStack {
//
//                                            Image("Polygon")
//                                                .resizable()
//                                                .frame(width: 20, height: 20)
//                                                .offset(x: rightOffsetX, y: 0 - geometry.size.height / 2)
//                                                .gesture(DragGesture(minimumDistance: 0)
//                                                    .onChanged { value in
//                                                        let xPosition = value.location.x
//                                                         rightOffsetX = xPosition
//                                                        trimEnd = viewStore.duration * (xPosition + (geometry.size.width / 2)) / geometry.size.width
//                                                    }
//                                                )
//                                            Path { path in
//                                                path.move(to: CGPoint(x: rightOffsetX + geometry.size.width / 2, y: 0))
//                                                path.addLine(to: CGPoint(x: rightOffsetX + geometry.size.width / 2, y: geometry.size.height))
//                                            }
//                                            .stroke(Color.blue, lineWidth: 5)
//
//                                            Image("Polygon")
//                                                .resizable()
//                                                .frame(width: 20, height: 20)
//                                                .offset(x: leftOffsetX, y: 0 - geometry.size.height / 2)
//                                                .gesture(DragGesture(minimumDistance: 0)
//                                                    .onChanged { value in
//                                                        let xPosition = value.location.x
//                                                        leftOffsetX = xPosition
//                                                        trimStart = viewStore.duration * (xPosition + (geometry.size.width / 2)) / geometry.size.width
//                                                    }
//                                                )
//                                            Path { path in
//
//                                                path.move(to: CGPoint(x: leftOffsetX + geometry.size.width / 2, y: 0))
//                                                path.addLine(to: CGPoint(x: leftOffsetX + geometry.size.width / 2, y: geometry.size.height))
//                                            }
//                                            .stroke(Color.blue, lineWidth: 5)
//
//
//                                        }.onAppear{
//                                            rightOffsetX = geometry.size.width / 2
//                                            leftOffsetX = 0 - geometry.size.width / 2
//                                        }
//                                    }
//                                }
//                                VStack{
//                                    Text(String(Int(trimStart)))
//                                    Text(String(Int(trimEnd)))
//                                }
//
//                            }
//                            .frame(width: 320,height:80)
//
//
//
//                            Button {
//                                if let audioURL = audioURL {
//                                    trimAudioFile(inputURL: audioURL, startTime: trimStart, endTime: trimEnd)
//                                }
//                            } label: {
//                                Text("trim")
//                            }
//                            #endif

                        



                    }
                }
            }.alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertMessage)
                )
            }.onAppear {
                viewStore.send(.loadWaveformData)
            }



        }
    }



    // trim処理
    func trimAudioFile(inputURL: URL, startTime: TimeInterval, endTime: TimeInterval) {
        do {


            let inputDocumentsPath = NSHomeDirectory() + "/Documents/" + inputURL.lastPathComponent

            // AVAudioFileを作成して入力ファイルを読み込みます
            let inputFile = try AVAudioFile(forReading: URL(fileURLWithPath: inputDocumentsPath))


            // 入力ファイルのフォーマットを取得します
            let fileFormat = inputFile.fileFormat
            let audioFormat = fileFormat.settings

            let documentsPath = NSHomeDirectory() + "/Documents/"
            let outputURL = URL(fileURLWithPath: documentsPath + "trim_aaa")


            // 出力ファイルを作成します
            let outputFile = try AVAudioFile(forWriting: outputURL, settings: audioFormat)

            // 切り取る範囲をフレーム単位に変換します
            guard let startTimeFrame = AVAudioFramePosition(exactly: Int(startTime) * Int(inputFile.fileFormat.sampleRate)),
                  let endTimeFrame = AVAudioFramePosition(exactly: Int(endTime) * Int(inputFile.fileFormat.sampleRate)) else {
                print("Invalid time range or sample rate.")
                return
            }

            // 切り取り処理を行います
            let buffer = AVAudioPCMBuffer(pcmFormat: inputFile.processingFormat, frameCapacity: AVAudioFrameCount(endTimeFrame - startTimeFrame))
            try inputFile.read(into: buffer!, frameCount: AVAudioFrameCount(endTimeFrame - startTimeFrame))
            try outputFile.write(from: buffer!)


            alertMessage = outputURL.lastPathComponent + "ファイルが分割されました"
            print("Trimming completed.")
            showAlert = true
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }


}




import AVFoundation

class WaveformAnalyzer {
    let audioURL: URL

    init(audioURL: URL) {
        self.audioURL = audioURL
    }

    func analyze() -> ([Float], Double){

        let buffers = loadAudioFile(audioURL)
        var volumes:[Float] = []

        buffers.0.forEach { buffer in
            volumes.append(Float(buffer.waveFormHeight))
        }

        return (volumes, buffers.1)
    }




    func loadAudioFile(_ fileUrl: URL) -> ([AVAudioPCMBuffer], Double) {
        var buffers: [AVAudioPCMBuffer] = []
        var duration: Double = 0.0

        var file:AVAudioFile?

        let documentsPath = NSHomeDirectory() + "/Documents/" + fileUrl.lastPathComponent

        do {
            file = try AVAudioFile(forReading: URL(fileURLWithPath: documentsPath),
                                                commonFormat: .pcmFormatFloat32,
                                              interleaved: false)
        }catch{
            print("Failed to load audio file: \(error.localizedDescription)")
            return (buffers,duration)
        }
        guard let file = file else {
            return (buffers,duration)
        }
        let correctLength = AVAudioFrameCount(file.length)

        let blockCount = AVAudioFrameCount(1024)
        var prevFramePosition = file.framePosition
        while file.framePosition < correctLength {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: blockCount) else {
                return (buffers,duration)
            }
            try? file.read(into: buffer, frameCount: blockCount)
            if file.framePosition == prevFramePosition {
                // There are error happened with the file
                break
            }
            prevFramePosition = file.framePosition
            buffers.append(buffer)
            buffer.frameLength = buffer.frameCapacity
            if file.framePosition == file.length && file.framePosition < correctLength {
                let delta = Int64(correctLength) - file.framePosition
                /// emptyBufferって何？それを使って何をしようとしているのか？
                let emptyBufferAmount = delta / Int64(blockCount)
                if emptyBufferAmount > 0 {
                    let emptyBuffers = [Int](repeating: 0, count: Int(emptyBufferAmount))
                        .compactMap { _ -> AVAudioPCMBuffer? in
                            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: blockCount)
                            buffer?.frameLength = buffer?.frameCapacity ?? 0
                            return buffer
                    }
                    if let lastEmptyBuffer = emptyBuffers.last {
                        lastEmptyBuffer.frameLength = AVAudioFrameCount(delta % Int64(blockCount))
                        buffers.append(contentsOf: emptyBuffers)
                    }
                    break
                } else {
                    buffer.frameLength = AVAudioFrameCount(delta)
                    break
                }
            }
            /// このコードブロックはどういう処理？
            if file.framePosition >= correctLength {
                let delta = file.framePosition - Int64(correctLength)
                buffer.frameLength = buffer.frameCapacity - UInt32(delta)
                break
            }
        }

        let sampleRate = Double(file.fileFormat.sampleRate)
        let frameLength = Double(file.length)
        duration = frameLength / sampleRate

        return (buffers, duration)
    }





}



struct AudioEditingView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store(initialState: VoiceMemoState(
                            uuid: UUID(),
                            date: Date(),
                            duration: 180,
                            time: 0,
                            mode: .notPlaying,
                            title: "Untitled",
                            url: URL(fileURLWithPath: ""),
                            text: "",
                            fileFormat: "",
                            samplingFrequency: 0.0,
                            quantizationBitDepth: 0,
                            numberOfChannels: 0
                        ),
                        reducer: voiceMemoReducer,
                        environment: VoiceMemoEnvironment(
                            audioPlayer: .mock,
                            mainRunLoop: .main
                        )
                    )
        let recordingStore = Store(initialState: RecordingMemoState(
            date: Date(),
            url: URL(string: "https://www.pointfree.co/functions")!, duration: 5

        ), reducer: recordingMemoReducer, environment: RecordingMemoEnvironment(audioRecorder: .mock, mainRunLoop: .main
          )
        )

        var randomArray: [Float] = []
        for _ in 0..<4000 {
            let randomValue = Float.random(in: 0...10)
            randomArray.append(randomValue)
        }
        return AudioEditingView(store: store, audioURL: nil,waveformData: randomArray)

    }
}

