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

    private let backgroundTaskManager = BackgroundTaskManager()

    init() {
        let environmentConfig = loadEnvironmentVariables()
        self.admobUnitId = environmentConfig.admobKey
        self.recordAdmobUnitId = environmentConfig.recordAdmobKey
        Purchases.configure(withAPIKey: environmentConfig.revenueCatKey)
        Logger.shared.initialize(with: environmentConfig.rollbarKey)

        let voiceMemoRepository = VoiceMemoRepository(coreDataAccessor: VoiceMemoCoredataAccessor(), cloudUploader: CloudUploader())
        voiceMemos = voiceMemoRepository.selectAllData()
    }

    var body: some Scene {
        WindowGroup {
            VoiceMemosView(
                store: Store(initialState: VoiceMemos.State(voiceMemos: IdentifiedArrayOf(uniqueElements: voiceMemos))) {
                    VoiceMemos()
                }, admobUnitId: admobUnitId, recordAdmobUnitId: recordAdmobUnitId
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
        guard
            let rollbarKey = ProcessInfo.processInfo.environment["ROLLBAR_KEY"] ?? Bundle.main.object(forInfoDictionaryKey: "ROLLBAR_KEY") as? String,
            let recordAdmobKey = ProcessInfo.processInfo.environment["RECORD_ADMOB_KEY"] ?? Bundle.main.object(forInfoDictionaryKey: "RECORD_ADMOB_KEY") as? String,
            let admobKey = ProcessInfo.processInfo.environment["ADMOB_KEY"] ?? Bundle.main.object(forInfoDictionaryKey: "ADMOB_KEY") as? String,
            let revenueCatKey = ProcessInfo.processInfo.environment["REVENUECAT_KEY"] ?? Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_KEY") as? String
        else {
            fatalError("One or more environment variables are missing")
        }

        return EnvironmentConfig(
            rollbarKey: rollbarKey,
            admobKey: admobKey,
            recordAdmobKey: recordAdmobKey,
            revenueCatKey: revenueCatKey
        )
    }

    struct EnvironmentConfig {
        let rollbarKey: String
        let admobKey: String
        let recordAdmobKey: String
        let revenueCatKey: String
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
