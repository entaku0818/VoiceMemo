import SwiftUI
import ComposableArchitecture

struct TutorialView: View {
    let store: StoreOf<VoiceMemos>
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text(LocalizedStringKey("シンプル録音へようこそ！"))
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(.top, 30)
                
                VStack(alignment: .leading, spacing: 15) {
                    TutorialItem(
                        icon: "mic.circle.fill",
                        title: "1. 録音する",
                        description: "マイクボタンをタップして録音を開始します",
                        customView: AnyView(
                            ZStack {
                                Circle()
                                    .foregroundColor(Color(.label))
                                    .frame(width: 40, height: 40)
                                
                                Circle()
                                    .foregroundColor(Color(.systemRed))
                                    .padding(2)
                                    .frame(width: 36, height: 36)
                            }
                        )
                    )
                    
                    TutorialItem(
                        icon: "stop.circle.fill",
                        title: "2. 録音を停止",
                        description: "停止ボタンをタップして録音を終了します",
                        customView: AnyView(
                            ZStack {
                                Circle()
                                    .foregroundColor(Color(.label))
                                    .frame(width: 40, height: 40)
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .foregroundColor(Color(.systemRed))
                                    .frame(width: 20, height: 20)
                            }
                        )
                    )
                    
                    TutorialItem(
                        icon: "play.circle.fill",
                        title: "3. 再生する",
                        description: "録音したメモをタップして再生できます"
                    )
                }
                .padding(.horizontal, 30)
                
                Button {
                    ViewStore(store, observe: { $0 }).send(.tutorialDismissed)
                } label: {
                    Text(LocalizedStringKey("始める"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .cornerRadius(25)
                }
                .padding(.top, 30)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .padding(.horizontal, 20)
        }
    }
}

struct TutorialItem: View {
    let icon: String
    let title: String
    let description: String
    let customView: AnyView?
    
    init(icon: String, title: String, description: String, customView: AnyView? = nil) {
        self.icon = icon
        self.title = title
        self.description = description
        self.customView = customView
    }
    
    var body: some View {
        HStack(spacing: 15) {
            if let customView = customView {
                customView
            } else {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
} 