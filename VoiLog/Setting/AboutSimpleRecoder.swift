//
//  AboutSimpleRecoder.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 18.9.2023.
//

import SwiftUI

struct AboutSimpleRecoder: View {

    @State private var isShareSheetPresented = false

    var body: some View {

        List {

            Button(action: {
                 // AppStoreのURLを指定して開く
                 if let url = URL(string: "https://apps.apple.com/app/id6443528409") {
                     UIApplication.shared.open(url, options: [:], completionHandler: nil)
                 }
             }) {
                 HStack {
                     Image(systemName: "hands.sparkles")
                     Text("AppStoreでレビューを書く")
                     Spacer()
                 }
             }

            Button(action: {
                isShareSheetPresented.toggle()
            }) {
                HStack {
                    Image(systemName: "person.wave.2")
                    Text("友人にアプリを教える")
                    Spacer()
                }
            }
            .sheet(isPresented: $isShareSheetPresented, content: {
                ActivityViewController(activityItems: ["https://apps.apple.com/app/id6443528409"])
            })


        }
        .listStyle(GroupedListStyle())
        .navigationTitle("アプリについて")

    }


}

#Preview {
    AboutSimpleRecoder()
}


// UIActivityViewControllerをSwiftUIのViewに組み込むためのラッパー
struct ActivityViewController: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIActivityViewController

    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return activityViewController
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 更新が必要な場合の処理はここに追加
    }
}
