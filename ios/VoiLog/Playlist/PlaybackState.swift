//
//  Untitled.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2025/06/21.
//

import Foundation

enum PlaybackState: Equatable {
  case idle
  case playing
  case paused
}

enum SortOption: String, CaseIterable, Equatable {
  case dateDescending = "日付順（新しい順）"
  case dateAscending = "日付順（古い順）"
  case titleAscending = "タイトル順（A-Z）"
  case durationDescending = "時間長順（長い順）"
  case durationAscending = "時間長順（短い順）"
}

enum DurationFilter: String, CaseIterable, Equatable {
  case all = "すべて"
  case short = "短い（1分未満）"
  case medium = "中間（1-5分）"
  case long = "長い（5分以上）"

  func matches(duration: TimeInterval) -> Bool {
    switch self {
    case .all: return true
    case .short: return duration < 60
    case .medium: return duration >= 60 && duration < 300
    case .long: return duration >= 300
    }
  }
}
