import SwiftUI
import RevenueCat

struct PaywallView: View {
    @State private var productName: String = ""
    @State private var productPrice: String = ""
    @State private var showAlert = false
    @State private var alertMessage: String = ""
    @State private var offering: Offering?

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode

    var purchaseManager: PurchaseManagerProtocol

    init(purchaseManager: PurchaseManagerProtocol) {
        self.purchaseManager = purchaseManager
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Spacer()
                    VStack(alignment: .center) {
                        Text("すべての機能が使い放題")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .padding(.bottom, 4)
                        Text("今すぐ1ヶ月無料体験してみよう！")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                    }.padding(.vertical, 30)
                    Spacer()
                }

                // プレミアム機能のヘッダー
                HStack {
                    Spacer()
                    Image(systemName: "music.mic.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .purple)
                    VStack(alignment: .leading) {
                        Text("プレミアムサービスでできること")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding()
                .background(
                    Rectangle()
                        .fill(Color.black)
                        .border(.white, width: colorScheme == .dark ? 0 : 1)
                )

                Spacer().frame(minHeight: 30)

                // 機能リスト
                VStack(spacing: 16) {
                    // 広告非表示機能
                    HStack {
                        Spacer().frame(width: 8)
                        Image(colorScheme == .dark ? .adsWhite : .adsBlack)
                            .resizable()
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading) {
                            Text("広告なしの使用体験")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .padding(.vertical, 2)
                            Text("全ての広告が非表示に！")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 2)
                        }
                        Spacer()
                    }

                    // iCloud同期機能
                    HStack {
                        Spacer().frame(width: 8)
                        Image(systemName: "icloud.and.arrow.up")
                            .resizable()
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading) {
                            Text("iCloud同期機能")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .padding(.vertical, 2)
                            Text("すべてのデータがiCloudで同期され、複数デバイスでの使用が可能に！")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 2)
                        }
                        .padding(.vertical)
                        Spacer()
                    }

                    // 音声編集機能
                    HStack {
                        Spacer().frame(width: 8)
                        Image(systemName: "waveform")
                            .resizable()
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading) {
                            Text("音声編集機能")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .padding(.vertical, 2)
                            Text("音声の分割編集ができ、使いやすく整理できます！")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 2)
                        }
                        .padding(.vertical)
                        Spacer()
                    }

                    // プレイリスト機能
                    HStack {
                        Spacer().frame(width: 8)
                        Image(systemName: "music.note.list")
                            .resizable()
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading) {
                            Text("プレイリストを無制限に作成")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .padding(.vertical, 2)
                            Text("通常3つまでのプレイリストを好きなだけ作成して、音声を整理できます！")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 2)
                        }
                        .padding(.vertical)
                        Spacer()
                    }
                }

                Spacer().frame(minHeight: 30)

                // 購入ボタン
                Button(action: {
                    Task {
                        await purchaseProduct()
                    }
                }) {
                    VStack {
                        Text("1ヶ月 無料でお試し")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("\(productPrice)/月")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(colorScheme == .dark ? Color.white : Color.clear, lineWidth: 1)
                    )
                }
                .padding()

                // リストアボタン
                Button("リストア購入") {
                    Task {
                        await restorePurchases()
                    }
                }
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(colorScheme == .dark ? Color.white : Color.clear, lineWidth: 1)
                )
                .padding()

                // フッター
                VStack(alignment: .center) {
                    HStack(alignment: .center) {
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
                .padding()

                Spacer()
            }
            .onAppear {
                Task {
                    await fetchProductInfo()
                }
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
        do {
            try await purchaseManager.purchasePro()
            await MainActor.run {
                alertMessage = "購入が完了しました！"
                showAlert = true
                presentationMode.wrappedValue.dismiss()
            }
        } catch {
            await MainActor.run {
                alertMessage = "購入に失敗しました"
                showAlert = true
            }
        }
    }

    // RevenueCat用のリストア処理
    func restorePurchases() async {
        do {
            try await purchaseManager.restorePurchases()
            alertMessage = "購入情報が復元しました！"
            showAlert = true
            presentationMode.wrappedValue.dismiss()
        } catch {
            alertMessage = "リストアに失敗しました"
            showAlert = true
        }
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
