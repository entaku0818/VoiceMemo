import SwiftUI
import StoreKit

struct PaywallView: View {
    @State private var productName: String = ""
    @State private var productPrice: String = ""

    @Environment(\.colorScheme) var colorScheme


    var iapManager: IAPManagerProtocol
    private var features: [String] = [
        "広告なしの使用体験",
    ]

    init(iapManager: IAPManagerProtocol) {
        self.iapManager = iapManager
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: 0) {

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
                        .border(colorScheme == .dark ? Color.white : Color.clear, width: 1)


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
                        .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(colorScheme == .dark ? Color.white : Color.clear, lineWidth: 1)
                        )
                }
                .padding()

                VStack(alignment: .center) {
                    HStack(alignment: .center) {
                        Spacer()
                        Link("利用規約", destination: URL(string: "https://voilog.web.app/terms_of_service.html")!)
                            .font(.body)
                            .foregroundColor(.blue)
                        Link("プライバシーポリシー", destination: URL(string: "https://voilog.web.app/privacy_policy.html")!)
                            .font(.body)
                            .foregroundColor(.blue)
                        Spacer()
                    }
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
