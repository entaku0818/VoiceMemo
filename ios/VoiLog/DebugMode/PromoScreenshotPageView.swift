import SwiftUI

#if DEBUG
// MARK: - Promo page (App Store screenshot layout shared by every slot)
//
// 承認済みの1枚目（HeroRecorderPageView / fastlane/hero_screenshot/compose.py）のデザインを全ページで共通化したもの。
// - 白 → 下だけ薄いラベンダーのグラデーション背景
// - 紫のピル（アプリ名）、2行の見出し（1行目は墨・2行目は紫）、白い角丸の機能チップ3つ
// - 黒い端末フレームに実画面のモック
// - 画面の主役部分を拡大し、端末からはみ出す紫枠のカードで強調する
// iPhone（440x956pt @3x = 1320x2868px）と iPad（1024x1366pt @2x = 2048x2732px）で同じ構成にする。

enum PromoStyle {
    // compose.py の色
    static let ink = Color(red: 20 / 255, green: 18 / 255, blue: 40 / 255)
    static let purple = Color(red: 92 / 255, green: 60 / 255, blue: 230 / 255)
    static let gradientTop = Color(red: 250 / 255, green: 248 / 255, blue: 1)
    static let gradientBottom = Color(red: 232 / 255, green: 226 / 255, blue: 1)
    static let frameFill = Color(red: 18 / 255, green: 18 / 255, blue: 22 / 255)
    static let frameStroke = Color(red: 70 / 255, green: 70 / 255, blue: 80 / 255)
    static let shadow = Color(red: 8 / 255, green: 4 / 255, blue: 30 / 255)
}

/// 端末ごとの寸法。iPhone の値は承認済みヒーロー（compose.py の px を 1/3 した pt）そのもの
struct PromoMetrics {
    let canvasSize: CGSize
    /// ヘッダー（ピル・見出し・チップ）の拡大率。iPhone = 1
    let headerScale: CGFloat
    let pillY: CGFloat
    let line1Y: CGFloat
    let line2Y: CGFloat
    let chipsY: CGFloat
    let line1MaxWidth: CGFloat
    let line2MaxWidth: CGFloat
    let chipsMaxWidth: CGFloat
    /// 端末フレームの左上と画面幅
    let deviceOrigin: CGPoint
    let screenWidth: CGFloat
    let bezel: CGFloat
    let deviceRadius: CGFloat
    let screenRadius: CGFloat
    /// 拡大カード
    let cardInset: CGFloat
    let cardRadius: CGFloat
    let cardBorder: CGFloat
    /// カードの上端をこの範囲に収める（端末内の画面タイトルを隠さず、キャンバスからはみ出さない）
    let cardMinY: CGFloat
    let cardBottomMargin: CGFloat

    var cardWidth: CGFloat { canvasSize.width - cardInset * 2 }

    static let iPhone = PromoMetrics(
        canvasSize: CGSize(width: 440, height: 956),
        headerScale: 1,
        pillY: 55.7,
        line1Y: 110.6,
        line2Y: 157,
        chipsY: 211.7,
        line1MaxWidth: 1180 / 3,
        line2MaxWidth: 1220 / 3,
        chipsMaxWidth: 440 - 140 / 3,
        deviceOrigin: CGPoint(x: 184 / 3, y: 760 / 3),
        screenWidth: 900 / 3,
        bezel: 26 / 3,
        deviceRadius: 120 / 3,
        screenRadius: 120 / 3 - 26 / 3,
        cardInset: 50 / 3,
        cardRadius: 48 / 3,
        cardBorder: 8 / 3,
        cardMinY: 372,
        cardBottomMargin: 16
    )

