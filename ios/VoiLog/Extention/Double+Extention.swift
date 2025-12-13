//
//  Double+Extention.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 9.9.2023.
//

import Foundation

extension Double {
    func formattedAsKHz() -> String {
        let kHzValue = self / 1000.0
        return String(format: "%.1f kHz", kHzValue)
    }
}
