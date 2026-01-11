//
//  AdDebugView.swift
//  VoiLog
//
//  Created by Claude on 2026.
//

import SwiftUI

#if DEBUG
struct AdDebugView: View {
    @State private var appUsageCount: Int = UserDefaults.standard.integer(forKey: "appUsageCount")

    var body: some View {
        List {
            Section(header: Text("起動回数")) {
                HStack {
                    Text("現在の起動回数")
                    Spacer()
                    Text("\(appUsageCount)")
                        .foregroundColor(.secondary)
                }

                Stepper("起動回数: \(appUsageCount)", value: $appUsageCount, in: 0...100)
                    .onChange(of: appUsageCount) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "appUsageCount")
                    }

                Text("5回に1回（5, 10, 15...回目）に広告表示")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("広告テスト")) {
                Button("App Open広告をプリロード") {
                    AppOpenAdManager.shared.preloadAd()
                }

                Button("App Open広告を表示（条件無視）") {
                    forceShowAppOpenAd()
                }
                .foregroundColor(.blue)

                Button("次回起動で広告表示（カウント調整）") {
                    let nextAdCount = ((appUsageCount / 5) + 1) * 5 - 1
                    appUsageCount = nextAdCount
                    UserDefaults.standard.set(nextAdCount, forKey: "appUsageCount")
                }
                .foregroundColor(.orange)
            }

            Section(header: Text("情報")) {
                HStack {
                    Text("次の広告表示")
                    Spacer()
                    let nextAd = ((appUsageCount / 5) + 1) * 5
                    Text("\(nextAd)回目の起動")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("プレミアムユーザー")
                    Spacer()
                    Text(UserDefaultsManager.shared.hasPurchasedProduct ? "はい" : "いいえ")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("広告テスト")
        .listStyle(GroupedListStyle())
    }

    private func forceShowAppOpenAd() {
        // プリロードされた広告があれば表示
        AppOpenAdManager.shared.showAdIfNeeded()
    }
}

#Preview {
    NavigationStack {
        AdDebugView()
    }
}
#endif
