//
//  SwiftUIView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 22.10.2022.
//

import SwiftUI
import ComposableArchitecture

struct SettingNotification: View {
    @State private var text = """
    
"""
    let store: Store<NotificationViewState, NotificationAction>
    var body: some View {
        VStack{
            List {
                Button(action: {
                    let content = UNMutableNotificationContent()
                    content.title = "お知らせ"
                    content.body = "テストですよ！"
                    content.sound = UNNotificationSound.default

                    let request = UNNotificationRequest(identifier: "immediately", content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                }){
                    Text("localpush")
                }

            }
        }.navigationTitle("通知の設定")
    }
}

struct SettingNotification_Previews: PreviewProvider {
    static var previews: some View {
        SettingNotification(
            store: Store(initialState:
                            NotificationViewState(text: ""),
                         reducer: NotificationReducer.debug(),
                         environment: NotificationEnvironment()
                 ))
    }
}

struct NotificationViewState: Equatable, Identifiable {
    var id: UUID = UUID()
    
    var text: String


}

enum NotificationAction: Equatable {
    case searchQueryChanged(String)
}
struct NotificationEnvironment {

}


let NotificationReducer = Reducer<
    NotificationViewState,
    NotificationAction,
    NotificationEnvironment
> { state, action, environment in
  enum PlayID {}

  switch action {

  case .searchQueryChanged(let text):
      state.text = text
      ThemaRepository.shared.insert(state: text)
      return .none
  }
}
