//
//  MailComposeViewControllerWrapper.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 21.9.2023.
//

import SwiftUI
import MessageUI
import UIKit

struct MailComposeViewControllerWrapper: UIViewControllerRepresentable {
    @Binding var isPresented: Bool

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            isPresented = false
            controller.dismiss(animated: true, completion: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let viewController = MFMailComposeViewController()
        viewController.mailComposeDelegate = context.coordinator
        viewController.setToRecipients(["entaku19890818@gmail.com"])
        viewController.setSubject("シンプル録音 問い合わせ - iOS")

        // iOSバージョンを取得
        let iOSVersion = UIDevice.current.systemVersion

        // アプリのバージョンを取得
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let mailBody = """



            [iOS: \(iOSVersion)  バージョン: \(appVersion)]

            """
            viewController.setMessageBody(mailBody, isHTML: false)
        } else {
            viewController.setMessageBody("", isHTML: false)
        }

        return viewController
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // Nothing to do here
    }
}
