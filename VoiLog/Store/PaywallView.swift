import SwiftUI
import StoreKit

struct PaywallView: View {
    // 製品情報を保持するための@Stateプロパティを追加
    @State private var productName: String = "ローディング中..."
    @State private var productPrice: String = ""

    // 特典のリスト
    private var features: [String] = [
        "広告なしの使用体験",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Image("AppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .padding()

                Text(productName)
                    .font(.largeTitle)
                    .padding()

                Text(productPrice)
                    .font(.title)
                    .padding()

                VStack(alignment: .leading) {
                    ForEach(features, id: \.self) { feature in
                        Text("• \(feature)")
                            .padding(.vertical, 2)
                    }
                }
                .padding()

                Spacer()

                Button(action: {
                    Task {
                        await purchaseProduct()
                    }
                }) {
                    Text("購入する")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .cornerRadius(10)
                }
                .padding()
            }
            .onAppear { 
                Task {
                    await fetchProductInfo()
                }
            }
        }
    }

    func fetchProductInfo() async {
        do {
            let (name, price) = try await IAPManager.shared.fetchProductNameAndPrice(productIdentifier: "pro")
            productName = name
            productPrice = price
        } catch {
            productName = "製品情報の取得に失敗しました"
            productPrice = ""
        }
    }

    func purchaseProduct() async {
        do {
            try await IAPManager.shared.startPurchase(productID: "pro")
        } catch {
            print(error)
        }
    }
}
