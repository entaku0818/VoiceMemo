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
  var volumes: @Sendable () async -> [Float]
  var resultText: @Sendable () async -> String
    var insertAudio: @Sendable (TimeInterval, URL, URL) async throws -> Bool
}

extension AudioRecorderClient: TestDependencyKey {
    static var previewValue: Self {
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
            },
            volumes: { [] }, // Add some stub values here if needed
            resultText: { "" },
            insertAudio: { _, _, _ in true }
        )
    }

    static let testValue = Self(
        currentTime: unimplemented("\(Self.self).currentTime", placeholder: nil),
        requestRecordPermission: unimplemented(
            "\(Self.self).requestRecordPermission", placeholder: false
        ),
        startRecording: unimplemented("\(Self.self).startRecording", placeholder: false),
        stopRecording: unimplemented("\(Self.self).stopRecording"),
        volumes: unimplemented("\(Self.self).volumes", placeholder: []),
        resultText: unimplemented("\(Self.self).resultText", placeholder: ""),
        insertAudio: unimplemented("\(Self.self).insertAudio", placeholder: false)
    )
}


extension DependencyValues {
  var audioRecorder: AudioRecorderClient {
    get { self[AudioRecorderClient.self] }
    set { self[AudioRecorderClient.self] = newValue }
  }
}


extension AudioRecorderClient: DependencyKey  {
  static var liveValue: Self {
    let audioRecorder = AudioRecorder()
    return Self(
      currentTime: { await audioRecorder.currentTime },
      requestRecordPermission: { await AudioRecorder.requestPermission() },
      startRecording: { url in try await audioRecorder.start(url: url) },
      stopRecording: { await audioRecorder.stop() },
      volumes: { await audioRecorder.amplitude() },
      resultText: { await audioRecorder.fetchResultText() },
      insertAudio: { insertTime, newAudioURL, existingAudioURL in
        try await audioRecorder.insertAudio(at: insertTime, newAudioURL: newAudioURL, existingAudioURL: existingAudioURL)
      }    )
  }
}

private actor AudioRecorder {
    var speechRecognizer: SFSpeechRecognizer?
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    var audioEngine: AVAudioEngine?
    var inputNode: AVAudioInputNode?
    var resultText: String = ""
    var buffers: [AVAudioPCMBuffer] = []
    var waveFormHeights:[CGFloat] = []
    var isFinal = false


    
    var currentTime: TimeInterval = 0

  static func requestPermission() async -> Bool {
      await withUnsafeContinuation { continuation in
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          continuation.resume(returning: granted)
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
        setupAVAudioSession()
      let stream = AsyncThrowingStream<Bool, Error> { continuation in
        do {
            speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
              audioEngine = AVAudioEngine()


            inputNode = audioEngine?.inputNode

            guard let inputNode = inputNode else {return}

            inputNode.volume = Float(UserDefaultsManager.shared.microphonesVolume)



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
            let fileFormat:AudioFormatID = Constants.FileFormat.init(rawValue: UserDefaultsManager.shared.selectedFileFormat)?.audioId ?? kAudioFormatMPEG4AAC
            let quantizationBitDepth:Int = UserDefaultsManager.shared.quantizationBitDepth
            let sampleRate: Double = UserDefaultsManager.shared.samplingFrequency
            let numberOfChannels: Int = 1

                  // オーディオファイル

            let settings = [
                AVFormatIDKey: fileFormat,
                AVNumberOfChannelsKey: numberOfChannels,
                AVSampleRateKey: sampleRate,
                AVLinearPCMBitDepthKey: quantizationBitDepth,  // 16-bit quantization
            ]

            let audioFile = try AVAudioFile(forWriting: url, settings: settings)


              inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
                // 音声を取得したら
                  self.currentTime = Double(audioFile.length) / sampleRate

                  self.recognitionRequest?.append(buffer) // 認識リクエストに取得した音声を加える

                  self.buffers.append(buffer)
                  self.waveFormHeights.append(buffer.waveFormHeight)

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

    func insertAudio(at insertTime: TimeInterval, newAudioURL: URL, existingAudioURL: URL) async throws -> Bool {
        self.stop()
        setupAVAudioSession()

        let stream = AsyncThrowingStream<Bool, Error> { continuation in


            do {
                speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
                  audioEngine = AVAudioEngine()

                inputNode = audioEngine?.inputNode

                // 既存の音声ファイルの読み込み
                let existingAudioFile = try AVAudioFile(forReading: existingAudioURL)


                // オーディオファイルを作成し、新しい音声ファイルのデータを書き込む
                let newAudioFile = try AVAudioFile(forWriting: newAudioURL, settings: existingAudioFile.fileFormat.settings)
                let buffer = AVAudioPCMBuffer(pcmFormat: newAudioFile.processingFormat, frameCapacity: AVAudioFrameCount(newAudioFile.length))
                try existingAudioFile.read(into: buffer!)
                try newAudioFile.write(from: buffer!)


                guard let inputNode = inputNode else {return}

                inputNode.volume = Float(UserDefaultsManager.shared.microphonesVolume)



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



                // TODO: ここのsampleRateはこれではダメ
                let sampleRate: Double = UserDefaultsManager.shared.samplingFrequency

                  inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
                    // 音声を取得したら
                      self.currentTime = Double(newAudioFile.length) / sampleRate

                      self.recognitionRequest?.append(buffer) // 認識リクエストに取得した音声を加える

                      self.buffers.append(buffer)
                      self.waveFormHeights.append(buffer.waveFormHeight)

                      do {
                        // audioFileにバッファを書き込む
                        try newAudioFile.write(from: buffer)
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
                continuation.yield(true)
                continuation.finish(throwing: error)
            }
        }

        guard let action = try await stream.first(where: { @Sendable _ in true }) else {
            throw CancellationError()
        }

        return action
    }


    private func setupAVAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .default, options: [.defaultToSpeaker,.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("マイクの音量を設定できませんでした。エラー: \(error.localizedDescription)")
        }
    }

    func amplitude() -> [Float] {
        debugPrint("waveFormHeights\(waveFormHeights)")
        return waveFormHeights.map { Float($0) }
    }
    func fetchResultText() -> String {

        return resultText
    }

}
