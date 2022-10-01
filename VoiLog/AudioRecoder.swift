//
//  AudioRecoder.swift
//  VoiceMemo
//
//  Created by 遠藤拓弥 on 4.9.2022.
//

import AVFoundation
import ComposableArchitecture
import Foundation
import Speech

struct AudioRecorderClient {
  var currentTime: @Sendable () async -> TimeInterval?
  var requestRecordPermission: @Sendable () async -> Bool
  var startRecording: @Sendable (URL) async throws -> Bool
  var stopRecording: @Sendable () async -> Void
  var volumes: @Sendable () async -> Float
  var resultText: @Sendable () async -> String
}


extension AudioRecorderClient {
  static var live: Self {
    let audioRecorder = AudioRecorder()
    return Self(
      currentTime: { await audioRecorder.currentTime },
      requestRecordPermission: { await AudioRecorder.requestPermission() },
      startRecording: { url in try await audioRecorder.start(url: url) },
      stopRecording: { await audioRecorder.stop() },
      volumes: { await audioRecorder.amplitude() },
      resultText: { await audioRecorder.fetchResultText() }
    )
  }
}

private actor AudioRecorder {
  var recorder: AVAudioRecorder?
    var speechRecognizer:SFSpeechRecognizer?
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    var audioEngine:AVAudioEngine?
    var inputNode:AVAudioInputNode?
    var resultText:String = ""
    var isFinal = false

  var currentTime: TimeInterval? {
    guard
      let recorder = self.recorder,
      recorder.isRecording
    else { return nil }
    return recorder.currentTime
  }

  static func requestPermission() async -> Bool {
    await withUnsafeContinuation { continuation in
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
        }
    }
  }

  func stop() {
      audioEngine?.stop()
      self.inputNode?.removeTap(onBus: 0)
      self.recognitionTask?.cancel()
      isFinal = true
    try? AVAudioSession.sharedInstance().setActive(false)
  }

    func start(url: URL) async throws -> Bool {
      self.stop()

      let stream = AsyncThrowingStream<Bool, Error> { continuation in
        do {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
              audioEngine = AVAudioEngine()

                  inputNode = audioEngine?.inputNode

              
              recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
              guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
              recognitionRequest.shouldReportPartialResults = true // 発話ごとに中間結果を返すかどうか
                      
              // requiresOnDeviceRecognition を true に設定すると、音声データがネットワークで送られない
              // ただし精度は下がる
              recognitionRequest.requiresOnDeviceRecognition = false
              


              self.recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in

                  // 取得した認識結の処理


                          
                  if let result = result {
                      self.isFinal = result.isFinal
                      // 認識結果をプリント
                      print("RecognizedText: \(result.bestTranscription.formattedString)")
                      self.resultText = result.bestTranscription.formattedString
                  }
                          
                  // 音声認識できない場合のエラー
                  // 一言も発しない場合もエラーとなるので、認識結果が0件の場合はエラーを投げない
                  if error != nil{
                      continuation.finish(throwing: error)
                  }
                  if self.isFinal {
                   
                      self.recognitionTask = nil
                      continuation.yield(true)
                      continuation.finish()
                  }
                  
              }
                  // オーディオファイル
              let audioFile = try AVAudioFile(forWriting: url, settings: AVAudioFormat(commonFormat: .pcmFormatFloat32  , sampleRate: 44100, channels: 1 , interleaved: true)!.settings)
                 
              inputNode?.installTap(onBus: 0, bufferSize: 1024, format: nil) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                // 音声を取得したら
                  self.recognitionRequest?.append(buffer) // 認識リクエストに取得した音声を加える
                  do {
                    // audioFileにバッファを書き込む
                    try audioFile.write(from: buffer)
                  } catch let error {
                    print("audioFile.writeFromBuffer error:", error)
                    continuation.finish(throwing: error)
                  }
              }
            
              
              audioEngine?.prepare()
              try audioEngine?.start()

            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try AVAudioSession.sharedInstance().setActive(true)

        } catch {
          continuation.finish(throwing: error)
        }
      }
     
      guard let action = try await stream.first(where: { @Sendable _ in true })
      else { throw CancellationError() }
      return action
    }
    
    
 


    
    func amplitude() -> Float {
        self.recorder?.updateMeters()
        let decibel = recorder?.averagePower(forChannel: 0) ?? 0
        // デシベルから振幅を取得する
         
        return (decibel + 160) / 320
    }
    func fetchResultText() -> String {

         
        return resultText
    }

}

