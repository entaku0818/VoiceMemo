//
//  AudioEditingView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 25.6.2023.
//


import SwiftUI
import AVFoundation
import Accelerate


struct AudioEditingView: View {
    @State private var waveformData: [Float]
    var audioURL: URL?

    init(waveformData: [Float], audioURL: URL?) {
        self._waveformData = State(initialValue: waveformData)
        self.audioURL = audioURL
    }

    var body: some View {
        VStack {
            WaveformView(waveformData: waveformData)
                .frame(height: 200)
            Button(action: {

            }) {
                Text("Play")
            }
            Text(String(audioURL?.absoluteString ?? ""))
        }
        .onAppear {
            loadWaveformData()
        }
    }

    func loadWaveformData() {
        if let audioURL = audioURL {
            let waveformAnalyzer = WaveformAnalyzer(audioURL: audioURL)
            waveformData = waveformAnalyzer.analyze()
        }
    }

}




import AVFoundation

class WaveformAnalyzer {
    let audioURL: URL

    init(audioURL: URL) {
        self.audioURL = audioURL
    }

    func analyze() -> [Float] {

        let buffers = loadAudioFile(audioURL)
        var volumes:[Float] = []

        buffers.forEach { buffer in
            volumes.append(Float(buffer.waveFormHeight))
        }

        return volumes
    }

    func loadAudioFile(_ fileUrl: URL) -> [AVAudioPCMBuffer] {
        var buffers: [AVAudioPCMBuffer] = []
        guard let file = try? AVAudioFile(forReading: fileUrl,
                                          commonFormat: .pcmFormatFloat32,
                                          interleaved: false) else {
            return []
        }
        let correctLength = AVAudioFrameCount(file.length)

        let blockCount = AVAudioFrameCount(1024)
        var prevFramePosition = file.framePosition
        while file.framePosition < correctLength {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: blockCount) else {
                return []
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

        return buffers
    }




}



struct AudioEditingView_Previews: PreviewProvider {
    static var previews: some View {


        return AudioEditingView(waveformData: [0.2, 0.5, 0.8, 0.3, 0.6], audioURL: nil)

    }
}


