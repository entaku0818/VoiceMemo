import SwiftUI
import StoreKit

struct PaywallView: View {
    @State private var productName: String = ""
    @State private var productPrice: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode


    var iapManager: IAPManagerProtocol


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
                        Text("今すぐ1ヶ月無料体験してみよう！")
                            .font(.title2)
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
                        .border(.white, width: colorScheme == .dark ? 0 : 1)

                )

                Spacer().frame(minHeight: 30)

                VStack(spacing: 16){
                    HStack{
                        Spacer().frame(width: 8)
                        Image(colorScheme == .dark ? .adsWhite : .adsBlack).resizable()
                            .foregroundColor(.white)
                            .frame(width: 36,height: 36)
                        VStack(alignment: .leading) {

                            Text("広告なしの使用体験")
                                .font(.title2)
                                .padding(.vertical, 2)
                            Text("全ての広告が非表示に！")
                                .font(.subheadline)
                                .padding(.vertical, 2)
                        }
                        Spacer()
                    }


                    HStack{
                        Spacer().frame(width: 8)
                        Image(systemName: "icloud.and.arrow.up")
                            .resizable()
                            .frame(width: 36,height: 36)
                        VStack(alignment: .leading) {
                            Text("iCloud同期機能")
                                .font(.title2)
                                .padding(.vertical, 2)
                            Text("すべてのデータがiCloudで同期され、複数デバイスでの使用が可能に！")
                                .font(.subheadline)
                                .padding(.vertical, 2)
                        }
                        .padding(.vertical)
                        Spacer()
                    }
                }



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

                Button("リストア購入") { 
                      Task {
                          await restorePurchases()
                      }
                  }
                  .padding()
                  .frame(maxWidth: .infinity)
                  .background(Color.gray)
                  .foregroundColor(.white)
                  .cornerRadius(10)
                  .overlay(
                      RoundedRectangle(cornerRadius: 10)
                          .stroke(colorScheme == .dark ? Color.white : Color.clear, lineWidth: 1)
                  ).padding()

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
                Spacer()
            }
            .onAppear {
                Task {
                    await fetchProductInfo()
                }
            }
        }.alert(isPresented: $showAlert) {
            Alert(title: Text(""), message: Text(alertMessage), dismissButton: .default(Text("OK")))
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
             alertMessage = "購入が完了しました！"
             showAlert = true
         } catch {
             print(error)
         }
     }

     func restorePurchases() async {
         do {
             try await iapManager.restorePurchases()
             alertMessage = "購入情報が復元しました！"
             showAlert = true
         } catch {
             print(error)
         }
     }
}



struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PaywallView(iapManager: MockIAPManager())
                .previewLayout(.sizeThatFits)
                .environment(\.locale, .init(identifier: "ja"))
                .environment(\.colorScheme, .light) // Light mode preview

            PaywallView(iapManager: MockIAPManager())
                .previewLayout(.sizeThatFits)
                .environment(\.locale, .init(identifier: "ja"))
                .environment(\.colorScheme, .dark) // Dark mode preview
                .background(.black)
        }
    }
}
