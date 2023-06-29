//
//  Environment.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 29.6.2023.
//

import Foundation

class EnvironmentProcess {
    static var processInfo: ProcessInfo {
        return ProcessInfo.processInfo
    }

    static func getEnvironmentVariable(_ variableName: String) -> String? {
        return processInfo.environment[variableName]
    }
}
