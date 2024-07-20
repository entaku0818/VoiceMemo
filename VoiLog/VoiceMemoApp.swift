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
import GoogleMobileAds
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .sound, .badge]) { (granted, _) in
            if granted {
                UNUserNotificationCenter.current().delegate = self
            }
        }

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        registerBackgroundTask()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        endBackgroundTask()
    }

    private func registerBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        assert(backgroundTask != .invalid)
    }

    private func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
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
        }
    }
}



extension VoiceMemoApp {
    func loadEnvironmentVariables() -> EnvironmentConfig {

        guard
            let rollbarKey = Bundle.main.object(forInfoDictionaryKey: "ROLLBAR_KEY") as? String ?? ProcessInfo.processInfo.environment["ROLLBAR_KEY"],
            let recordAdmobKey = Bundle.main.object(forInfoDictionaryKey: "RECORD_ADMOB_KEY") as? String ?? ProcessInfo.processInfo.environment["RECORD_ADMOB_KEY"],
            let admobKey = Bundle.main.object(forInfoDictionaryKey: "ADMOB_KEY") as? String ?? ProcessInfo.processInfo.environment["ADMOB_KEY"],
            let revenueCatKey = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_KEY") as? String ?? ProcessInfo.processInfo.environment["REVENUECAT_KEY"]
        else {
            fatalError("One or more environment variables are missing")
        }

        return EnvironmentConfig(rollbarKey: rollbarKey, admobKey: admobKey, recordAdmobKey: recordAdmobKey, revenueCatKey: revenueCatKey)
    }

    struct EnvironmentConfig {
        let rollbarKey: String
        let admobKey: String
        let recordAdmobKey:String
        let revenueCatKey: String
    }
}
