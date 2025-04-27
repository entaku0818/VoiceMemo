//
//  File.swift
//  VoiLogTests
//
//  Created by 遠藤拓弥 on 2024/12/26.
//

@testable import VoiLog
import XCTest
import ComposableArchitecture
import SwiftTesting

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

    func mockPlaylistRepository() -> PlaylistRepository {
        let mockRepository = PlaylistRepository()
        @Dependency(\.playlistRepository) var repository
        repository = mockRepository
        return mockRepository
    }

    func testOnAppear() async throws {
        let playlistId = UUID()
        let detail = PlaylistDetail(
            id: playlistId,
            name: "Test Playlist",
            voices: [testVoice],
            createdAt: testDate,
            updatedAt: testDate
        )
        
        let initialState = PlaylistDetailFeature.State(
            id: playlistId,
            name: "",
            voices: [],
            createdAt: testDate,
            updatedAt: testDate
        )
        
        let mockPlaylistRepo = PlaylistRepository()
        mockPlaylistRepo.fetchPlaylist = { id in
            return detail
        }
        
        let reducer = PlaylistDetailFeature()
        
        try await withDependencies {
            $0.playlistRepository = mockPlaylistRepo
        } operation: {
            let testStore = try TestStore(initialState: initialState, reducer: reducer)
            
            await testStore.send(.view(.onAppear))
            await testStore.receive { state in
                state.isLoading = true
            }
            
            await testStore.receive(.dataLoaded(detail)) { state in
                state.name = detail.name
                state.voices = detail.voices
                state.createdAt = detail.createdAt
                state.updatedAt = detail.updatedAt
                state.isLoading = false
                state.error = nil
            }
        }
    }

    func testEditPlaylistName() async throws {
        let playlistId = UUID()
        let initialState = PlaylistDetailFeature.State(
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
        
        let mockPlaylistRepo = PlaylistRepository()
        mockPlaylistRepo.updatePlaylist = { playlist, newName in
            return Playlist(id: playlistId, name: newName)
        }
        mockPlaylistRepo.fetchPlaylist = { id in
            return updatedDetail
        }
        
        let reducer = PlaylistDetailFeature()
        
        try await withDependencies {
            $0.playlistRepository = mockPlaylistRepo
        } operation: {
            let testStore = try TestStore(initialState: initialState, reducer: reducer)
            
            await testStore.send(.view(.editButtonTapped))
            await testStore.receive { state in
                state.isEditingName = true
                state.editingName = "Old Name"
            }
            
            await testStore.send(.binding(.set(\.editingName, "New Name")))
            await testStore.receive { state in
                state.editingName = "New Name"
            }
            
            await testStore.send(.view(.saveNameButtonTapped))
            
            await testStore.receive(.nameUpdateSuccess(updatedDetail)) { state in
                state.name = "New Name"
                state.voices = []
                state.updatedAt = updatedDetail.updatedAt
                state.isEditingName = false
                state.editingName = ""
            }
        }
    }

    func testAddVoiceToPlaylist() async throws {
        let playlistId = UUID()
        let voiceId = UUID()
        
        let initialState = PlaylistDetailFeature.State(
            id: playlistId,
            name: "Test Playlist",
            voices: [],
            createdAt: testDate,
            updatedAt: testDate,
            isShowingVoiceSelection: true
        )
        
        let updatedDetail = PlaylistDetail(
            id: playlistId,
            name: "Test Playlist",
            voices: [testVoice],
            createdAt: testDate,
            updatedAt: testDate
        )
        
        let mockPlaylistRepo = PlaylistRepository()
        mockPlaylistRepo.addVoiceToPlaylist = { voiceId, playlist in
            return Playlist(id: playlistId, name: "Test Playlist")
        }
        mockPlaylistRepo.fetchPlaylist = { id in
            return updatedDetail
        }
        
        let reducer = PlaylistDetailFeature()
        
        try await withDependencies {
            $0.playlistRepository = mockPlaylistRepo
        } operation: {
            let testStore = try TestStore(initialState: initialState, reducer: reducer)
            
            await testStore.send(.view(.addVoiceToPlaylist(voiceId)))
            
            await testStore.receive(.voiceAddedToPlaylist(updatedDetail)) { state in
                state.name = updatedDetail.name
                state.voices = updatedDetail.voices
                state.updatedAt = updatedDetail.updatedAt
            }
        }
    }

    func testRemoveVoiceFromPlaylist() async throws {
        let playlistId = UUID()
        let voiceId = UUID()
        
        let initialState = PlaylistDetailFeature.State(
            id: playlistId,
            name: "Test Playlist",
            voices: [testVoice],
            createdAt: testDate,
            updatedAt: testDate
        )
        
        let updatedDetail = PlaylistDetail(
            id: playlistId,
            name: "Test Playlist",
            voices: [],
            createdAt: testDate,
            updatedAt: testDate
        )
        
        let mockPlaylistRepo = PlaylistRepository()
        mockPlaylistRepo.removeVoiceFromPlaylist = { voiceId, playlist in
            return Playlist(id: playlistId, name: "Test Playlist")
        }
        mockPlaylistRepo.fetchPlaylist = { id in
            return updatedDetail
        }
        
        let reducer = PlaylistDetailFeature()
        
        try await withDependencies {
            $0.playlistRepository = mockPlaylistRepo
        } operation: {
            let testStore = try TestStore(initialState: initialState, reducer: reducer)
            
            await testStore.send(.view(.removeVoice(voiceId)))
            
            await testStore.receive(.voiceRemoved(updatedDetail)) { state in
                state.name = updatedDetail.name
                state.voices = updatedDetail.voices
                state.updatedAt = updatedDetail.updatedAt
            }
        }
    }

    func testLoadVoiceMemos() async throws {
        let playlistId = UUID()
        let voiceId = testVoice.id
        let voiceUrl = testVoice.url
        
        let initialState = PlaylistDetailFeature.State(
            id: playlistId,
            name: "Test Playlist",
            voices: [testVoice],
            createdAt: testDate,
            updatedAt: testDate
        )
        
        let mockVoiceMemos = [
            VoiceMemoReducer.State(
                uuid: voiceId,
                date: testDate,
                duration: 60.0,
                time: 0,
                mode: .notPlaying,
                title: "Test Voice",
                url: voiceUrl,
                text: "Test Text",
                fileFormat: "m4a",
                samplingFrequency: 44100,
                quantizationBitDepth: 16,
                numberOfChannels: 1,
                hasPurchasedPremium: false
            )
        ]
        
        let mockVoiceMemoAccessor = MockVoiceMemoCoredataAccessor()
        mockVoiceMemoAccessor.fetchedVoices = [testVoice]
        
        let reducer = PlaylistDetailFeature()
        
        try await withDependencies {
            $0.voiceMemoCoredataAccessor = mockVoiceMemoAccessor
        } operation: {
            let testStore = try TestStore(initialState: initialState, reducer: reducer)
            
            await testStore.send(.view(.loadVoiceMemos))
            
            await testStore.receive(.voiceMemosLoaded(mockVoiceMemos)) { state in
                state.voiceMemos = IdentifiedArray(uniqueElements: mockVoiceMemos)
            }
        }
    }
}

