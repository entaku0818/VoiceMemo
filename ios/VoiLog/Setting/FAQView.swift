//
//  FAQView.swift
//  VoiLog
//

import SwiftUI
import SafariServices

struct FAQView: UIViewControllerRepresentable {
    private let url = URL(string: "https://voilog.web.app/faq.html")!

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredControlTintColor = .systemRed
        return safari
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct FAQScreen: View {
    var body: some View {
        FAQView()
            .ignoresSafeArea()
    }
}

#Preview {
    FAQScreen()
}
