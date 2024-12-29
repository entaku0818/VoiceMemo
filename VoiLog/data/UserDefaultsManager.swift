//
//  UserDefaultsManager.swift
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

    func logError(_ message: String) {
        let timestamp = Date().description(with: .current)
        let logMessage = "[\(timestamp)] \(message)"

        var errorLogs = defaults.array(forKey: "ErrorLogs") as? [String] ?? []
        errorLogs.append(logMessage)

        defaults.set(errorLogs, forKey: "ErrorLogs")
        defaults.synchronize()
    }

    // Property to retrieve error logs
    var errorLogs: [String] {
        defaults.array(forKey: "ErrorLogs") as? [String] ?? []
    }

    // ファイル形式の設定値を保存するプロパティ
    var selectedFileFormat: String {
        get {
            defaults.string(forKey: "SelectedFileFormat") ?? Constants.defaultFileFormat.rawValue
        }
        set {
            defaults.set(newValue, forKey: "SelectedFileFormat")
        }
    }

    var samplingFrequency: Double {
        get {
            let value = defaults.double(forKey: "SamplingFrequency")
            return value == 0 ? Constants.defaultSamplingFrequency.rawValue : value
        }
        set {
            defaults.set(newValue, forKey: "SamplingFrequency")
        }
    }

    var quantizationBitDepth: Int {
        get {
            let value = defaults.integer(forKey: "QuantizationBitDepth")
            return value == 0 ? Constants.defaultQuantizationBitDepth.rawValue : value
        }
        set {
            defaults.set(newValue, forKey: "QuantizationBitDepth")
        }
    }
    var numberOfChannels: Int {
        get {
            let value = defaults.integer(forKey: "NumberOfChannels")
            return value == 0 ? Constants.defaultNumberOfChannels.rawValue : value
        }
        set {
            defaults.set(newValue, forKey: "NumberOfChannels")
        }
    }

    var microphonesVolume: Double {
        get {
            let value = defaults.double(forKey: "MicrophonesVolume")
            return value == 0 ? Constants.defaultMicrophonesVolume.rawValue : value
        }
        set {
            defaults.set(newValue, forKey: "MicrophonesVolume")
        }
    }

    // インストール日を保存するプロパティ
    var installDate: Date? {
        get {
            defaults.object(forKey: "InstallDate") as? Date
        }
        set {
            defaults.set(newValue, forKey: "InstallDate")
        }
    }

    // レビューのリクエストカウントを保存する
    var reviewRequestCount: Int {
        get {
            defaults.object(forKey: "ReviewRequestCount") as? Int ?? 0
        }
        set {
            defaults.set(newValue, forKey: "ReviewRequestCount")
        }
    }

    // デベロッパーサポートしたかどうか？
    var hasSupportedDeveloper: Bool {
        get {
            defaults.bool(forKey: "HasSupportedDeveloper")
        }
        set {
            defaults.set(newValue, forKey: "HasSupportedDeveloper")
        }
    }

    var hasPurchasedProduct: Bool {
        get {
            defaults.bool(forKey: "HasPurchasedProduct")
        }
        set {
            defaults.set(newValue, forKey: "HasPurchasedProduct")
        }
    }
}
