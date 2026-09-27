import SwiftUI

/// 録音中のスクロール波形（iOS 標準「ボイスメモ」風）。
///
/// 最新のサンプルを赤い再生ヘッドの位置に描き、古いサンプルほど左へ流す。
/// 上部には経過時間の目盛り、再生ヘッドより右（これから録る部分）には点線の基準線を引く。
/// 録音済みの範囲（0:00〜再生ヘッド）は背景をグレーにし、0:00 より左（録音前）はそれより薄いグレーにする。
/// サンプルは 100ms ごとにしか増えないので、録音中は TimelineView で毎フレーム
/// 「前のサンプルからの経過時間」ぶん左へずらし、波形と目盛りを連続的にスクロールさせる。
struct RecordingWaveformView: View {
    let samples: [Float]
    /// 録音の経過時間。目盛りの位置合わせに使う。
    let duration: TimeInterval
    /// 録音中だけスクロールを動かす（一時停止中は止める）
    var isRecording = true
    /// 1 サンプルあたりの時間（RecordingFeature のメータータイマー間隔と揃える）
    var sampleInterval: TimeInterval = 0.1

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2
    private let rulerHeight: CGFloat = 22
    /// 再生ヘッドの横位置（幅に対する割合）。画面の真ん中に置く。
    private let playheadRatio: CGFloat = 0.5

    /// 最後にサンプルが増えた時刻（スクロールの補間の起点）
    @State private var lastSampleDate = Date()

    private var step: CGFloat { barWidth + barSpacing }

    var body: some View {
        TimelineView(.animation(paused: !isRecording)) { timeline in
            let progress = isRecording
                ? RecordingWaveform.scrollProgress(
                    sinceLastSample: timeline.date.timeIntervalSince(lastSampleDate),
                    interval: sampleInterval
                )
                : 0
            canvas(progress: CGFloat(progress))
        }
        .onChange(of: samples.count) { _, _ in
            lastSampleDate = Date()
        }
        .accessibilityHidden(true)
    }

    /// - Parameter progress: 次のサンプルまでの進み具合（0...1）。この割合ぶん波形と目盛りを左へずらす。
    private func canvas(progress: CGFloat) -> some View {
        Canvas { context, size in
            let playheadX = (size.width * playheadRatio).rounded()
            let waveTop = rulerHeight
            let waveHeight = size.height - rulerHeight
            let midY = waveTop + waveHeight / 2
            // サンプルがまだ無いうちはずらさない（何も無い範囲が1本ぶん録音済みに見えないように）
            let scroll = samples.isEmpty ? 0 : progress * step
            // 録音開始（0:00）の位置。録音直後は再生ヘッドと同じで、録音が進むほど左へ流れる
            let recordingStartX = playheadX - CGFloat(samples.count) * step - scroll

            // 0:00 より左（録音前）の背景。録音済みの範囲より薄いグレーにする
            if recordingStartX > 0 {
                let beforeStart = CGRect(x: 0, y: waveTop, width: recordingStartX, height: waveHeight)
                context.fill(Path(beforeStart), with: .color(Color(uiColor: .systemGray6)))
            }

            // 録音済みの範囲の背景（0:00 の位置から再生ヘッドまで）
            if !samples.isEmpty {
                let startX = max(0, recordingStartX)
                let recorded = CGRect(x: startX, y: waveTop, width: playheadX - startX, height: waveHeight)
                context.fill(Path(recorded), with: .color(Color(uiColor: .systemGray5)))
            }

            drawRuler(in: &context, size: size, playheadX: playheadX, time: duration + Double(progress) * sampleInterval)

            // 未来側（再生ヘッドより右）の点線基準線
            var baseline = Path()
            baseline.move(to: CGPoint(x: playheadX, y: midY))
            baseline.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(baseline, with: .color(.secondary.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))

            // 波形（末尾=最新を再生ヘッド位置に置き、左へ遡って描く）
            let maxBarHeight = waveHeight * 0.92
            for (offset, level) in samples.reversed().enumerated() {
                let x = playheadX - CGFloat(offset) * step - barWidth - scroll
                if x < -barWidth { break }
                let height = max(2, CGFloat(level) * maxBarHeight)
                let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(.primary))
            }

            // 再生ヘッド
            var head = Path()
            head.move(to: CGPoint(x: playheadX, y: waveTop - 4))
            head.addLine(to: CGPoint(x: playheadX, y: size.height))
            context.stroke(head, with: .color(.red), lineWidth: 2)
            let knob = CGRect(x: playheadX - 5, y: waveTop - 9, width: 10, height: 10)
            context.fill(Path(ellipseIn: knob), with: .color(.red))
        }
    }

    /// 経過時間の目盛り。0.5 秒ごとに短い線、1 秒ごとに長い線とラベル。
    private func drawRuler(in context: inout GraphicsContext, size: CGSize, playheadX: CGFloat, time duration: TimeInterval) {
        let pointsPerSecond = step / CGFloat(sampleInterval)
        let halfSeconds = Int((Double(playheadX) / Double(pointsPerSecond) + 1) * 2)
        let futureHalfSeconds = Int((Double(size.width - playheadX) / Double(pointsPerSecond) + 1) * 2)
        let startHalf = Int((duration * 2).rounded(.down)) - halfSeconds
        let endHalf = Int((duration * 2).rounded(.down)) + futureHalfSeconds

        for half in max(0, startHalf)...max(0, endHalf) {
            let time = Double(half) / 2
            let x = playheadX - CGFloat(duration - time) * pointsPerSecond
            guard x >= 0, x <= size.width else { continue }
            let isSecond = half % 2 == 0
            var tick = Path()
            tick.move(to: CGPoint(x: x, y: rulerHeight - (isSecond ? 8 : 4)))
            tick.addLine(to: CGPoint(x: x, y: rulerHeight))
            context.stroke(tick, with: .color(.secondary.opacity(isSecond ? 0.8 : 0.4)), lineWidth: 1)
            if isSecond, half % 4 == 0 {
                let seconds = Int(time)
                let label = Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
                context.draw(label, at: CGPoint(x: x, y: 5), anchor: .center)
            }
        }
    }
}

private func previewSamples() -> [Float] {
    var waveform = RecordingWaveform()
    for index in 0..<120 {
        let wave = Float(abs(sin(Double(index) / 6)))
        waveform.append(decibels: -45 + 35 * wave)
    }
    return waveform.samples
}

#Preview {
    RecordingWaveformView(samples: previewSamples(), duration: 12)
        .frame(height: 220)
        .padding()
}
