import Foundation
import Dependencies

struct UserDefaultsClient {
    var logError: @Sendable (String) -> Void
    var errorLogs: @Sendable () -> [String]
    var selectedFileFormat: @Sendable () -> String
    var setSelectedFileFormat: @Sendable (String) -> Void
    var samplingFrequency: @Sendable () -> Double
    var setSamplingFrequency: @Sendable (Double) -> Void
    var quantizationBitDepth: @Sendable () -> Int
    var setQuantizationBitDepth: @Sendable (Int) -> Void
    var numberOfChannels: @Sendable () -> Int
    var setNumberOfChannels: @Sendable (Int) -> Void
    var microphonesVolume: @Sendable () -> Double
    var setMicrophonesVolume: @Sendable (Double) -> Void
    var installDate: @Sendable () -> Date?
    var setInstallDate: @Sendable (Date?) -> Void
    var reviewRequestCount: @Sendable () -> Int
    var setReviewRequestCount: @Sendable (Int) -> Void
    var hasSupportedDeveloper: @Sendable () -> Bool
    var setHasSupportedDeveloper: @Sendable (Bool) -> Void
    var hasPurchasedProduct: @Sendable () -> Bool
    var setHasPurchasedProduct: @Sendable (Bool) -> Void
    var hasSeenTutorial: @Sendable () -> Bool
    var setHasSeenTutorial: @Sendable (Bool) -> Void
    var hasShownTrialPromotion: @Sendable () -> Bool
    var setHasShownTrialPromotion: @Sendable (Bool) -> Void
    var noiseCancellationEnabled: @Sendable () -> Bool
    var setNoiseCancellationEnabled: @Sendable (Bool) -> Void
    var autoGainControlEnabled: @Sendable () -> Bool
    var setAutoGainControlEnabled: @Sendable (Bool) -> Void
    var selectedRecordingPreset: @Sendable () -> String
    var setSelectedRecordingPreset: @Sendable (String) -> Void
    var isTranscriptionEnabled: @Sendable () -> Bool
    var setIsTranscriptionEnabled: @Sendable (Bool) -> Void
    var playbackVolumeBoost: @Sendable () -> Float
    var setPlaybackVolumeBoost: @Sendable (Float) -> Void
    var adBasedTranscriptionUnlockCount: @Sendable () -> Int
    var setAdBasedTranscriptionUnlockCount: @Sendable (Int) -> Void
    var bool: @Sendable (String) -> Bool
    var set: @Sendable (Bool, String) -> Void

    // 広告視聴による文字起こし無料アンロック回数の上限（lifetime）。issue #207
    static let freeAdBasedTranscriptionLimit = 3
    /// UserDefaults に残すエラーログの上限件数
    static let errorLogLimit = 200
}