    static let iPad = PromoMetrics(
        canvasSize: CGSize(width: 1024, height: 1366),
        headerScale: 1.8,
        pillY: 100,
        line1Y: 199,
        line2Y: 283,
        chipsY: 381,
        line1MaxWidth: 900,
        line2MaxWidth: 920,
        chipsMaxWidth: 940,
        deviceOrigin: CGPoint(x: (1024 - 628) / 2, y: 440),
        screenWidth: 600,
        bezel: 14,
        deviceRadius: 44,
        screenRadius: 32,
        cardInset: 110,
        cardRadius: 28,
        cardBorder: 5,
        cardMinY: 560,
        cardBottomMargin: 30
    )
}

// MARK: - Background

struct PromoBackground: View {
    var body: some View {
        LinearGradient(colors: [PromoStyle.gradientTop, PromoStyle.gradientBottom], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Header (pill / 2-line headline / chips)

struct PromoHeaderView: View {
    let language: AppLanguage
    let pill: String
    let line1: String
    let line2: String
    let chips: [String]
    var metrics: PromoMetrics = .iPhone

    private var scale: CGFloat { metrics.headerScale }
    private var centerX: CGFloat { metrics.canvasSize.width / 2 }

    var body: some View {
        ZStack {
            Text(pill)
                .font(.system(size: 50 / 3 * scale, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 45 / 3 * scale)
                .frame(height: 94 / 3 * scale)
                .background(Capsule().fill(PromoStyle.purple))
                .frame(maxWidth: metrics.canvasSize.width - 60 * scale)
                .position(x: centerX, y: metrics.pillY)

            headline(line1, size: 40 * scale, maxWidth: metrics.line1MaxWidth, color: PromoStyle.ink)
                .position(x: centerX, y: metrics.line1Y)

            headline(line2, size: 124 / 3 * scale, maxWidth: metrics.line2MaxWidth, color: PromoStyle.purple)
                .position(x: centerX, y: metrics.line2Y)

            HeroChipsView(labels: chips, scale: scale)
                .frame(maxWidth: metrics.chipsMaxWidth)
                .position(x: centerX, y: metrics.chipsY)
        }
        .frame(width: metrics.canvasSize.width, height: metrics.canvasSize.height)
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
}

// MARK: - Chips
/// 3つのチップを1行に並べる。入らなければ少し縮小し、それでも入らなければ2段にする
struct HeroChipsView: View {
    let labels: [String]
    var scale: CGFloat = 1

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(labels, size: 40 / 3 * scale)
            row(labels, size: 34 / 3 * scale)
            twoRows(size: 40 / 3 * scale)
            twoRows(size: 34 / 3 * scale)
            twoRows(size: 30 / 3 * scale)
        }
    }

    private func twoRows(size: CGFloat) -> some View {
        VStack(spacing: 6 * scale) {
            row(Array(labels.prefix(2)), size: size)
            row(Array(labels.dropFirst(2)), size: size)
        }
    }

    private func row(_ items: [String], size: CGFloat) -> some View {
        HStack(spacing: 20 / 3 * scale) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundColor(PromoStyle.purple)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 28 / 3 * scale)
                    .frame(height: size + 12 * scale)
                    .background(Capsule().fill(Color.white))
            }
        }
        .fixedSize()
    }
}

// MARK: - Device frame (black bezel)

/// 黒い端末フレーム。`content` は画面サイズ（screenSize）で描かれたものを渡す
struct PromoDeviceFrame<Content: View>: View {
    let screenSize: CGSize
    let bezel: CGFloat
    let radius: CGFloat
    let screenRadius: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: radius)
                .fill(PromoStyle.frameFill)
                .shadow(color: PromoStyle.shadow.opacity(120 / 255 * 0.9), radius: 50 / 3 / 1.6, y: 10)
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(PromoStyle.frameStroke, lineWidth: 4 / 3)

            content()
                .frame(width: screenSize.width, height: screenSize.height, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: screenRadius))
                .offset(x: bezel, y: bezel)
        }
        .frame(width: screenSize.width + bezel * 2, height: screenSize.height + bezel * 2)
    }
}

