//
//  PlaybackFeatureTests.swift
//  VoiLogTests
//
//  Tests for PlaybackFeature including enhanced search functionality
//

import Foundation
import XCTest
import ComposableArchitecture
@testable import VoiLog

@MainActor
final class PlaybackFeatureTests: XCTestCase {

    // MARK: - Test Data

    private let sampleMemos = [
        PlaybackFeature.VoiceMemo(
            id: UUID(),
            title: "Short Recording",
            date: Date().addingTimeInterval(-3600), // 1 hour ago
            duration: 30, // 30 seconds
            url: URL(fileURLWithPath: "/test1.m4a"),
            text: "This is a short recording"
        ),
        PlaybackFeature.VoiceMemo(
            id: UUID(),
            title: "Medium Recording",
            date: Date().addingTimeInterval(-7200), // 2 hours ago
            duration: 180, // 3 minutes
            url: URL(fileURLWithPath: "/test2.m4a"),
            text: "This is a medium length recording",
            isFavorite: true
        ),
        PlaybackFeature.VoiceMemo(
            id: UUID(),
            title: "Long Recording",
            date: Date().addingTimeInterval(-1800), // 30 minutes ago
            duration: 600, // 10 minutes
            url: URL(fileURLWithPath: "/test3.m4a"),
            text: "This is a long recording with detailed content"
        )
    ]

    // MARK: - Basic Functionality Tests

    func test_onAppear_loadsVoiceMemos() async {
        let store = TestStore(
            initialState: PlaybackFeature.State(),
            reducer: { PlaybackFeature() }
        ) {
            $0.voiceMemoRepository.selectAllData = { [] }
        }

        await store.send(.view(.onAppear))
        await store.receive(.memosLoaded([])) {
            $0.voiceMemos = []
            $0.isLoading = false
        }
    }

    func test_refreshRequested_reloadsData() async {
        let store = TestStore(
            initialState: PlaybackFeature.State(),
            reducer: { PlaybackFeature() }
        ) {
            $0.voiceMemoRepository.selectAllData = { [] }
        }

        await store.send(.view(.refreshRequested)) {
            $0.isLoading = true
        }
        await store.receive(.memosLoaded([])) {
            $0.voiceMemos = []
            $0.isLoading = false
        }
    }

    // MARK: - Enhanced Search Tests

    func test_setSortOption_updatesState() async {
        let store = TestStore(
            initialState: PlaybackFeature.State(),
            reducer: { PlaybackFeature() }
        )

        await store.send(.view(.setSortOption(.titleAscending))) {
            $0.sortOption = .titleAscending
        }

        await store.send(.view(.setSortOption(.durationDescending))) {
            $0.sortOption = .durationDescending
        }
    }

    func test_toggleFavoritesFilter_updatesState() async {
        let store = TestStore(
            initialState: PlaybackFeature.State(),
            reducer: { PlaybackFeature() }
        )

        await store.send(.view(.toggleFavoritesFilter)) {
            $0.showFavoritesOnly = true
        }

        await store.send(.view(.toggleFavoritesFilter)) {
            $0.showFavoritesOnly = false
        }
    }

    func test_setDurationFilter_updatesState() async {
        let store = TestStore(
            initialState: PlaybackFeature.State(),
            reducer: { PlaybackFeature() }
        )

        await store.send(.view(.setDurationFilter(.short))) {
            $0.durationFilter = .short
        }

        await store.send(.view(.setDurationFilter(.long))) {
            $0.durationFilter = .long
        }
    }

    func test_toggleSearchFilters_updatesState() async {
        let store = TestStore(
            initialState: PlaybackFeature.State(),
            reducer: { PlaybackFeature() }
        )

        await store.send(.view(.toggleSearchFilters)) {
            $0.showSearchFilters = true
        }

        await store.send(.view(.toggleSearchFilters)) {
            $0.showSearchFilters = false
        }
    }

    // MARK: - Title Editing Tests

    func test_startEditingTitle_setsEditingState() async {
        let memo = sampleMemos[0]
        let store = TestStore(
            initialState: PlaybackFeature.State(voiceMemos: [memo]),
            reducer: { PlaybackFeature() }
        )

        await store.send(.view(.startEditingTitle(memo.id))) {
            $0.editingMemoId = memo.id
            $0.editingTitle = memo.title
        }
    }

    func test_cancelEditingTitle_clearsEditingState() async {
        let memo = sampleMemos[0]
        let store = TestStore(
            initialState: PlaybackFeature.State(
                voiceMemos: [memo],
                editingMemoId: memo.id,
                editingTitle: "Editing..."
            ),
            reducer: { PlaybackFeature() }
        )

        await store.send(.view(.cancelEditingTitle)) {
            $0.editingMemoId = nil
            $0.editingTitle = ""
        }
    }

