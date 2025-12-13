//
//  Playlist.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/23.
//

import Foundation
// MARK: - Models
struct Playlist: Equatable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
