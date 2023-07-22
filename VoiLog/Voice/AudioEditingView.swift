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
    let store: Store<RecordingMemoState, RecordingMemoAction>


    @State private var waveformData: [Float]
    @State private var totalDuration: Double
    var audioURL: URL?

    @State private var trimStart: Double = 0.0
    @State private var trimEnd: Double = 10.0
    @State private var editmode: Bool = false

    @State private var rightOffsetX: CGFloat = 0
    @State private var leftOffsetX: CGFloat = 0

    @State private var showAlert = false
    @State private var alertMessage = ""



    init(store: Store<RecordingMemoState, RecordingMemoAction>,audioURL: URL?) {
        self._waveformData = State(initialValue: [])
        self._totalDuration = State(initialValue: 0.0)
        self.audioURL = audioURL

        self.store = store
    }

    init(store: Store<RecordingMemoState, RecordingMemoAction>,audioURL: URL?, waveformData: [Float]) {
        self.store = store
        self._waveformData = State(initialValue: waveformData)
        self._totalDuration = State(initialValue: 0.0)
        self.audioURL = audioURL
    }

    var body: some View {
        
        WithViewStore(store) { viewStore in
            VStack {
                ScrollViewReader { scrollViewProxy in

                    GeometryReader { geometry in
                        VStack{
                            ZStack(alignment: .center) {
                                    // 背景
                                    Rectangle()
                                        .fill(Color.gray)


                                    ScrollView(.horizontal, showsIndicators: false) {

                                        LazyHStack(alignment: .center, spacing: 1) {
                                            Spacer().frame(width: geometry.size.width / 2)
                                            ForEach(Array(waveformData.enumerated()), id: \.offset) { index, volume in
                                                let height: CGFloat = CGFloat(volume * 30) + 1
                                                Rectangle()
                                                    .fill(Color.pink)
                                                    .frame(width: 2, height: height)
                                                    .id(index)
                                            }
                                            Spacer().frame(width:  geometry.size.width / 2)
                                        }

                                    }



                                GeometryReader { geometry2 in

                                    VStack{
                                        Spacer()
                                        Path { path in
                                            let startPoint = CGPoint(x: 0, y: geometry2.size.height / 2)
                                            let endPoint = CGPoint(x: geometry2.size.width, y: geometry2.size.height / 2)
                                            path.move(to: startPoint)
                                            path.addLine(to: endPoint)
                                        }
                                        .stroke(Color.white, lineWidth:1)
                                        Spacer()
                                    }
                                }

                            }
                            ZStack(alignment: .center) {
                                // 背景
                                Rectangle()
                                    .fill(Color.gray)


                                ScrollView(.horizontal, showsIndicators: false) {
                                    GeometryReader { geometry in
                                        LazyHStack(alignment: .center, spacing: 1) {
                                            ForEach(Array(waveformData.enumerated()), id: \.offset) { index, volume in
                                                let height: CGFloat = CGFloat(volume * 10) + 1
                                                let percent = waveformData.count / 200
                                                if percent == 0 {
                                                    Rectangle()
                                                        .fill(Color.pink)
                                                        .frame(width:1, height: height)
                                                        .id(index)
                                                }else if index % percent == 0 {
                                                    Rectangle()
                                                        .fill(Color.pink)
                                                        .frame(width:1, height: height)
                                                        .id(index)
                                                }
                                            }
                                        }
                                    }
                                }

                                HStack{
                                    GeometryReader { geometry in
                                        ZStack {
                                            Image("Polygon")
                                                .resizable()
                                                .frame(width: 20, height: 20)
                                                .offset(x: rightOffsetX, y: 0 - geometry.size.height / 2)
                                                .gesture(DragGesture(minimumDistance: 0)
                                                    .onChanged { value in

                                                        rightOffsetX = value.location.x

                                                    }
                                                )
                                            Path { path in
                                                path.move(to: CGPoint(x: rightOffsetX + geometry.size.width / 2, y: 0))
                                                path.addLine(to: CGPoint(x: rightOffsetX + geometry.size.width / 2, y: geometry.size.height))
                                            }
                                            .stroke(Color.blue, lineWidth: 5)

                                            Image("Polygon")
                                                .resizable()
                                                .frame(width: 20, height: 20)
                                                .offset(x: leftOffsetX, y: 0 - geometry.size.height / 2)
                                                .gesture(DragGesture(minimumDistance: 0)
                                                    .onChanged { value in

                                                        leftOffsetX = value.location.x

                                                    }
                                                )
                                            Path { path in

                                                path.move(to: CGPoint(x: leftOffsetX + geometry.size.width / 2, y: 0))
                                                path.addLine(to: CGPoint(x: leftOffsetX + geometry.size.width / 2, y: geometry.size.height))
                                            }
                                            .stroke(Color.blue, lineWidth: 5)


                                        }.onAppear{
                                            rightOffsetX = geometry.size.width / 2
                                            leftOffsetX = 0 - geometry.size.width / 2
                                        }
                                    }
                                }

                            }
                            .frame(height:80)


                            Button {
                                if let audioURL = audioURL {
                                    trimAudioFile(inputURL: audioURL, startTime: trimStart, endTime: trimEnd)
                                }
                            } label: {
                                Text("trim")
                            }

                        }



                    }
                }
            }
            .onAppear {
                loadWaveformData()
            }.alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertMessage)
                )
            }



        }
    }

    func loadWaveformData() {
        if let audioURL = audioURL {
            let waveformAnalyzer = WaveformAnalyzer(audioURL: audioURL)
            waveformData = waveformAnalyzer.analyze().0
            totalDuration =  waveformAnalyzer.analyze().1
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
            guard let startTimeFrame = AVAudioFramePosition(exactly: startTime * inputFile.fileFormat.sampleRate),
                  let endTimeFrame = AVAudioFramePosition(exactly: endTime * inputFile.fileFormat.sampleRate) else {
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
                            text: ""
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
        return AudioEditingView(store: recordingStore, audioURL: nil,waveformData: randomArray)

    }
}


