//
//  PlaylistDetail.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/12/25.
//

import Foundation
struct PlaylistDetail: Equatable {
    static func == (lhs: PlaylistDetail, rhs: PlaylistDetail) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.voices.map(\.id) == rhs.voices.map(\.id) &&
        lhs.createdAt == rhs.createdAt &&
        lhs.updatedAt == rhs.updatedAt
    }

    let id: UUID
    var name: String
    var voices: [VoiceMemoRepository.Voice]
    let createdAt: Date
    var updatedAt: Date

}
