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
import FirebaseCrashlytics


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
    var speechRecognizer: SFSpeechRecognizer?
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    var audioEngine: AVAudioEngine?
    var inputNode: AVAudioInputNode?
    var resultText: String = ""
    var isFinal = false
    let sampleRate: Double = 44100

    var currentTime: TimeInterval = 0

  static func requestPermission() async -> Bool {
    await withUnsafeContinuation { continuation in
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
        SFSpeechRecognizer.requestAuthorization { _ in

        }
    }
  }

  func stop() {
      if currentTime < 2 {return}
      audioEngine?.stop()
      self.inputNode?.removeTap(onBus: 0)
      self.recognitionTask?.cancel()
      isFinal = true
      resultText = ""
    try? AVAudioSession.sharedInstance().setActive(false)
  }

    func start(url: URL) async throws -> Bool {
      self.stop()
        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try AVAudioSession.sharedInstance().setActive(true)
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
                  if let error = error as? NSError {
                      // 一言も発しない場合もエラーとなるので、認識結果が0件の場合はエラーを投げない

                      continuation.yield(true)
                      continuation.finish()
                  }
                  if self.isFinal {

                      self.recognitionTask = nil
                      continuation.yield(true)
                      continuation.finish()
                  }

              }
                  // オーディオファイル
              let audioFile = try AVAudioFile(forWriting: url,
                      settings: [
                        AVFormatIDKey: kAudioFormatMPEG4AAC, // フォーマットをM4Aに指定
                        AVSampleRateKey: 44100.0, // サンプルレート
                        AVNumberOfChannelsKey: 2, // チャンネル数
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue // 音質
                    ])

              inputNode?.installTap(onBus: 0, bufferSize: 1024, format: nil) { (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
                // 音声を取得したら
                  self.currentTime = Double(audioFile.length) / self.sampleRate

                  self.recognitionRequest?.append(buffer) // 認識リクエストに取得した音声を加える
                  do {
                    // audioFileにバッファを書き込む
                    try audioFile.write(from: buffer)
                  } catch let error {
                      Logger.shared.logError("audioFile.writeFromBuffer error:" + error.localizedDescription)
                    print("audioFile.writeFromBuffer error:", error)
                    continuation.finish(throwing: error)
                  }
              }

              audioEngine?.prepare()
              try audioEngine?.start()

        } catch {
            Logger.shared.logError(error.localizedDescription)
          continuation.finish(throwing: error)
        }
      }

      guard let action = try await stream.first(where: { @Sendable _ in true })
      else {
          throw CancellationError()
      }
      return action
    }

    func amplitude() -> Float {
        // デシベルから振幅を取得する

        return 0
    }
    func fetchResultText() -> String {

        return resultText
    }

}
