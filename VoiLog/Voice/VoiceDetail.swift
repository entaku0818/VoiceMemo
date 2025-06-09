//
//  VoiceDetail.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 24.6.2023.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation

struct VoiceMemoDetail: View {
    let store: StoreOf<VoiceMemoReducer>
    @State private var showingAudioEditor = false
    @State private var showingPaywall = false
    @State private var showingShareOptions = false

    @Environment(\.presentationMode) var presentationMode

    let admobUnitId: String

    // 時間表示フォーマッター
    private let dateComponentsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in

            VStack {
                TextField(
                    "名称未設定", // プレースホルダーのテキストを指定
                    text: viewStore.binding(
                        get: \.title,
                        send: VoiceMemoReducer.Action.titleTextFieldChanged)
                ).font(.system(size: 18))
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 0.5)
                ).padding()
                HStack {

                    if let formattedDate = formatDateTime(viewStore.date) {
                        Text(formattedDate)
                            .font(.footnote.monospacedDigit())
                            .foregroundColor(Color(.systemGray))
                    }
                    Spacer()

                    dateComponentsFormatter.string(from: viewStore.time == 0 ? viewStore.duration : viewStore.time).map {
                        Text($0)
                            .font(.footnote.monospacedDigit())
                            .foregroundColor(Color(.systemGray))
                    }
                    Button(action: { viewStore.send(.playButtonTapped) }) {
                        Image(systemName: viewStore.mode.isPlaying ? "stop.circle" : "play.circle")
                            .font(.system(size: 36))
                    }

                }.padding()

                HStack (spacing: 8){
                    Button(action: {
                        viewStore.send(.toggleLoop)
                    }) {
                        Image(systemName: "repeat")
                            .imageScale(.large)
                            .font(.system(size: 16, weight: viewStore.isLooping ? .heavy : .light))
                            .padding()
                    }
                    Button(action: {
                        viewStore.send(.skipBy(-60))
                    }) {
                        Image(systemName: "gobackward.60")
                            .imageScale(.large)
                            .padding()
                    }
                    Button(action: {
                        viewStore.send(.skipBy(-10))
                    }) {
                        Image(systemName: "gobackward.10")
                            .imageScale(.large)
                            .padding()
                    }
                    Button(action: {
                        viewStore.send(.skipBy(10))
                    }) {
                        Image(systemName: "goforward.10")
                            .imageScale(.large)
                            .padding()
                    }
                    Button(action: {
                        viewStore.send(.skipBy(60))
                    }) {
                        Image(systemName: "goforward.60")
                            .imageScale(.large)
                            .padding()
                    }
                    Button(action: { viewStore.send(.onTapPlaySpeed) }) {
                        Text(viewStore.playSpeed.description)
                            .font(.system(size: 16))
                    }

                }

                ProgressView(value: viewStore.time / viewStore.duration)
                    .frame(height: 10)
                    .progressViewStyle(.linear)
                    .accentColor(Color.gray)
                    .padding()

                // 編集ボタンを追加
                Button(action: {
                    if viewStore.hasPurchasedPremium {
                        // プレミアム購入済みの場合は編集画面へ
                        showingAudioEditor = true
                    } else {
                        // 未購入の場合はPaywallへ
                        showingPaywall = true
                    }
                }) {
                    HStack {
                        Image(systemName: "waveform")
                        Text("音声を編集")
                    }
                    .frame(width: 200, height: 40)
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .padding(.bottom)
                .fullScreenCover(isPresented: $showingAudioEditor) {
                    NavigationView {
                        // URLを正しく構築
                        let documentsPath = NSHomeDirectory() + "/Documents"
                        let audioFilePath = documentsPath + "/" + viewStore.url.lastPathComponent
                        let fullURL = URL(fileURLWithPath: audioFilePath)
                        
                        AudioEditorView(
                            store: Store(
                                initialState: AudioEditorReducer.State(
                                    memoID: viewStore.uuid,
                                    audioURL: fullURL,
                                    originalTitle: viewStore.title,
                                    duration: viewStore.duration
                                ),
                                reducer: { AudioEditorReducer() }
                            )
                        )
                    }
                }
                .sheet(isPresented: $showingPaywall) {
                    PaywallView(purchaseManager: PurchaseManager.shared)
                }

                ScrollView {
                    Text(viewStore.text)
                }.frame(minHeight: 50, maxHeight: 200)
                .padding(16)
                Spacer()
                if !viewStore.hasPurchasedPremium {
                    AdmobBannerView(unitId: admobUnitId).frame(width: .infinity, height: 50)
                }

            }
            .onAppear {
                viewStore.send(.onAppear)
            }
            .navigationBarItems(trailing:
                Button(action: {
                    showingShareOptions = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            )
            .actionSheet(isPresented: $showingShareOptions) {
                ActionSheet(
                    title: Text("シェア先を選択"),
                    message: Text("どちらの形式でシェアしますか？"),
                    buttons: [
                        .default(Text("Mac用 (標準形式)")) {
                            shareForMac(viewStore: viewStore)
                        },
                        .default(Text("Windows用 (MP4形式)")) { 
                            shareForWindows(viewStore: viewStore)
                        },
                        .cancel(Text("キャンセル"))
                    ]
                )
            }
        }
    }

    func formatDateTime(_ date: Date) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .medium
        dateFormatter.locale = Locale.autoupdatingCurrent // Set to the default locale of the user's device
        return dateFormatter.string(from: date)
    }

    // Mac用のシェア処理（m4aのまま）
    private func shareForMac(viewStore: ViewStore<VoiceMemoReducer.State, VoiceMemoReducer.Action>) {
        let textToShare = viewStore.title
        var itemsToShare: [Any] = [textToShare]
        let inputDocumentsPath = NSHomeDirectory() + "/Documents/" + viewStore.url.lastPathComponent
        let audioFileURL = NSURL(fileURLWithPath: inputDocumentsPath)
        itemsToShare.append(audioFileURL)
        
        presentActivityViewController(items: itemsToShare)
    }
    
    // Windows用のシェア処理（WAV形式に変換）
    // Windows用のシェア処理（MP4形式に変換）
    private func shareForWindows(viewStore: ViewStore<VoiceMemoReducer.State, VoiceMemoReducer.Action>) {
        let textToShare = viewStore.title
        let inputDocumentsPath = NSHomeDirectory() + "/Documents/" + viewStore.url.lastPathComponent
        let inputURL = URL(fileURLWithPath: inputDocumentsPath)

        // MP4ファイルの出力パス
        let baseFileName = viewStore.url.lastPathComponent.replacingOccurrences(of: ".m4a", with: "")
        let outputFileName = "\(baseFileName)_windows.mp4"
        let outputPath = NSHomeDirectory() + "/Documents/" + outputFileName
        let outputURL = URL(fileURLWithPath: outputPath)

        convertToMP4(inputURL: inputURL, outputURL: outputURL) { success in
            DispatchQueue.main.async {
                if success {
                    var itemsToShare: [Any] = [textToShare + " (MP4形式)"]
                    let mp4FileURL = NSURL(fileURLWithPath: outputPath)
                    itemsToShare.append(mp4FileURL)
                    self.presentActivityViewController(items: itemsToShare)
                } else {
                    // 変換に失敗した場合は元のファイルをシェア
                    var itemsToShare: [Any] = [textToShare]
                    let audioFileURL = NSURL(fileURLWithPath: inputDocumentsPath)
                    itemsToShare.append(audioFileURL)
                    self.presentActivityViewController(items: itemsToShare)
                }
            }
        }
    }

    // 関数名も変更
    private func convertToMP4(inputURL: URL, outputURL: URL, completion: @escaping (Bool) -> Void) {
        do {
            let asset = AVAsset(url: inputURL)

            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                completion(false)
                return
            }

            // 既存のファイルがあれば削除
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = AVFileType.mp4  // MP4形式

            exportSession.audioMix = nil
            exportSession.videoComposition = nil

            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    completion(true)
                case .failed, .cancelled:
                    print("MP4変換エラー: \(exportSession.error?.localizedDescription ?? "不明なエラー")")
                    completion(false)
                default:
                    completion(false)
                }
            }
        } catch {
            print("MP4変換処理エラー: \(error.localizedDescription)")
            completion(false)
        }
    }

    // UIActivityViewControllerを表示する共通処理
    private func presentActivityViewController(items: [Any]) {
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(activityViewController, animated: true, completion: nil)
    }
}

struct VoiceDetail_Previews: PreviewProvider {
    static var previews: some View {

        VoiceMemoDetail(
            store: Store(
                initialState: VoiceMemoReducer.State(
                    uuid: UUID(),
                    date: Date(),
                    duration: 180,
                    time: 0,
                    mode: .notPlaying,
                    title: "",
                    url: URL(fileURLWithPath: ""),
                    text: "",
                    fileFormat: "",
                    samplingFrequency: 0.0,
                    quantizationBitDepth: 0,
                    numberOfChannels: 0, hasPurchasedPremium: false
                )
            ) {
                VoiceMemoReducer()
            }, admobUnitId: ""
        )
    }
}
