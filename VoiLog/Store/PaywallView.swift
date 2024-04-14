import SwiftUI
import StoreKit

struct PaywallView: View {
    @State private var productName: String = ""
    @State private var productPrice: String = ""

    var iapManager: IAPManagerProtocol
    private var features: [String] = [
        "広告なしの使用体験",
    ]

    init(iapManager: IAPManagerProtocol) {
        self.iapManager = iapManager
    }

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
                        Text("✅\(feature)")
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
            let (name, price) = try await iapManager.fetchProductNameAndPrice(productIdentifier: "pro")
            productName = name
            productPrice = price
        } catch {
            productName = "製品情報の取得に失敗しました"
            productPrice = ""
        }
    }

    func purchaseProduct() async {
        do {
            try await iapManager.startPurchase(productID: "pro")
        } catch {
            print(error)
        }
    }
}



struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView(iapManager: MockIAPManager())
            .previewLayout(.sizeThatFits) // This adjusts the preview to just fit the content
            .environment(\.locale, .init(identifier: "ja")) // Set locale to Japanese for testing
    }
}
