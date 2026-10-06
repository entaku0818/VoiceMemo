import SwiftUI

#if DEBUG
// MARK: - Hero (slot 0) page
//
// fastlane/hero_screenshot/compose.py の v5（白版）を SwiftUI で再現したもの。
// compose.py は 1320x2868px の実機キャプチャを合成しているので、ここでは 440x956pt（@3x）に換算して同じ位置に置く。
// 背景・ピル・見出し・チップ・端末フレーム・拡大カードは PromoScreenshotPageView.swift の共通部品を使う
// （2枚目以降の PromoScreenshotPageView も同じ部品で描くので、全ページのデザインが揃う）。
// ja / en-US の出荷用ヒーローは実機キャプチャ版（承認済み）を使い、それ以外の言語でこのビューを使う。
struct HeroRecorderPageView: View {
    let language: AppLanguage

    private let metrics = PromoMetrics.iPhone
    static let canvasSize = PromoMetrics.iPhone.canvasSize

    /// 拡大カードに切り出す録音画面の範囲（WAVE_BOX = (0, 480, 1320, 1590) px）
    private let cropTop: CGFloat = 480 / 3
    private let cropHeight: CGFloat = 1110 / 3
    private let cardY: CGFloat = 1110 / 3

    var body: some View {
        ZStack(alignment: .topLeading) {
            PromoBackground()

            PromoHeaderView(
                language: language,
                pill: language.string("hero_pill"),
                line1: language.string("hero_line1"),
                line2: language.string("hero_line2"),
                chips: language.strings("hero_chips"),
                metrics: metrics
            )
            phone
            zoomCard
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipped()
        // 端末とカードの配置は RTL でも左右対称のまま固定し、中身（文言・録音画面）だけ言語の向きにする
        .environment(\.layoutDirection, .leftToRight)
    }

    // MARK: Phone mock

    private var screenScale: CGFloat { metrics.screenWidth / Self.canvasSize.width }
    private var screenHeight: CGFloat { Self.canvasSize.height * screenScale }

    private var phone: some View {
        PromoDeviceFrame(
            screenSize: CGSize(width: metrics.screenWidth, height: screenHeight),
            bezel: metrics.bezel,
            radius: metrics.deviceRadius,
            screenRadius: metrics.screenRadius
        ) {
            HeroRecordingScreenMock(language: language)
                .screenshotLanguage(language)
                .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
                .scaleEffect(screenScale, anchor: .topLeading)
        }
        .offset(x: metrics.deviceOrigin.x, y: metrics.deviceOrigin.y)
    }

    // MARK: Zoomed card

    private var cardScale: CGFloat { metrics.cardWidth / Self.canvasSize.width }

    private var zoomCard: some View {
        let cardHeight = cropHeight * cardScale
        return HeroRecordingScreenMock(language: language)
            .screenshotLanguage(language)
            .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
            .offset(y: -cropTop)
            .frame(width: Self.canvasSize.width, height: cropHeight, alignment: .topLeading)
            .clipped()
            .scaleEffect(cardScale, anchor: .topLeading)
            .frame(width: metrics.cardWidth, height: cardHeight, alignment: .topLeading)
            .promoFocusCard(radius: metrics.cardRadius, border: metrics.cardBorder)
            .offset(x: metrics.cardInset, y: cardY)
    }
}

// MARK: - Recording screen mock (RecordingView while recording)
/// 録音中の実画面（RecordingView + iOS 26 のタブバー）を 440x956pt で再現したモック。
/// 位置は fastlane/hero_screenshot/raw/<lang>/recording_wave.png（iPhone 17 Pro Max の実機キャプチャ）に合わせている。
struct HeroRecordingScreenMock: View {
    let language: AppLanguage
    /// 経過時間（秒）。目盛りのラベルとタイマーに使う
    var elapsedSeconds = 12

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white

            statusBar

            Text(language.string("hero_screen_title"))
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 400, alignment: .leading)
                .position(x: 20 + 200, y: 141)

