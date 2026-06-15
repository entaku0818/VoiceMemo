//
//  Logger.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 10.6.2023.
//

import Foundation
import FirebaseCrashlytics

class RollbarLogger {
    static let shared = RollbarLogger()

    private init() {}

    func initialize(with accessToken: String) {
        Crashlytics.crashlytics().setCustomValue(UUID().uuidString, forKey: "UUID")
    }

    func logError(_ message: String) {
        Crashlytics.crashlytics().log("Error: \(message)")
    }

    func logInfo(_ message: String, context: String) {
        Crashlytics.crashlytics().log("\(context): \(message)")
    }

    func logInfo(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }
}
