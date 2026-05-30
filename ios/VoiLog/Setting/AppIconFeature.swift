//
//  AppIconFeature.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2026.05.25.
//

import SwiftUI
import ComposableArchitecture
import UIKit

// MARK: - UIApplicationIconClient Dependency

struct UIApplicationIconClient: Sendable {
    var setAlternateIconName: @Sendable (String?) async throws -> Void
    var currentAlternateIconName: @Sendable () -> String?
}

extension UIApplicationIconClient: DependencyKey {
    static var liveValue: UIApplicationIconClient {
        .init(
            setAlternateIconName: { name in
                try await UIApplication.shared.setAlternateIconName(name)
            },
            currentAlternateIconName: {
                UIApplication.shared.alternateIconName
            }
        )
    }

    static var testValue: UIApplicationIconClient {
        .init(
            setAlternateIconName: { _ in },
            currentAlternateIconName: { nil }
        )
    }
}

extension DependencyValues {
    var uiApplicationIconClient: UIApplicationIconClient {
        get { self[UIApplicationIconClient.self] }
        set { self[UIApplicationIconClient.self] = newValue }
    }
}

// MARK: - AppIconFeature

@Reducer
struct AppIconFeature {

    // MARK: - AppIcon

    enum AppIcon: String, CaseIterable, Identifiable {
        case `default` = "AppIcon"
        case blue = "AppIcon_Blue"
        case red = "AppIcon_Red"
        case green = "AppIcon_Green"
        case purple = "AppIcon_Purple"
        case orange = "AppIcon_Orange"
        case pink = "AppIcon_Pink"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .default: return String(localized: "デフォルト")
            case .blue: return String(localized: "ブルー")
            case .red: return String(localized: "レッド")
            case .green: return String(localized: "グリーン")
            case .purple: return String(localized: "パープル")
            case .orange: return String(localized: "オレンジ")
            case .pink: return String(localized: "ピンク")
            }
        }

        var iconColor: Color {
            switch self {
            case .default: return Color.primary                        // 黒(ライト) / 白(ダーク)
            case .blue:    return Color("AppIconColorBlue")            // #0066CC / #3399FF
            case .red:     return Color("AppIconColorRed")             // #CC0000 / #FF3333
            case .green:   return Color("AppIconColorGreen")           // #009944 / #33CC66
            case .purple:  return Color("AppIconColorPurple")          // #6600CC / #9933FF
            case .orange:  return Color("AppIconColorOrange")          // #FF6600 / #FF9933
            case .pink:    return Color("AppIconColorPink")            // #CC0066 / #FF3399
            }
        }

        /// デフォルト以外はプレミアム限定
        var isPremium: Bool { self != .default }

        var previewImageName: String { "AppIconPreview\(self == .default ? "" : rawValue.replacingOccurrences(of: "AppIcon", with: ""))" }

        /// UIApplication.setAlternateIconName に渡す名前（デフォルトは nil）
        var alternateIconName: String? { self == .default ? nil : rawValue }
    }

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var selectedIcon: AppIcon = .default
        var hasPurchasedPremium: Bool
        var isLoading = false
        var errorMessage: String?

        init(hasPurchasedPremium: Bool = UserDefaultsManager.shared.hasPurchasedProduct) {
            self.hasPurchasedPremium = hasPurchasedPremium
        }
    }

    // MARK: - Action

    enum Action: Equatable {
        case onAppear
        case selectIcon(AppIcon)
        case iconChangeCompleted(AppIcon)
        case iconChangeFailed(String)
    }

    // MARK: - Dependencies

    @Dependency(\.uiApplicationIconClient) var iconClient

    // MARK: - Body

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.hasPurchasedPremium = UserDefaultsManager.shared.hasPurchasedProduct
                let currentIconName = iconClient.currentAlternateIconName()
                if let iconName = currentIconName, let icon = AppIcon(rawValue: iconName) {
                    state.selectedIcon = icon
                } else {
                    state.selectedIcon = .default
                }
                return .none

            case let .selectIcon(icon):
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        try await iconClient.setAlternateIconName(icon.alternateIconName)
                        await send(.iconChangeCompleted(icon))
                    } catch {
                        await send(.iconChangeFailed(error.localizedDescription))
                    }
                }

            case let .iconChangeCompleted(icon):
                state.isLoading = false
                state.selectedIcon = icon
                return .none

            case let .iconChangeFailed(message):
                state.isLoading = false
                state.errorMessage = message
                return .none
            }
        }
    }
}
