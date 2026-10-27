//
//  StepStatusVocabularyTests.swift
//  dialogTests
//
//  The lifecycle vocabulary: every spelling `StepStatus(lenient:)` accepts and the state it maps to,
//  the retired lifecycle enums staying gone, and `ItemSetModel`'s status derivations.
//

import XCTest
@testable import Dialog

@MainActor
final class StepStatusVocabularyTests: XCTestCase {

    // MARK: - Synonym groups

    /// Restated as a literal, independent of the production table.
    private static let censusGroups: [StepStatus: Set<String>] = [
        .active: ["active", "downloading", "installing", "wait"],
        .completed: ["complete", "completed", "installed", "success"],
        .failed: ["error", "fail", "failed", "failure"],
        .pending: ["pending"],
        .skipped: ["skipped"]
    ]

    func testTheProductionTableMatchesTheCensus() {
        XCTAssertEqual(StepStatus.synonyms, Self.censusGroups,
                       "StepStatus.synonyms and the measured vocabulary must not drift")
    }

    /// One assertion per spelling, so a single mis-mapped spelling fails.
    func testEverySpellingMapsToItsMeasuredState() {
        XCTAssertEqual(StepStatus(lenient: "active"), .active)
        XCTAssertEqual(StepStatus(lenient: "downloading"), .active)
        XCTAssertEqual(StepStatus(lenient: "installing"), .active)
        XCTAssertEqual(StepStatus(lenient: "wait"), .active)

        XCTAssertEqual(StepStatus(lenient: "complete"), .completed)
        XCTAssertEqual(StepStatus(lenient: "completed"), .completed)
        XCTAssertEqual(StepStatus(lenient: "installed"), .completed)
        XCTAssertEqual(StepStatus(lenient: "success"), .completed)

        XCTAssertEqual(StepStatus(lenient: "error"), .failed)
        XCTAssertEqual(StepStatus(lenient: "fail"), .failed)
        XCTAssertEqual(StepStatus(lenient: "failed"), .failed)
        XCTAssertEqual(StepStatus(lenient: "failure"), .failed)

        XCTAssertEqual(StepStatus(lenient: "pending"), .pending)

        XCTAssertEqual(StepStatus(lenient: "skipped"), .skipped)
    }

    func testTheTableAndTheParseAgreeForEverySpelling() {
        for (state, spellings) in StepStatus.synonyms {
            for spelling in spellings {
                XCTAssertEqual(StepStatus(lenient: spelling), state,
                               "'\(spelling)' is listed under \(state) but does not parse to it")
            }
        }
    }

    /// No spelling belongs to two states.
    func testNoSpellingIsClaimedByTwoStates() {
        var seen: [String: StepStatus] = [:]
        for (state, spellings) in StepStatus.synonyms {
            for spelling in spellings {
                if let owner = seen[spelling] {
                    XCTFail("'\(spelling)' is claimed by both \(owner) and \(state)")
                }
                seen[spelling] = state
            }
        }
        XCTAssertEqual(seen.count, 14, "the census found 14 distinct spellings")
    }

    /// Every raw value parses to itself.
    func testEveryRawValueParsesToItself() {
        for state in [StepStatus.pending, .active, .completed, .failed, .skipped] {
            XCTAssertEqual(StepStatus(lenient: state.rawValue), state)
        }
    }

    func testCaseAndWhitespaceAreNotVocabulary() {
        XCTAssertEqual(StepStatus(lenient: "Completed"), .completed)
        XCTAssertEqual(StepStatus(lenient: "INSTALLED"), .completed)
        XCTAssertEqual(StepStatus(lenient: "  failed  "), .failed)
    }

    /// An unrecognised word is nil, not `pending`; callers state their own fallback.
    func testAnUnknownWordIsNil() {
        for word in ["done", "ok", "running", "cancelled", "", "   "] {
            XCTAssertNil(StepStatus(lenient: word), "'\(word)' must not be invented")
        }
    }

    /// `StatusBadgeView.state`'s external-fact words are a separate type, not lifecycle states.
    func testExternalFactVocabularyIsNotFoldedIn() {
        for word in ["compliant", "enabled", "encrypted", "healthy", "supported"] {
            XCTAssertNil(StepStatus(lenient: word),
                         "'\(word)' describes a finding, not a step's lifecycle")
        }
    }

