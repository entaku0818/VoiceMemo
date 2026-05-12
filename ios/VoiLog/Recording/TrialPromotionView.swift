import SwiftUI

struct TrialPromotionView: View {
    var onStartTrial: () -> Void
    var onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // バッジアイコン
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)

                VStack(spacing: 2) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    Text("10")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 20)

            // タイトル
            Text(String(localized: "10回録音達成！", table: "Recording"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Text(String(localized: "プレミアムで録音をもっと活用しませんか？", table: "Recording"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

            // 特典リスト
            VStack(spacing: 16) {
                benefitRow(icon: "rectangle.slash", text: String(localized: "広告なしで快適に録音・再生", table: "Recording"))
                benefitRow(icon: "icloud.and.arrow.up", text: String(localized: "iCloud同期で複数デバイスに対応", table: "Recording"))
                benefitRow(icon: "waveform", text: String(localized: "音声の分割編集が使い放題", table: "Recording"))
                benefitRow(icon: "music.note.list", text: String(localized: "プレイリストを無制限に作成", table: "Recording"))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)

            // 無料トライアルボタン
            Button(action: onStartTrial) {
                VStack(spacing: 4) {
                    Text(String(localized: "1ヶ月無料で試す", table: "Recording"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(String(localized: "いつでもキャンセル可能", table: "Recording"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // 閉じるボタン
            Button(action: onDismiss) {
                Text(String(localized: "今はしない", table: "Recording"))
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)

            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 28)

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white : .primary)

            Spacer()
        }
    }
}

#Preview("Light") {
    TrialPromotionView(onStartTrial: {}, onDismiss: {})
}

#Preview("Dark") {
    TrialPromotionView(onStartTrial: {}, onDismiss: {})
        .preferredColorScheme(.dark)
}
