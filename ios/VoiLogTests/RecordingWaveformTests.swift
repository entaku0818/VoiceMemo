import XCTest
import ComposableArchitecture
@testable import VoiLog

final class RecordingWaveformTests: XCTestCase {

    // MARK: - normalizedLevel

    func testNormalizedLevel_BelowNoiseFloor_IsZero() {
        XCTAssertEqual(RecordingWaveform.normalizedLevel(decibels: -60), 0)
        XCTAssertEqual(RecordingWaveform.normalizedLevel(decibels: RecordingWaveform.noiseFloor), 0)
        XCTAssertEqual(RecordingWaveform.normalizedLevel(decibels: -160), 0)
    }

    func testNormalizedLevel_AtOrAboveCeiling_IsOne() {
        XCTAssertEqual(RecordingWaveform.normalizedLevel(decibels: RecordingWaveform.ceiling), 1)
        XCTAssertEqual(RecordingWaveform.normalizedLevel(decibels: 0), 1)
        XCTAssertEqual(RecordingWaveform.normalizedLevel(decibels: 6), 1, "0dB を超える値は 1 に丸める")
    }

    func testNormalizedLevel_NonFinite_IsZero() {
        XCTAssertEqual(RecordingWaveform.normalizedLevel(decibels: -.infinity), 0)
        XCTAssertEqual(RecordingWaveform.normalizedLevel(decibels: .nan), 0)
    }

    func testNormalizedLevel_IsMonotonicallyIncreasing() {
        let levels = stride(from: RecordingWaveform.noiseFloor, through: RecordingWaveform.ceiling, by: 2)
            .map(RecordingWaveform.normalizedLevel(decibels:))
        XCTAssertEqual(levels, levels.sorted())
        XCTAssertEqual(Set(levels).count, levels.count)
    }

    func testNormalizedLevel_CurveSeparatesSpeechFromAmbientNoise() {
        // 環境音(-45dB)はほぼ点、実測の話し声の中央値(-27.5dB)は半分近くまで、大きめの声(-20dB)ははっきり立つ
        let ambient = RecordingWaveform.normalizedLevel(decibels: -45)
        let typicalSpeech = RecordingWaveform.normalizedLevel(decibels: -27.5)
        let loudSpeech = RecordingWaveform.normalizedLevel(decibels: -20)
        XCTAssertLessThan(ambient, 0.05)
        XCTAssertGreaterThan(typicalSpeech, 0.4)
        XCTAssertGreaterThan(loudSpeech, 0.65)
    }

    // MARK: - append

    func testAppend_RisingLevel_IsReflectedImmediately() {
        var waveform = RecordingWaveform()
        waveform.append(decibels: -60)
        waveform.append(decibels: -10)
        XCTAssertEqual(waveform.samples.last, RecordingWaveform.normalizedLevel(decibels: -10))
    }

    func testAppend_FallingLevel_ReleasesGradually() {
        var waveform = RecordingWaveform()
        waveform.append(decibels: 0)
        waveform.append(decibels: -60)
        // 1.0 から 0 へ一気に落ちず、releaseFactor ぶんだけ戻る
        XCTAssertEqual(waveform.samples, [1, 1 - RecordingWaveform.releaseFactor])
        waveform.append(decibels: -60)
        let expected = (1 - RecordingWaveform.releaseFactor) * (1 - RecordingWaveform.releaseFactor)
        XCTAssertEqual(waveform.samples.last ?? 1, expected, accuracy: 0.0001)
    }

    func testAppend_KeepsAtMostCapacitySamples_DroppingOldest() {
        var waveform = RecordingWaveform()
        for _ in 0..<RecordingWaveform.capacity {
            waveform.append(decibels: -60)
        }
        waveform.append(decibels: 0)
        XCTAssertEqual(waveform.samples.count, RecordingWaveform.capacity)
        XCTAssertEqual(waveform.samples.last, 1)
    }

    func testReset_ClearsSamples() {
        var waveform = RecordingWaveform()
        waveform.append(decibels: -10)
        waveform.reset()
        XCTAssertTrue(waveform.samples.isEmpty)
    }

    // MARK: - RecordingFeature との連携

    @MainActor
    func testVolumesUpdated_AppendsToWaveform() async {
        let store = TestStore(initialState: RecordingFeature.State(recordingState: .recording)) {
            RecordingFeature()
        }

        await store.send(.volumesUpdated(-20)) {
            $0.volumes = -20
            $0.waveform.append(decibels: -20)
        }
        await store.send(.volumesUpdated(-60)) {
            $0.volumes = -60
            $0.waveform.append(decibels: -60)
        }
        XCTAssertEqual(store.state.waveform.samples.count, 2)
    }

    // MARK: - scrollProgress

    func testScrollProgress_IsFractionOfInterval() {
        XCTAssertEqual(RecordingWaveform.scrollProgress(sinceLastSample: 0, interval: 0.1), 0)
        XCTAssertEqual(RecordingWaveform.scrollProgress(sinceLastSample: 0.05, interval: 0.1), 0.5, accuracy: 0.0001)
    }

    func testScrollProgress_ClampsToZeroAndOne() {
        XCTAssertEqual(RecordingWaveform.scrollProgress(sinceLastSample: 0.35, interval: 0.1), 1, "次のサンプルが遅れても1本ぶんより先へは流さない")
        XCTAssertEqual(RecordingWaveform.scrollProgress(sinceLastSample: -0.02, interval: 0.1), 0, "時計のずれで負になっても逆走しない")
    }

    func testScrollProgress_InvalidInput_IsZero() {
        XCTAssertEqual(RecordingWaveform.scrollProgress(sinceLastSample: 0.05, interval: 0), 0)
        XCTAssertEqual(RecordingWaveform.scrollProgress(sinceLastSample: .nan, interval: 0.1), 0)
        XCTAssertEqual(RecordingWaveform.scrollProgress(sinceLastSample: .infinity, interval: 0.1), 0)
    }
}
