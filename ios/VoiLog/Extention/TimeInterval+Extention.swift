//
//  File.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/11/11.
//

import Foundation
extension TimeInterval {
    func formattedTime() -> String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
