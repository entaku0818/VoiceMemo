//
//  PreviewPlaylistRepository.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/25.
//

import Foundation
final class PreviewPlaylistRepository: PlaylistRepository {

    private var playlists: [Playlist]

    init() {
        // サンプルデータの作成
        self.playlists = [
            Playlist(
                id: UUID(),
                name: "お気に入り",
                createdAt: Date(),
                updatedAt: Date()
            ),
            Playlist(
                id: UUID(),
                name: "通勤中",
                createdAt: Date().addingTimeInterval(-86400), // 1日前
                updatedAt: Date().addingTimeInterval(-86400)
            ),
            Playlist(
                id: UUID(),
                name: "勉強用",
                createdAt: Date().addingTimeInterval(-172800), // 2日前
                updatedAt: Date().addingTimeInterval(-172800)
            )
        ]
    }

    func create(name: String) async throws -> Playlist {
        let playlist = Playlist(
            id: UUID(),
            name: name,
            createdAt: Date(),
            updatedAt: Date()
        )
        playlists.insert(playlist, at: 0)
        return playlist
    }

    func fetchAll() async throws -> [Playlist] {
        playlists
    }

    func fetch(by id: UUID) async throws -> PlaylistDetail? {
        guard let playlist = playlists.first else {
            return nil
        }

        // プレビュー用のダミーVoiceデータを作成
        let mockVoices = [
            VoiceMemoRepository.Voice(
                title: "テスト音声1",
                url: URL(string: "file://test1.m4a")!,
                id: UUID(),
                text: "テストテキスト1",
                createdAt: Date(),
                updatedAt: Date(),
                duration: 60.0,
                fileFormat: "m4a",
                samplingFrequency: 44100,
                quantizationBitDepth: 16,
                numberOfChannels: 1,
                isCloud: false
            ),
            VoiceMemoRepository.Voice(
                title: "テスト音声2",
                url: URL(string: "file://test2.m4a")!,
                id: UUID(),
                text: "テストテキスト2",
                createdAt: Date(),
                updatedAt: Date(),
                duration: 120.0,
                fileFormat: "m4a",
                samplingFrequency: 44100,
                quantizationBitDepth: 16,
                numberOfChannels: 1,
                isCloud: false
            )
        ]

        return PlaylistDetail(
            id: playlist.id,
            name: playlist.name,
            voices: mockVoices,
            createdAt: playlist.createdAt,
            updatedAt: playlist.updatedAt
        )
    }

    func update(_ playlist: Playlist, name: String) async throws -> Playlist {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw PlaylistRepositoryError.notFound
        }

        let updated = Playlist(
            id: playlist.id,
            name: name,
            createdAt: playlist.createdAt,
            updatedAt: Date()
        )
        playlists[index] = updated
        return updated
    }

    func addVoice(voiceId: UUID, to playlist: Playlist) async throws -> Playlist {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw PlaylistRepositoryError.notFound
        }

        let updated = Playlist(
            id: playlist.id,
            name: playlist.name,
            createdAt: playlist.createdAt,
            updatedAt: Date()
        )
        playlists[index] = updated
        return updated
    }

    func removeVoice(voiceId: UUID, from playlist: Playlist) async throws -> Playlist {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw PlaylistRepositoryError.notFound
        }

        let updated = Playlist(
            id: playlist.id,
            name: playlist.name,
            createdAt: playlist.createdAt,
            updatedAt: Date()
        )
        playlists[index] = updated
        return updated
    }

    func delete(_ playlist: Playlist) async throws {
        playlists.removeAll { $0.id == playlist.id }
    }

    func deleteAll() async throws {
        playlists.removeAll()
    }
}
