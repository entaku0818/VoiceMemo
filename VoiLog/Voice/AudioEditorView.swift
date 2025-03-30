import SwiftUI
import ComposableArchitecture

struct AudioEditorView: View {
    let store: StoreOf<AudioEditorReducer>
    @Environment(\.presentationMode) private var presentationMode
    
    // 時間表示用のフォーマッタ
    private let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Button("キャンセル") {
                        viewStore.send(.cancel)
                    }
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Text("音声編集中")
                        .multilineTextAlignment(.center)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("保存") {
                        viewStore.send(.save)
                    }
                    .disabled(!viewStore.isEdited)
                }
                .padding()
                
                // 波形表示
                ZStack {
                    if viewStore.isLoadingWaveform {
                        ProgressView("波形データを読み込んでいます...")
                            .progressViewStyle(CircularProgressViewStyle())
                    } else if viewStore.waveformData.isEmpty {
                        Text("波形データがありません")
                            .foregroundColor(.gray)
                    } else {
                        WaveformView(
                            waveformData: viewStore.waveformData,
                            selectedRange: viewStore.selectedRange,
                            currentTime: viewStore.currentPlaybackTime,
                            duration: viewStore.duration,
                            onRangeSelected: { range in
                                viewStore.send(.selectRange(range))
                            },
                            onSeek: { position in
                                viewStore.send(.seek(to: position))
                            }
                        )
                    }
                }
                .frame(height: 150)
                .padding()
                
                // 再生時間表示
                HStack {
                    Text(formatTime(viewStore.currentPlaybackTime))
                        .font(.caption)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text(formatTime(viewStore.duration))
                        .font(.caption)
                        .monospacedDigit()
                }
                .padding(.horizontal)
                
                // 再生コントロール
                HStack(spacing: 30) {
                    Button(action: {
                        viewStore.send(.seek(to: max(0, viewStore.currentPlaybackTime - 5)))
                    }) {
                        Image(systemName: "gobackward.5")
                            .font(.title2)
                    }
                    
                    Button(action: {
                        viewStore.send(.playPause)
                    }) {
                        Image(systemName: viewStore.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 50))
                    }
                    
                    Button(action: {
                        viewStore.send(.seek(to: min(viewStore.duration, viewStore.currentPlaybackTime + 5)))
                    }) {
                        Image(systemName: "goforward.5")
                            .font(.title2)
                    }
                }
                .padding()
                
                Divider()
                
                // 編集ツールバー
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        // 分割ボタン
                        Button(action: {
                            viewStore.send(.split)
                        }) {
                            VStack {
                                Image(systemName: "scissors.badge.ellipsis")
                                    .font(.title2)
                                Text("分割")
                                    .font(.caption)
                            }
                            .frame(width: 70, height: 70)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .disabled(viewStore.selectedRange == nil ||
                                 viewStore.selectedRange?.lowerBound != viewStore.selectedRange?.upperBound ||
                                 viewStore.processingOperation != nil)
                    }
                    .padding()
                }
                
                // 編集ヘルプテキスト
                if viewStore.selectedRange == nil {
                    Text("波形を2回タップして分割位置を指定してください\n(1回目のタップで開始点、2回目のタップで分割ポイント)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                } else if let range = viewStore.selectedRange, range.lowerBound == range.upperBound {
                    Text("分割ポイントを選択しています: \(formatTime(range.lowerBound))\n赤い線の位置で分割されます\n(分割すると赤い線までの前半部分が保存されます)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                } else if let range = viewStore.selectedRange {
                    Text("選択範囲: \(formatTime(range.lowerBound)) - \(formatTime(range.upperBound))\n(範囲をタップするとリセットされます)")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // 編集履歴
                if !viewStore.editHistory.isEmpty {
                    VStack(alignment: .leading) {
                        Text("編集履歴:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(Array(viewStore.editHistory.enumerated()), id: \.offset) { index, operation in
                                    HStack {
                                        Text("\(index + 1).")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text(operation.description)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .frame(height: 100)
                    }
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding()
                }
            }
            .onAppear {
                viewStore.send(.loadAudio)
            }
            .onChange(of: viewStore.shouldDismiss) { shouldDismiss in
                if shouldDismiss {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .alert(isPresented: Binding(
                get: { viewStore.errorMessage != nil },
                set: { if !$0 { viewStore.send(.errorOccurred("")) } }
            )) {
                if let message = viewStore.errorMessage, message.starts(with: "分割が完了") {
                    // 成功メッセージの場合
                    return Alert(
                        title: Text("処理完了"),
                        message: Text(message),
                        dismissButton: .default(Text("OK"))
                    )
                } else {
                    // エラーメッセージの場合
                    return Alert(
                        title: Text("エラー"),
                        message: Text(viewStore.errorMessage ?? ""),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .overlay(
                Group {
                    if viewStore.processingOperation != nil {
                        ZStack {
                            Color.black.opacity(0.5)
                                .edgesIgnoringSafeArea(.all)
                            
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                
                                Text("処理中...")
                                    .foregroundColor(.white)
                                    .padding(.top)
                            }
                            .padding(30)
                            .background(Color.gray.opacity(0.7))
                            .cornerRadius(10)
                        }
                    }
                }
            )
        }
        .navigationBarHidden(true)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        timeFormatter.string(from: time) ?? "0:00"
    }
}

// プレースホルダー拡張
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct AudioEditorView_Previews: PreviewProvider {
    static var previews: some View {
        AudioEditorView(
            store: Store(
                initialState: AudioEditorReducer.State(
                    memoID: UUID(),
                    audioURL: URL(string: "file:///path/to/audio.m4a")!,
                    originalTitle: "テスト録音",
                    duration: 60.0,
                    waveformData: (0..<100).map { _ in Float.random(in: 0...1) },
                    shouldDismiss: false
                ),
                reducer: { AudioEditorReducer() }
            )
        )
    }
} 