extension PlaylistRepository {
    var fetchPlaylist: ((UUID) async throws -> PlaylistDetail?)? = nil
    var updatePlaylist: ((Playlist, String) async throws -> Playlist)? = nil
    var addVoiceToPlaylist: ((UUID, Playlist) async throws -> Playlist)? = nil
    var removeVoiceFromPlaylist: ((UUID, Playlist) async throws -> Playlist)? = nil
    
    func fetch(_ id: UUID) async throws -> PlaylistDetail? {
        if let fetchPlaylist = fetchPlaylist {
            return try await fetchPlaylist(id)
        }
        throw PlaylistRepositoryError.notFound
    }
    
    func update(_ playlist: Playlist, _ newName: String) async throws -> Playlist {
        if let updatePlaylist = updatePlaylist {
            return try await updatePlaylist(playlist, newName)
        }
        throw PlaylistRepositoryError.databaseError
    }
    
    func addVoice(_ voiceId: UUID, _ playlist: Playlist) async throws -> Playlist {
        if let addVoiceToPlaylist = addVoiceToPlaylist {
            return try await addVoiceToPlaylist(voiceId, playlist)
        }
        throw PlaylistRepositoryError.databaseError
    }
    
    func removeVoice(_ voiceId: UUID, _ playlist: Playlist) async throws -> Playlist {
        if let removeVoiceFromPlaylist = removeVoiceFromPlaylist {
            return try await removeVoiceFromPlaylist(voiceId, playlist)
        }
        throw PlaylistRepositoryError.databaseError
    }
}
