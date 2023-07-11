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
    var insertAudio: @Sendable (TimeInterval, URL) async throws -> Void
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
      resultText: { await audioRecorder.fetchResultText() },
      insertAudio: { insertTime, newAudioURL in try await audioRecorder.insertAudio(at: insertTime, newAudioURL: newAudioURL) }
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
    var buffers: [AVAudioPCMBuffer] = []
    var waveFormHeights:[CGFloat] = []
    var isFinal = false


    
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
        setupAVAudioSession()
      let stream = AsyncThrowingStream<Bool, Error> { continuation in
        do {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
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

    private func setupAVAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .default, options: .defaultToSpeaker)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("マイクの音量を設定できませんでした。エラー: \(error.localizedDescription)")
        }
    }

    func amplitude() -> [Float] {

        #if DEBUG
        debugPrint("waveFormHeights\(waveFormHeights)")
        return waveFormHeights.map { Float($0) }
        #else
        return []
        #endif
    }
    func fetchResultText() -> String {

        return resultText
    }


    func insertAudio(at insertTime: TimeInterval, newAudioURL: URL) async throws {
      // 新しい音声ファイルを読み込む
      let newAudioFile = try AVAudioFile(forReading: newAudioURL)

      // 保存する新しい音声ファイルのURLを作成
      let saveURL = generateSaveURL()

      // 保存するオーディオフォーマットを設定
      let fileFormat = AVFileType.caf

      // オーディオファイルを作成し、新しい音声ファイルのデータを書き込む
      let audioFile = try AVAudioFile(forWriting: saveURL, settings: newAudioFile.fileFormat.settings)
      let buffer = AVAudioPCMBuffer(pcmFormat: newAudioFile.processingFormat, frameCapacity: AVAudioFrameCount(newAudioFile.length))
      try newAudioFile.read(into: buffer!)
      try audioFile.write(from: buffer!)

      // 既存の音声ファイルの再生が終了してから新しい音声ファイルを挿入するようにスケジュール
      existingPlayerNode.completionHandler = { [weak self] in
        guard let self = self else { return }

        // 挿入する位置をフレーム単位で計算
        let insertFramePosition = AVAudioFramePosition(insertTime * self.audioFile.processingFormat.sampleRate)

        // 新しい音声ファイルのデータを読み込む
        let buffer = AVAudioPCMBuffer(pcmFormat: newAudioFile.processingFormat, frameCapacity: AVAudioFrameCount(newAudioFile.length))
        try! newAudioFile.read(into: buffer!)

        // ミキサーノードに新しい音声ファイルを挿入
        self.audioEngine.mainMixerNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(buffer!.frameLength), format: self.audioEngine.mainMixerNode.outputFormat(forBus: 0)) { (buffer, time) in
          if time.sampleTime >= insertFramePosition {
            // 指定位置以降のフレームであれば、新しい音声ファイルのデータを使用する
            buffer.copy(from: buffer)
          } else {
            // 指定位置より前のフレームであれば、既存の音声ファイルのデータを使用する
            try! self.audioFile.read(into: buffer)
          }
        }

        // プレイヤーノードとミキサーノードを切断
        self.audioEngine.disconnectNodeOutput(self.playerNode)
        self.audioEngine.disconnectNodeOutput(self.mixerNode)

        // プレイヤーノードをミキサーノードに接続
        self.audioEngine.connect(self.playerNode, to: self.mixerNode, format: self.audioFile.processingFormat)

        // 新しい音声ファイルをミキサーノードに接続
        self.audioEngine.connect(self.newPlayerNode, to: self.mixerNode, format: newAudioFile.processingFormat)

        // プレイヤーノードとミキサーノードの出力をメインミキサーノードに接続
        self.audioEngine.connect(self.mixerNode, to: self.audioEngine.mainMixerNode, format: self.audioFile.processingFormat)

        // プレイヤーノードを再生
        self.playerNode.play()
      }

      // 新しい音声ファイルを再生
      newPlayerNode.scheduleFile(newAudioFile, at: nil)
      newPlayerNode.play()
    }

    func generateSaveURL() -> URL {
      // ドキュメントディレクトリのURLを取得
      let documentDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

      // 保存するファイル名を作成（一意の名前となるようにタイムスタンプを使用）
      let fileName = "\(UUID().uuidString).caf"

      // 保存するファイルのURLを作成
      let saveURL = documentDirectoryURL.appendingPathComponent(fileName)

      return saveURL
    }

}