// MARK: - Focus card (zoomed part of the screen, sticking out of the device)

extension View {
    /// 白い角丸・紫の枠線・影のカードにする（承認済みヒーローの拡大カードと同じ見た目）
    func promoFocusCard(radius: CGFloat, border: CGFloat) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(PromoStyle.purple, lineWidth: border)
            )
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(Color.white)
                    .shadow(color: PromoStyle.shadow.opacity(150 / 255 * 0.9), radius: 44 / 3 / 1.6, y: 8)
            )
    }
}

// MARK: - Screen slots

enum PromoDevice {
    case iPhone
    case iPad

    var metrics: PromoMetrics {
        switch self {
        case .iPhone: .iPhone
        case .iPad: .iPad
        }
    }

    /// モック画面の設計サイズ（旧 PhoneFrameView / IPadFrameView と同じ）
    var designSize: CGSize {
        switch self {
        case .iPhone: CGSize(width: 390, height: 844)
        case .iPad: CGSize(width: 820, height: 1180)
        }
    }

    /// 拡大カードの中でモックを描く幅。iPad は横長のままだと拡大しても余白ばかりになるので、
    /// 幅を詰めて描き直し（中身は同じ画面）、iPhone と同じくらいの拡大率にする
    var cardDesignSize: CGSize {
        switch self {
        case .iPhone: designSize
        case .iPad: CGSize(width: 560, height: designSize.height)
        }
    }
}

extension ScreenshotScreen {
    /// 拡大カードに切り出す範囲（モックの設計座標の y 範囲。横は全幅）
    func focusRange(on device: PromoDevice) -> ClosedRange<CGFloat> {
        switch (self, device) {
        case (.aiRecording, .iPhone): 140...330
        case (.aiRecording, .iPad): 140...300
        case (.playbackList, .iPhone): 640...830
        case (.playbackList, .iPad): 976...1166
        case (.useCase, .iPhone): 150...470
        case (.useCase, .iPad): 150...480
        case (.waveformEditor, .iPhone): 100...420
        case (.waveformEditor, .iPad): 100...420
        case (.backgroundRecording, .iPhone): 720...820
        case (.backgroundRecording, .iPad): 1056...1156
        case (.playlist, .iPhone): 140...420
        case (.playlist, .iPad): 140...420
        case (.timestampedTranscription, .iPhone): 140...460
        case (.timestampedTranscription, .iPad): 140...400
        case (.aiTranscription, .iPhone): 158...470
        case (.aiTranscription, .iPad): 158...480
        case (.shareSheet, .iPhone): 440...700
        case (.shareSheet, .iPad): 776...1036
        case (.premium, .iPhone): 330...560
        case (.premium, .iPad): 330...560
        }
    }

    /// ロック画面・プレミアムのように背景が暗い画面はステータスバーを白にする
    var hasDarkStatusBarBackground: Bool {
        self == .backgroundRecording || self == .premium
    }
}

/// モック画面 + ステータスバーを設計サイズで描く
struct PromoScreenContent: View {
    let screen: ScreenshotScreen
    let language: AppLanguage
    let device: PromoDevice
    var size: CGSize

    init(screen: ScreenshotScreen, language: AppLanguage, device: PromoDevice, size: CGSize? = nil) {
        self.screen = screen
        self.language = language
        self.device = device
        self.size = size ?? device.designSize
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            screen.mockView(language: language)
                .preferredColorScheme(.light)
                .frame(width: size.width, height: size.height)
            PromoStatusBar(device: device, width: size.width, light: screen.hasDarkStatusBarBackground)
        }
        .frame(width: size.width, height: size.height)
        .screenshotLanguage(language)
    }
}

struct PromoStatusBar: View {
    let device: PromoDevice
    let width: CGFloat
    let light: Bool

