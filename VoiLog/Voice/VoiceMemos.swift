//
//  VoiceMemos.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/11/14.
//

import Foundation
import ComposableArchitecture
import UIKit
import StoreKit
struct VoiceMemos: Reducer {
    struct State: Equatable {
        enum Mode {
            case recording
            case playback
        }
        @PresentationState var alert: AlertState<AlertAction>?
        var audioRecorderPermission = RecorderPermission.undetermined
        @PresentationState var recordingMemo: RecordingMemo.State?
        var voiceMemos: IdentifiedArrayOf<VoiceMemoReducer.State> = []
        var isMailComposePresented: Bool = false
        var syncStatus: SyncStatus = .notSynced
        var hasPurchasedPremium: Bool = false
        var currentMode: Mode = .recording

        var currentPlayingMemo: VoiceMemoReducer.State?


        enum RecorderPermission {
            case allowed
            case denied
            case undetermined
        }
        enum SyncStatus {
            case synced
            case syncing
            case notSynced
            case cantUseCloud
        }

    }

    enum Action: Equatable {
        case alert(PresentationAction<AlertAction>)
        case onAppear
        case onDelete(uuid: UUID)
        case openSettingsButtonTapped
        case recordButtonTapped
        case recordPermissionResponse(Bool)
        case recordingMemo(PresentationAction<RecordingMemo.Action>)
        case voiceMemos(id: VoiceMemoReducer.State.ID, action: VoiceMemoReducer.Action)
        case mailComposeDismissed
        case synciCloud
        case syncSuccess
        case syncFailure
        case toggleMode

    }

    enum AlertAction: Equatable {
        case onAddReview
        case onGoodReview
        case onBadReview
        case onMailTap
    }

    @Dependency(\.audioRecorder.requestRecordPermission) var requestRecordPermission
    @Dependency(\.date) var date
    @Dependency(\.openSettings) var openSettings
    @Dependency(\.temporaryDirectory) var temporaryDirectory
    @Dependency(\.uuid) var uuid

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .toggleMode:
                state.currentMode = (state.currentMode == .playback) ? .recording : .playback
                return .none
            case .onAppear:

                let installDate = UserDefaultsManager.shared.installDate
                let reviewCount = UserDefaultsManager.shared.reviewRequestCount

                state.hasPurchasedPremium = UserDefaultsManager.shared.hasPurchasedProduct

                // 初回起動時
                if let installDate = installDate {
                    let currentDate = Date()
                    if let interval = Calendar.current.dateComponents([.day], from: installDate, to: currentDate).day {
                        if interval >= 7 && reviewCount == 0 {
                            if UIApplication.shared.connectedScenes.first is UIWindowScene {
                                state.alert = AlertState {
                                    TextState("シンプル録音について")
                                } actions: {
                                    ButtonState(action: .send(.onGoodReview)) {
                                        TextState("はい")
                                    }
                                    ButtonState(action: .send(.onBadReview)) {
                                        TextState("いいえ、フィードバックを送信")
                                    }
                                } message: {
                                    TextState(
                                        "シンプル録音に満足していますか？"
                                    )
                                }
                                UserDefaultsManager.shared.reviewRequestCount = reviewCount + 1
                            }
                        }
                    }
                }else{
                    UserDefaultsManager.shared.installDate = Date()
                }


                return .none

            case let .onDelete(uuid):
                state.voiceMemos.removeAll { $0.uuid == uuid }
                let voiceMemoRepository: VoiceMemoRepository = VoiceMemoRepository(coreDataAccessor: VoiceMemoCoredataAccessor(), cloudUploader: CloudUploader())
                voiceMemoRepository.delete(id: uuid)
                return .none

            case .openSettingsButtonTapped:
                return .run { _ in
                    await self.openSettings()
                }
            case .synciCloud:
                state.syncStatus = .syncing
                return .run { send in
                    let voiceMemoRepository: VoiceMemoRepository = VoiceMemoRepository(coreDataAccessor: VoiceMemoCoredataAccessor(), cloudUploader: CloudUploader())
                    let result = await voiceMemoRepository.syncToCloud()
                    if result {
                        await send(.syncSuccess)
                    } else {
                        await send(.syncFailure)
                    }
                }

            case .syncSuccess:
                let voiceMemoRepository: VoiceMemoRepository = VoiceMemoRepository(coreDataAccessor: VoiceMemoCoredataAccessor(), cloudUploader: CloudUploader())
                state.voiceMemos = IdentifiedArrayOf(uniqueElements:  voiceMemoRepository.selectAllData())
                state.syncStatus = .synced
                return .none

            case .syncFailure:
                state.syncStatus = .notSynced
                return .none


