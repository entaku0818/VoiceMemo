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
    let testDate = Date()
    let testVoice = VoiceMemoRepository.Voice(
        title: "Test Voice",
        url: URL(string: "file://test.m4a")!,
        id: UUID(),
        text: "Test Text",
        createdAt: Date(),
        updatedAt: Date(),
        duration: 60.0,
        fileFormat: "m4a",
        samplingFrequency: 44100,
        quantizationBitDepth: 16,
        numberOfChannels: 1,
        isCloud: false
    )



    func testEditPlaylistName() async {
        let playlistId = UUID()
        let initialDetail = PlaylistDetail(
            id: playlistId,
            name: "Old Name",
            voices: [],
            createdAt: testDate,
            updatedAt: testDate
        )

        let updatedDetail = PlaylistDetail(
            id: playlistId,
            name: "New Name",
            voices: [],
            createdAt: testDate,
            updatedAt: testDate
        )

        let store = TestStore(
            initialState: PlaylistDetailFeature.State(
                id: playlistId,
                name: "Old Name",
                voices: [],
                createdAt: testDate,
                updatedAt: testDate
            )
        ) {
            PlaylistDetailFeature()
        }

        await store.send(.editButtonTapped) {
            $0.isEditingName = true
            $0.editingName = "Old Name"
        }

        await store.send(.updateName("New Name")) {
            $0.editingName = "New Name"
        }

    }
}
