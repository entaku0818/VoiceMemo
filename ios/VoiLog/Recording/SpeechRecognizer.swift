import Foundation
import Speech

enum SpeechRecognizer {
    static func recognize(url: URL) async -> (String, [TimestampedSegment])? {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { return nil }

        let recognizer = SFSpeechRecognizer(locale: Locale.current)
        guard recognizer?.isAvailable == true else { return nil }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        return await withCheckedContinuation { continuation in
            recognizer?.recognitionTask(with: request) { result, error in
                guard let result = result, result.isFinal else {
                    if error != nil { continuation.resume(returning: nil) }
                    return
                }

                let fullText = result.bestTranscription.formattedString
                let segments = result.bestTranscription.segments.map { segment in
                    TimestampedSegment(
                        text: segment.substring,
                        timestamp: segment.timestamp,
                        duration: segment.duration,
                        confidence: segment.confidence
                    )
                }
                continuation.resume(returning: (fullText, segments))
            }
        }
    }
}
