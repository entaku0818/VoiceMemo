//
//  Constants.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 15.6.2023.
//

import Foundation
class Constants {


    enum FileFormat: String, CaseIterable {
        case WAV
        case AAC
    }

    enum SamplingFrequency: Int, CaseIterable {
        case hz11000 = 11000
        case hz22000 = 22000
        case hz44100 = 44100
        case hz88200 = 88200

        var stringValue: String {
            switch self {
            case .hz11000:
                return "11,000Hz"
            case .hz22000:
                return "22,000Hz"
            case .hz44100:
                return "44,100Hz"
            case .hz88200:
                return "88,200Hz"
            }
        }
    }

}