            case .recordButtonTapped:
                switch state.audioRecorderPermission {
                case .undetermined:
                    return .run { send in
                        await send(.recordPermissionResponse(self.requestRecordPermission()))
                    }

                case .denied:
                    state.alert = AlertState { TextState("Permission is required to record voice memos.") }
                    return .none

                case .allowed:

                    state.recordingMemo = newRecordingMemo
                    return .none
                }

            case let .recordingMemo(.presented(.delegate(.didFinish(.success(recordingMemo))))):
                state.recordingMemo = nil
                state.voiceMemos.insert(
                    VoiceMemoReducer.State(

                        uuid: recordingMemo.uuid,
                        date: recordingMemo.date,
                        duration: recordingMemo.duration, time: 0,
                        url: recordingMemo.url,
                        text: recordingMemo.resultText,
                        fileFormat: recordingMemo.fileFormat,
                        samplingFrequency: recordingMemo.samplingFrequency,
                        quantizationBitDepth: recordingMemo.quantizationBitDepth,
                        numberOfChannels: recordingMemo.numberOfChannels,
                        hasPurchasedPremium: UserDefaultsManager.shared.hasPurchasedProduct
                    ),
                    at: 0
                )
                let voiceMemoRepository: VoiceMemoRepository = VoiceMemoRepository(coreDataAccessor: VoiceMemoCoredataAccessor(), cloudUploader: CloudUploader())
                voiceMemoRepository.insert(state: recordingMemo)

                return .none

            case .recordingMemo(.presented(.delegate(.didFinish(.failure)))):
                state.alert = AlertState { TextState("Voice memo recording failed.") }
                state.recordingMemo = nil

                return .none

            case .recordingMemo:
                return .none

            case let .recordPermissionResponse(permission):
                state.audioRecorderPermission = permission ? .allowed : .denied
                if permission {
                    state.recordingMemo = newRecordingMemo
                    return .none
                } else {
                    state.alert = AlertState { TextState("Permission is required to record voice memos.") }
                    return .none
                }

            case let .voiceMemos(id: id, action: .delegate(delegateAction)):
               switch delegateAction {
               case .playbackFailed:
                   state.alert = AlertState { TextState("Voice memo playback failed.") }
                   return .none

               case .playbackStarted:
                   state.currentPlayingMemo = state.voiceMemos[id: id]
                   for memoID in state.voiceMemos.ids where memoID != id {
                       state.voiceMemos[id: memoID]?.mode = .notPlaying
                   }
                   return .none

               case .playbackStopped:
                   state.currentPlayingMemo = nil
                   for memoID in state.voiceMemos.ids where memoID != id {
                       state.voiceMemos[id: memoID]?.mode = .notPlaying
                   }
                   return .none

               case let .playbackInProgress(currentTime):
                   if let currentMemoId = state.currentPlayingMemo?.id,
                      currentMemoId == id {
                       state.voiceMemos[id: id]?.time = currentTime
                   }
                   return .none
               }

            case .voiceMemos:
                return .none
            case .alert(.presented(.onAddReview)):


                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                }
                return .none
            case .alert(.presented(.onGoodReview)):

                state.alert = AlertState(
                    title: TextState("シンプル録音について"),
                    message: TextState("ご利用ありがとうございます！次の画面でアプリの評価をお願いします。"),
                    dismissButton: .default(TextState("OK"),
                                            action: .send(.onAddReview))
                )
                return .none
            case .alert(.presented(.onBadReview)):

                state.alert = AlertState(
                    title: TextState("ご不便かけて申し訳ありません"),
                    message: TextState("次の画面のメールにて詳細に状況を教えてください。"),
                    dismissButton: .default(TextState("OK"),
                                            action: .send(.onMailTap))
                )
                return .none

            case .alert(.presented(.onMailTap)):

                state.alert = nil
                state.isMailComposePresented.toggle()
                return .none
            case .alert(.dismiss):
                return .none

            case .mailComposeDismissed:
                state.isMailComposePresented = false
                return .none
            }
        }
        .ifLet(\.$alert, action: /Action.alert)
        .ifLet(\.$recordingMemo, action: /Action.recordingMemo) {
            RecordingMemo()
        }
        .forEach(\.voiceMemos, action: /Action.voiceMemos) {
            VoiceMemoReducer()
        }


    }

    func documentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    private var newRecordingMemo: RecordingMemo.State {
        RecordingMemo.State(
            uuid: UUID(),
            date: self.date.now,
            duration: 0,
            volumes: 0.0,
            resultText: "",
            mode: .recording,
            fileFormat: "m4a",
            samplingFrequency: 44100,
            quantizationBitDepth: 16,
            numberOfChannels: 2,
            url: self.documentsDirectory()
                .appendingPathComponent(self.uuid().uuidString)
                .appendingPathExtension("m4a"),
            startTime: 0,
            time: 0
        )
    }




}