    /// The verdict words have one owner, `ExternalFactStatus`: `"unenrolled"` appears on a code line
    /// of exactly one inspect file, and no file has a `case "pass"` switch.
    func testTheVerdictWordsHaveOneOwner() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        var owners: [String] = []
        var oldSwitch: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for raw in text.components(separatedBy: .newlines) {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("//") { continue }
                if line.contains("\"unenrolled\"") { owners.append(file.lastPathComponent) }
                if line.contains("case \"pass\"") { oldSwitch.append(file.lastPathComponent) }
            }
        }
        XCTAssertEqual(Set(owners), ["ExternalFactStatus.swift"], "a second verdict list — alias ExternalFactStatus")
        XCTAssertEqual(oldSwitch, [], "the fold's own word switch must not come back")
    }

    // MARK: - Lifecycle enums

    /// The other lifecycle enums are gone. Progress, message and reason live beside the state
    /// (`progressValues`, `statusMessages`), as the result file keeps them beside `status`.
    func testTheFiveLifecycleEnumsHaveCollapsedOntoStepStatus() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("dialog/Views/Inspect")
        var declared: [String] = []
        let wanted = ["enum InspectItemStatus", "enum SimpleItemStatus",
                      "enum InstallRowStatus", "enum MonitoringItemStatus"]

        if let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let file as URL in walker where file.pathExtension == "swift" {
                guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
                for name in wanted where source.contains(name) {
                    declared.append("\(name) — \(file.lastPathComponent)")
                }
            }
        }
        XCTAssertEqual(declared.sorted(), [],
                       "still-separate lifecycle enums: \(declared.sorted())")
    }

    // MARK: - Retired enums

    /// Source text of a repo-relative file.
    private func repoSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }


    /// `SimpleItemStatus` stays gone.
    func testSimpleItemStatusIsGone() throws {
        let source = try repoSource("dialog/Views/Inspect/Core Framework/InspectConfig.swift")
        XCTAssertFalse(source.contains("enum SimpleItemStatus"),
                       "SimpleItemStatus had no consumers and must not come back")
    }

    /// `completedWithWarning` is `.completed` plus a validation-warning flag, not a state.
    func testCompletedWithWarningIsAFlagNotAState() throws {
        let common = try repoSource("dialog/Views/Inspect/Core Framework/PresetCommonViews.swift")
        XCTAssertFalse(common.contains("enum InstallRowStatus"),
                       "InstallRowStatus must have collapsed onto StepStatus")
        // The case, not the word.
        XCTAssertFalse(common.contains("case completedWithWarning"),
                       "the warning is a flag beside the state, not a case")
        XCTAssertTrue(common.contains("-> StepStatus"),
                      "resolveInstallStatus must answer in the shared vocabulary")

        let badge = try repoSource("dialog/Views/Inspect/Core Framework/Components/StatusComponents.swift")
        XCTAssertTrue(badge.contains("var hasWarning: Bool"),
                      "the badge takes the warning as a flag")
        XCTAssertTrue(badge.contains("let status: StepStatus"),
                      "the badge takes the shared lifecycle vocabulary")
    }

    /// `InspectItemStatus` stays gone. `StepStatus` is String-backed with a frozen wire rawValue,
    /// so a failure reason cannot be an associated value; it is kept beside the state.
    func testInspectItemStatusIsGone() throws {
        let source = try repoSource("dialog/Views/Inspect/Core Framework/InspectConfig.swift")
        XCTAssertFalse(source.contains("enum InspectItemStatus"),
                       "InspectItemStatus must have collapsed onto StepStatus")
    }

    /// `downloading` and `installing` map to `active`.
    func testDownloadingMapsOntoActive() {
        XCTAssertEqual(StepStatus(lenient: "downloading"), .active)
        XCTAssertEqual(StepStatus(lenient: "installing"), .active)
        XCTAssertEqual(StepStatus(lenient: "active"), .active)
    }

    /// `wait` is `.active`, as classic swiftDialog draws it as an in-flight spinner.
    /// The second half reads classic's source, so the two move together.
    func testWaitIsInFlightAndAgreesWithClassic() throws {
        XCTAssertEqual(StepStatus(lenient: "wait"), .active, "`wait` is in-flight, not queued")
        XCTAssertNotEqual(StepStatus(lenient: "wait"), .pending)

        let list = try repoSource("dialog/Views/ListView.swift")
        XCTAssertTrue(list.contains(#"case "wait":"#),
                      "classic still renders `wait` as its own in-flight view, not a glyph")
    }

    /// A completed-with-warning row still shows the warning glyph and its reason.
    func testTheWarningGlyphIsStillReachable() throws {
        let badge = try repoSource("dialog/Views/Inspect/Core Framework/Components/StatusComponents.swift")
        XCTAssertTrue(badge.contains("StatusGlyph.warning"),
                      "a completed-with-warning row still shows the warning glyph")
        XCTAssertTrue(badge.contains("a setting couldn't be verified"),
                      "and still says why")
    }

    /// Expected failure: raw-string lifecycle comparisons remain, probed on the two unambiguous
    /// lifecycle words.
    func testNoSiteStillComparesLifecycleStatusAsARawString() throws {
        XCTExpectFailure("comparison sites still test lifecycle status by string equality "
                         + "(scripts/status-vocab-census.py counts them)")

        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("dialog/Views/Inspect")

        // The census's site definition narrowed to two words, so external-fact strings cannot match.
        let probe = try NSRegularExpression(
            pattern: #"(?:==|!=)\s*"(installed|downloading)"|case\s+"(installed|downloading)""#)

        var sites: [String] = []
        if let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let file as URL in walker where file.pathExtension == "swift" {
                // StepModel.swift holds the parse, so it alone may switch on these strings.
                guard file.lastPathComponent != "StepModel.swift",
                      let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let range = NSRange(source.startIndex..<source.endIndex, in: source)
                if probe.firstMatch(in: source, range: range) != nil {
                    sites.append(file.lastPathComponent)
                }
            }
        }
        XCTAssertEqual(sites.sorted(), [], "raw-string lifecycle comparisons: \(sites.sorted())")
    }

    // MARK: - install-list layouts

    /// `install-list` cards/manifest map a block's status string onto `StepStatus`. `"progress"` is
    /// not a lifecycle spelling, so it is mapped explicitly.
    func testProgressIsNotALifecycleSpellingAndMustBeMappedExplicitly() {
        XCTAssertNil(StepStatus(lenient: "progress"),
                     "if this ever parses, the explicit mapping in GuidanceInstallListBlock.bridged is redundant")
        // The words that cross on their own.
        XCTAssertEqual(StepStatus(lenient: "success"), .completed)
        XCTAssertEqual(StepStatus(lenient: "wait"), .active)
        XCTAssertEqual(StepStatus(lenient: "pending"), .pending)
        XCTAssertEqual(StepStatus(lenient: "fail"), .failed)
    }

    /// An absent or unknown layout stays on rows.
    func testInstallListLayoutFallsBackToRows() {
        XCTAssertEqual(InstallListLayout(nil), .rows)
        XCTAssertEqual(InstallListLayout("rows"), .rows)
        XCTAssertEqual(InstallListLayout("nonsense"), .rows)
        XCTAssertEqual(InstallListLayout("cards"), .cards)
        XCTAssertEqual(InstallListLayout("manifest"), .manifest)
        XCTAssertEqual(InstallListLayout("MANIFEST"), .manifest, "authored case must not decide the layout")
    }

    // MARK: - ItemSetModel

    private func itemConfig(id: String, name: String) throws -> InspectConfig.ItemConfig {
        let json = #"{"id":"\#(id)","displayName":"\#(name)"}"#
        return try JSONDecoder().decode(InspectConfig.ItemConfig.self, from: Data(json.utf8))
    }

    func testItemSetModelMapsEachLifecycleStateToItsStatus() throws {
        let state = InspectState()
        state.items = [
            try itemConfig(id: "done",    name: "Done"),
            try itemConfig(id: "failed",  name: "Failed"),
            try itemConfig(id: "running", name: "Running"),
            try itemConfig(id: "waiting", name: "Waiting")
        ]
        state.completedItems   = ["done"]
        state.failedItems      = ["failed"]
        state.downloadingItems = ["running"]

        let model = ItemSetModel.build(from: state)
        // Not Dictionary(uniqueKeysWithValues:), which traps on a duplicate key.
        let byID = Dictionary(model.rows.map { ($0.item.id, $0) }, uniquingKeysWith: { first, _ in first })

        XCTAssertEqual(byID["done"]?.status,    .completed)
        XCTAssertEqual(byID["failed"]?.status,  .failed)
        XCTAssertEqual(byID["running"]?.status, .active)
        XCTAssertEqual(byID["waiting"]?.status, .pending)
    }

    /// `failed` is tested before `completed`, so an item in both reads as failed.
    func testItemSetModelPrefersFailedOverCompleted() throws {
        let state = InspectState()
        state.items = [try itemConfig(id: "both", name: "Both")]
        state.completedItems = ["both"]
        state.failedItems    = ["both"]

        let model = ItemSetModel.build(from: state)
        XCTAssertEqual(model.rows.first?.status, .failed,
                       "failed is checked first in the original derivation; extraction must not reorder it")
    }

    /// An item in both completed and failed sets (a passing plist check never clears `failedItems`)
    /// shows the failed word beside the failed glyph; `statusText` derives from the resolved `status`.
    func testItemSetModelBothCompletedAndFailedAgreesOnFailedWordAndGlyph() throws {
        let state = InspectState()
        state.items = [try itemConfig(id: "both", name: "Both")]
        state.completedItems = ["both"]
        state.failedItems    = ["both"]

        let model = ItemSetModel.build(from: state)
        let row = try XCTUnwrap(model.rows.first)

        XCTAssertEqual(row.status, .failed,
                       "failed is checked first in resolveInstallStatus")
        XCTAssertEqual(row.statusText, "Failed",
                       "the word must agree with the glyph — before the fix this independently " +
                       "re-derived \"Completed\" from displayStatusText's completed-first order")
    }

    func testItemSetModelRowCountMatchesTheItemSet() throws {
        let state = InspectState()
        state.items = [
            try itemConfig(id: "a", name: "A"),
            try itemConfig(id: "b", name: "B")
        ]
        XCTAssertEqual(ItemSetModel.build(from: state).rows.count, 2)
    }

    func testItemSetModelIsEmptyForAnEmptyItemSet() {
        XCTAssertTrue(ItemSetModel.build(from: InspectState()).rows.isEmpty)
    }

    // MARK: - ItemSetModel.statusText
    // `statusText` follows `InspectLayoutProtocol`'s default `getItemStatus(for:)`, not
    // `PresetCommonViews.getItemStatus(for:state:)`; the two differ on failed rows and log lines.

    /// A failed-only item reads "Failed", not "Waiting".
    func testItemSetModelFailedRowStatusTextReadsFailedNotWaiting() throws {
        let state = InspectState()
        state.items = [try itemConfig(id: "failed", name: "Failed")]
        state.failedItems = ["failed"]

        let model = ItemSetModel.build(from: state)
        XCTAssertEqual(model.rows.first?.statusText, "Failed",
                       "PresetCommonViews.getItemStatus has no failedItems branch and would " +
                       "read \"Waiting\" here — this is the defect the rule exists to guard")
    }

    /// A failed row honours the `uiLabels.failedStatus` override.
    func testItemSetModelStatusTextHonoursUILabelsFailedStatusOverride() throws {
        let json = #"{"preset":"1","uiLabels":{"failedStatus":"Custom Failed"}}"#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))

        let state = InspectState()
        state.config = config
        state.items = [try itemConfig(id: "failed", name: "Failed")]
        state.failedItems = ["failed"]

        let model = ItemSetModel.build(from: state)
        XCTAssertEqual(model.rows.first?.statusText, "Custom Failed",
                       "uiLabels.failedStatus must override the hardcoded \"Failed\" default")
    }

    /// A completed row whose validation failed reads the failed status and warns.
    func testItemSetModelCompletedRowWithValidationFailureReadsFailedStatusAndWarns() throws {
        let json = #"{"id":"done","displayName":"Done","plistKey":"com.example.plist"}"#
        let item = try JSONDecoder().decode(InspectConfig.ItemConfig.self, from: Data(json.utf8))

        let state = InspectState()
        state.items = [item]
        state.completedItems = ["done"]
        state.plistValidationResults = ["done": false] // validation failed

        let model = ItemSetModel.build(from: state)
        let row = try XCTUnwrap(model.rows.first)

        XCTAssertTrue(row.hasWarning, "a completed item whose plist validation failed must warn")
        XCTAssertEqual(row.statusText, "Failed",
                       "the completed-but-warning branch reads uiLabels?.failedStatus ?? " +
                       "\"Failed\", not the completed text")
    }

    /// With validation passing, a completed row warns about nothing.
    func testItemSetModelCompletedRowWithoutValidationFailureReadsCompletedAndNoWarning() throws {
        let json = #"{"id":"done","displayName":"Done","plistKey":"com.example.plist"}"#
        let item = try JSONDecoder().decode(InspectConfig.ItemConfig.self, from: Data(json.utf8))

        let state = InspectState()
        state.items = [item]
        state.completedItems = ["done"]
        state.plistValidationResults = ["done": true] // validation passed

        let model = ItemSetModel.build(from: state)
        let row = try XCTUnwrap(model.rows.first)

        XCTAssertFalse(row.hasWarning)
        XCTAssertEqual(row.statusText, "Completed")
    }

    /// A completed row takes a log-monitor line only when it starts with "Completed" or "Installed".
    func testItemSetModelCompletedRowRespectsLogMonitorPrefixGuard() throws {
        let state = InspectState()
        state.items = [try itemConfig(id: "done", name: "Done")]
        state.completedItems = ["done"]

        // A stale non-completion line is skipped.
        state.logMonitorStatuses = ["done": "Downloading update..."]
        let staleModel = ItemSetModel.build(from: state)
        XCTAssertEqual(staleModel.rows.first?.statusText, "Completed",
                       "a log line without a Completed/Installed prefix must be ignored for a " +
                       "completed item — PresetCommonViews.getItemStatus has no such guard")

        // A line with the prefix is used.
        state.logMonitorStatuses = ["done": "Completed successfully"]
        let freshModel = ItemSetModel.build(from: state)
        XCTAssertEqual(freshModel.rows.first?.statusText, "Completed successfully",
                       "a log line prefixed Completed/Installed must win")
    }

    // MARK: - Duplicate rows

    /// An item in both completed and downloading sets is listed once, as completed, so row ids stay
    /// unique for `ForEach`.
    func testAnItemInBothCompletedAndDownloadingIsListedOnceAsCompleted() throws {
        let state = InspectState()
        state.items = [try itemConfig(id: "both", name: "Both"), try itemConfig(id: "other", name: "Other")]
        state.completedItems   = ["both"]
        state.downloadingItems = ["both", "other"]

        let model = ItemSetModel.build(from: state)

        XCTAssertEqual(model.rows.map(\.id), ["both", "other"], "each item once, completed first")
        XCTAssertEqual(model.rows.first?.status, .completed)
        XCTAssertEqual(Set(model.rows.map(\.id)).count, model.rows.count, "row ids are unique")
    }
}

