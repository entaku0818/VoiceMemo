//
//  File.swift
//  VoiLogTests
//
//  Created by 遠藤拓弥 on 2024/12/26.
//

@testable import VoiLog
import XCTest
import ComposableArchitecture

@MainActor
final class PlaylistDetailFeatureTests: XCTestCase {



    func testPlaybackSpeedChange() async {
        let store = TestStore(initialState: PlaylistDetailFeature.State(
            id: UUID(),
            playbackSpeed: .normal
        )) {
            PlaylistDetailFeature()
        }

        await store.send(.changePlaybackSpeed) {
            $0.playbackSpeed = .faster
        }
    }
}
