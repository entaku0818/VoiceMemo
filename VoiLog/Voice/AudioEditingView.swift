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
    @State private var audioPlayer: AVAudioPlayer?
    @State private var waveformData: [Float] = []
    @State var audioURL: URL?

    var body: some View {
        VStack {
            WaveformView(waveformData: waveformData, waveformColor: .black)
                .frame(height: 200)

            Button(action: {
                playAudio()
            }) {
                Text("Play")
            }
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

    func playAudio() {
        guard let audioURL = Bundle.main.url(forResource: "audio", withExtension: "mp3") else {
            return
        }

        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            self.audioPlayer = audioPlayer
            audioPlayer.play()
        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
        }
    }
}

struct WaveformView: View {
    var waveformData: [Float]
    var waveformColor: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 背景
                Rectangle()
                    .fill(Color.gray)

                // 波形描画
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height

                    // 波形の描画
                    let stepX = width / CGFloat(waveformData.count)
                    let halfHeight = height / 2.0
                    let centerY = height - halfHeight

                    path.move(to: CGPoint(x: 0, y: centerY))

                    for (index, value) in waveformData.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = centerY + CGFloat(value) * halfHeight
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(waveformColor, lineWidth: 2)

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
}



struct WaveformAnalyzer {
    let audioURL: URL

    func analyze() -> [Float] {


          do {
              let audioFile = try AVAudioFile(forReading: audioURL, commonFormat: .pcmFormatFloat32, interleaved: false)
              let format = audioFile.processingFormat
              let frameCount = UInt32(audioFile.length)

              guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                  return []
              }
              try audioFile.read(into: audioBuffer)
              let channelData = UnsafeBufferPointer(start: audioBuffer.floatChannelData?[0], count:Int(audioBuffer.frameLength))
              let waveformData = Array(channelData)
              return waveformData

          } catch {
              print("Failed to read audio file: \(error.localizedDescription)")
              return []
          }



      }
}


struct AudioEditingView_Previews: PreviewProvider {
    static var previews: some View {
        AudioEditingView(audioURL: nil)
    }
}
