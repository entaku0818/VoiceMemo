//
//  Logger.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 10.6.2023.
//

import Foundation
import FirebaseCrashlytics
import RollbarNotifier


class Logger {
    static let shared = Logger()

    private init() {
        if let variableValue = EnvironmentProcess.getEnvironmentVariable("ROLLBAR_CONFIG") {
            Crashlytics.crashlytics().setCustomValue(UUID(), forKey: "UUID")
            let config = RollbarConfig.mutableConfig(withAccessToken: variableValue)
            Rollbar.initWithConfiguration(config)
        }

    }

    func logError(_ message: String) {
        Crashlytics.crashlytics().log("Error: \(message)")
        Rollbar.errorMessage(message)
    }

    func logInfo(_ message: String, context:String) {
        Rollbar.infoMessage(message, data: nil,context:context)
    }

    func logInfo(_ message: String) {
        Rollbar.infoMessage(message)
    }
}
