//
//  ListItemCommandRuleTests.swift
//  dialogTests
//
//  The list item commands: add, order, delete and placement, with the counting rule.
//

import XCTest
@testable import Dialog

// MARK: - listitem: add

@MainActor
final class ListItemAddTests: XCTestCase {

    private let rows: [(id: String, name: String)] = [("teams", "Microsoft Teams")]

    /// `add` makes the row id the fetched config would use for the same app, so a later config takes it over.
    func testAddMakesARowIdFromTheTitle() {
        XCTAssertEqual(ListItemCommand.resolve("add, title: MiddleClick, status: wait", rows: rows),
                       .add(itemId: "app-middleclick", title: "MiddleClick", icon: nil, status: .active, message: nil))
    }

    func testAddKeepsAnIdAndIconItIsGiven() {
        XCTAssertEqual(ListItemCommand.resolve("add, id: sw-42, title: Notes, icon: SF=note.text", rows: rows),
                       .add(itemId: "sw-42", title: "Notes", icon: "SF=note.text", status: nil, message: nil))
    }

    /// The same add twice is one row, then its update.
    func testAddForARowThatExistsIsItsUpdate() {
        XCTAssertEqual(ListItemCommand.resolve("add, title: Microsoft Teams, status: success", rows: rows),
                       .update(itemId: "teams", status: .completed, message: nil))
        XCTAssertEqual(ListItemCommand.resolve("add, title: Notes, status: success",
                                               rows: [("app-notes", "Something else")]),
                       .update(itemId: "app-notes", status: .completed, message: nil), "by id")
    }

    /// Without `add`, an unknown title stays unresolved.
    func testWithoutAddAnUnknownTitleStaysUnresolved() {
        XCTAssertEqual(ListItemCommand.resolve("title: MiddleClick, status: wait", rows: rows),
                       .unresolved(target: "MiddleClick"))
    }

    /// An added row is shown and never counted toward completion.
    func testAnAddedRowNeverHoldsCompletion() {
        let state = InspectState()
        state.items = [InspectConfig.ItemConfig(id: "a", displayName: "A", guiIndex: 3)]
        state.addItem(id: "app-middleclick", title: "MiddleClick", icon: nil)
        state.addItem(id: "app-middleclick", title: "MiddleClick", icon: nil)
        XCTAssertEqual(state.items.map(\.id), ["a", "app-middleclick"], "added once")
        XCTAssertEqual(state.items.last?.guiIndex, 4, "after every configured row")

        state.applyItemStatus("app-middleclick", .active)
        state.applyItemStatus("a", .completed)
        XCTAssertEqual(state.trackedItems.map(\.id), ["a"])
        XCTAssertEqual(state.trackedCompletedCount, 1)
        XCTAssertEqual(state.trackedCompletedCount, state.trackedItems.count, "done, though MiddleClick is installing")

        state.applyItemStatus("app-middleclick", .failed)
        XCTAssertEqual(state.trackedFailedCount, 0, "an added row's failure is not the run's")
    }

    /// Rows filling a list deployed empty are the list, so they count.
    func testRowsFillingAListDeployedEmptyCount() throws {
        let state = InspectState()
        state.config = try JSONDecoder().decode(InspectConfig.self, from: Data(#"{"preset": "3", "items": []}"#.utf8))
        state.addItem(id: "sw-1", title: "Slack", icon: nil)
        state.addItem(id: "sw-2", title: "Zoom", icon: nil)
        XCTAssertEqual(state.trackedItems.map(\.id), ["sw-1", "sw-2"])
        state.applyItemStatus("sw-1", .completed)
        XCTAssertEqual(state.trackedCompletedCount, 1, "not done while Zoom is still installing")
        state.applyItemStatus("sw-2", .completed)
        XCTAssertEqual(state.trackedCompletedCount, state.trackedItems.count, "done when Fleet's rows are")
    }
}

// MARK: - listitem: order

@MainActor
final class ListItemOrderTests: XCTestCase {

    func testOrderParsesItsIds() {
        XCTAssertEqual(ListItemCommand.resolve("order, ids: b|a| c", rows: []), .order(ids: ["b", "a", "c"]))
        XCTAssertEqual(ListItemCommand.resolve("order, ids: ", rows: []), .empty)
    }

    /// Only the named rows move, into the slots they already hold.
    func testOnlyTheNamedRowsMoveAndTheyKeepTheirSlots() {
        let rows = ["bootstrap", "z", "profile", "y", "x", "script"]
        XCTAssertEqual(ListItemCommand.reordered(rows, by: ["x", "y", "z"], id: { $0 }),
                       ["bootstrap", "x", "profile", "y", "z", "script"])
        XCTAssertNil(ListItemCommand.reordered(rows, by: ["z", "y"], id: { $0 }), "already in order: nothing to do")
    }

    /// One order reaches every step holding its rows; the script added first ends up last.
    func testTheOrderReachesEveryStepThatHoldsItsRows() throws {
        let json = #"{"preset": "5", "introSteps": [{"id": "security", "stepType": "installation", "items": [{"id": "profiles", "displayName": "Configuration profiles"}, {"id": "bootstrap", "displayName": "Bootstrap package"}]}, {"id": "install", "stepType": "installation", "items": [{"id": "script", "displayName": "Finishing setup"}, {"id": "sw-2", "displayName": "Beta"}, {"id": "sw-1", "displayName": "Alpha"}]}]}"#
        let steps = try XCTUnwrap(try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8)).introSteps)
        let ordered = try XCTUnwrap(ListItemCommand.reorderingRows(of: steps, by: ["bootstrap", "profiles", "sw-1", "sw-2", "script"]))
        XCTAssertEqual(ordered[0].items?.map(\.id), ["bootstrap", "profiles"])
        XCTAssertEqual(ordered[1].items?.map(\.id), ["sw-1", "sw-2", "script"], "Finishing setup last, where it runs")
        XCTAssertNil(ListItemCommand.reorderingRows(of: ordered, by: ["bootstrap", "profiles", "sw-1", "sw-2", "script"]))
    }

