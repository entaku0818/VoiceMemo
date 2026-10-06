import XCTest
import AVFoundation
@testable import VoiLog

/// 長時間録音の区切り（#224）と、強制終了からの復旧（#223）のテスト。
/// 実際の AVAudioFile で一時ディレクトリにファイルを作って確かめる。
final class RecordingSegmentsTests: XCTestCase {

    var directory: URL!
    var defaults: UserDefaults!
    var suiteName: String!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecordingSegmentsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suiteName = "RecordingSegmentsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Helpers

    private let sampleRate: Double = 16000

    /// 正弦波を frames ぶん書いたファイルを作る（拡張子で WAV / m4a を切り替える）
    @discardableResult
    private func makeAudioFile(_ url: URL, frames: AVAudioFrameCount) throws -> URL {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        var settings: [String: Any] = [AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: 1]
        if url.pathExtension == "wav" {
            settings[AVFormatIDKey] = kAudioFormatLinearPCM
            settings[AVLinearPCMBitDepthKey] = 16
            settings[AVLinearPCMIsFloatKey] = false
        } else {
            settings[AVFormatIDKey] = kAudioFormatMPEG4AAC
        }
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            buffer.floatChannelData![0][i] = Float(sin(Double(i) * 2 * .pi * 440 / sampleRate)) * 0.3
        }
        // スコープを抜けると閉じられ、ヘッダ（m4a なら moov）が書かれる
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            try file.write(from: buffer)
        }
        return url
    }

    /// 強制終了したときと同じ形（RIFF と data のサイズが 0）にヘッダを壊す
    private func breakWAVHeader(_ url: URL) throws {
        var data = try Data(contentsOf: url)
        data.replaceSubrange(4..<8, with: [0, 0, 0, 0])
        let range = data.range(of: Data("data".utf8))!
        data.replaceSubrange(range.upperBound..<(range.upperBound + 4), with: [0, 0, 0, 0])
        try data.write(to: url)
    }

    private func frameLength(_ url: URL) throws -> AVAudioFramePosition {
        try AVAudioFile(forReading: url).length
    }

    // MARK: - WAVHeaderRepair

    func testRepair_ZeroSizedHeader_RestoresAllFrames() throws {
        let url = try makeAudioFile(directory.appendingPathComponent("broken.wav"), frames: 16000)
        try breakWAVHeader(url)
        XCTAssertEqual((try? AVAudioFile(forReading: url))?.length ?? 0, 0, "壊したヘッダでは長さ0として読まれる前提")

        XCTAssertTrue(try WAVHeaderRepair.repairIfNeeded(url))

        XCTAssertEqual(try frameLength(url), 16000)
    }

    func testRepair_ValidFile_DoesNothing() throws {
        let url = try makeAudioFile(directory.appendingPathComponent("ok.wav"), frames: 8000)
        let before = try Data(contentsOf: url)

        XCTAssertFalse(try WAVHeaderRepair.repairIfNeeded(url))

        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    func testRepair_NonWAVFile_ReturnsFalse() throws {
        let url = try makeAudioFile(directory.appendingPathComponent("a.m4a"), frames: 8000)
        XCTAssertFalse(try WAVHeaderRepair.repairIfNeeded(url))
    }

    // MARK: - RecordingSegments.merge

    func testMerge_SingleSegment_MovesFile() async throws {
        let segment = try makeAudioFile(directory.appendingPathComponent("seg-0000.wav"), frames: 4000)
        let destination = directory.appendingPathComponent("final.wav")

        try await RecordingSegments.merge([segment], into: destination)

        XCTAssertFalse(FileManager.default.fileExists(atPath: segment.path))
        XCTAssertEqual(try frameLength(destination), 4000)
    }

    func testMerge_WAVSegments_ConcatenatesAllFrames() async throws {
        let first = try makeAudioFile(directory.appendingPathComponent("seg-0000.wav"), frames: 16000)
        let second = try makeAudioFile(directory.appendingPathComponent("seg-0001.wav"), frames: 8000)
        let destination = directory.appendingPathComponent("final.wav")

        try await RecordingSegments.merge([first, second], into: destination)

        XCTAssertEqual(try frameLength(destination), 24000)
    }

    func testMerge_M4ASegments_ConcatenatesDuration() async throws {
        let first = try makeAudioFile(directory.appendingPathComponent("seg-0000.m4a"), frames: 16000)
        let second = try makeAudioFile(directory.appendingPathComponent("seg-0001.m4a"), frames: 16000)
        let destination = directory.appendingPathComponent("final.m4a")

        try await RecordingSegments.merge([first, second], into: destination)

        let duration = try await AVURLAsset(url: destination).load(.duration).seconds
        XCTAssertEqual(duration, 2.0, accuracy: 0.15)
    }

    func testMerge_NoSegments_Throws() async {
        do {
            try await RecordingSegments.merge([], into: directory.appendingPathComponent("final.wav"))
            XCTFail("区切りが無いときは失敗する")
        } catch {
            XCTAssertEqual(error as? RecordingSegments.MergeError, .noSegments)
        }
    }

    func testSegmentFiles_SortedByIndex() throws {
        let dir = directory.appendingPathComponent("segs", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for index in [2, 0, 1] {
            try makeAudioFile(RecordingSegments.segmentURL(index: index, in: dir, fileExtension: "wav"), frames: 100)
        }

        let names = RecordingSegments.segmentFiles(in: dir).map(\.lastPathComponent)

        XCTAssertEqual(names, ["seg-0000.wav", "seg-0001.wav", "seg-0002.wav"])
    }

    func testSegmentDirectory_IsOutsideDocumentsRoot() {
        let final = directory.appendingPathComponent("\(UUID().uuidString).m4a")
        let dir = RecordingSegments.directory(for: final)

        // 孤児ファイルの走査（Documents 直下）に区切りが引っかからないこと
        XCTAssertNotEqual(dir.deletingLastPathComponent(), directory)
        XCTAssertEqual(dir.lastPathComponent, final.deletingPathExtension().lastPathComponent)
    }

    // MARK: - RecordingJournal

    func testJournal_AddAndRemove() {
        let journal = RecordingJournal(defaults: defaults)
        let url = directory.appendingPathComponent("a.wav")

        journal.add(finalURL: url)
        XCTAssertEqual(journal.entries().map(\.finalPath), [url.path])

        journal.remove(finalURL: url)
        XCTAssertTrue(journal.entries().isEmpty)
    }

    func testJournal_AddSameURLTwice_KeepsOneEntry() {
        let journal = RecordingJournal(defaults: defaults)
        let url = directory.appendingPathComponent("a.wav")

        journal.add(finalURL: url)
        journal.add(finalURL: url)

        XCTAssertEqual(journal.entries().count, 1)
    }

    // MARK: - InterruptedRecordingRecovery

    func testRecover_PreviousProcess_MergesSegmentsAndRepairsWAV() async throws {
        let journal = RecordingJournal(defaults: defaults)
        let id = UUID()
        let final = directory.appendingPathComponent("\(id.uuidString).wav")
        let segments = RecordingSegments.directory(for: final)
        try FileManager.default.createDirectory(at: segments, withIntermediateDirectories: true)
        try makeAudioFile(RecordingSegments.segmentURL(index: 0, in: segments, fileExtension: "wav"), frames: 16000)
        // 最後の区切りは書きかけのまま強制終了した
        let last = try makeAudioFile(RecordingSegments.segmentURL(index: 1, in: segments, fileExtension: "wav"), frames: 8000)
        try breakWAVHeader(last)
        journal.add(finalURL: final, processID: UUID())

        let recovered = await InterruptedRecordingRecovery.recover(journal: journal, currentProcessID: UUID())

        XCTAssertEqual(recovered, [id])
        XCTAssertEqual(try frameLength(final), 24000, "書きかけの区切りもヘッダを直して取り込む")
        XCTAssertFalse(FileManager.default.fileExists(atPath: segments.path))
        XCTAssertTrue(journal.entries().isEmpty)
    }

    func testRecover_SkipsUnreadableM4ASegment() async throws {
        let journal = RecordingJournal(defaults: defaults)
        let id = UUID()
        let final = directory.appendingPathComponent("\(id.uuidString).m4a")
        let segments = RecordingSegments.directory(for: final)
        try FileManager.default.createDirectory(at: segments, withIntermediateDirectories: true)
        try makeAudioFile(RecordingSegments.segmentURL(index: 0, in: segments, fileExtension: "m4a"), frames: 16000)
        // moov が無い書きかけの m4a（強制終了したときと同じく開けない）
        try Data(repeating: 0x41, count: 4096)
            .write(to: RecordingSegments.segmentURL(index: 1, in: segments, fileExtension: "m4a"))
        journal.add(finalURL: final, processID: UUID())

        let recovered = await InterruptedRecordingRecovery.recover(journal: journal, currentProcessID: UUID())

        XCTAssertEqual(recovered, [id])
        let duration = try await AVURLAsset(url: final).load(.duration).seconds
        XCTAssertEqual(duration, 1.0, accuracy: 0.15)
    }

    func testRecover_SingleFileWithBrokenHeader_RepairsIt() async throws {
        let journal = RecordingJournal(defaults: defaults)
        let id = UUID()
        let final = try makeAudioFile(directory.appendingPathComponent("\(id.uuidString).wav"), frames: 16000)
        try breakWAVHeader(final)
        journal.add(finalURL: final, processID: UUID())

        let recovered = await InterruptedRecordingRecovery.recover(journal: journal, currentProcessID: UUID())

        XCTAssertEqual(recovered, [id])
        XCTAssertEqual(try frameLength(final), 16000)
    }

    func testRecover_CurrentProcessEntry_IsLeftAlone() async throws {
        let journal = RecordingJournal(defaults: defaults)
        let processID = UUID()
        let final = directory.appendingPathComponent("\(UUID().uuidString).wav")
        let segments = RecordingSegments.directory(for: final)
        try FileManager.default.createDirectory(at: segments, withIntermediateDirectories: true)
        try makeAudioFile(RecordingSegments.segmentURL(index: 0, in: segments, fileExtension: "wav"), frames: 1600)
        journal.add(finalURL: final, processID: processID)

        // いま録音中かもしれない同じプロセスの記録には触らない
        let recovered = await InterruptedRecordingRecovery.recover(journal: journal, currentProcessID: processID)

        XCTAssertTrue(recovered.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: segments.path))
        XCTAssertEqual(journal.entries().count, 1)
    }

    func testRecover_FileAlreadyGone_ClearsEntry() async {
        let journal = RecordingJournal(defaults: defaults)
        journal.add(finalURL: directory.appendingPathComponent("\(UUID().uuidString).wav"), processID: UUID())

        let recovered = await InterruptedRecordingRecovery.recover(journal: journal, currentProcessID: UUID())

        XCTAssertTrue(recovered.isEmpty)
        XCTAssertTrue(journal.entries().isEmpty)
    }
}
