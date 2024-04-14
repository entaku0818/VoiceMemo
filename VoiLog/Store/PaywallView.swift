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

                HStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/){
                    Spacer()
                    VStack(alignment: .center){

                        Text("すべての機能が使い放題")
                            .font(.title)
                            .foregroundColor(.black)
                        Text("今すぐ1ヶ月無料体験してみよう！")
                            .font(.title2)
                            .foregroundColor(.black)
                    }.padding(.vertical,30)
                    Spacer()

                }
                HStack{
                    Spacer()
                    Image(systemName: "music.mic.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white,.purple)
                    VStack(alignment: .leading){

                        Text("プレミアムサービスでできること")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Spacer()

                }.padding()
                .background(
                    Rectangle()
                        .fill(Color.black)


                )

                Spacer().frame(minHeight: 30)

                VStack(alignment: .leading) {
                    ForEach(features, id: \.self) { feature in
                        Text("✅\(feature)")
                            .padding(.vertical, 2)
                    }
                }
                .padding()

                Spacer().frame(minHeight: 30)

                Button(action: {
                    Task {
                        await purchaseProduct()
                    }
                }) {
                    VStack{
                        Text("1ヶ月 無料でお試し")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("\(productPrice)/月")
                            .foregroundColor(.white)

                    }
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
