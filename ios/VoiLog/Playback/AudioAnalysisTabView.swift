//
//  AudioAnalysisTabView.swift
//  VoiLog
//
//  Extracted from EnhancedVoiceMemoDetailView for Issue #123
//

import SwiftUI
import AVFoundation

struct AudioAnalysisTabView: View {
    let memo: PlaybackFeature.VoiceMemo
    let isAnalyzingAudio: Bool
    let audioAnalysisData: AudioAnalysisData?
    let waveformData: [Float]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isAnalyzingAudio {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(String(localized: "音声を分析中...", table: "Playback"))
                            .font(.headline)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(50)
                } else if let analysisData = audioAnalysisData {
                    // 波形ビジュアライゼーション
                    DetailSection(title: String(localized: "波形", table: "Playback")) {
                        SimpleWaveformView(data: waveformData)
                            .frame(height: 150)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // 音声特性
                    DetailSection(title: String(localized: "音声特性", table: "Playback")) {
                        InfoRow(icon: "waveform", label: String(localized: "平均音量", table: "Playback"), value: String(format: "%.1f dB", analysisData.averageVolume))
                        InfoRow(icon: "speaker.wave.3", label: String(localized: "ピーク音量", table: "Playback"), value: String(format: "%.1f dB", analysisData.peakVolume))
                        InfoRow(icon: "waveform.path.ecg", label: String(localized: "ダイナミックレンジ", table: "Playback"), value: String(format: "%.1f dB", analysisData.dynamicRange))
                        InfoRow(icon: "metronome", label: String(localized: "サンプリングレート", table: "Playback"), value: "\(Int(memo.samplingFrequency)) Hz")
                        InfoRow(icon: "speaker.wave.2", label: String(localized: "ビットレート", table: "Playback"), value: calculateBitrate())
                    }

                    // 周波数分析
                    DetailSection(title: String(localized: "周波数分析", table: "Playback")) {
                        FrequencyChart(data: analysisData.frequencyData)
                            .frame(height: 200)
                    }

                    // 無音検出
                    DetailSection(title: String(localized: "無音分析", table: "Playback")) {
                        InfoRow(icon: "speaker.slash", label: String(localized: "無音時間", table: "Playback"), value: formatDuration(analysisData.silenceDuration))
                        InfoRow(icon: "percent", label: String(localized: "無音比率", table: "Playback"), value: String(format: "%.1f%%", analysisData.silenceRatio * 100))
                        InfoRow(icon: "scissors", label: String(localized: "無音区間数", table: "Playback"), value: "\(analysisData.silenceSegments.count)")
                    }
                }
            }
            .padding()
        }
    }

    private func calculateBitrate() -> String {
        let bitrate = Double(memo.fileSize * 8) / memo.duration / 1000
        return String(format: "%.0f kbps", bitrate)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Analysis Logic (static helpers used by EnhancedVoiceMemoDetailView)

enum AudioAnalyzer {
    static func generateWaveform(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        let samplesPerPoint = max(1, frameLength / 100)
        var waveform: [Float] = []

        for i in stride(from: 0, to: frameLength, by: samplesPerPoint) {
            let endIndex = min(i + samplesPerPoint, frameLength)
            var sum: Float = 0
            for j in i..<endIndex {
                sum += abs(channelDataValue[j])
            }
            let average = sum / Float(endIndex - i)
            waveform.append(average)
        }

        return waveform
    }

    static func analyzeVolume(buffer: AVAudioPCMBuffer) -> (average: Double, peak: Double) {
        guard let channelData = buffer.floatChannelData else { return (-60, -60) }
        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        var peak: Float = 0

        for i in 0..<frameLength {
            let value = abs(channelDataValue[i])
            sum += value
            peak = max(peak, value)
        }

        let average = sum / Float(frameLength)
        let avgDB = 20 * log10(max(average, 0.00001))
        let peakDB = 20 * log10(max(peak, 0.00001))

        return (Double(avgDB), Double(peakDB))
    }

    static func detectSilence(buffer: AVAudioPCMBuffer, threshold: Float) -> [(start: TimeInterval, end: TimeInterval)] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate

        var silenceSegments: [(start: TimeInterval, end: TimeInterval)] = []
        var silenceStart: Int?

        let thresholdLinear = pow(10, threshold / 20)

        for i in 0..<frameLength {
            let value = abs(channelDataValue[i])

            if value < thresholdLinear {
                if silenceStart == nil {
                    silenceStart = i
                }
            } else {
                if let start = silenceStart {
                    let startTime = Double(start) / sampleRate
                    let endTime = Double(i) / sampleRate
                    if endTime - startTime > 0.5 {
                        silenceSegments.append((start: startTime, end: endTime))
                    }
                    silenceStart = nil
                }
            }
        }

        if let start = silenceStart {
            let startTime = Double(start) / sampleRate
            let endTime = Double(frameLength) / sampleRate
            if endTime - startTime > 0.5 {
                silenceSegments.append((start: startTime, end: endTime))
            }
        }

        return silenceSegments
    }

    static func analyzeFrequency(buffer: AVAudioPCMBuffer) -> [(frequency: Float, amplitude: Float)] {
        let frequencies: [Float] = [50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]

        guard let channelData = buffer.floatChannelData else {
            return frequencies.map { (frequency: $0, amplitude: -60) }
        }

        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        return frequencies.map { freq in
            let bandStart = Int(Float(frameLength) * freq / Float(buffer.format.sampleRate))
            let bandEnd = min(bandStart + Int(Float(frameLength) * 0.1), frameLength)

            var sum: Float = 0
            for i in bandStart..<bandEnd {
                if i < frameLength {
                    sum += abs(channelDataValue[i])
                }
            }

            let average = sum / Float(bandEnd - bandStart)
            let amplitudeDB = 20 * log10(max(average, 0.00001))

            return (frequency: freq, amplitude: amplitudeDB)
        }
    }

    static func generateDummyWaveform() -> [Float] {
        (0..<100).map { _ in Float.random(in: -1...1) }
    }

    static func generateDummyFrequencyData() -> [(frequency: Float, amplitude: Float)] {
        let frequencies: [Float] = [50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]
        return frequencies.map { freq in
            (frequency: freq, amplitude: Float.random(in: -60...0))
        }
    }
}
