//
//  VoiceMemoApp.swift
//  VoiceMemo
//
//  Created by 遠藤拓弥 on 3.9.2022.
//

import SwiftUI
import ComposableArchitecture

@main
struct VoiceMemoApp: App {
    var voiceMemos:[VoiceMemoState] = []
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
              store: Store(
                initialState: VoiceMemosState(voiceMemos:IdentifiedArrayOf(uniqueElements: voiceMemos)),
                reducer:
                  voiceMemosReducer
                  .debug(),
                environment: VoiceMemosEnvironment(
                  audioPlayer: .live,
                  audioRecorder: .live,
                  mainRunLoop: .main,
                  openSettings: {
                    await MainActor.run {
                      UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    }
                  },
                  temporaryDirectory: { URL(fileURLWithPath: DocumentsPath) },
                  uuid: { UUID() }
                )
              )
            )
        }
    }
    
    
    
    
}