extension UserDefaultsClient: DependencyKey {
    static let liveValue = Self(
        logError: { message in
            let timestamp = Date().description(with: .current)
            let logMessage = "[\(timestamp)] \(message)"
            let defaults = UserDefaults.standard
            var errorLogs = defaults.array(forKey: "ErrorLogs") as? [String] ?? []
            errorLogs.append(logMessage)
            // 以前は無制限に追記していて UserDefaults が際限なく膨らんでいた。
            // 調査に使うのは直近だけなので上限を設ける
            if errorLogs.count > UserDefaultsClient.errorLogLimit {
                errorLogs.removeFirst(errorLogs.count - UserDefaultsClient.errorLogLimit)
            }
            defaults.set(errorLogs, forKey: "ErrorLogs")
        },
        errorLogs: {
            UserDefaults.standard.array(forKey: "ErrorLogs") as? [String] ?? []
        },
        selectedFileFormat: {
            UserDefaults.standard.string(forKey: "SelectedFileFormat") ?? Constants.defaultFileFormat.rawValue
        },
        setSelectedFileFormat: { newValue in
            UserDefaults.standard.set(newValue, forKey: "SelectedFileFormat")
        },
        samplingFrequency: {
            let value = UserDefaults.standard.double(forKey: "SamplingFrequency")
            return value == 0 ? Constants.defaultSamplingFrequency.rawValue : value
        },
        setSamplingFrequency: { newValue in
            UserDefaults.standard.set(newValue, forKey: "SamplingFrequency")
        },
        quantizationBitDepth: {
            let value = UserDefaults.standard.integer(forKey: "QuantizationBitDepth")
            return value == 0 ? Constants.defaultQuantizationBitDepth.rawValue : value
        },
        setQuantizationBitDepth: { newValue in
            UserDefaults.standard.set(newValue, forKey: "QuantizationBitDepth")
        },
        numberOfChannels: {
            let value = UserDefaults.standard.integer(forKey: "NumberOfChannels")
            return value == 0 ? Constants.defaultNumberOfChannels.rawValue : value
        },
        setNumberOfChannels: { newValue in
            UserDefaults.standard.set(newValue, forKey: "NumberOfChannels")
        },
        microphonesVolume: {
            let value = UserDefaults.standard.double(forKey: "MicrophonesVolume")
            return value == 0 ? Constants.defaultMicrophonesVolume.rawValue : value
        },
        setMicrophonesVolume: { newValue in
            UserDefaults.standard.set(newValue, forKey: "MicrophonesVolume")
        },
        installDate: {
            UserDefaults.standard.object(forKey: "InstallDate") as? Date
        },
        setInstallDate: { newValue in
            UserDefaults.standard.set(newValue, forKey: "InstallDate")
        },
        reviewRequestCount: {
            UserDefaults.standard.object(forKey: "ReviewRequestCount") as? Int ?? 0
        },
        setReviewRequestCount: { newValue in
            UserDefaults.standard.set(newValue, forKey: "ReviewRequestCount")
        },
        hasSupportedDeveloper: {
            UserDefaults.standard.bool(forKey: "HasSupportedDeveloper")
        },
        setHasSupportedDeveloper: { newValue in
            UserDefaults.standard.set(newValue, forKey: "HasSupportedDeveloper")
        },
        hasPurchasedProduct: {
            UserDefaults.standard.bool(forKey: "HasPurchasedProduct")
        },
        setHasPurchasedProduct: { newValue in
            UserDefaults.standard.set(newValue, forKey: "HasPurchasedProduct")
        },
        hasSeenTutorial: {
            UserDefaults.standard.bool(forKey: "HasSeenTutorial")
        },
        setHasSeenTutorial: { newValue in
            UserDefaults.standard.set(newValue, forKey: "HasSeenTutorial")
        },
        hasShownTrialPromotion: {
            UserDefaults.standard.bool(forKey: "HasShownTrialPromotion")
        },
        setHasShownTrialPromotion: { newValue in
            UserDefaults.standard.set(newValue, forKey: "HasShownTrialPromotion")
        },
        noiseCancellationEnabled: {
            UserDefaults.standard.bool(forKey: "NoiseCancellationEnabled")
        },
        setNoiseCancellationEnabled: { newValue in
            UserDefaults.standard.set(newValue, forKey: "NoiseCancellationEnabled")
        },
        autoGainControlEnabled: {
            UserDefaults.standard.bool(forKey: "AutoGainControlEnabled")
        },
        setAutoGainControlEnabled: { newValue in
            UserDefaults.standard.set(newValue, forKey: "AutoGainControlEnabled")
        },
        selectedRecordingPreset: {
            UserDefaults.standard.string(forKey: "SelectedRecordingPreset") ?? RecordingPreset.memo.rawValue
        },
        setSelectedRecordingPreset: { newValue in
            UserDefaults.standard.set(newValue, forKey: "SelectedRecordingPreset")
        },
        isTranscriptionEnabled: {
            UserDefaults.standard.object(forKey: "TranscriptionEnabled") as? Bool ?? true
        },
        setIsTranscriptionEnabled: { newValue in
            UserDefaults.standard.set(newValue, forKey: "TranscriptionEnabled")
        },
        playbackVolumeBoost: {
            let value = UserDefaults.standard.float(forKey: "PlaybackVolumeBoost")
            return value < 1.0 ? 1.0 : value
        },
        setPlaybackVolumeBoost: { newValue in
            UserDefaults.standard.set(newValue, forKey: "PlaybackVolumeBoost")
        },
        adBasedTranscriptionUnlockCount: {
            UserDefaults.standard.integer(forKey: "AdBasedTranscriptionUnlockCount")
        },
        setAdBasedTranscriptionUnlockCount: { newValue in
            UserDefaults.standard.set(newValue, forKey: "AdBasedTranscriptionUnlockCount")
        },
        bool: { key in
            UserDefaults.standard.bool(forKey: key)
        },
        set: { value, key in
            UserDefaults.standard.set(value, forKey: key)
        }
    )

    static let testValue = Self(
        logError: { _ in },
        errorLogs: { [] },
        selectedFileFormat: { Constants.defaultFileFormat.rawValue },
        setSelectedFileFormat: { _ in },
        samplingFrequency: { Constants.defaultSamplingFrequency.rawValue },
        setSamplingFrequency: { _ in },
        quantizationBitDepth: { Constants.defaultQuantizationBitDepth.rawValue },
        setQuantizationBitDepth: { _ in },
        numberOfChannels: { Constants.defaultNumberOfChannels.rawValue },
        setNumberOfChannels: { _ in },
        microphonesVolume: { Constants.defaultMicrophonesVolume.rawValue },
        setMicrophonesVolume: { _ in },
        installDate: { nil },
        setInstallDate: { _ in },
        reviewRequestCount: { 0 },
        setReviewRequestCount: { _ in },
        hasSupportedDeveloper: { false },
        setHasSupportedDeveloper: { _ in },
        hasPurchasedProduct: { false },
        setHasPurchasedProduct: { _ in },
        hasSeenTutorial: { false },
        setHasSeenTutorial: { _ in },
        hasShownTrialPromotion: { false },
        setHasShownTrialPromotion: { _ in },
        noiseCancellationEnabled: { false },
        setNoiseCancellationEnabled: { _ in },
        autoGainControlEnabled: { false },
        setAutoGainControlEnabled: { _ in },
        selectedRecordingPreset: { RecordingPreset.memo.rawValue },
        setSelectedRecordingPreset: { _ in },
        isTranscriptionEnabled: { true },
        setIsTranscriptionEnabled: { _ in },
        playbackVolumeBoost: { 1.0 },
        setPlaybackVolumeBoost: { _ in },
        adBasedTranscriptionUnlockCount: { 0 },
        setAdBasedTranscriptionUnlockCount: { _ in },
        bool: { _ in false },
        set: { _, _ in }
    )
}

extension DependencyValues {
    var userDefaults: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}
