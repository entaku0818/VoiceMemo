import SwiftUI

struct PaywallView: View {
    var body: some View {
        VStack {
            Text("シンプル録音Proプラン")
                .font(.largeTitle)
                .padding()
            Text("¥1200")
                .font(.title)
                .padding()
            Button(action: {
                Task{
                    await purchaseProduct()
                }
            }) {
                Text("購入する")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }

    func purchaseProduct() async {
        do {
            try await IAPManager.shared.startPurchase(productID: "pro")
        } catch let error {
            print(error)
        }

    }
}

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView()
    }
}

