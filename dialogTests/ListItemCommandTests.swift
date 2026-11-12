//
//  ListItemCommandTests.swift
//  dialogTests
//
//  Classic `listitem:` command-file lines on presets 5 and 6: how a line resolves to a row, and that
//  the write reaches `monitoringService`, the store the rows read (not `inspectState`).
//

import XCTest
@testable import Dialog

/// `@MainActor`: `UnifiedMonitoringService` is main-actor isolated.
@MainActor
final class ListItemCommandTests: XCTestCase {

    // MARK: - Fixture

    /// Real rows decoded through a config. No `paths` or `requirements`, so the 2s poller skips
    /// them and a pushed status survives.
    private func rows(_ itemsJSON: String = defaultItemsJSON,
                      file: StaticString = #filePath, line: UInt = #line) throws -> [InspectConfig.ListItem] {
        let json = #"{"preset": "preset5", "introSteps": [{"id": "install", "items": [\#(itemsJSON)]}]}"#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        return try XCTUnwrap(config.introSteps?.first?.items, file: file, line: line)
    }

    private static let defaultItemsJSON = """
        {"id": "teams", "displayName": "Microsoft Teams"},
        {"id": "chrome", "displayName": "Google Chrome"},
        {"id": "Slack", "displayName": ""}
        """

    private func resolve(_ remainder: String) throws -> ListItemCommand.Outcome {
        let items: [any MonitoredItem] = try rows()
        return ListItemCommand.resolve(remainder, items: items)
    }

    // MARK: - Resolving the row

    /// `title:` resolves to the matching row's id.
    func testTitleResolvesToTheMatchingRow() throws {
        XCTAssertEqual(try resolve(" title: Microsoft Teams, status: wait, statustext: Installing"),
                       .update(itemId: "teams", status: .active, message: "Installing"))
    }

    /// Title matching ignores case.
    func testTitleMatchesCaseInsensitively() throws {
        XCTAssertEqual(try resolve("title: microsoft TEAMS, status: success"),
                       .update(itemId: "teams", status: .completed, message: nil))
    }

    /// `displayName` first, then `id`; the third fixture row is only reachable by id.
    func testTitleFallsBackToTheRowIdWhenNoDisplayNameMatches() throws {
        XCTAssertEqual(try resolve("title: slack, status: success"),
                       .update(itemId: "Slack", status: .completed, message: nil))
    }

    /// `index:` is positional against the step's `items`.
    func testIndexResolvesPositionally() throws {
        XCTAssertEqual(try resolve("index: 0, status: success"),
                       .update(itemId: "teams", status: .completed, message: nil))
        XCTAssertEqual(try resolve("index: 1, status: wait"),
                       .update(itemId: "chrome", status: .active, message: nil))
    }

    /// An unknown title changes nothing; it is logged, never guessed.
    func testAnUnresolvableTitleChangesNothing() throws {
        XCTAssertEqual(try resolve("title: Adobe Photoshop, status: success"),
                       .unresolved(target: "Adobe Photoshop"))
    }

    /// Title is an exact name, not a substring: `Google` and `Microsoft` match no row.
    /// (`Chrome` and `Teams` are row ids, so they would resolve.)
    func testTitleIsAnExactNameNotASubstring() throws {
        XCTAssertEqual(try resolve("title: Google, status: success"),
                       .unresolved(target: "Google"))
        XCTAssertEqual(try resolve("title: Microsoft, status: success"),
                       .unresolved(target: "Microsoft"))
    }

    func testAnOutOfRangeIndexChangesNothing() throws {
        XCTAssertEqual(try resolve("index: 9, status: success"), .unresolved(target: "index 9"))
        XCTAssertEqual(try resolve("index: -1, status: success"), .unresolved(target: "index -1"))
    }

    /// A line that addresses nothing, or carries nothing, is a no-op.
    func testALineThatAddressesOrCarriesNothingIsANoOp() throws {
        XCTAssertEqual(try resolve("status: success"), .empty)
        XCTAssertEqual(try resolve("title: Microsoft Teams"), .empty)
        XCTAssertEqual(try resolve(""), .empty)
    }

    // MARK: - Status vocabulary

    /// Classic's six words (`AppDefaults.ckListStatusOptions`) map onto `StepStatus` as the classic surface maps them.
    func testEveryClassicStatusWordMapsToItsLifecycleState() {
        XCTAssertEqual(ListItemCommand.lifecycle("wait"), .active)
        XCTAssertEqual(ListItemCommand.lifecycle("progress"), .active)
        XCTAssertEqual(ListItemCommand.lifecycle("success"), .completed)
        XCTAssertEqual(ListItemCommand.lifecycle("fail"), .failed)
        XCTAssertEqual(ListItemCommand.lifecycle("error"), .failed)
        XCTAssertEqual(ListItemCommand.lifecycle("pending"), .pending)
    }

    /// Classic's own list is fully covered, so a word added there fails here.
    func testClassicsOwnVocabularyListIsFullyCovered() {
        for word in AppDefaults().ckListStatusOptions {
            XCTAssertNotNil(ListItemCommand.lifecycle(word),
                            "'\(word)' is in ckListStatusOptions and must map to a lifecycle state")
        }
    }

