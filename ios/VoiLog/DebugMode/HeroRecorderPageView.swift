import SwiftUI

#if DEBUG
// MARK: - Hero (slot 0) page
//
// fastlane/hero_screenshot/compose.py の v5（白版）を SwiftUI で再現したもの。
// compose.py は 1320x2868px の実機キャプチャを合成しているので、ここでは 440x956pt（@3x）に換算して同じ位置に置く。
// - 薄いラベンダーのグラデーション (250,248,255) → (232,226,255)
// - 紫のピル（アプリ名）、2行の見出し（墨 + 紫アクセント）、3つのチップ
// - 録音中画面の端末モックと、その「録音中・タイマー・目盛り・波形」部分を拡大して紫枠で囲んだカード
// ja / en-US の出荷用ヒーローは実機キャプチャ版（承認済み）を使い、それ以外の言語でこのビューを使う。
struct HeroRecorderPageView: View {
    let language: AppLanguage

    static let canvasSize = CGSize(width: 440, height: 956)

    // compose.py の色
    static let ink = Color(red: 20 / 255, green: 18 / 255, blue: 40 / 255)
    static let purple = Color(red: 92 / 255, green: 60 / 255, blue: 230 / 255)
    private let gradientTop = Color(red: 250 / 255, green: 248 / 255, blue: 1)
    private let gradientBottom = Color(red: 232 / 255, green: 226 / 255, blue: 1)

    // compose.py の座標（px）を pt に換算した値
    private let phoneX: CGFloat = 184 / 3
    private let phoneY: CGFloat = 760 / 3
    private let screenWidth: CGFloat = 900 / 3
    private let bezel: CGFloat = 26 / 3
    private let phoneRadius: CGFloat = 120 / 3
    /// 拡大カードに切り出す録音画面の範囲（WAVE_BOX = (0, 480, 1320, 1590) px）
    private let cropTop: CGFloat = 480 / 3
    private let cropHeight: CGFloat = 1110 / 3
    private let cardX: CGFloat = 50 / 3
    private let cardY: CGFloat = 1110 / 3
    private let cardRadius: CGFloat = 48 / 3

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [gradientTop, gradientBottom], startPoint: .top, endPoint: .bottom)

            header
            phone
            zoomCard
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipped()
        // 端末とカードの配置は RTL でも左右対称のまま固定し、中身（文言・録音画面）だけ言語の向きにする
        .environment(\.layoutDirection, .leftToRight)
    }

    // MARK: Header (pill / headline / chips)

    private var header: some View {
        // 中心位置は compose.py の描画結果から換算（ピル 55.7pt / 見出し1 110.6pt / 見出し2 157pt / チップ 211.7pt）
        ZStack {
            Text(language.string("hero_pill"))
                .font(.system(size: 50 / 3, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 45 / 3)
                .frame(height: 94 / 3)
                .background(Capsule().fill(Self.purple))
                .frame(maxWidth: Self.canvasSize.width - 60)
                .position(x: Self.canvasSize.width / 2, y: 55.7)

            headline(language.string("hero_line1"), size: 40, maxWidth: 1180 / 3, color: Self.ink)
                .position(x: Self.canvasSize.width / 2, y: 110.6)

            headline(language.string("hero_line2"), size: 124 / 3, maxWidth: 1220 / 3, color: Self.purple)
                .position(x: Self.canvasSize.width / 2, y: 157)

            HeroChipsView(labels: language.strings("hero_chips"))
                .frame(maxWidth: Self.canvasSize.width - 140 / 3)
                .position(x: Self.canvasSize.width / 2, y: 211.7)
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .screenshotLanguage(language)
    }

    private func headline(_ text: String, size: CGFloat, maxWidth: CGFloat, color: Color) -> some View {
        Text(text)
            .font(.system(size: size, weight: language.heroHeadlineWeight))
            .foregroundColor(color)
            .lineLimit(1)
            // 長い言語（フィンランド語・マラヤーラム語など）は1行に収まるまで縮小する
            .minimumScaleFactor(0.4)
            .frame(maxWidth: maxWidth)
    }

    // MARK: Phone mock

    private var screenScale: CGFloat { screenWidth / Self.canvasSize.width }
    private var screenHeight: CGFloat { Self.canvasSize.height * screenScale }

    private var phone: some View {
        let phoneWidth = screenWidth + bezel * 2
        let phoneHeight = screenHeight + bezel * 2
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: phoneRadius)
                .fill(Color(red: 18 / 255, green: 18 / 255, blue: 22 / 255))
                .shadow(color: Color(red: 8 / 255, green: 4 / 255, blue: 30 / 255).opacity(120 / 255 * 0.9), radius: 50 / 3 / 1.6, y: 10)
            RoundedRectangle(cornerRadius: phoneRadius)
                .strokeBorder(Color(red: 70 / 255, green: 70 / 255, blue: 80 / 255), lineWidth: 4 / 3)

            HeroRecordingScreenMock(language: language)
                .screenshotLanguage(language)
                .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
                .scaleEffect(screenScale, anchor: .topLeading)
                .frame(width: screenWidth, height: screenHeight, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: phoneRadius - bezel))
                .offset(x: bezel, y: bezel)
        }
        .frame(width: phoneWidth, height: phoneHeight)
        .offset(x: phoneX, y: phoneY)
    }

    // MARK: Zoomed card

    private var cardWidth: CGFloat { Self.canvasSize.width - cardX * 2 }
    private var cardScale: CGFloat { cardWidth / Self.canvasSize.width }

    private var zoomCard: some View {
        let cardHeight = cropHeight * cardScale
        return HeroRecordingScreenMock(language: language)
            .screenshotLanguage(language)
            .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
            .offset(y: -cropTop)
            .frame(width: Self.canvasSize.width, height: cropHeight, alignment: .topLeading)
            .clipped()
            .scaleEffect(cardScale, anchor: .topLeading)
            .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cardRadius)
                    .strokeBorder(Self.purple, lineWidth: 8 / 3)
            )
            .background(
                RoundedRectangle(cornerRadius: cardRadius)
                    .fill(Color.white)
                    .shadow(color: Color(red: 8 / 255, green: 4 / 255, blue: 30 / 255).opacity(150 / 255 * 0.9), radius: 44 / 3 / 1.6, y: 8)
            )
            .offset(x: cardX, y: cardY)
    }
}

// MARK: - Chips
/// 3つのチップを1行に並べる。入らなければ少し縮小し、それでも入らなければ2段にする
struct HeroChipsView: View {
    let labels: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(labels, size: 40 / 3)
            row(labels, size: 34 / 3)
            twoRows(size: 40 / 3)
            twoRows(size: 34 / 3)
            twoRows(size: 30 / 3)
        }
    }

    private func twoRows(size: CGFloat) -> some View {
        VStack(spacing: 6) {
            row(Array(labels.prefix(2)), size: size)
            row(Array(labels.dropFirst(2)), size: size)
        }
    }

    private func row(_ items: [String], size: CGFloat) -> some View {
        HStack(spacing: 20 / 3) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundColor(HeroRecorderPageView.purple)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 28 / 3)
                    .frame(height: size + 12)
                    .background(Capsule().fill(Color.white))
            }
        }
        .fixedSize()
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
