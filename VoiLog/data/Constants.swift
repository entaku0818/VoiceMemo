//
//  Constants.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 15.6.2023.
//

import Foundation
import CoreAudioTypes

class Constants {


    enum FileFormat: String, CaseIterable {
        case WAV
        case AAC
        
        var audioId: AudioFormatID {
            switch self {
            case .WAV:
                return kAudioFormatLinearPCM
            case .AAC:
                return kAudioFormatMPEG4AAC
            }
        }
    }

    enum SamplingFrequency: Double, CaseIterable {
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


    enum QuantizationBitDepth: Int, CaseIterable {
        case bit8 = 8
        case bit16 = 16
        case bit24 = 24
        case bit32 = 32

        var stringValue: String {
            switch self {
            case .bit8:
                return "8bit"
            case .bit16:
                return "16bit"
            case .bit24:
                return "24bit"
            case .bit32:
                return "32bit"
            }
        }
    }
    

}
