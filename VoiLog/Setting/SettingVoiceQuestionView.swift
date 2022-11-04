//
//  SwiftUIView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 22.10.2022.
//

import SwiftUI
import ComposableArchitecture

struct SettingVoiceQuestionView: View {
    

    let store: Store<SettingVoiceQuestionViewState, SettingVoiceQuestionAction>
    var body: some View {
        WithViewStore(self.store) { viewStore in
            VStack{
                TextField("質問", text: viewStore.binding(
                    get: \.text, send: SettingVoiceQuestionAction.searchQueryChanged
                  ))
                Spacer()
            }.navigationTitle("質問の設定")
        }
    }
}

struct SettingVoiceQuestionView_Previews: PreviewProvider {
    static var previews: some View {
        SettingVoiceQuestionView(store:
        Store(initialState:
                SettingVoiceQuestionViewState(
                    text:ThemaRepository.shared.select()
                ),
                reducer: SettingVoiceQuestionReducer.debug(),
                environment: SettingVoiceQuestionEnvironment()
        ))
    }
}


struct SettingVoiceQuestionViewState: Equatable, Identifiable {
    var id: UUID = UUID()
    
    var text: String


}

enum SettingVoiceQuestionAction: Equatable {
    case searchQueryChanged(String)
}
struct SettingVoiceQuestionEnvironment {

}


let SettingVoiceQuestionReducer = Reducer<
    SettingVoiceQuestionViewState,
    SettingVoiceQuestionAction,SettingVoiceQuestionEnvironment
> { state, action, environment in
  enum PlayID {}

  switch action {

  case .searchQueryChanged(let text):
      state.text = text
      ThemaRepository.shared.insert(state: text)
      return .none
  }
}
