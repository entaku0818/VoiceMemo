import SwiftUI
import UIKit

struct FirstRecordingCelebrationView: View {
    var onShare: () -> Void
    var onEditTitle: () -> Void
    var onRecordAgain: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // アイコン
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text(String(localized: "🎉 保存されました！"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(localized: "初めての録音が完了しました"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // アクションボタン
            VStack(spacing: 12) {
                Button(action: onEditTitle) {
                    HStack {
                        Image(systemName: "pencil")
                        Text(String(localized: "タイトルを編集する"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                Button(action: onShare) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(String(localized: "録音を共有する"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(uiColor: UIColor.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }

                Button(action: onRecordAgain) {
                    HStack {
                        Image(systemName: "mic.circle")
                        Text(String(localized: "もう一度録音する"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(uiColor: UIColor.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)

            Button(action: onDismiss) {
                Text(String(localized: "閉じる"))
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }

            Spacer()
        }
        .padding()
    }
}

#Preview {
    FirstRecordingCelebrationView(
        onShare: {},
        onEditTitle: {},
        onRecordAgain: {},
        onDismiss: {}
    )
}
