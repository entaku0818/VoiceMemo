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
}

extension UserDefaultsClient: DependencyKey {
    static let liveValue = Self(
        logError: { message in
            let timestamp = Date().description(with: .current)
            let logMessage = "[\(timestamp)] \(message)"
            let defaults = UserDefaults.standard
            var errorLogs = defaults.array(forKey: "ErrorLogs") as? [String] ?? []
            errorLogs.append(logMessage)
            defaults.set(errorLogs, forKey: "ErrorLogs")
            defaults.synchronize()
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
        setHasSeenTutorial: { _ in }
    )
}

extension DependencyValues {
    var userDefaults: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}
