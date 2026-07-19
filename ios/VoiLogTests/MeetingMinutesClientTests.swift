import XCTest
import ComposableArchitecture
@testable import VoiLog

// MARK: - MeetingMinutesGenerator (オンデバイス/クラウドフォールバックの振り分けロジック)

final class MeetingMinutesGeneratorTests: XCTestCase {

    func testGenerate_emptyText_throwsWithoutCallingEitherPath() async {
        let onDeviceCalled = LockIsolated(false)
        let cloudCalled = LockIsolated(false)

        do {
            _ = try await MeetingMinutesGenerator.generate(
                text: "   ",
                isOnDeviceAvailable: { true },
                onDevice: { _ in
                    onDeviceCalled.setValue(true)
                    return MeetingMinutesResult(summary: "", todos: [])
                },
                cloudFallback: { _ in
                    cloudCalled.setValue(true)
                    return MeetingMinutesResult(summary: "", todos: [])
                }
            )
            XCTFail("空文字はエラーになるはず")
        } catch {
            XCTAssertEqual(error as? MeetingMinutesError, .noTranscriptionText)
        }

        XCTAssertFalse(onDeviceCalled.value)
        XCTAssertFalse(cloudCalled.value)
    }

    func testGenerate_onDeviceAvailable_usesOnDeviceNotCloud() async throws {
        let cloudCalled = LockIsolated(false)
        let expected = MeetingMinutesResult(summary: "オンデバイス要約", todos: ["TODO"])

        let result = try await MeetingMinutesGenerator.generate(
            text: "会議の文字起こし",
            isOnDeviceAvailable: { true },
            onDevice: { _ in expected },
            cloudFallback: { _ in
                cloudCalled.setValue(true)
                return MeetingMinutesResult(summary: "", todos: [])
            }
        )

        XCTAssertEqual(result, expected)
        XCTAssertFalse(cloudCalled.value, "オンデバイスが使えるならクラウドは呼ばれないはず")
    }

    func testGenerate_onDeviceUnavailable_fallsBackToCloud() async throws {
        let onDeviceCalled = LockIsolated(false)
        let expected = MeetingMinutesResult(summary: "クラウド要約", todos: [])

        let result = try await MeetingMinutesGenerator.generate(
            text: "会議の文字起こし",
            isOnDeviceAvailable: { false },
            onDevice: { _ in
                onDeviceCalled.setValue(true)
                return MeetingMinutesResult(summary: "", todos: [])
            },
            cloudFallback: { _ in expected }
        )

        XCTAssertEqual(result, expected)
        XCTAssertFalse(onDeviceCalled.value, "オンデバイスが非対応ならオンデバイス実装は呼ばれないはず")
    }

    func testGenerate_onDeviceThrows_propagatesWithoutFallingBackToCloud() async {
        let cloudCalled = LockIsolated(false)

        do {
            _ = try await MeetingMinutesGenerator.generate(
                text: "会議の文字起こし",
                isOnDeviceAvailable: { true },
                onDevice: { _ in throw MeetingMinutesError.generationFailed("失敗") },
                cloudFallback: { _ in
                    cloudCalled.setValue(true)
                    return MeetingMinutesResult(summary: "", todos: [])
                }
            )
            XCTFail("エラーが伝播するはず")
        } catch {
            XCTAssertEqual(error as? MeetingMinutesError, .generationFailed("失敗"))
        }

        XCTAssertFalse(cloudCalled.value, "生成失敗は非対応と異なりクラウドへフォールバックしない")
    }
}

// MARK: - MeetingMinutesCloudFallback (クラウドAPI経由の議事録生成)

@MainActor
final class MeetingMinutesCloudFallbackTests: XCTestCase {

    private func makeFallback(
        generateMinutes: @escaping @Sendable (String, String, String) async throws -> TranscriptionClient.MinutesResponse,
        currentUserIDToken: @escaping @Sendable (Bool) async throws -> String = { _ in "test-token" }
    ) -> MeetingMinutesCloudFallback {
        withDependencies {
            $0.transcriptionClient = TranscriptionClient(
                uploadURL: { _, _ in .init(uploadUrl: "", fileId: "", blobName: "") },
                transcribe: { _, _, _ in .init(transcription: "", segments: nil, summary: nil) },
                uploadAudio: { _, _, _ in },
                generateMinutes: generateMinutes
            )
            $0.firebaseAuthClient = FirebaseAuthClient(currentUserIDToken: currentUserIDToken)
        } operation: {
            MeetingMinutesCloudFallback()
        }
    }

    func testGenerate_success_mapsResponseToResult() async throws {
        let fallback = makeFallback(
            generateMinutes: { _, _, _ in .init(summary: "クラウド要約", todos: ["TODO A", "TODO B"]) }
        )

        let result = try await fallback.generate(text: "会議の文字起こし")

        XCTAssertEqual(result.summary, "クラウド要約")
        XCTAssertEqual(result.todos, ["TODO A", "TODO B"])
    }

    func testGenerate_uploadURL401_retriesWithForcedRefreshToken() async throws {
        let fallback = makeFallback(
            generateMinutes: { token, _, _ in
                if token == "stale-token" {
                    throw TranscriptionError.serverError(401, "Unauthorized")
                }
                return .init(summary: "再試行成功", todos: [])
            },
            currentUserIDToken: { forcingRefresh in forcingRefresh ? "fresh-token" : "stale-token" }
        )

        let result = try await fallback.generate(text: "会議の文字起こし")

        XCTAssertEqual(result.summary, "再試行成功")
    }

    func testGenerate_serverError_throwsGenerationFailed() async {
        let fallback = makeFallback(
            generateMinutes: { _, _, _ in throw TranscriptionError.serverError(500, "Internal Server Error") }
        )

        do {
            _ = try await fallback.generate(text: "会議の文字起こし")
            XCTFail("サーバーエラーはgenerationFailedとして伝播するはず")
        } catch {
            guard case .generationFailed = error as? MeetingMinutesError else {
                XCTFail("Expected .generationFailed but got \(error)")
                return
            }
        }
    }
}
