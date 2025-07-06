import Foundation
import AVFoundation

struct RecordingConfiguration: Equatable {
    let fileFormat: AudioFileFormat
    let quality: AudioQuality
    let sampleRate: Double
    let numberOfChannels: Int
    
    static let `default` = RecordingConfiguration(
        fileFormat: .m4a,
        quality: .high,
        sampleRate: 44100,
        numberOfChannels: 1
    )
    
    enum AudioFileFormat: String, CaseIterable {
        case m4a = "m4a"
        case wav = "wav"
        case aiff = "aiff"
        case caf = "caf"
        
        var settings: [String: Any] {
            switch self {
            case .m4a:
                return [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
            case .wav:
                return [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false
                ]
            case .aiff:
                return [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: true
                ]
            case .caf:
                return [
                    AVFormatIDKey: kAudioFormatAppleLossless
                ]
            }
        }
        
        var fileExtension: String {
            return rawValue
        }
    }
    
    enum AudioQuality: String, CaseIterable {
        case low, medium, high, max
        
        var avQuality: AVAudioQuality {
            switch self {
            case .low: return .low
            case .medium: return .medium
            case .high: return .high
            case .max: return .max
            }
        }
    }
    
    var recordingSettings: [String: Any] {
        var settings = fileFormat.settings
        settings[AVSampleRateKey] = sampleRate
        settings[AVNumberOfChannelsKey] = numberOfChannels
        settings[AVEncoderAudioQualityKey] = quality.avQuality.rawValue
        return settings
    }
}