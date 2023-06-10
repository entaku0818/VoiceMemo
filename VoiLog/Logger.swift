//
//  Logger.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 10.6.2023.
//

import Foundation
import FirebaseCrashlytics

class Logger {
    static let shared = Logger()

    private init() {
        Crashlytics.crashlytics().setCustomValue(UUID(), forKey: "UUID")
    }

    func logError(_ message: String) {
        Crashlytics.crashlytics().log("Error: \(message)")
    }
}
