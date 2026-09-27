import SwiftUI

/// 録音中のスクロール波形（iOS 標準「ボイスメモ」風）。
///
/// 最新のサンプルを赤い再生ヘッドの位置に描き、古いサンプルほど左へ流す。
/// 上部には経過時間の目盛り、再生ヘッドより右（これから録る部分）には点線の基準線を引く。
struct RecordingWaveformView: View {
    let samples: [Float]
    /// 録音の経過時間。目盛りの位置合わせに使う。
    let duration: TimeInterval
    /// 1 サンプルあたりの時間（RecordingFeature のメータータイマー間隔と揃える）
    var sampleInterval: TimeInterval = 0.1

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2
    private let rulerHeight: CGFloat = 22
    /// 再生ヘッドの横位置（幅に対する割合）。左側に過去の波形を多く見せる。
    private let playheadRatio: CGFloat = 0.72

    private var step: CGFloat { barWidth + barSpacing }

    var body: some View {
        Canvas { context, size in
            let playheadX = (size.width * playheadRatio).rounded()
            let waveTop = rulerHeight
            let waveHeight = size.height - rulerHeight
            let midY = waveTop + waveHeight / 2

            drawRuler(in: &context, size: size, playheadX: playheadX)

            // 未来側（再生ヘッドより右）の点線基準線
            var baseline = Path()
            baseline.move(to: CGPoint(x: playheadX, y: midY))
            baseline.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(baseline, with: .color(.secondary.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))

            // 波形（末尾=最新を再生ヘッド位置に置き、左へ遡って描く）
            let maxBarHeight = waveHeight * 0.92
            for (offset, level) in samples.reversed().enumerated() {
                let x = playheadX - CGFloat(offset) * step - barWidth
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
        .accessibilityHidden(true)
    }

    /// 経過時間の目盛り。0.5 秒ごとに短い線、1 秒ごとに長い線とラベル。
    private func drawRuler(in context: inout GraphicsContext, size: CGSize, playheadX: CGFloat) {
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
