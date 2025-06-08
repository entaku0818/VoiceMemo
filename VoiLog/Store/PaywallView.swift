import SwiftUI
import RevenueCat
import Dependencies

struct PaywallView: View {
    @State private var productName: String = ""
    @State private var productPrice: String = ""
    @State private var showAlert = false
    @State private var alertMessage: String = ""
    @State private var offering: Offering?

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
                        
                        Text("すべての機能が使い放題")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 4)
                        
                        Text("今すぐ1ヶ月無料体験してみよう！")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
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
                    
                    Text("プレミアム特典")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Spacer()
                }
                .padding(.vertical, 20)

                // 機能リスト
                VStack(spacing: 24) {
                    // 広告非表示機能
                    featureRow(
                        systemName: "rectangle.slash",
                        title: "広告なしの使用体験",
                        description: "全ての広告が非表示に！",
                        systemImage: true
                    )

                    // iCloud同期機能
                    featureRow(
                        systemName: "icloud.and.arrow.up",
                        title: "iCloud同期機能",
                        description: "すべてのデータがiCloudで同期され、複数デバイスでの使用が可能に！",
                        systemImage: true
                    )

                    // 音声編集機能
                    featureRow(
                        systemName: "waveform",
                        title: "音声編集機能",
                        description: "音声の分割編集ができ、使いやすく整理できます！",
                        systemImage: true
                    )

                    // プレイリスト機能
                    featureRow(
                        systemName: "music.note.list",
                        title: "プレイリストを無制限に作成",
                        description: "通常3つまでのプレイリストを好きなだけ作成して、音声を整理できます！",
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
                        Text("1ヶ月 無料でお試し")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("\(productPrice)/月")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
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

                // リストアボタン
                Button("リストア購入") {
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
                        Link("利用規約", destination: URL(string: "https://voilog.web.app/terms_of_service.html")!)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.blue)
                        Link("プライバシーポリシー", destination: URL(string: "https://voilog.web.app/privacy_policy.html")!)
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
                // PaywallViewが閉じられたことをAnalyticsに記録
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
        do {
            let (name, price) = try await purchaseManager.fetchProPlan()
            productName = name
            productPrice = price
        } catch {
            productName = "製品情報の取得に失敗しました"
            productPrice = ""
            showAlert = true
            alertMessage = "製品情報の取得に失敗しました"
        }
    }

    // RevenueCat用の購入処理
    func purchaseProduct() async {
        // 購入試行をAnalyticsに記録
        analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallPurchaseAttempted, [
            "product_name": productName,
            "product_price": productPrice,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        do {
            try await purchaseManager.purchasePro()
            
            // 購入成功をAnalyticsに記録
            analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallPurchaseCompleted, [
                "product_name": productName,
                "product_price": productPrice,
                "timestamp": Date().timeIntervalSince1970
            ])
            
            await MainActor.run {
                alertMessage = "購入が完了しました！"
                showAlert = true
                presentationMode.wrappedValue.dismiss()
            }
        } catch {
            // 購入失敗をAnalyticsに記録
            analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallPurchaseFailed, [
                "product_name": productName,
                "product_price": productPrice,
                "error": error.localizedDescription,
                "timestamp": Date().timeIntervalSince1970
            ])
            
            await MainActor.run {
                alertMessage = "購入に失敗しました"
                showAlert = true
            }
        }
    }

    // RevenueCat用のリストア処理
    func restorePurchases() async {
        // リストア試行をAnalyticsに記録
        analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallRestoreAttempted, [
            "timestamp": Date().timeIntervalSince1970
        ])
        
        do {
            try await purchaseManager.restorePurchases()
            
            // リストア成功をAnalyticsに記録
            analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallRestoreCompleted, [
                "timestamp": Date().timeIntervalSince1970
            ])
            
            alertMessage = "購入情報が復元しました！"
            showAlert = true
            presentationMode.wrappedValue.dismiss()
        } catch {
            // リストア失敗をAnalyticsに記録
            analytics.logEvent(FirebaseAnalyticsClient.PaywallEvent.paywallRestoreFailed, [
                "error": error.localizedDescription,
                "timestamp": Date().timeIntervalSince1970
            ])
            
            alertMessage = "リストアに失敗しました"
            showAlert = true
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
