import Foundation
import os.log
import Dependencies

/// アプリ全体で使用するLogger
struct AppLoggerClient {
    var recording: Logger
    var playback: Logger
    var data: Logger
    var file: Logger
    var sync: Logger
    var purchase: Logger
    var ui: Logger
    var general: Logger
}

extension AppLoggerClient: DependencyKey {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.voilog"

    static let liveValue = AppLoggerClient(
        recording: Logger(subsystem: subsystem, category: "Recording"),
        playback: Logger(subsystem: subsystem, category: "Playback"),
        data: Logger(subsystem: subsystem, category: "Data"),
        file: Logger(subsystem: subsystem, category: "File"),
        sync: Logger(subsystem: subsystem, category: "Sync"),
        purchase: Logger(subsystem: subsystem, category: "Purchase"),
        ui: Logger(subsystem: subsystem, category: "UI"),
        general: Logger(subsystem: subsystem, category: "General")
    )

    static let testValue = AppLoggerClient(
        recording: Logger(subsystem: "test", category: "Recording"),
        playback: Logger(subsystem: "test", category: "Playback"),
        data: Logger(subsystem: "test", category: "Data"),
        file: Logger(subsystem: "test", category: "File"),
        sync: Logger(subsystem: "test", category: "Sync"),
        purchase: Logger(subsystem: "test", category: "Purchase"),
        ui: Logger(subsystem: "test", category: "UI"),
        general: Logger(subsystem: "test", category: "General")
    )
}

extension DependencyValues {
    var logger: AppLoggerClient {
        get { self[AppLoggerClient.self] }
        set { self[AppLoggerClient.self] = newValue }
    }
}

// MARK: - Convenience for non-TCA code (static access)
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.voilog"

    static let recording = Logger(subsystem: subsystem, category: "Recording")
    static let playback = Logger(subsystem: subsystem, category: "Playback")
    static let data = Logger(subsystem: subsystem, category: "Data")
    static let file = Logger(subsystem: subsystem, category: "File")
    static let sync = Logger(subsystem: subsystem, category: "Sync")
    static let purchase = Logger(subsystem: subsystem, category: "Purchase")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let general = Logger(subsystem: subsystem, category: "General")
}
