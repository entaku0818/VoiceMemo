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


class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
      FirebaseApp.configure()
      GADMobileAds.sharedInstance().start(completionHandler: nil)
      Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

      UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]){
          (granted, _) in
          if granted{
              UNUserNotificationCenter.current().delegate = self
          }
      }
      return true
  }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        // アプリ起動時も通知を行う
        completionHandler([ .badge, .sound, .alert ])
    }
}


@main
struct VoiceMemoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var voiceMemos: [VoiceMemoReducer.State] = []
    let DocumentsPath = NSHomeDirectory() + "/Documents"
    init() {
        let voiceMemoRepository = VoiceMemoRepository()
        voiceMemos = voiceMemoRepository.selectAllData()
    }
    var body: some Scene {
        WindowGroup {
//            RecordingMemoView(store: Store(initialState: RecordingMemoState(
//                date: Date(),
//                duration: 5,
//                mode: .recording,
//                url:  URL(fileURLWithPath: NSTemporaryDirectory())
//                  .appendingPathComponent(UUID().uuidString)
//                  .appendingPathExtension("m4a")
//            ), reducer: recordingMemoReducer, environment: RecordingMemoEnvironment(audioRecorder: .live, mainRunLoop: .main
//
//              )
//            ))
            VoiceMemosView(
              store: Store(initialState: VoiceMemos.State()) {
                VoiceMemos()._printChanges()
              }
            )
        }
    }

}
