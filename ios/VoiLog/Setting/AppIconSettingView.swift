//
//  AppIconSettingView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2026.05.25.
//

import SwiftUI
import ComposableArchitecture

// MARK: - AppIconSettingView

struct AppIconSettingView: View {
    @Perception.Bindable var store: StoreOf<AppIconFeature>

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(AppIconFeature.AppIcon.allCases) { icon in
                        iconCell(icon)
                    }
                }
                .padding(.vertical, 12)
            }

            if !store.hasPurchasedPremium {
                Section {
                    NavigationLink(destination: PaywallView(purchaseManager: PurchaseManager.shared)) {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "プレミアムにアップグレード"))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text(String(localized: "全カラーバリエーションを解放"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let errorMessage = store.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(String(localized: "アイコンカスタマイズ"))
        .listStyle(.grouped)
        .onAppear { store.send(.onAppear) }
        .overlay {
            if store.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private func iconCell(_ icon: AppIconFeature.AppIcon) -> some View {
        let isSelected = store.selectedIcon == icon
        let isLocked = icon.isPremium && !store.hasPurchasedPremium

        Button {
            store.send(.selectIcon(icon))
        } label: {
            iconCellContent(icon: icon, isSelected: isSelected, isLocked: isLocked)
        }
        .buttonStyle(.plain)
        .disabled(store.isLoading || isLocked)
    }

    @ViewBuilder
    private func iconCellContent(icon: AppIconFeature.AppIcon, isSelected: Bool, isLocked: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                // 実際のアイコン画像
                Image(icon.rawValue)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                // ロック中はアイコンを暗く表示
                if isLocked {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.black.opacity(0.4))
                        .frame(width: 76, height: 76)
                }

                // 選択済みインジケーター
                if isSelected {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.primary, lineWidth: 3)
                        .frame(width: 76, height: 76)

                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.primary, Color(uiColor: .systemBackground))
                                .font(.system(size: 20))
                                .padding(3)
                        }
                        Spacer()
                    }
                    .frame(width: 76, height: 76)
                }
            }

            Text(icon.displayName)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isLocked ? .secondary : .primary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        AppIconSettingView(
            store: Store(
                initialState: AppIconFeature.State(hasPurchasedPremium: false)
            ) {
                AppIconFeature()
            } withDependencies: {
                $0.uiApplicationIconClient = .init(
                    setAlternateIconName: { _ in },
                    currentAlternateIconName: { nil }
                )
            }
        )
    }
}

#Preview("Premium User") {
    NavigationView {
        AppIconSettingView(
            store: Store(
                initialState: AppIconFeature.State(hasPurchasedPremium: true)
            ) {
                AppIconFeature()
            } withDependencies: {
                $0.uiApplicationIconClient = .init(
                    setAlternateIconName: { _ in },
                    currentAlternateIconName: { "AppIcon_Blue" }
                )
            }
        )
    }
}