    /// Items are renumbered so array order and guiIndex agree (presets 1–4 read either).
    func testItemsAreRenumberedSoEverySortModeAgrees() {
        let state = InspectState()
        state.items = ["c", "b", "a"].map { InspectConfig.ItemConfig(id: $0, displayName: $0.uppercased()) }   // all guiIndex 0
        state.reorderItems(["a", "b", "c"])
        XCTAssertEqual(state.items.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(state.items.map(\.guiIndex), [0, 1, 2])
        XCTAssertEqual(state.items.sorted { $0.guiIndex < $1.guiIndex }.map(\.id), ["a", "b", "c"])
    }
}

// MARK: - listitem: delete

@MainActor
final class ListItemDeleteTests: XCTestCase {
    private let rows: [(id: String, name: String)] = [("teams", "Microsoft Teams")]

    /// `delete` (or `remove`) by id, or by title.
    func testDeleteParsesByIdOrTitle() {
        XCTAssertEqual(ListItemCommand.resolve("delete, id: sw-7", rows: rows), .delete(itemId: "sw-7"))
        XCTAssertEqual(ListItemCommand.resolve("remove, id: sw-7", rows: rows), .delete(itemId: "sw-7"))
        XCTAssertEqual(ListItemCommand.resolve("delete, title: Microsoft Teams", rows: rows), .delete(itemId: "teams"))
        XCTAssertEqual(ListItemCommand.resolve("delete, title: Zoom", rows: rows), .unresolved(target: "Zoom"))
        XCTAssertEqual(ListItemCommand.resolve("delete", rows: rows), .empty)
    }

    /// A removed row takes its recorded state with it.
    func testARemovedRowTakesItsStateWithIt() throws {
        let state = InspectState()
        state.config = try JSONDecoder().decode(InspectConfig.self, from: Data(#"{"preset": "3", "items": []}"#.utf8))
        state.addItem(id: "sw-1", title: "Slack", icon: nil)
        state.addItem(id: "sw-2", title: "Zoom", icon: nil)
        state.applyItemStatus("sw-2", .failed)
        state.itemProgress["sw-2"] = 40
        state.removeItem("sw-2")
        XCTAssertEqual(state.items.map(\.id), ["sw-1"])
        XCTAssertEqual(state.trackedFailedCount, 0)
        XCTAssertNil(state.itemProgress["sw-2"])
        state.removeItem("nope")
        XCTAssertEqual(state.items.map(\.id), ["sw-1"], "an unknown id is a no-op")
    }
}

// MARK: - Added rows and reorders

@MainActor
final class ListItemPlacementTests: XCTestCase {
    private func steps(_ json: String) throws -> [InspectConfig.IntroStep] {
        try JSONDecoder().decode([InspectConfig.IntroStep].self, from: Data(json.utf8))
    }

    /// On a step deployed empty, added rows are the list and count; beside configured rows they are extras.
    func testARowCountsWhenItsStepWasDeployedEmpty() throws {
        let deployed = try steps(#"""
        [{"id": "splash", "stepType": "intro"},
         {"id": "setup", "stepType": "installation", "items": [{"id": "bootstrap", "displayName": "Bootstrap"}]},
         {"id": "apps", "stepType": "installation", "items": []}]
        """#)
        let place = ListItemCommand.placement(of: "sw-1", in: deployed, named: nil, current: "splash", deployed: deployed)
        XCTAssertEqual(place?.index, 2, "not the bootstrap's step (another kind): the last installation step")
        XCTAssertEqual(place?.counted, true, "deployed empty: Fleet's rows are its list")
        let now = try steps(#"""
        [{"id": "splash", "stepType": "intro"},
         {"id": "setup", "stepType": "installation", "items": [{"id": "bootstrap", "displayName": "Bootstrap"}]},
         {"id": "apps", "stepType": "installation", "items": [{"id": "sw-1", "displayName": "Slack"}]}]
        """#)
        let second = ListItemCommand.placement(of: "sw-2", in: now, named: nil, current: "splash", deployed: deployed)
        XCTAssertEqual(second?.index, 2)
        XCTAssertEqual(second?.counted, true, "the apps step was deployed empty: its second row counts too")
        XCTAssertEqual(ListItemCommand.placement(of: "profiles", in: now, named: nil, current: nil, deployed: deployed)?.counted,
                       false, "beside the configured bootstrap row: an extra")
        XCTAssertNil(ListItemCommand.placement(of: "sw-1", in: now, named: nil, current: nil, deployed: deployed),
                     "already on a step: not added again")
        XCTAssertEqual(ListItemCommand.placement(of: "x", in: now, named: "splash", current: nil, deployed: deployed)?.index, 0,
                       "step: names the step")
    }

    /// Preset 4 keeps showing the same item through a reorder.
    func testTheShownItemIsFollowedThroughAReorder() {
        let old = ["chrome", "slack", "zoom", "teams"], new = ["teams", "zoom", "slack", "chrome"]
        XCTAssertEqual(ListItemCommand.index(following: 2, from: old, to: new), 1, "Zoom, now second")
        XCTAssertNil(ListItemCommand.index(following: 2, from: old, to: ["chrome", "slack", "teams"]), "Zoom is gone")
        XCTAssertNil(ListItemCommand.index(following: 9, from: old, to: new))
    }
}
