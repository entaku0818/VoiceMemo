import Foundation

// MARK: - TimestampedSegment

struct TimestampedSegment: Codable, Equatable, Identifiable {
    var id: UUID
    let text: String
    let timestamp: TimeInterval
    let duration: TimeInterval
    let confidence: Float

    init(id: UUID = UUID(), text: String, timestamp: TimeInterval, duration: TimeInterval, confidence: Float = 1.0) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.confidence = confidence
    }

    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "[%02d:%02d]", minutes, seconds)
    }
}

// MARK: - TimestampedTranscription

struct TimestampedTranscription: Codable, Equatable {
    let segments: [TimestampedSegment]
    let fullText: String

    var formattedText: String {
        segments.map { "\($0.formattedTimestamp) \($0.text)" }.joined(separator: "\n")
    }

    static func fromJSON(_ json: String) -> TimestampedTranscription? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TimestampedTranscription.self, from: data)
    }

    func toJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
