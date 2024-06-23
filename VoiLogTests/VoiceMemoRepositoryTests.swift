//
//  VoiceMemoRepositoryTests.swift
//  VoiLogTests
//
//  Created by 遠藤拓弥 on 2024/06/22.
//

import Foundation
import XCTest
@testable import VoiLog

class VoiceMemoRepositoryTests: XCTestCase {
    var mockAccessor: MockVoiceMemoCoredataAccessor!
    var repository: VoiceMemoRepository!

    override func setUp() {
        super.setUp()
        mockAccessor = MockVoiceMemoCoredataAccessor()
        repository = VoiceMemoRepository(coreDataAccessor: mockAccessor)
    }

    override func tearDown() {
        mockAccessor = nil
        repository = nil
        super.tearDown()
    }

    func testInsertVoice() {
        let state = RecordingMemo.State(
            uuid: UUID(),
            date: Date(),
            duration: 60.0,
            url: URL(string: "file:///path/to/voice.m4a")!,
            resultText: "Test voice memo"
        )

        repository.insert(state: state)

        XCTAssertEqual(mockAccessor.insertedVoice?.id, state.uuid)
        XCTAssertEqual(mockAccessor.insertedVoice?.createdAt, state.date)
        XCTAssertEqual(mockAccessor.insertedVoice?.duration, state.duration)
        XCTAssertEqual(mockAccessor.insertedVoice?.url, state.url)
        XCTAssertEqual(mockAccessor.insertedVoice?.text, state.resultText)
        XCTAssertEqual(mockAccessor.insertedVoice?.fileFormat, state.fileFormat)
        XCTAssertEqual(mockAccessor.insertedVoice?.samplingFrequency, state.samplingFrequency)
        XCTAssertEqual(mockAccessor.insertedVoice?.quantizationBitDepth, Int16(state.quantizationBitDepth))
        XCTAssertEqual(mockAccessor.insertedVoice?.numberOfChannels, Int16(state.numberOfChannels))
    }

    func testSelectAllData() {
        // Setup mock data
        mockAccessor.fetchedVoice = VoiceMemoRepository.Voice(
            title: "Test",
            url: URL(string: "file:///path/to/voice.m4a")!,
            id: UUID(),
            text: "Test voice memo",
            createdAt: Date(),
            duration: 60.0,
            fileFormat: "m4a",
            samplingFrequency: 44100.0,
            quantizationBitDepth: 16,
            numberOfChannels: 2
        )
        let result = repository.selectAllData()
        XCTAssertTrue(result.isEmpty)
    }

    func testFetchVoice() {
        let uuid = UUID()
        let expectedVoice = VoiceMemoRepository.Voice(
            title: "Test",
            url: URL(string: "file:///path/to/voice.m4a")!,
            id: uuid,
            text: "Test voice memo",
            createdAt: Date(),
            duration: 60.0,
            fileFormat: "m4a",
            samplingFrequency: 44100.0,
            quantizationBitDepth: 16,
            numberOfChannels: 2
        )
        mockAccessor.fetchedVoice = expectedVoice

        let result = repository.fetch(uuid: uuid)
        XCTAssertEqual(result?.uuid, expectedVoice.id)
        XCTAssertEqual(result?.date, expectedVoice.createdAt)
        XCTAssertEqual(result?.duration, expectedVoice.duration)
        XCTAssertEqual(result?.url, expectedVoice.url)
        XCTAssertEqual(result?.resultText, expectedVoice.text)
    }

    func testDeleteVoice() {
        let uuid = UUID()
        repository.delete(id: uuid)
        XCTAssertEqual(mockAccessor.deletedId, uuid)
    }

    func testUpdateVoice() {
        let state = VoiceMemoReducer.State(
            uuid: UUID(),
            date: Date(),
            duration: 60.0,
            time: 0,
            title: "Updated title",
            url: URL(string: "file:///path/to/voice.m4a")!,
            text: "Updated text",
            fileFormat: "m4a",
            samplingFrequency: 44100.0,
            quantizationBitDepth: 16,
            numberOfChannels: 2,
            hasPurchasedPremium: true
        )

        repository.update(state: state)

        XCTAssertEqual(mockAccessor.updatedVoice?.id, state.uuid)
        XCTAssertEqual(mockAccessor.updatedVoice?.createdAt, state.date)
        XCTAssertEqual(mockAccessor.updatedVoice?.duration, state.duration)
        XCTAssertEqual(mockAccessor.updatedVoice?.url, state.url)
        XCTAssertEqual(mockAccessor.updatedVoice?.text, state.text)
        XCTAssertEqual(mockAccessor.updatedVoice?.title, state.title)
        XCTAssertEqual(mockAccessor.updatedVoice?.fileFormat, state.fileFormat)
        XCTAssertEqual(mockAccessor.updatedVoice?.samplingFrequency, state.samplingFrequency)
        XCTAssertEqual(mockAccessor.updatedVoice?.quantizationBitDepth, Int16(state.quantizationBitDepth))
        XCTAssertEqual(mockAccessor.updatedVoice?.numberOfChannels, Int16(state.numberOfChannels))
    }

    func testUpdateTitle() {
        let uuid = UUID()
        let newTitle = "New Title"

        repository.updateTitle(uuid: uuid, newTitle: newTitle)

        XCTAssertEqual(mockAccessor.updatedTitle?.uuid, uuid)
        XCTAssertEqual(mockAccessor.updatedTitle?.newTitle, newTitle)
    }
}
