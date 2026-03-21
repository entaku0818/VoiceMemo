//
//  DeveloperAppsSectionView.swift
//  VoiLog
//

import SwiftUI
import UIKit

// MARK: - Constants

struct DeveloperAppItem: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let searchTerm: String
}

private let developerApps: [DeveloperAppItem] = [
    .init(name: "Speedmeter - GPS速度計", subtitle: "スピードメーター", searchTerm: "Speedmeter GPS速度計"),
    .init(name: "One Task Steps", subtitle: "シンプルタスク管理", searchTerm: "One Task Steps"),
    .init(name: "CountDown - イベントタイマー", subtitle: "カウントダウンタイマー", searchTerm: "CountDown イベントタイマー"),
    .init(name: "スマート動画プレイヤー", subtitle: "動画プレイヤー", searchTerm: "スマート動画プレイヤー"),
    .init(name: "シンプル文字起こし", subtitle: "音声文字起こし", searchTerm: "シンプル文字起こし"),
    .init(name: "読み上げナレーター", subtitle: "テキスト読み上げ", searchTerm: "読み上げナレーター"),
    .init(name: "レトロフォト - クラシック撮影", subtitle: "フィルム風カメラ", searchTerm: "レトロフォト クラシック撮影")
]

// MARK: - Section View

struct DeveloperAppsSectionView: View {
    var body: some View {
        Section(header: Text("開発者の他のアプリ")) {
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
                    Text(app.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(app.subtitle)
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
        guard
            let encoded = app.searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let searchURL = URL(string: "https://itunes.apple.com/search?term=\(encoded)&country=jp&media=software&limit=1")
        else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: searchURL)
            let response = try JSONDecoder().decode(AppSearchResponse.self, from: data)
            if let result = response.results.first {
                artworkURL = URL(string: result.artworkUrl100)
                storeURL = URL(string: result.trackViewUrl)
            }
        } catch {
            // アイコン取得失敗時はプレースホルダーのまま表示
        }
    }
}

// MARK: - iTunes Search API Models

private struct AppSearchResponse: Decodable {
    let results: [AppSearchResult]
}

private struct AppSearchResult: Decodable {
    let artworkUrl100: String
    let trackViewUrl: String
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
