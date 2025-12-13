import SwiftUI

struct WaveformView: View {
    let waveformData: [Float]
    let selectedRange: ClosedRange<Double>?
    let currentTime: Double
    let duration: TimeInterval
    let onRangeSelected: (ClosedRange<Double>?) -> Void
    let onSeek: (Double) -> Void

    @State private var isSelecting = false
    @State private var selectionStart: CGFloat = 0
    @State private var selectionEnd: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false

    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 1
    private let minBarHeight: CGFloat = 3
    private let selectionColor = Color.blue.opacity(0.3)
    private let waveformColor = Color.blue
    private let currentPositionColor = Color.red

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 波形表示
                HStack(spacing: barSpacing) {
                    ForEach(0..<min(waveformData.count, Int(geometry.size.width / (barWidth + barSpacing))), id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(waveformColor)
                            .frame(width: barWidth, height: max(CGFloat(waveformData[index]) * geometry.size.height * 0.8, minBarHeight))
                    }
                }

                // 選択範囲
                if let selectedRange = selectedRange {
                    let startPosition = CGFloat(selectedRange.lowerBound / duration) * geometry.size.width
                    let endPosition = CGFloat(selectedRange.upperBound / duration) * geometry.size.width

                    Rectangle()
                        .fill(selectionColor)
                        .frame(width: endPosition - startPosition, height: geometry.size.height)
                        .position(x: startPosition + (endPosition - startPosition) / 2, y: geometry.size.height / 2)
                }

                // 現在の再生位置
                Rectangle()
                    .fill(currentPositionColor)
                    .frame(width: 2, height: geometry.size.height)
                    .position(x: CGFloat(currentTime / duration) * geometry.size.width, y: geometry.size.height / 2)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        if !isSelecting {
                            isSelecting = true
                            selectionStart = value.startLocation.x
                        }
                        selectionEnd = value.location.x

                        // 選択範囲を時間に変換して通知
                        let startTime = Double(selectionStart / geometry.size.width) * duration
                        let endTime = Double(selectionEnd / geometry.size.width) * duration

                        // 時間の範囲を確保
                        let minTime = max(0, min(startTime, endTime))
                        let maxTime = min(duration, max(startTime, endTime))

                        if minTime != maxTime {
                            onRangeSelected(minTime...maxTime)
                        } else {
                            // 単一の点を選択した場合（分割ポイント）
                            onRangeSelected(minTime...minTime)
                        }
                    }
                    .onEnded { _ in
                        if selectionStart == selectionEnd {
                            // タップ操作の場合は、その位置に再生位置を移動
                            let seekPosition = Double(selectionStart / geometry.size.width) * duration
                            onSeek(seekPosition)
                            isSelecting = false
                        }
                    }
            )
            .contentShape(Rectangle())
            .onTapGesture { location in
                // 選択をクリア
                if !isDragging {
                    isSelecting = false
                    onRangeSelected(nil)

                    // タップした位置に再生位置を移動
                    let seekPosition = Double(location.x / geometry.size.width) * duration
                    onSeek(seekPosition)
                }
            }
        }
    }
}

// プレビュー用のデータ生成
private func generateSampleWaveformData(count: Int) -> [Float] {
    var data = [Float]()
    for i in 0..<count {
        let progress = Float(i) / Float(count)
        let value = sin(progress * .pi * 4) * 0.4 + 0.5
        data.append(value)
    }
    return data
}

struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        WaveformView(
            waveformData: generateSampleWaveformData(count: 100),
            selectedRange: 10.0...20.0,
            currentTime: 15.0,
            duration: 60.0,
            onRangeSelected: { _ in },
            onSeek: { _ in }
        )
        .frame(height: 100)
        .padding()
        .previewLayout(.sizeThatFits)
        .previewDisplayName("選択範囲あり")

        WaveformView(
            waveformData: generateSampleWaveformData(count: 100),
            selectedRange: nil,
            currentTime: 30.0,
            duration: 60.0,
            onRangeSelected: { _ in },
            onSeek: { _ in }
        )
        .frame(height: 100)
        .padding()
        .previewLayout(.sizeThatFits)
        .previewDisplayName("選択範囲なし")
    }
}