    /// `progress` is mapped by hand: the lenient parse rejects it as a lifecycle spelling.
    func testProgressIsMappedHereBecauseTheLenientParseRejectsIt() {
        XCTAssertNil(StepStatus(lenient: "progress"))
        XCTAssertEqual(ListItemCommand.lifecycle("progress"), .active,
                       "a downloading row must not silently render as pending")
    }

    func testTheStatusWordsCaseIsNotAContract() throws {
        XCTAssertEqual(try resolve("title: Microsoft Teams, status: SUCCESS"),
                       .update(itemId: "teams", status: .completed, message: nil))
    }

    /// An unknown status word changes nothing, and its `statustext:` is dropped with it.
    func testAnUnknownStatusWordChangesNothingIncludingTheMessage() throws {
        XCTAssertEqual(try resolve("title: Microsoft Teams, status: sparkle, statustext: Installed"),
                       .unknownStatus(word: "sparkle"))
    }

    // MARK: - statustext

    /// `statustext:` applies with or without a status.
    func testStatusTextIsCarriedWithAndWithoutAStatus() throws {
        XCTAssertEqual(try resolve("title: Google Chrome, status: wait, statustext: Downloading"),
                       .update(itemId: "chrome", status: .active, message: "Downloading"))
        XCTAssertEqual(try resolve("title: Google Chrome, statustext: Queued"),
                       .update(itemId: "chrome", status: nil, message: "Queued"))
    }

    /// Split on the first colon only; a message keeps its own punctuation.
    func testAStatusTextKeepsItsOwnPunctuation() throws {
        XCTAssertEqual(try resolve("title: Google Chrome, statustext: Downloading: 40%"),
                       .update(itemId: "chrome", status: nil, message: "Downloading: 40%"))
    }

    /// `statustext:` is not read as `status:`.
    func testStatusTextIsNotReadAsAStatus() throws {
        XCTAssertEqual(try resolve("title: Google Chrome, statustext: success"),
                       .update(itemId: "chrome", status: nil, message: "success"),
                       "the word 'success' inside statustext must stay a message")
    }

    // MARK: - Store the write reaches

    /// The outcome lands in `itemStatuses`/`statusMessages`, which the rows read.
    func testTheOutcomeAppliesToTheMonitoringStores() throws {
        let service = UnifiedMonitoringService()
        guard case .update(let itemId, let status, let message) =
                try resolve("title: Microsoft Teams, status: wait, statustext: Installing") else {
            return XCTFail("expected an update")
        }
        service.setItemStatus(itemId, status: try XCTUnwrap(status))
        service.setStatusMessage(itemId, message: try XCTUnwrap(message))
        drainMain()

        XCTAssertEqual(service.itemStatuses["teams"], .active)
        XCTAssertEqual(service.statusMessages["teams"], "Installing")
    }

    /// Runs after the service's `DispatchQueue.main.async` publish on the same serial queue.
    private func drainMain() {
        let exp = expectation(description: "main queue drained")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 2)
    }

    // MARK: - Wiring

    /// Preset 5 wires `onListItem` and writes to `monitoringService`. Checked on the source, since
    /// `monitoringService` is a `@StateObject` and not readable outside a render pass.
    func testPreset5WiresOnListItemAndWritesToTheMonitoringService() throws {
        let source = try repoSource("dialog/Views/Inspect/Preset Layouts/Preset5+Commands.swift")

        XCTAssertTrue(source.contains("commandRouter.onListItem"),
                      "Preset 5 must wire onListItem, or the router parses the line and drops it")

        let handler = try XCTUnwrap(source.range(of: "func handleListItemCommand"))
        let body = String(source[handler.lowerBound...].prefix(1200))
        XCTAssertTrue(body.contains("monitoringService.setItemStatus"),
                      "the status must reach monitoringService — the store the rows read")
        XCTAssertTrue(body.contains("monitoringService.setStatusMessage"),
                      "and so must the message")
        XCTAssertFalse(body.contains("inspectState."),
                       "inspectState is a DIFFERENT set of stores; a push routed there never "
                       + "reaches the provisioning or journey rows")
    }

    /// Preset 6 resolves its steps by title or id and applies through the `item:` status path.
    func testPreset6ResolvesStepsAndAppliesThroughTheItemStatusPath() throws {
        let steps = [(id: "welcome", name: "Welcome"), (id: "apps", name: "Install apps")]
        XCTAssertEqual(ListItemCommand.resolve("title: install apps, status: success", rows: steps),
                       .update(itemId: "apps", status: .completed, message: nil))
        XCTAssertEqual(ListItemCommand.resolve("index: 0, status: fail", rows: steps),
                       .update(itemId: "welcome", status: .failed, message: nil))
        XCTAssertEqual(ListItemCommand.resolve("title: Nope, status: wait", rows: steps),
                       .unresolved(target: "Nope"))

        let source = try repoSource("dialog/Views/Inspect/Preset Layouts/Preset6+Commands.swift")
        let handler = try XCTUnwrap(source.range(of: "func handleListItemCommand"))
        let body = String(source[handler.lowerBound...].prefix(900))
        XCTAssertTrue(body.contains("ListItemCommand.resolve") && body.contains("applyItemStatus"))
        XCTAssertFalse(body.contains("updateItemStatusIcon"))
    }

    private func repoSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
