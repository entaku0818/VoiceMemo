//
//  UserDe.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 15.6.2023.
//

import Foundation
class UserDefaultsManager {
    static let shared = UserDefaultsManager()

    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults.standard
    }

    // ファイル形式の設定値を保存するプロパティ
    var selectedFileFormat: String {
        get {
            return defaults.string(forKey: "SelectedFileFormat") ?? Constants.defaultFileFormat.rawValue
        }
        set {
            defaults.set(newValue, forKey: "SelectedFileFormat")
        }
    }
    
    var samplingFrequency: Double {
        get {
            return defaults.double(forKey: "SamplingFrequency") ?? Constants.defaultSamplingFrequency.rawValue
        }
        set {
            defaults.set(newValue, forKey: "SamplingFrequency")
        }
    }
    
    var quantizationBitDepth: Int {
        get {
            return defaults.integer(forKey: "QuantizationBitDepth") ?? Constants.defaultQuantizationBitDepth.rawValue
        }
        set {
            defaults.set(newValue, forKey: "QuantizationBitDepth")
        }
    }

}
