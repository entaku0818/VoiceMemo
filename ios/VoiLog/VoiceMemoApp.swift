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
import ActivityKit
import os.log

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Firebase初期化（必須、同期）
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        // AdMob初期化を遅延実行（UIが表示された後）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            GADMobileAds.sharedInstance().start(completionHandler: nil)
        }

        // 通知許可リクエストを遅延
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]) { granted, _ in
                if granted {
                    DispatchQueue.main.async {
                        UNUserNotificationCenter.current().delegate = self
                    }
                }
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

    var admobUnitId: String!
    var recordAdmobUnitId: String!
    var playListAdmobUnitId: String!

    private let backgroundTaskManager = BackgroundTaskManager()

    init() {
        let environmentConfig = loadEnvironmentVariables()
        self.admobUnitId = environmentConfig.admobKey
        self.recordAdmobUnitId = environmentConfig.recordAdmobKey
        self.playListAdmobUnitId = environmentConfig.playListAdmobKey

        // Rollbarは軽量なので同期で初期化
        RollbarLogger.shared.initialize(with: environmentConfig.rollbarKey)

        // RevenueCatを遅延初期化（StoreKit 2が重いため）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            Purchases.configure(withAPIKey: environmentConfig.revenueCatKey)
        }

        // データ読み込みも遅延（UIが先に表示されるようにする）
        // 注: VoiceAppFeature内でreloadDataが呼ばれるので、ここでの読み込みは不要
    }

    var body: some Scene {
        WindowGroup {
            VoiceAppView(
                store: Store(initialState: VoiceAppFeature.State()) {
                    VoiceAppFeature()
                },
                recordAdmobUnitId: recordAdmobUnitId,
                playListAdmobUnitId: playListAdmobUnitId,
                admobUnitId: admobUnitId
            )
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                AppLogger.general.debug("Application did enter background")
                backgroundTaskManager.registerBackgroundTask()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                AppLogger.general.debug("Application will enter foreground")
                backgroundTaskManager.endBackgroundTask()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                UserDefaultsManager.shared.logError("applicationWillTerminate")
                cleanupLiveActivities()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                UserDefaultsManager.shared.logError("applicationWillTerminate")
                cleanupLiveActivities()
            }
        }
    }
}

extension VoiceMemoApp {
    func loadEnvironmentVariables() -> EnvironmentConfig {
        guard let rollbarKey = Bundle.main.object(forInfoDictionaryKey: "ROLLBAR_KEY") as? String,
              let admobKey = Bundle.main.object(forInfoDictionaryKey: "ADMOB_KEY") as? String,
              let recordAdmobKey = Bundle.main.object(forInfoDictionaryKey: "RECORD_ADMOB_KEY") as? String,
              let revenueCatKey = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_KEY") as? String,
              let playListAdmobKey = Bundle.main.object(forInfoDictionaryKey: "PLAYLIST_ADMOB_KEY") as? String
        else {
            fatalError("Required environment variables are missing in Info.plist")
        }

        return EnvironmentConfig(
            rollbarKey: rollbarKey,
            admobKey: admobKey,
            recordAdmobKey: recordAdmobKey,
            revenueCatKey: revenueCatKey,
            playListAdmobKey: playListAdmobKey
        )
    }

    struct EnvironmentConfig {
        let rollbarKey: String
        let admobKey: String
        let recordAdmobKey: String
        let revenueCatKey: String
        let playListAdmobKey: String
    }

    func cleanupLiveActivities() {
        if #available(iOS 16.1, *) {
            Task {
                for activity in Activity<RecordActivityAttributes>.activities {
                    AppLogger.general.debug("Cleaning up background activity: \(activity.id)")
                    let finalContentState = RecordActivityAttributes.ContentState(emoji: "⏹️", recordingTime: 0)
                    let finalActivityContent = ActivityContent(state: finalContentState, staleDate: Date())
                    await activity.end(finalActivityContent, dismissalPolicy: .immediate)
                }
            }
        }
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
            guard let processingTask = task as? BGProcessingTask else { return }
            self.handleBackgroundTask(task: processingTask)
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
            AppLogger.general.error("Could not schedule app refresh: \(error)")
        }
    }
}