// MARK: - Removal notice

/// A removal and a cleared download look the same now; only history (`wasCompleted`) tells them
/// apart. The state stays pending; only the statustext differs, until the notice expires.
@MainActor
final class RemovalNoticeTests: XCTestCase {

    private func itemConfig(id: String, name: String) throws -> InspectConfig.ItemConfig {
        try JSONDecoder().decode(InspectConfig.ItemConfig.self,
                                 from: Data(#"{"id": "\#(id)", "displayName": "\#(name)", "paths": []}"#.utf8))
    }

    /// A removed row is pending, but its word says it was removed.
    func testARemovedItemSaysSoRatherThanReadingAsQueued() throws {
        let state = InspectState()
        state.items = [try itemConfig(id: "gone", name: "Gone")]
        state.removedItems = ["gone": Date()]

        let row = try XCTUnwrap(ItemSetModel.build(from: state).rows.first)
        XCTAssertEqual(row.status, .pending,
                       "a removed app is not installed, so its STATE is pending — this is deliberate")
        XCTAssertEqual(row.statusText, "Removed",
                       "only the WORD distinguishes it from an item that was never installed")
    }

    /// After `removalNoticeDwell` (30s) the row settles back to the pending word.
    func testTheNoticeExpiresAndTheRowSettles() throws {
        let state = InspectState()
        state.items = [try itemConfig(id: "gone", name: "Gone")]
        state.removedItems = ["gone": Date(timeIntervalSinceNow: -(AppInspector.removalNoticeDwell + 1))]

        XCTAssertEqual(ItemSetModel.build(from: state).rows.first?.statusText, "Waiting",
                       "past the dwell the removal stops being news")
    }

    /// An item never installed gets no notice.
    func testAnItemThatWasNeverInstalledIsUnaffected() throws {
        let state = InspectState()
        state.items = [try itemConfig(id: "fresh", name: "Fresh")]

        XCTAssertEqual(ItemSetModel.build(from: state).rows.first?.statusText, "Waiting")
    }

    /// The log monitor still wins over the filesystem inference.
    func testTheLogMonitorStillWins() throws {
        let state = InspectState()
        state.items = [try itemConfig(id: "gone", name: "Gone")]
        state.removedItems = ["gone": Date()]
        state.logMonitorStatuses["gone"] = "Reinstalling…"

        XCTAssertEqual(ItemSetModel.build(from: state).rows.first?.statusText, "Reinstalling…")
    }

    /// "Finished" means an outcome, success or not, so one failure cannot hold Continue forever.
    func testFinishedMeansAnOutcomeNotASuccess() {
        XCTAssertTrue(StepStatus.completed.isFinished)
        XCTAssertTrue(StepStatus.failed.isFinished)
        XCTAssertTrue(StepStatus.skipped.isFinished)
        XCTAssertFalse(StepStatus.pending.isFinished)
        XCTAssertFalse(StepStatus.active.isFinished)
    }
}
