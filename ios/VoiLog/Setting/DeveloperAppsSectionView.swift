//
//  DeveloperAppsSectionView.swift
//  VoiLog
//

import SwiftUI
import UIKit

// MARK: - Constants

struct DeveloperAppItem: Identifiable {
    let id = UUID()
    let name: String      // localization key (Japanese fallback)
    let subtitle: String  // localization key (Japanese fallback)
    let appId: Int
}

private let developerApps: [DeveloperAppItem] = [
    .init(name: "シンプル文字起こし", subtitle: "音声文字起こし", appId: 6504149514),
    .init(name: "読み上げナレーター", subtitle: "テキスト読み上げ", appId: 6478449537),
    .init(name: "One Task Steps", subtitle: "シンプルタスク管理", appId: 6748559225),
    .init(name: "スマート動画プレイヤー", subtitle: "動画プレイヤー", appId: 6740053785),
    .init(name: "CountDown - イベントタイマー", subtitle: "カウントダウンタイマー", appId: 6745453926),
    .init(name: "レトロフォト - クラシック撮影", subtitle: "フィルム風カメラ", appId: 6468934085),
    .init(name: "Speedmeter - GPS速度計", subtitle: "スピードメーター", appId: 6756532069)
]

// MARK: - Section View

struct DeveloperAppsSectionView: View {
    var body: some View {
        Section(header: Text(String(localized: "開発者の他のアプリ"))) {
            ForEach(developerApps) { app in
                DeveloperAppRowView(app: app)
            }
        }
    }
}

// MARK: - Row View

private struct DeveloperAppRowView: View {
    let app: DeveloperAppItem

    @State private var artworkURL: URL?
    @State private var storeURL: URL?
    @State private var fetchedName: String?

    private var displayName: String {
        fetchedName ?? NSLocalizedString(app.name, comment: "")
    }

    var body: some View {
        Button {
            guard let url = storeURL else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(NSLocalizedString(app.subtitle, comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .task {
            await fetchAppInfo()
        }
    }

    private func fetchAppInfo() async {
        let locale = Locale.current.region?.identifier.lowercased() ?? "jp"
        if let result = await lookup(country: locale) {
            apply(result)
        } else if locale != "us", let result = await lookup(country: "us") {
            apply(result)
        }
    }

    private func lookup(country: String) async -> AppSearchResult? {
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(app.appId)&country=\(country)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(AppSearchResponse.self, from: data)
            return response.results.first
        } catch {
            return nil
        }
    }

    private func apply(_ result: AppSearchResult) {
        artworkURL = URL(string: result.artworkUrl100)
        storeURL = URL(string: result.trackViewUrl)
        fetchedName = result.trackName
    }
}

// MARK: - iTunes Search API Models

private struct AppSearchResponse: Decodable {
    let results: [AppSearchResult]
}

private struct AppSearchResult: Decodable {
    let artworkUrl100: String
    let trackViewUrl: String
    let trackName: String
    let description: String?
}

// MARK: - Preview

#Preview {
    NavigationView {
        List {
            DeveloperAppsSectionView()
        }
        .listStyle(.grouped)
    }
}
