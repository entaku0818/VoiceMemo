import XCTest
import AVFoundation
@testable import VoiLog

/// 実際の AVAudioRecorder で録音して、区切りの切り替えと停止時の結合を確かめる（#224）。
/// マイクの許可が無い環境（CI のシミュレータなど）では録音を始められないのでスキップする。
/// ローカルでは `xcrun simctl privacy <UDID> grant microphone com.entaku.VoiLogDevelop` で許可してから流す。
final class RecorderIntegrationTests: XCTestCase {

    var directory: URL!
    var defaults: UserDefaults!
    var suiteName: String!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecorderIntegration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suiteName = "RecorderIntegration-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func record(format: RecordingConfiguration.AudioFileFormat, seconds: Double) async throws -> URL {
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw XCTSkip("マイクの許可が無いため録音の結合テストをスキップ")
        }
        let journal = RecordingJournal(defaults: defaults)
        let recorder = LongRecordingAudioRecorder(
            segmentDuration: 1.0,
            rotationCheckInterval: .milliseconds(200),
            journal: journal
        )
        let url = directory.appendingPathComponent("\(UUID().uuidString).\(format.fileExtension)")
        let configuration = RecordingConfiguration(
            fileFormat: format,
            quality: .high,
            sampleRate: 16000,
            numberOfChannels: 1,
            noiseCancellationEnabled: false,
            autoGainControlEnabled: false
        )

        let started = try await recorder.startRecording(url: url, configuration: configuration)
        guard started else { throw XCTSkip("この環境では録音を開始できない") }
        XCTAssertEqual(journal.entries().map(\.finalPath), [url.path], "録音中は記録が残る")

        try await Task.sleep(for: .seconds(seconds))
        let segmentCount = RecordingSegments.segmentFiles(in: RecordingSegments.directory(for: url)).count
        XCTAssertGreaterThanOrEqual(segmentCount, 2, "1秒ごとに区切りが切り替わっている")

        await recorder.stopRecording()

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "停止すると1ファイルにつながる")
        XCTAssertFalse(FileManager.default.fileExists(atPath: RecordingSegments.directory(for: url).path), "区切りは消える")
        XCTAssertEqual(journal.entries().count, 1, "保存するまで記録は残す")

        await recorder.markRecordingSaved(url: url)
        XCTAssertTrue(journal.entries().isEmpty)
        return url
    }

    func testRecordWAV_RotatesAndMergesSegments() async throws {
        let url = try await record(format: .wav, seconds: 3.5)
        let duration = try await AVURLAsset(url: url).load(.duration).seconds
        // 区切りの切り替えは 200ms ごとの確認なので、合計は録音時間とほぼ同じ（重なり・確認間隔ぶんの誤差あり）
        XCTAssertEqual(duration, 3.5, accuracy: 0.6)
    }

    func testRecordM4A_RotatesAndMergesSegments() async throws {
        let url = try await record(format: .m4a, seconds: 3.5)
        let duration = try await AVURLAsset(url: url).load(.duration).seconds
        XCTAssertEqual(duration, 3.5, accuracy: 0.6)
    }
}