    func test_editingTitleChanged_updatesEditingTitle() async {
        let store = TestStore(
            initialState: PlaybackFeature.State(),
            reducer: { PlaybackFeature() }
        )

        await store.send(.view(.editingTitleChanged("New Title"))) {
            $0.editingTitle = "New Title"
        }
    }

    func test_saveEditingTitle_updatesTitle() async {
        let memo = sampleMemos[0]
        let store = TestStore(
            initialState: PlaybackFeature.State(
                voiceMemos: [memo],
                editingMemoId: memo.id,
                editingTitle: "Updated Title"
            ),
            reducer: { PlaybackFeature() }
        ) {
            $0.voiceMemoRepository.updateTitle = { _, _ in }
        }

        await store.send(.view(.saveEditingTitle))
        await store.receive(.view(.updateTitle(memo.id, "Updated Title"))) {
            $0.voiceMemos[0].title = "Updated Title"
        }
        await store.receive(.view(.cancelEditingTitle)) {
            $0.editingMemoId = nil
            $0.editingTitle = ""
        }
    }

    // MARK: - Favorite Toggle Tests

    func test_toggleFavorite_updatesFavoriteStatus() async {
        let memo = sampleMemos[0]
        let store = TestStore(
            initialState: PlaybackFeature.State(voiceMemos: [memo]),
            reducer: { PlaybackFeature() }
        )

        await store.send(.view(.toggleFavorite(memo.id))) {
            $0.voiceMemos[0].isFavorite = true
        }

        await store.send(.view(.toggleFavorite(memo.id))) {
            $0.voiceMemos[0].isFavorite = false
        }
    }

    // MARK: - Delete Tests

    func test_deleteMemo_showsConfirmation() async {
        let memo = sampleMemos[0]
        let store = TestStore(
            initialState: PlaybackFeature.State(voiceMemos: [memo]),
            reducer: { PlaybackFeature() }
        )

        await store.send(.view(.deleteMemo(memo.id))) {
            $0.selectedMemoForDeletion = memo.id
            $0.showDeleteConfirmation = true
        }
    }

    func test_confirmDelete_removesVoiceMemo() async {
        let memo = sampleMemos[0]
        let store = TestStore(
            initialState: PlaybackFeature.State(
                voiceMemos: [memo],
                selectedMemoForDeletion: memo.id,
                showDeleteConfirmation: true
            ),
            reducer: { PlaybackFeature() }
        ) {
            $0.voiceMemoRepository.delete = { _ in }
        }

        await store.send(.view(.confirmDelete)) {
            $0.voiceMemos = []
            $0.selectedMemoForDeletion = nil
            $0.showDeleteConfirmation = false
        }
        await store.receive(.delegate(.memoDeleted(memo.id)))
    }

    func test_cancelDelete_clearsDeleteState() async {
        let memo = sampleMemos[0]
        let store = TestStore(
            initialState: PlaybackFeature.State(
                voiceMemos: [memo],
                selectedMemoForDeletion: memo.id,
                showDeleteConfirmation: true
            ),
            reducer: { PlaybackFeature() }
        )

        await store.send(.view(.cancelDelete)) {
            $0.selectedMemoForDeletion = nil
            $0.showDeleteConfirmation = false
        }
    }

    // MARK: - Duration Filter Tests

    func test_durationFilter_matchesCorrectly() {
        // Test short duration filter
        XCTAssertTrue(PlaybackFeature.State.DurationFilter.short.matches(duration: 30))
        XCTAssertFalse(PlaybackFeature.State.DurationFilter.short.matches(duration: 90))

        // Test medium duration filter
        XCTAssertTrue(PlaybackFeature.State.DurationFilter.medium.matches(duration: 180))
        XCTAssertFalse(PlaybackFeature.State.DurationFilter.medium.matches(duration: 30))
        XCTAssertFalse(PlaybackFeature.State.DurationFilter.medium.matches(duration: 600))

        // Test long duration filter
        XCTAssertTrue(PlaybackFeature.State.DurationFilter.long.matches(duration: 600))
        XCTAssertFalse(PlaybackFeature.State.DurationFilter.long.matches(duration: 180))

        // Test all filter
        XCTAssertTrue(PlaybackFeature.State.DurationFilter.all.matches(duration: 30))
        XCTAssertTrue(PlaybackFeature.State.DurationFilter.all.matches(duration: 180))
        XCTAssertTrue(PlaybackFeature.State.DurationFilter.all.matches(duration: 600))
    }

    // MARK: - Search Text Tests

    func test_searchQuery_binding_updatesState() async {
        let store = TestStore(
            initialState: PlaybackFeature.State(),
            reducer: { PlaybackFeature() }
        )

        await store.send(.binding(.set(\.searchQuery, "test query"))) {
            $0.searchQuery = "test query"
        }
    }
}
