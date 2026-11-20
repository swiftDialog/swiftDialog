//
//  ItemRowConsistencyTests.swift
//  dialogTests
//
//  Item rows read the same on the three list presets.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog

// One item-row model on every item preset: the word from ItemSetModel.row, the colour from
// itemStatusColor. Preset 3's tile is the one with a view-state type to test directly.
@MainActor
final class ItemRowConsistencyTests: XCTestCase {
    private func state(_ items: [(String, String)] = [("a", "Alpha")]) throws -> InspectState {
        let s = InspectState()
        s.items = try items.map { try JSONDecoder().decode(InspectConfig.ItemConfig.self,
            from: Data(#"{"id":"\#($0.0)","displayName":"\#($0.1)"}"#.utf8)) }
        return s
    }

    func testTheSharedWords() throws {
        let s = try state()
        XCTAssertEqual(ItemSetModel.row(for: s.items[0], state: s).statusText, "Waiting")
        s.downloadingItems = ["a"]
        XCTAssertEqual(ItemSetModel.row(for: s.items[0], state: s).statusText, "Installing...")
        s.downloadingItems = []; s.completedItems = ["a"]
        XCTAssertEqual(ItemSetModel.row(for: s.items[0], state: s).statusText, "Completed")
        s.failedItems = ["a"]
        XCTAssertEqual(ItemSetModel.row(for: s.items[0], state: s).statusText, "Failed", "failed wins, as the glyph")
    }

    func testAFinishedTileDropsAStaleInstallLine() throws {
        let s = try state()
        s.completedItems = ["a"]; s.logMonitorStatuses["a"] = "Installing Alpha…"
        let tile = OnboardingTileState(item: s.items[0], state: s, accent: .blue, palette: .fixture)
        XCTAssertEqual(tile.statusText, "Completed", "Preset 3 used to keep showing 'Installing Alpha…' here")
        XCTAssertEqual(tile.statusColor, ResolvedPalette.fixture.success, "the palette's success, so a brand colour reaches Preset 3")
    }

    func testTheTileAddsItsPercentOnlyToTheWord() throws {
        let s = try state()
        s.downloadingItems = ["a"]; s.itemProgress["a"] = 42
        XCTAssertEqual(OnboardingTileState(item: s.items[0], state: s, accent: .blue, palette: .fixture).statusText, "Installing... 42%")
        s.itemStatusText["a"] = "Copying files"
        XCTAssertEqual(OnboardingTileState(item: s.items[0], state: s, accent: .blue, palette: .fixture).statusText, "Copying files",
                       "a script's own line is shown as sent")
    }

    func testAuthoredWordsWinEverywhere() throws {
        let s = InspectState()
        s.items = [try JSONDecoder().decode(InspectConfig.ItemConfig.self,
            from: Data(#"{"id":"a","displayName":"Alpha","completedStatus":"Ready to use","pendingStatus":"Up next"}"#.utf8))]
        XCTAssertEqual(ItemSetModel.row(for: s.items[0], state: s).statusText, "Up next")
        s.completedItems = ["a"]
        XCTAssertEqual(OnboardingTileState(item: s.items[0], state: s, accent: .blue, palette: .fixture).statusText, "Ready to use")
    }
}