    var body: some View {
        HStack {
            Text("9:41")
                .font(.system(size: device == .iPhone ? 16 : 14, weight: .semibold))
                .frame(width: 64)
            Spacer()
            HStack(spacing: 6) {
                if device == .iPhone {
                    Image(systemName: "cellularbars")
                }
                Image(systemName: "wifi")
                Image(systemName: "battery.100percent")
            }
            .font(.system(size: device == .iPhone ? 14 : 13, weight: .semibold))
        }
        .foregroundColor(light ? .white : .black)
        .padding(.horizontal, device == .iPhone ? 22 : 16)
        .frame(width: width, height: device == .iPhone ? 54 : 30)
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// App Store 用スクリーンショット1枚（ヒーロー以外）
struct PromoScreenshotPageView: View {
    let screen: ScreenshotScreen
    let language: AppLanguage
    var device: PromoDevice = .iPhone

    private var metrics: PromoMetrics { device.metrics }
    private var designSize: CGSize { device.designSize }
    private var screenScale: CGFloat { metrics.screenWidth / designSize.width }
    private var screenSize: CGSize { CGSize(width: metrics.screenWidth, height: designSize.height * screenScale) }
    private var cardDesignSize: CGSize { device.cardDesignSize }
    private var cardScale: CGFloat { metrics.cardWidth / cardDesignSize.width }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PromoBackground()

            PromoHeaderView(
                language: language,
                pill: language.string("hero_pill"),
                line1: language.string("promo_\(screen.rawValue)_line1"),
                line2: language.string("promo_\(screen.rawValue)_line2"),
                chips: language.strings("promo_\(screen.rawValue)_chips"),
                metrics: metrics
            )

            PromoDeviceFrame(
                screenSize: screenSize,
                bezel: metrics.bezel,
                radius: metrics.deviceRadius,
                screenRadius: metrics.screenRadius
            ) {
                PromoScreenContent(screen: screen, language: language, device: device)
                    .scaleEffect(screenScale, anchor: .topLeading)
            }
            .offset(x: metrics.deviceOrigin.x, y: metrics.deviceOrigin.y)

            focusCard
        }
        .frame(width: metrics.canvasSize.width, height: metrics.canvasSize.height)
        .clipped()
        // 端末とカードの配置は RTL でも左右対称のまま固定し、中身（文言・画面）だけ言語の向きにする
        .environment(\.layoutDirection, .leftToRight)
    }

    private var focusCard: some View {
        let range = screen.focusRange(on: device)
        let cropHeight = range.upperBound - range.lowerBound
        let cardHeight = cropHeight * cardScale
        // 端末内の切り出し位置の中心にカードの中心を合わせ、ヘッダーとキャンバス下端の間に収める
        let cropCenterOnCanvas = metrics.deviceOrigin.y + metrics.bezel + (range.lowerBound + cropHeight / 2) * screenScale
        let maxY = metrics.canvasSize.height - metrics.cardBottomMargin - cardHeight
        let cardY = min(max(cropCenterOnCanvas - cardHeight / 2, metrics.cardMinY), maxY)

        return PromoScreenContent(screen: screen, language: language, device: device, size: cardDesignSize)
            .offset(y: -range.lowerBound)
            .frame(width: cardDesignSize.width, height: cropHeight, alignment: .topLeading)
            .clipped()
            .scaleEffect(cardScale, anchor: .topLeading)
            .frame(width: metrics.cardWidth, height: cardHeight, alignment: .topLeading)
            .promoFocusCard(radius: metrics.cardRadius, border: metrics.cardBorder)
            .offset(x: metrics.cardInset, y: cardY)
    }
}

#Preview("Promo pages (JA)") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(ScreenshotSlots.iPhone, id: \.self) { screen in
                PromoScreenshotPageView(screen: screen, language: .japanese)
            }
        }
    }
}

#Preview("Promo page iPad (EN)") {
    PromoScreenshotPageView(screen: .playbackList, language: .english, device: .iPad)
}
#endif
