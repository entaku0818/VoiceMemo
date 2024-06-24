//
//  test.swift
//  VoiLogTests
//
//  Created by 遠藤拓弥 on 2024/06/16.
//

import Foundation
import XCTest
import ComposableArchitecture
@testable import VoiLog

@MainActor
final class VoiceMemosTests: XCTestCase {

    func testOnAppear_FirstLaunch() async {

        let store =  TestStore(initialState: VoiceMemos.State()) {
            VoiceMemos()
        }

        await store.send(.onAppear)
        XCTAssertNotNil(UserDefaultsManager.shared.installDate)
    }

    func testOnAppear_ReviewPrompt() async {
        let initialDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        UserDefaultsManager.shared.installDate = initialDate
        UserDefaultsManager.shared.reviewRequestCount = 0

        let store = TestStore(initialState: VoiceMemos.State()) {
            VoiceMemos()
        }

        await store.send(.onAppear) {
            $0.alert = AlertState(
                title: TextState("シンプル録音について"),
                message: TextState("シンプル録音に満足していますか？"),
                buttons: [
                    .default(TextState("はい"), action: .send(.onGoodReview)),
                    .default(TextState("いいえ、フィードバックを送信"), action: .send(.onBadReview))
                ]
            )
        }

        XCTAssertEqual(UserDefaultsManager.shared.reviewRequestCount, 1)
    }

    func testOnDelete() async {
        let uuid = UUID()
        let voiceMemo = VoiceMemoReducer.State(
            uuid: uuid,
            date: Date(),
            duration: 60.0,
            time: 60.0,
            url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a"),
            text: "サンプルメモ",
            fileFormat: "m4a",
            samplingFrequency: 44100.0,
            quantizationBitDepth: 16,
            numberOfChannels: 2,
            hasPurchasedPremium: false
        )


        var initialState = VoiceMemos.State()
        initialState.voiceMemos = [voiceMemo]

        let store = TestStore(initialState: initialState) {
            VoiceMemos()
        }

        await store.send(.onDelete(uuid: uuid)) {
            $0.voiceMemos = []
        }
    }


    func testRecordPermissionResponse_Denied() async {
        let store = TestStore(initialState: VoiceMemos.State()) {
            VoiceMemos()
        }

        await store.send(.recordPermissionResponse(false)) {
            $0.audioRecorderPermission = .denied
            $0.alert = AlertState(title: TextState("Permission is required to record voice memos."))
        }
    }

}

