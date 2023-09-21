//
//  MailComposeViewControllerWrapper.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 21.9.2023.
//

import SwiftUI
import MessageUI

struct MailComposeViewControllerWrapper: UIViewControllerRepresentable {
    @Binding var isPresented: Bool

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            isPresented = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let viewController = MFMailComposeViewController()
        viewController.mailComposeDelegate = context.coordinator
        viewController.setToRecipients(["entaku19890818@gmail.com"]) // 宛先メールアドレスを設定
        viewController.setSubject("メールの件名") // メールの件名を設定
        viewController.setMessageBody("メールの本文", isHTML: false) // メールの本文を設定
        return viewController
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // Nothing to do here
    }
}
