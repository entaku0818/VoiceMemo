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
            return defaults.string(forKey: "SelectedFileFormat") ?? ""
        }
        set {
            defaults.set(newValue, forKey: "SelectedFileFormat")
        }
    }
    var samplingFrequency: Int {
        get {
            return defaults.integer(forKey: "SamplingFrequency")
        }
        set {
            defaults.set(newValue, forKey: "SamplingFrequency")
        }
    }

}