            VStack(spacing: 8) {
                Text(language.string("hero_recording_status"))
                    .font(.title2.bold())
                    .foregroundColor(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60))
                    .font(.title.monospacedDigit().bold())
                    .foregroundColor(.black)
            }
            .frame(width: 400)
            .position(x: 220, y: 216)

            // 承認済みヒーローの撮影時点では波形に左右 16pt の余白があった
            HeroWaveformView(elapsedSeconds: Double(elapsedSeconds))
                .frame(width: 408, height: 220)
                .position(x: 220, y: 283 + 110)
                .environment(\.layoutDirection, .leftToRight)

            controls
                .position(x: 220, y: 820)

            tabBar
                .position(x: 220, y: 901)
        }
        .frame(width: 440, height: 956)
    }

    private var statusBar: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 70)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100percent.bolt")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .green)
            }
            .font(.system(size: 15, weight: .semibold))
        }
        .foregroundColor(.black)
        .padding(.horizontal, 32)
        .frame(width: 440)
        .position(x: 220, y: 32)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var controls: some View {
        HStack(spacing: 32) {
            ZStack {
                Circle().fill(Color(.systemGray)).frame(width: 70, height: 70)
                RoundedRectangle(cornerRadius: 4).fill(Color.red).frame(width: 25, height: 25)
            }
            ZStack {
                Circle().fill(Color(.systemGray2)).frame(width: 60, height: 60)
                Image(systemName: "pause.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabItem(icon: "record.circle.fill", label: language.string("tab_recording"), selected: true)
            tabItem(icon: "play.circle.fill", label: language.string("tab_playback"), selected: false)
            tabItem(icon: "list.bullet", label: language.string("tab_playlist"), selected: false)
            tabItem(icon: "gearshape.fill", label: language.string("tab_settings"), selected: false)
        }
        .padding(4)
        .frame(width: 398, height: 62)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 2)
        )
    }

    private func tabItem(icon: String, label: String, selected: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .symbolRenderingMode(selected ? .palette : .monochrome)
                .foregroundStyle(selected ? Color.white : Color.black, Color.blue)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundColor(selected ? .blue : .black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Capsule()
                .fill(selected ? Color(white: 0.92) : Color.clear)
        )
    }
}

// MARK: - Static waveform (looks like RecordingWaveformView while recording)
/// RecordingWaveformView と同じ寸法（バー幅 3pt・間隔 2pt・目盛り高 22pt・100ms/バー）で描く静的な波形。
/// 承認済みヒーロー（2026-09 撮影）に合わせ、再生ヘッドは幅の約 72% の位置に置く
/// （現行アプリは中央・録音済み範囲をグレー表示に変わっている。RecordingWaveformView 参照）。
struct HeroWaveformView: View {
    let elapsedSeconds: Double
    var playheadRatio: CGFloat = 0.72

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2
    private let rulerHeight: CGFloat = 22
    private let sampleInterval: Double = 0.1

    /// 話し声らしい決定的なバーの高さ（0...1）。末尾が最新
    static let levels: [CGFloat] = {
        var result: [CGFloat] = []
        var seed: UInt64 = 0x5EED_1234
        for index in 0..<120 {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let noise = CGFloat((seed >> 33) % 1000) / 1000
            let envelope = 0.72 + 0.12 * sin(CGFloat(index) / 7)
            var level = envelope + (noise - 0.5) * 0.22
            // 息継ぎのような短い落ち込み
            if index % 37 == 30 || index % 37 == 31 { level *= 0.35 }
            result.append(min(0.95, max(0.12, level)))
        }
        return result
    }()

    var body: some View {
        Canvas { context, size in
            let step = barWidth + barSpacing
            let playheadX = (size.width * playheadRatio).rounded()
            let waveTop = rulerHeight
            let waveHeight = size.height - rulerHeight
            let midY = waveTop + waveHeight / 2

            // 目盛り
            let pointsPerSecond = step / CGFloat(sampleInterval)
            let firstHalf = Int(((elapsedSeconds - Double(playheadX / pointsPerSecond)) * 2).rounded(.down))
            let lastHalf = Int(((elapsedSeconds + Double((size.width - playheadX) / pointsPerSecond)) * 2).rounded(.up))
            for half in max(0, firstHalf)...max(0, lastHalf) {
                let time = Double(half) / 2
                let x = playheadX - CGFloat(elapsedSeconds - time) * pointsPerSecond
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

            // 未来側の点線
            var baseline = Path()
            baseline.move(to: CGPoint(x: playheadX, y: midY))
            baseline.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(baseline, with: .color(.secondary.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))

            // 波形
            let maxBarHeight = waveHeight * 0.92
            for (offset, level) in Self.levels.reversed().enumerated() {
                let x = playheadX - CGFloat(offset) * step - barWidth
                if x < -barWidth { break }
                let height = max(2, level * maxBarHeight)
                let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(.black))
            }

            // 再生ヘッド
            var head = Path()
            head.move(to: CGPoint(x: playheadX, y: waveTop - 4))
            head.addLine(to: CGPoint(x: playheadX, y: size.height))
            context.stroke(head, with: .color(.red), lineWidth: 2)
            context.fill(Path(ellipseIn: CGRect(x: playheadX - 5, y: waveTop - 9, width: 10, height: 10)), with: .color(.red))
        }
    }
}
#endif
