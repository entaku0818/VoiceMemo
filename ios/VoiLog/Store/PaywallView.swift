import SwiftUI
import RevenueCat
import Dependencies

struct PaywallView: View {
    @State private var productName: String = ""
    @State private var productPrice: String = ""
    @State private var annualPrice: String = ""
    @State private var isAnnualSelected = true
    @State private var showAlert = false
    @State private var alertMessage: String = ""
    @State private var offering: Offering?
    @State private var purchaseCompleted = false

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @Dependency(\.firebaseAnalytics) var analytics

    var purchaseManager: PurchaseManagerProtocol

    init(purchaseManager: PurchaseManagerProtocol) {
        self.purchaseManager = purchaseManager
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ヘッダー部分をよりモダンなデザインに
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    VStack(alignment: .center, spacing: 12) {
                        Text("Premium")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(String(localized: "AI文字起こしを使いこなす", table: "Premium"))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 4)

                        if isAnnualSelected {
                            Text(annualPrice.isEmpty ? "" : "\(annualPrice)/年")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        } else {
                            Text(String(localized: "7日間無料体験 → その後\(productPrice.isEmpty ? "" : " \(productPrice)")/月", table: "Premium"))
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 30)
                }
                .padding(.top, 20)

                // プレミアム機能のヘッダー
                HStack {
                    Spacer()
                    Image(systemName: "crown.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.yellow)

                    Text(String(localized: "プレミアム特典", table: "Premium"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    Spacer()
                }
                .padding(.vertical, 20)

                // プラン選択
                HStack(spacing: 12) {
                    planButton(
                        title: String(localized: "年額", table: "Premium"),
                        price: annualPrice.isEmpty ? "-" : annualPrice,
                        unit: String(localized: "/ 年", table: "Premium"),
                        badge: String(localized: "お得", table: "Premium"),
                        isSelected: isAnnualSelected
                    ) {
                        isAnnualSelected = true
                    }
                    planButton(
                        title: String(localized: "月額", table: "Premium"),
                        price: productPrice.isEmpty ? "-" : productPrice,
                        unit: String(localized: "/ 月", table: "Premium"),
                        badge: nil,
                        isSelected: !isAnnualSelected
                    ) {
                        isAnnualSelected = false
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // 機能リスト
                VStack(spacing: 24) {
                    // AI文字起こし機能
                    featureRow(
                        systemName: "sparkles",
                        title: String(localized: "AI文字起こし無制限", table: "Premium"),
                        description: String(localized: "高精度なAI文字起こしが無制限で使い放題！", table: "Premium"),
                        systemImage: true
                    )

                    // 広告非表示機能
                    featureRow(
                        systemName: "rectangle.slash",
                        title: String(localized: "広告なしの使用体験", table: "Premium"),
                        description: String(localized: "全ての広告が非表示に！", table: "Premium"),
                        systemImage: true
                    )

                    // iCloud同期機能
                    featureRow(
                        systemName: "icloud.and.arrow.up",
                        title: String(localized: "iCloud同期機能", table: "Premium"),
                        description: String(localized: "すべてのデータがiCloudで同期され、複数デバイスでの使用が可能に！", table: "Premium"),
                        systemImage: true
                    )

                    // 音声編集機能
                    featureRow(
                        systemName: "waveform",
                        title: String(localized: "音声編集機能", table: "Premium"),
                        description: String(localized: "音声の分割編集ができ、使いやすく整理できます！", table: "Premium"),
                        systemImage: true
                    )

                    // プレイリスト機能
                    featureRow(
                        systemName: "music.note.list",
                        title: String(localized: "プレイリストを無制限に作成", table: "Premium"),
                        description: String(localized: "通常3つまでのプレイリストを好きなだけ作成して、音声を整理できます！", table: "Premium"),
                        systemImage: true
                    )

                    // アイコンカスタマイズ機能
                    featureRow(
                        systemName: "app.badge",
                        title: String(localized: "アイコンカスタマイズ", table: "Premium"),
                        description: String(localized: "6色のカラーバリエーションからお気に入りのアイコンに変更できます！", table: "Premium"),
                        systemImage: true
                    )

                }
                .padding(.horizontal)

                Spacer().frame(minHeight: 30)

                // 購入ボタン
                Button(action: {
                    Task {
                        await purchaseProduct()
                    }
                }) {
                    VStack(spacing: 4) {
                        if isAnnualSelected {
                            Text(String(localized: "年額プランを始める", table: "Premium"))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("\(annualPrice)\(String(localized: "年（自動更新）", table: "Premium"))")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        } else {
                            Text(String(localized: "7日間無料で試す", table: "Premium"))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("その後 \(productPrice)\(String(localized: "月（自動更新）", table: "Premium"))")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
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
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // サブスクリプション条件の説明（Guideline 3.1.2 対応）
                Text(isAnnualSelected
                     ? String(localized: "\(annualPrice.isEmpty ? String(localized: "サブスクリプション料金", table: "Premium") : annualPrice)/年で自動的に課金されます。更新日の24時間前までにAppleのサブスクリプション設定からいつでもキャンセルできます。", table: "Premium")
                     : String(localized: "7日間の無料トライアル終了後、\(productPrice.isEmpty ? String(localized: "サブスクリプション料金", table: "Premium") : productPrice)/月で自動的に課金されます。更新日の24時間前までにAppleのサブスクリプション設定からいつでもキャンセルできます。", table: "Premium"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                // リストアボタン
                Button(String(localized: "リストア購入", table: "Premium")) {
                    Task {
                        await restorePurchases()
                    }
                }
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.top, 12)

                // フッター
                VStack(alignment: .center) {
                    HStack(alignment: .center, spacing: 20) {
                        Spacer()
                        Link(String(localized: "利用規約", table: "Premium"), destination: URL(string: "https://voilog.web.app/terms_of_service.html")!)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.blue)
                        Link(String(localized: "プライバシーポリシー", table: "Premium"), destination: URL(string: "https://voilog.web.app/privacy_policy.html")!)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
                .padding(.vertical, 20)

                Spacer()
            }
            .onAppear {
                // PaywallViewが表示されたことをAnalyticsに記録
                analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallViewed, [
                    "timestamp": Date().timeIntervalSince1970,
                    "source": "paywall_view"
                ])

                Task {
                    await fetchProductInfo()
                }
            }
            .onDisappear {
                // 購入完了によるdismissはdismissedとして記録しない
                guard !purchaseCompleted else { return }
                analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallDismissed, [
                    "timestamp": Date().timeIntervalSince1970
                ])
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(""), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    // RevenueCat用の商品情報取得処理
    func fetchProductInfo() async {
        async let monthly = purchaseManager.fetchProPlan()
        async let annual = purchaseManager.fetchAnnualPlan()
        do {
            let (name, price) = try await monthly
            await MainActor.run {
                productName = name
                productPrice = price
            }
        } catch {
            await MainActor.run {
                productPrice = ""
            }
        }
        do {
            let (_, price) = try await annual
            await MainActor.run {
                annualPrice = price
            }
        } catch {
            await MainActor.run {
                annualPrice = ""
                if productPrice.isEmpty {
                    showAlert = true
                    alertMessage = String(localized: "製品情報の取得に失敗しました", table: "Premium")
                }
            }
        }
    }

    // RevenueCat用の購入処理
    func purchaseProduct() async {
        let name = productName
        let price = isAnnualSelected ? annualPrice : productPrice

        await MainActor.run {
            analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallPurchaseAttempted, [
                "product_name": name,
                "product_price": price,
                "timestamp": Date().timeIntervalSince1970
            ])
        }

        do {
            if isAnnualSelected {
                try await purchaseManager.purchaseAnnual()
            } else {
                try await purchaseManager.purchasePro()
            }

            await MainActor.run {
                analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallPurchaseCompleted, [
                    "product_name": name,
                    "product_price": price,
                    "timestamp": Date().timeIntervalSince1970
                ])
                purchaseCompleted = true
                alertMessage = String(localized: "購入が完了しました！", table: "Premium")
                showAlert = true
                presentationMode.wrappedValue.dismiss()
            }
        } catch {
            let isCancelled = (error as? ErrorCode) == .purchaseCancelledError
            await MainActor.run {
                if isCancelled {
                    analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallPurchaseCancelled, [
                        "product_name": name,
                        "product_price": price,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                } else {
                    analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallPurchaseFailed, [
                        "product_name": name,
                        "product_price": price,
                        "error": error.localizedDescription,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                    alertMessage = String(localized: "購入に失敗しました", table: "Premium")
                    showAlert = true
                }
            }
        }
    }

    // RevenueCat用のリストア処理
    func restorePurchases() async {
        await MainActor.run {
            analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallRestoreAttempted, [
                "timestamp": Date().timeIntervalSince1970
            ])
        }

        do {
            try await purchaseManager.restorePurchases()

            await MainActor.run {
                analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallRestoreCompleted, [
                    "timestamp": Date().timeIntervalSince1970
                ])
                purchaseCompleted = true
                alertMessage = String(localized: "購入情報が復元しました！", table: "Premium")
                showAlert = true
                presentationMode.wrappedValue.dismiss()
            }
        } catch {
            await MainActor.run {
                analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallRestoreFailed, [
                    "error": error.localizedDescription,
                    "timestamp": Date().timeIntervalSince1970
                ])
                alertMessage = String(localized: "リストアに失敗しました", table: "Premium")
                showAlert = true
            }
        }
    }

    // プラン選択ボタン
    @ViewBuilder
    private func planButton(title: String, price: String, unit: String, badge: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(8)
                } else {
                    Spacer().frame(height: 18)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .black))
                Text(price)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .black))
                Text(unit)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected
                        ? LinearGradient(colors: [Color.blue, Color.purple.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // 機能行の共通コンポーネント
    @ViewBuilder
    private func featureRow(image: Image? = nil, systemName: String? = nil, title: String, description: String, systemImage: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)

                if systemImage, let systemName = systemName {
                    Image(systemName: systemName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(Color.blue)
                } else if let image = image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Text(description)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PaywallView(purchaseManager: MockPurchaseManager())
                .previewLayout(.sizeThatFits)
                .environment(\.locale, .init(identifier: "ja"))
                .environment(\.colorScheme, .light)

            PaywallView(purchaseManager: MockPurchaseManager())
                .previewLayout(.sizeThatFits)
                .environment(\.locale, .init(identifier: "ja"))
                .environment(\.colorScheme, .dark)
                .background(.black)
        }
    }
}
