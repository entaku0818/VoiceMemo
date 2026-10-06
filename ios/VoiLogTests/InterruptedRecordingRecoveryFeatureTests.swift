import XCTest
import ComposableArchitecture
@testable import VoiLog

/// 起動時の自動復旧（#223）
@MainActor
final class InterruptedRecordingRecoveryFeatureTests: XCTestCase {

    private final class NoopAccessor: VoiceMemoCoredataAccessorProtocol {
        func insert(voice: VoiceMemoRepository.Voice, isCloud: Bool) {}
        func selectAllData() -> [VoiceMemoRepository.Voice] { [] }
        func fetch(uuid: UUID) -> VoiceMemoRepository.Voice? { nil }
        func delete(id: UUID) {}
        func update(voice: VoiceMemoRepository.Voice) {}
        func updateTitle(uuid: UUID, newTitle: String) {}
        func removeDuplicates() -> Int { 0 }
    }

    private func makeStore(
        recovered: [UUID],
        restoredIDs: LockIsolated<[Set<UUID>]>,
        restoreResult: Int
    ) -> TestStoreOf<VoiceAppFeature> {
        var repository = VoiceMemoRepositoryClient(
            insert: { _ in },
            selectAllData: { [] },
            fetch: { _ in nil },
            delete: { _ in },
            update: { _ in },
            updateTitle: { _, _ in },
            updateTags: { _, _ in },
            updateMeetingMinutes: { _, _ in },
            syncToCloud: { true },
            checkForDifferences: { false },
            restoreOrphanedRecordings: { 0 }
        )
        repository.restoreInterruptedRecordings = { ids in
            restoredIDs.withValue { $0.append(ids) }
            return restoreResult
        }
        return TestStore(initialState: VoiceAppFeature.State()) {
            VoiceAppFeature()
        } withDependencies: {
            $0.voiceMemoRepository = repository
            $0.voiceMemoCoredataAccessor = NoopAccessor()
            $0.interruptedRecordingRecovery = InterruptedRecordingRecoveryClient { recovered }
            $0.userDefaults.bool = { _ in true }
        }
    }

    func testOnAppear_RecoveredRecording_RestoresAndReloadsList() async {
        await withMainSerialExecutor {
            let id = UUID()
            let restored = LockIsolated<[Set<UUID>]>([])
            let store = makeStore(recovered: [id], restoredIDs: restored, restoreResult: 1)
            store.exhaustivity = .off

            await store.send(.view(.onAppear))
            await store.receive(\.playbackFeature.view.reloadData)

            XCTAssertEqual(restored.value, [[id]])
        }
    }

    func testOnAppear_NothingRecovered_DoesNotTouchRepository() async {
        await withMainSerialExecutor {
            let restored = LockIsolated<[Set<UUID>]>([])
            let store = makeStore(recovered: [], restoredIDs: restored, restoreResult: 0)
            store.exhaustivity = .off

            await store.send(.view(.onAppear))
            await store.finish()

            XCTAssertTrue(restored.value.isEmpty)
        }
    }
}
