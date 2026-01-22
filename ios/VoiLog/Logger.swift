//
//  Logger.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 10.6.2023.
//

import Foundation
import FirebaseCrashlytics
import RollbarNotifier
import UIKit

class RollbarLogger {
    static let shared = RollbarLogger()

    private var userUUID: String = ""

    private init() {}

    func initialize(with accessToken: String) {
        // Generate unique user ID for crash tracking
        userUUID = UUID().uuidString

        // Configure Crashlytics
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(userUUID, forKey: "UUID")
        crashlytics.setCustomValue(UIDevice.current.systemVersion, forKey: "ios_version")
        crashlytics.setCustomValue(UIDevice.current.model, forKey: "device_model")
        crashlytics.setCustomValue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown", forKey: "app_version")
        crashlytics.setCustomValue(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown", forKey: "build_number")

        // Rollbar configuration
        let config = RollbarConfig.mutableConfig(withAccessToken: accessToken)
        Rollbar.initWithConfiguration(config)

        // Log initialization
        crashlytics.log("App initialized with UUID: \(userUUID)")
    }

    // MARK: - Error Logging

    func logError(_ message: String) {
        Crashlytics.crashlytics().log("Error: \(message)")
        Rollbar.errorMessage(message)
    }

    /// Record a non-fatal error to Crashlytics with detailed information
    func recordError(_ error: Error, userInfo: [String: Any]? = nil, file: String = #file, line: Int = #line, function: String = #function) {
        var info: [String: Any] = [
            "file": (file as NSString).lastPathComponent,
            "line": line,
            "function": function
        ]

        if let userInfo = userInfo {
            info.merge(userInfo) { _, new in new }
        }

        let nsError = NSError(
            domain: "com.entaku.VoiLog",
            code: (error as NSError).code,
            userInfo: info
        )

        Crashlytics.crashlytics().record(error: nsError)
        Rollbar.errorError(nsError, data: info, context: function)
    }

    /// Record a non-fatal exception for crash analysis
    func recordException(name: String, reason: String, stackTrace: [String]? = nil) {
        let exception = ExceptionModel(name: name, reason: reason)
        if let stackTrace = stackTrace {
            exception.stackTrace = stackTrace.enumerated().map { index, trace in
                StackFrame(symbol: trace)
            }
        }
        Crashlytics.crashlytics().record(exceptionModel: exception)

        // Also log to Rollbar
        Rollbar.errorMessage("\(name): \(reason)")
    }

    // MARK: - Breadcrumb Logging

    /// Add a breadcrumb for crash context
    func logBreadcrumb(_ message: String, category: BreadcrumbCategory = .general) {
        let formattedMessage = "[\(category.rawValue)] \(message)"
        Crashlytics.crashlytics().log(formattedMessage)
    }

    enum BreadcrumbCategory: String {
        case general = "General"
        case navigation = "Navigation"
        case userAction = "UserAction"
        case network = "Network"
        case audio = "Audio"
        case coreData = "CoreData"
        case purchase = "Purchase"
    }

    // MARK: - User Context

    /// Set user ID for crash reports
    func setUserID(_ userID: String) {
        Crashlytics.crashlytics().setUserID(userID)
    }

    /// Set custom key-value for crash context
    func setCustomValue(_ value: Any, forKey key: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    /// Set premium user status for crash reports
    func setPremiumStatus(_ isPremium: Bool) {
        Crashlytics.crashlytics().setCustomValue(isPremium, forKey: "is_premium_user")
    }

    // MARK: - Info Logging

    func logInfo(_ message: String, context: String) {
        Crashlytics.crashlytics().log("Info: \(message) - Context: \(context)")
        Rollbar.infoMessage(message, data: nil, context: context)
    }

    func logInfo(_ message: String) {
        Crashlytics.crashlytics().log("Info: \(message)")
        Rollbar.infoMessage(message)
    }

    // MARK: - Debug Helpers

    /// Force a test crash (only for debug builds)
    #if DEBUG
    func forceCrash() {
        fatalError("Test crash triggered by RollbarLogger.forceCrash()")
    }
    #endif
}
