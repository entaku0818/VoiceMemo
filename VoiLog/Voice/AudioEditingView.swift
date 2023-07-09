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

    @State private var waveformData: [Float]
    @State private var totalDuration: Double
    var audioURL: URL?

    init(store: Store<VoiceMemoState, VoiceMemoAction>,audioURL: URL?) {
        self.store = store
        self._waveformData = State(initialValue: [])
        self._totalDuration = State(initialValue: 0.0)
        self.audioURL = audioURL
    }

    init(store: Store<VoiceMemoState, VoiceMemoAction>,audioURL: URL?,waveformData: [Float]) {
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
                        ZStack(alignment: .bottom) {
                            // 背景
                            Rectangle()
                                .fill(Color.gray)

                            VStack{
                                Spacer()
                                ScrollView(.horizontal, showsIndicators: false) {

                                    HStack(spacing: 2) {
                                        Spacer().frame(width: geometry.size.width / 2)
                                        ForEach(Array(waveformData.enumerated()), id: \.offset) { index, volume in
                                            let height: CGFloat = CGFloat(volume * 30) + 1
                                            Rectangle()
                                                .fill(Color.pink)
                                                .frame(width: 3, height: height)
                                                .id(index)
                                        }
                                        Spacer().frame(width:  geometry.size.width / 2)
                                    }
                                    .onChange(of: viewStore.time) { _ in
                                        DispatchQueue.main.async {
                                            let waveformDatalength = CGFloat(waveformData.count)
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

                    }
                }
                #if DEBUG
                #endif 
                Text(String(audioURL?.absoluteString ?? ""))
            }
            .onAppear {
                loadWaveformData()
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

        var randomArray: [Float] = []
        for _ in 0..<1000 {
            let randomValue = Float.random(in: 0...10)
            randomArray.append(randomValue)
        }
        return AudioEditingView(store: store, audioURL: nil,waveformData: randomArray)

    }
}


