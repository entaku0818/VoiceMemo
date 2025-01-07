//
//  VoiceMemoApp.swift
//  VoiceMemo
//
//  Created by 遠藤拓弥 on 3.9.2022.
//

import SwiftUI
import ComposableArchitecture
import FirebaseCore
import GoogleMobileAds
import FirebaseCrashlytics
import RollbarNotifier
import RevenueCat
import UIKit
import Firebase
import UserNotifications
import BackgroundTasks

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                UNUserNotificationCenter.current().delegate = self
            }
        }

        return true
    }

    // UNUserNotificationCenterDelegate method
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

@main
struct VoiceMemoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var voiceMemos: [VoiceMemoReducer.State] = []
    let DocumentsPath = NSHomeDirectory() + "/Documents"

    var admobUnitId: String!
    var recordAdmobUnitId: String!
    var playListAdmobUnitId: String!


    private let backgroundTaskManager = BackgroundTaskManager()

    init() {
        let environmentConfig = loadEnvironmentVariables()
        self.admobUnitId = environmentConfig.admobKey
        self.recordAdmobUnitId = environmentConfig.recordAdmobKey
        self.playListAdmobUnitId = environmentConfig.playListAdmobKey

        Purchases.configure(withAPIKey: environmentConfig.revenueCatKey)
        RollbarLogger.shared.initialize(with: environmentConfig.rollbarKey)

        let voiceMemoRepository = VoiceMemoRepository(coreDataAccessor: VoiceMemoCoredataAccessor(), cloudUploader: CloudUploader())
        voiceMemos = voiceMemoRepository.selectAllData()
    }

    var body: some Scene {
        WindowGroup {
            VoiceMemosView(
                store: Store(initialState: VoiceMemos.State(voiceMemos: IdentifiedArrayOf(uniqueElements: voiceMemos))) {
                    VoiceMemos()
                }, admobUnitId: admobUnitId, recordAdmobUnitId: recordAdmobUnitId, playListAdmobUnitId: playListAdmobUnitId
            )
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                print("applicationDidEnterBackground")
                backgroundTaskManager.registerBackgroundTask()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                print("applicationWillEnterForeground")
                backgroundTaskManager.endBackgroundTask()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                UserDefaultsManager.shared.logError("applicationWillTerminate")

            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                UserDefaultsManager.shared.logError("applicationWillTerminate")

            }
        }
    }
}

extension VoiceMemoApp {
    func loadEnvironmentVariables() -> EnvironmentConfig {
        let isCI = ProcessInfo.processInfo.environment["CI"] != nil

        let rollbarKey = ProcessInfo.processInfo.environment["ROLLBAR_KEY"]
        let recordAdmobKey = ProcessInfo.processInfo.environment["RECORD_ADMOB_KEY"]
        let admobKey = ProcessInfo.processInfo.environment["ADMOB_KEY"]
        let revenueCatKey = ProcessInfo.processInfo.environment["REVENUECAT_KEY"]
        let playListAdmobKey = ProcessInfo.processInfo.environment["PLAYLIST_ADMOB_KEY"]

        let missingKeys = [
            ("ROLLBAR_KEY", rollbarKey),
            ("RECORD_ADMOB_KEY", recordAdmobKey),
            ("ADMOB_KEY", admobKey),
            ("REVENUECAT_KEY", revenueCatKey),
            ("PLAYLIST_ADMOB_KEY", playListAdmobKey)
        ].filter { $0.1 == nil }.map { $0.0 }

        guard missingKeys.isEmpty else {
            if isCI {
                fatalError("Missing environment variables in CI: \(missingKeys.joined(separator: ", "))")
            } else {
                return EnvironmentConfig(
                    rollbarKey: Bundle.main.object(forInfoDictionaryKey: "ROLLBAR_KEY") as? String ?? "",
                    admobKey: Bundle.main.object(forInfoDictionaryKey: "ADMOB_KEY") as? String ?? "",
                    recordAdmobKey: Bundle.main.object(forInfoDictionaryKey: "RECORD_ADMOB_KEY") as? String ?? "",
                    revenueCatKey: Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_KEY") as? String ?? "",
                    playListAdmobKey: Bundle.main.object(forInfoDictionaryKey: "PLAYLIST_ADMOB_KEY") as? String ?? ""
                )
            }
        }

        return EnvironmentConfig(
            rollbarKey: rollbarKey!,
            admobKey: admobKey!,
            recordAdmobKey: recordAdmobKey!,
            revenueCatKey: revenueCatKey!,
            playListAdmobKey: playListAdmobKey!
        )
    }

    struct EnvironmentConfig {
        let rollbarKey: String
        let admobKey: String
        let recordAdmobKey: String
        let revenueCatKey: String
        let playListAdmobKey: String
    }
}

class BackgroundTaskManager {
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    init() {
        registerBackgroundTasks()
    }

    // Registering the traditional background task
    func registerBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        assert(backgroundTask != .invalid)
    }

    func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.entaku.VoiLog.background", using: nil) { task in
            self.handleBackgroundTask(task: task as! BGProcessingTask)
        }
    }

    private func handleBackgroundTask(task: BGProcessingTask) {
        scheduleAppRefresh()

        task.expirationHandler = {
            // Clean up if needed before the task expires
        }

        // Simulate a long-running task
        DispatchQueue.global().async {
            task.setTaskCompleted(success: true)
        }
    }

    // Schedule the next background task
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.entaku.VoiLog.background")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
}
