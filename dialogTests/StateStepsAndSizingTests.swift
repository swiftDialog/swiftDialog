//
//  StateStepsAndSizingTests.swift
//  dialogTests
//
//  The shared state and its steps: completion, outcomes, visibility, the item lifecycle, the
//  shared navigation, step language, the guidance update and set commands, plist polling, sizes
//  and the required-selection validation.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog

// A plist key that contains dots is ONE key — launchd's disabled.plist holds
// `com.apple.screensharing` — and the dotted walk is only the fallback.
@MainActor
final class PlistExactKeyTests: XCTestCase {

    private func writePlist(_ dict: [String: Any]) throws -> String {
        let path = NSTemporaryDirectory() + "plist-exact-\(UUID().uuidString).plist"
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: URL(fileURLWithPath: path))
        addTeardownBlock { try? FileManager.default.removeItem(atPath: path) }
        return path
    }

    func testADottedKeyIsReadWhole() throws {
        let path = try writePlist(["com.apple.screensharing": false, "Settings": ["Network": ["enabled": true]]])
        XCTAssertEqual(Validation.shared.getPlistValue(at: path, key: "com.apple.screensharing"), "false")
        XCTAssertEqual(Validation.shared.getPlistValue(at: path, key: "Settings.Network.enabled"), "true",
                       "the nested walk still works when no exact key matches")
        XCTAssertNil(Validation.shared.getPlistValue(at: path, key: "com.apple.remotedesktop"))
    }

    func testTheStatusPollerHoldsTheSameRule() {
        let dict: [String: Any] = ["com.apple.screensharing": false, "a": ["b": 1]]
        XCTAssertEqual(PlistStatusPoller.readNestedKey(from: dict, keyPath: "com.apple.screensharing") as? Bool, false)
        XCTAssertEqual(PlistStatusPoller.readNestedKey(from: dict, keyPath: "a.b") as? Int, 1)
    }
}

// The shorter language: progress entries derived from the cards, category selectors, the
// inferred key — so an author writes each option once.
final class ShorterLanguageTests: XCTestCase {

    private var cards: [InspectConfig.OptionCard] { get throws { try JSONDecoder().decode(
        [InspectConfig.OptionCard].self, from: Data(#"""
        [{"id":"everything","label":"Everything","category":"Quick","includes":["category:Quick"]},
         {"id":"a","label":"A","subtitle":"First","category":"Quick","sfSymbol":"a.circle",
          "iconPath":"/System/Library/CoreServices/Finder.app"},
         {"id":"b","label":"B","category":"Quick","runMessage":"Doing B now"},
         {"id":"wipe","label":"Wipe","category":"Removes","runOrder":1,"cancels":["category:Quick"]},
         {"id":"c","label":"C","category":"Other"}]
        """#.utf8)) } }

    func testCategorySelectorsExpandToTheSection() {
        XCTAssertEqual(OptionPlan.expand(["category:Quick", "c"], in: try cards), ["everything", "a", "b", "c"])
        XCTAssertEqual(OptionPlan.resolve(cards: try cards, picked: ["everything"]).run, ["everything", "a", "b"],
                       "an umbrella including its own category does not include itself")
        XCTAssertEqual(OptionPlan.resolve(cards: try cards, picked: ["everything", "c", "wipe"]).run, ["wipe", "c"])
    }

    func testEntriesAreDerivedFromTheCardsInRunOrder() throws {
        let entries = OptionPlan.cadenceEntries(cards: try cards, run: ["wipe", "a", "b"], minDwell: 0.5, timeout: nil)
        XCTAssertEqual(entries.map(\.id), ["a", "b", "wipe"], "runOrder 1 runs after the 0s, ties in card order")
        XCTAssertEqual(entries[0].label, "A")
        XCTAssertEqual(entries[0].subtitle, "First")
        XCTAssertEqual(entries[0].sfSymbol, "a.circle")
        XCTAssertEqual(entries[0].imagePath, "/System/Library/CoreServices/Finder.app")
        XCTAssertEqual(entries[0].message, "A…")
        XCTAssertEqual(entries[1].message, "Doing B now")
        XCTAssertEqual(entries[0].attribute.source, "ipc")
        XCTAssertEqual(entries[0].minDwell, 0.5)
        XCTAssertEqual(entries[0].timeout, 600)
    }

    func testTheOnlyChooserIsTheFollowedKey() throws {
        let one = try JSONDecoder().decode([InspectConfig.IntroStep].self, from: Data(#"""
        [{"id":"pick","stepType":"options","optionMultiSelect":true,"optionKey":"tasks"},
         {"id":"single","stepType":"options","optionKey":"restart"}]
        """#.utf8))
        XCTAssertEqual(OptionPlan.followedKey(explicit: nil, in: one), "tasks")
        XCTAssertEqual(OptionPlan.followedKey(explicit: "other", in: one), "other")
        let two = try JSONDecoder().decode([InspectConfig.IntroStep].self, from: Data(#"""
        [{"id":"p1","stepType":"options","optionMultiSelect":true},
         {"id":"p2","stepType":"options","optionMultiSelect":true}]
        """#.utf8))
        XCTAssertNil(OptionPlan.followedKey(explicit: nil, in: two), "two choosers and no name: no guess")
    }
}

// `<step>.done` / `<step>.failed`: a later step depends on what the run really did.
final class CadenceOutcomeTests: XCTestCase {
    func testOutcomeSplitsFinishedFromFailed() {
        let o = CadenceMonitorService.outcome(entries: ["zoom", "teams", "slack"], passed: 3,
                                              timedOut: [0], failed: [0])
        XCTAssertEqual(o.done, ["teams", "slack"])
        XCTAssertEqual(o.failed, ["zoom"])
    }

    func testAnUnfinishedRunRecordsOnlyWhatPassed() {
        let o = CadenceMonitorService.outcome(entries: ["zoom", "teams", "slack"], passed: 1,
                                              timedOut: [], failed: [])
        XCTAssertEqual(o.done, ["zoom"])
        XCTAssertTrue(o.failed.isEmpty)
    }

    func testLintKnowsAProgressStepRecordsItsOutcome() throws {
        let json = #"{"preset":"5","introSteps":[{"id":"run","stepType":"cadence","cadence":[]},{"id":"perm","stepType":"intro","title":"x","showWhen":{"key":"run.done","anyOf":["zoom"]}}]}"#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        XCTAssertFalse(InspectLint.lint(config: config).contains { $0.message.contains("records 'run.done'") })
    }
}

// One outcome record and one visibility rule for every preset.
final class CrossPresetOutcomeTests: XCTestCase {
    private func steps(_ json: String) throws -> [InspectConfig.IntroStep] {
        try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8)).introSteps ?? []
    }

    func testItemOutcomeIsConfigOrderedAndFailureWins() {
        let o = StepOutcome.items(["slack", "zoom", "teams"], completed: ["teams", "zoom", "slack"], failed: ["zoom"])
        XCTAssertEqual(o.done, ["slack", "teams"])
        XCTAssertEqual(o.failed, ["zoom"])
    }

    func testRecordWritesBothKeys() {
        var values: [String: String] = [:]
        StepOutcome.record(into: &values, scope: "run", done: ["a", "b"], failed: ["c"])
        XCTAssertEqual(values["run.done"], "a,b")
        XCTAssertEqual(values["run.failed"], "c")
    }

    func testNavigationPassesOverStepsThatDoNotShow() throws {
        let s = try steps(#"{"preset":"6","introSteps":[{"id":"a","title":"a"},{"id":"perm","title":"p","showWhen":{"key":"run.done","anyOf":["zoom"]}},{"id":"end","title":"e"}]}"#)
        XCTAssertEqual(StepVisibility.next(after: 0, in: s, values: [:]), 2, "no zoom: the permission step is passed over")
        XCTAssertEqual(StepVisibility.next(after: 0, in: s, values: ["run.done": "teams,zoom"]), 1)
        XCTAssertEqual(StepVisibility.previous(before: 2, in: s, values: [:]), 0, "Back passes over it too")
        XCTAssertNil(StepVisibility.next(after: 2, in: s, values: [:]))
    }

    func testABlockCarriesShowWhen() throws {
        let block = try JSONDecoder().decode(InspectConfig.GuidanceContent.self,
            from: Data(#"{"type":"info","content":"Allow screen recording","showWhen":{"key":"items.done","anyOf":["zoom"]}}"#.utf8))
        XCTAssertEqual(block.showWhen?.key, "items.done")
        XCTAssertFalse(block.showWhen!.matches(["items.done": "slack"]))
        XCTAssertTrue(block.showWhen!.matches(["items.done": "slack,zoom"]))
    }
}

// The consolidated shared pieces keep each preset's behaviour.
@MainActor
final class InspectQuickWinParityTests: XCTestCase {
    private func item(_ id: String) throws -> InspectConfig.ItemConfig {
        try JSONDecoder().decode(InspectConfig.ItemConfig.self, from: Data(#"{"id":"\#(id)","displayName":"\#(id)"}"#.utf8))
    }

    private func state(_ ids: [String]) throws -> InspectState {
        let state = InspectState()
        state.items = try ids.map(item)
        return state
    }

    // MARK: Words: every word each preset accepted resolves as before.

    func testEveryWordAPresetAcceptedResolvesAsBefore() {
        let old: [String: StepStatus] = [
            "success": .completed, "completed": .completed,
            "failed": .failed, "error": .failed,
            "downloading": .active, "installing": .active, "checking": .active, "running": .active,
            "pending": .pending
        ]
        for (word, status) in old {
            XCTAssertEqual(StepStatus(itemCommand: word), status, word)
            XCTAssertEqual(StepStatus(itemCommand: word.uppercased()), status, "case-insensitive, as before: \(word)")
        }
        // Spellings newly accepted:
        XCTAssertEqual(StepStatus(itemCommand: "complete"), .completed)
        XCTAssertEqual(StepStatus(itemCommand: "installed"), .completed)
        XCTAssertEqual(StepStatus(itemCommand: "fail"), .failed)
        XCTAssertEqual(StepStatus(itemCommand: "failure"), .failed)
        XCTAssertEqual(StepStatus(itemCommand: "active"), .active)
        XCTAssertEqual(StepStatus(itemCommand: "wait"), .active)
        XCTAssertEqual(StepStatus(itemCommand: "skipped"), .skipped, "every handler treats skipped as no change")
        XCTAssertNil(StepStatus(itemCommand: "bogus"))
    }

    // MARK: Item-set transitions

    func testCompletedClearsFailedAndWorkingAndPinsProgress() throws {
        let s = try state(["a"])
        s.failedItems = ["a"]; s.downloadingItems = ["a"]
        s.applyItemStatus("a", .completed)
        XCTAssertEqual(s.completedItems, ["a"]); XCTAssertTrue(s.failedItems.isEmpty)
        XCTAssertTrue(s.downloadingItems.isEmpty); XCTAssertEqual(s.itemProgress["a"], 100)
    }

    func testFailedClearsCompletedAndWorking() throws {
        let s = try state(["a"])
        s.completedItems = ["a"]; s.downloadingItems = ["a"]
        s.applyItemStatus("a", .failed)
        XCTAssertEqual(s.failedItems, ["a"]); XCTAssertTrue(s.completedItems.isEmpty); XCTAssertTrue(s.downloadingItems.isEmpty)
    }

    func testActiveClearsAFailureAndACompletion() throws {
        let s = try state(["a", "b"])
        s.failedItems = ["a"]; s.completedItems = ["b"]
        s.applyItemStatus("a", .active); s.applyItemStatus("b", .active)
        XCTAssertEqual(s.downloadingItems, ["a", "b"])
        XCTAssertTrue(s.failedItems.isEmpty, "retry clears the failure")
        XCTAssertTrue(s.completedItems.isEmpty, "consolidated: a re-driven finished item shows working (it stayed completed on P1–3 before)")
    }

    func testTheGlobalCommandFileRecordsAnyId() throws {
        let s = try state(["a"])
        s.applyItemStatus("step-only", .completed, knownItemsOnly: false)
        XCTAssertEqual(s.completedItems, ["step-only"])
    }

    func testPendingClearsEverythingAndProgress() throws {
        let s = try state(["a"])
        s.completedItems = ["a"]; s.itemProgress["a"] = 40
        s.applyItemStatus("a", .pending)
        XCTAssertTrue(s.completedItems.isEmpty); XCTAssertNil(s.itemProgress["a"])
    }

    func testUnknownIdsAndSkippedChangeNothing() throws {
        let s = try state(["a"])
        s.applyItemStatus("ghost", .completed)
        s.applyItemStatus("a", .skipped)
        XCTAssertTrue(s.completedItems.isEmpty); XCTAssertTrue(s.failedItems.isEmpty); XCTAssertTrue(s.downloadingItems.isEmpty)
    }

    func testTheCommandSetsTheLineFirstEvenForAnUnknownWord() throws {
        let s = try state(["a"])
        s.applyItemStatusCommand("a", word: "checking", message: "Checking FileVault…")
        XCTAssertEqual(s.itemStatusText["a"], "Checking FileVault…"); XCTAssertEqual(s.downloadingItems, ["a"])
        s.applyItemStatusCommand("a", word: "success", message: nil)
        XCTAssertNil(s.itemStatusText["a"], "a status without a message clears the line")
        s.applyItemStatusCommand("a", word: "bogus", message: "still updates the line")
        XCTAssertEqual(s.itemStatusText["a"], "still updates the line", "as the old closure did")
        XCTAssertEqual(s.completedItems, ["a"], "but no state changes")
        s.applyItemStatusCommand("ghost", word: "success", message: "x")
        XCTAssertNil(s.itemStatusText["ghost"])
    }

    // MARK: step_add / step_remove

    private func steps(_ ids: [String]) throws -> [InspectConfig.IntroStep] {
        let list = ids.map { #"{"id":"\#($0)","title":"\#($0)"}"# }.joined(separator: ",")
        return try JSONDecoder().decode(InspectConfig.self, from: Data(#"{"preset":"5","introSteps":[\#(list)]}"#.utf8)).introSteps ?? []
    }

    private func applied(_ o: StepListMutation.Outcome) -> (ids: [String], index: Int, cursor: Int)? {
        guard case .applied(let s, let i, let c, _) = o else { return nil }
        return (s.map(\.id), i, c)
    }

    func testAddAppendsAtOrAfterAndKeepsTheMountedStepMounted() throws {
        let base = try steps(["a", "b", "c"])
        let append = applied(StepListMutation.add(payload: #"{"step":{"id":"x","title":"x"}}"#, to: base, cursor: 1, label: "T"))
        XCTAssertEqual(append?.ids, ["a", "b", "c", "x"]); XCTAssertEqual(append?.cursor, 1)
        let before = applied(StepListMutation.add(payload: #"{"step":{"id":"x","title":"x"},"at":0}"#, to: base, cursor: 1, label: "T"))
        XCTAssertEqual(before?.ids, ["x", "a", "b", "c"]); XCTAssertEqual(before?.cursor, 2, "inserted before the cursor: cursor moves with its step")
        let after = applied(StepListMutation.add(payload: #"{"step":{"id":"x","title":"x"},"after":"b"}"#, to: base, cursor: 1, label: "T"))
        XCTAssertEqual(after?.ids, ["a", "b", "x", "c"]); XCTAssertEqual(after?.cursor, 1)
        let atCursor = applied(StepListMutation.add(payload: #"{"step":{"id":"x","title":"x"},"at":1}"#, to: base, cursor: 1, label: "T"))
        XCTAssertEqual(atCursor?.cursor, 2, "inserted AT the cursor also moves it, as both presets did")
        let intoEmpty = applied(StepListMutation.add(payload: #"{"step":{"id":"x","title":"x"}}"#, to: [], cursor: 0, label: "T"))
        XCTAssertEqual(intoEmpty?.cursor, 0, "nothing was mounted: the cursor stays")
    }

    func testAddRejectionsAndReplay() throws {
        let base = try steps(["a"])
        func rejected(_ payload: String) -> Bool {
            if case .rejected = StepListMutation.add(payload: payload, to: base, cursor: 0, label: "T") { return true }
            return false
        }
        XCTAssertTrue(rejected("not json"))
        XCTAssertTrue(rejected(#"{"step":{"id":"","title":"x"}}"#), "id required")
        XCTAssertTrue(rejected(#"{"step":{"id":"x","title":"x"},"after":"a","at":0}"#), "after and at are exclusive")
        XCTAssertTrue(rejected(#"{"step":{"id":"x","title":"x"},"after":"nope"}"#), "unknown anchor")
        XCTAssertTrue(rejected(#"{"step":{"id":"x","title":"x"},"at":5}"#), "out of range")
        XCTAssertTrue(rejected(#"{"step":{"id":"a","title":"different"}}"#), "same id, different step")
        if case .duplicate(let id) = StepListMutation.add(payload: #"{"step":{"id":"a","title":"a"}}"#, to: base, cursor: 0, label: "T") {
            XCTAssertEqual(id, "a")
        } else { XCTFail("an identical replay is a duplicate, acked ok") }
    }

    func testRemoveKeepsTheMountedStepAndRefusesToRemoveIt() throws {
        let base = try steps(["a", "b", "c"])
        let gone = applied(StepListMutation.remove(id: "a", from: base, cursor: 2))
        XCTAssertEqual(gone?.ids, ["b", "c"]); XCTAssertEqual(gone?.cursor, 1)
        let later = applied(StepListMutation.remove(id: "c", from: base, cursor: 0))
        XCTAssertEqual(later?.cursor, 0)
        if case .rejected = StepListMutation.remove(id: "b", from: base, cursor: 1) {} else { XCTFail("current step") }
        if case .rejected = StepListMutation.remove(id: "zz", from: base, cursor: 1) {} else { XCTFail("unknown id") }
    }

    // MARK: batch_update

    func testBatchUpdateResolution() throws {
        let json = #"{"preset":"5","introSteps":[{"id":"one","title":"1"},{"id":"two","title":"2","content":[{"type":"text","content":"a"},{"type":"status-badge","id":"badge","label":"B"}]}]}"#
        let list = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8)).introSteps ?? []
        guard case .success(let byId) = GuidanceBatchUpdate.resolve(#"{"step":"two","updates":{"0":{"value":"x"},"badge":{"state":"ok"},"nope":{"v":"1"}}}"#, in: list) else {
            return XCTFail("resolves")
        }
        XCTAssertEqual(byId.stepId, "two"); XCTAssertEqual(Set(byId.blocks.keys), [0, 1]); XCTAssertEqual(byId.unresolvedKeys, ["nope"])
        guard case .success(let anyStep) = GuidanceBatchUpdate.resolve(#"{"step":"_","updates":{"badge":{"state":"ok"}}}"#, in: list) else {
            return XCTFail("_ finds the step holding the block")
        }
        XCTAssertEqual(anyStep.stepId, "two")
        XCTAssertEqual(GuidanceBatchUpdate.resolve("nope", in: list).failure, .invalidJSON)
        XCTAssertEqual(GuidanceBatchUpdate.resolve(#"{"step":"one","updates":{}}"#, in: list).failure, .unknownStep("one"),
                       "a step without content cannot take a batch, as before")
    }
}

private extension Result {
    var failure: Failure? { if case .failure(let f) = self { return f }; return nil }
}


// One item lifecycle for every inspect surface (`ItemLifecycle`).
final class ItemLifecycleTests: XCTestCase {
    private func run(_ start: (Set<String>, Set<String>, Set<String>), _ status: StepStatus) -> ItemLifecycle {
        var l = ItemLifecycle(completed: start.0, failed: start.1, active: start.2)
        l.apply("x", status)
        return l
    }

    func testEveryTransitionFromEveryState() {
        let starts: [(Set<String>, Set<String>, Set<String>)] = [([], [], []), (["x"], [], []), ([], ["x"], []), ([], [], ["x"])]
        for start in starts {
            XCTAssertEqual(run(start, .completed), ItemLifecycle(completed: ["x"], failed: [], active: []))
            XCTAssertEqual(run(start, .failed), ItemLifecycle(completed: [], failed: ["x"], active: []))
            XCTAssertEqual(run(start, .active), ItemLifecycle(completed: [], failed: [], active: ["x"]))
            XCTAssertEqual(run(start, .pending), ItemLifecycle(completed: [], failed: [], active: []))
            XCTAssertEqual(run(start, .skipped), ItemLifecycle(completed: start.0, failed: start.1, active: start.2))
        }
    }

    func testOtherItemsAreUntouched() {
        var l = ItemLifecycle(completed: ["a"], failed: ["b"], active: ["c"])
        l.apply("x", .completed)
        XCTAssertEqual(l, ItemLifecycle(completed: ["a", "x"], failed: ["b"], active: ["c"]))
    }
}

// Processing steps on Presets 5 and 6: one start/countdown flow and one completion record.
final class StepCompletionTests: XCTestCase {
    private func step(_ json: String) throws -> InspectConfig.IntroStep {
        try XCTUnwrap(try JSONDecoder().decode(InspectConfig.self,
            from: Data(#"{"preset":"5","introSteps":[\#(json)]}"#.utf8)).introSteps?.first)
    }

    func testStart() throws {
        XCTAssertEqual(ProcessingFlow.start(try step(#"{"id":"a","stepType":"processing","processingDuration":5}"#)), .countdown(seconds: 5))
        XCTAssertEqual(ProcessingFlow.start(try step(#"{"id":"a","stepType":"processing","waitForExternalTrigger":true}"#)), .wait,
                       "no countdown but waiting for a trigger: wait (Preset 6 used to complete at once)")
        XCTAssertEqual(ProcessingFlow.start(try step(#"{"id":"a","stepType":"processing","successMessage":"Done"}"#)),
                       .completeNow(.success(message: "Done")))
        XCTAssertEqual(ProcessingFlow.start(try step(#"{"id":"a","stepType":"processing","processingDuration":0,"waitForExternalTrigger":true}"#)), .wait)
    }

    func testAfterCountdown() throws {
        XCTAssertEqual(ProcessingFlow.afterCountdown(try step(#"{"id":"a","processingDuration":3,"waitForExternalTrigger":true}"#)), .wait)
        XCTAssertEqual(ProcessingFlow.afterCountdown(try step(#"{"id":"a","processingDuration":3,"processingMode":"progressive"}"#)), .wait)
        XCTAssertEqual(ProcessingFlow.afterCountdown(try step(#"{"id":"a","processingDuration":3,"autoResult":"failure"}"#)),
                       .complete(.failure(message: "Operation failed")))
        XCTAssertEqual(ProcessingFlow.afterCountdown(try step(#"{"id":"a","processingDuration":3,"autoResult":"failure","failureMessage":"Nope"}"#)),
                       .complete(.failure(message: "Nope")))
        XCTAssertEqual(ProcessingFlow.afterCountdown(try step(#"{"id":"a","processingDuration":3,"successMessage":"Yes"}"#)),
                       .complete(.success(message: "Yes")))
    }

    private struct Book { var completed = Set<String>(); var failed = [String: String](); var skipped = Set<String>(); var values = [String: String]() }

    private func record(_ r: InspectCompletionResult, _ id: String, _ steps: [InspectConfig.IntroStep], _ b: inout Book) -> StepCompletion.Effect {
        StepCompletion.record(r, stepId: id, steps: steps, completed: &b.completed, failed: &b.failed, skipped: &b.skipped, values: &b.values)
    }

    func testEveryResult() throws {
        let steps = [try step(#"{"id":"a","stepType":"processing"}"#)]
        var b = Book(skipped: ["a"])
        XCTAssertEqual(record(.failure(message: nil), "a", steps, &b), .completed)
        XCTAssertEqual(b.failed["a"], "Step failed"); XCTAssertTrue(b.skipped.isEmpty); XCTAssertEqual(b.values["processingResult_a"], "failed")
        XCTAssertEqual(b.completed, ["a"], "a failed step is finished, flagged by failed")
        _ = record(.warning(message: nil), "a", steps, &b)
        XCTAssertNil(b.failed["a"]); XCTAssertEqual(b.values["processingResult_a"], "warning")
        _ = record(.cancelled, "a", steps, &b)
        XCTAssertEqual(b.skipped, ["a"]); XCTAssertEqual(b.values["processingResult_a"], "skipped")
        _ = record(.success(message: "ok"), "a", steps, &b)
        XCTAssertTrue(b.skipped.isEmpty); XCTAssertNil(b.failed["a"]); XCTAssertEqual(b.values["processingResult_a"], "success")
    }

    func testManualConfirmRecordsWithoutCompleting() throws {
        let steps = [try step(#"{"id":"a","stepType":"processing","requireManualConfirm":true}"#)]
        var b = Book()
        XCTAssertEqual(record(.failure(message: "x"), "a", steps, &b), .awaitingConfirm)
        XCTAssertTrue(b.completed.isEmpty); XCTAssertEqual(b.failed["a"], "x"); XCTAssertEqual(b.values["processingResult_a"], "failed")
        XCTAssertEqual(record(.success(message: nil), "a", steps, &b), .awaitingConfirm)
        XCTAssertEqual(b.values["processingResult_a"], "success")
    }

    func testUnknownStepsRecordNothing() throws {
        var b = Book()
        XCTAssertEqual(record(.success(message: nil), "ghost", [try step(#"{"id":"a"}"#)], &b), .unknownStep)
        XCTAssertTrue(b.completed.isEmpty); XCTAssertTrue(b.values.isEmpty)
    }
}

extension StepCompletionTests {
    func testTheClickCompletesWithTheRecordedResult() {
        var completed = Set<String>(), failed = [String: String](), skipped = Set<String>()
        XCTAssertFalse(StepCompletion.confirm(stepId: "a", completed: &completed, failed: &failed, skipped: &skipped, values: [:]),
                       "nothing recorded: an ordinary Continue")
        failed["a"] = "Disk full"
        XCTAssertTrue(StepCompletion.confirm(stepId: "a", completed: &completed, failed: &failed, skipped: &skipped,
                                             values: ["processingResult_a": "failed"]))
        XCTAssertEqual(completed, ["a"]); XCTAssertEqual(failed["a"], "Disk full", "the recorded reason stays")
        XCTAssertTrue(StepCompletion.confirm(stepId: "b", completed: &completed, failed: &failed, skipped: &skipped,
                                             values: ["processingResult_b": "success"]))
        XCTAssertTrue(completed.contains("b")); XCTAssertNil(failed["b"])
    }
}

extension StepCompletionTests {
    /// A retry leaves nothing behind: the outcome and the recorded result `showWhen` reads are gone,
    /// and another step's record is untouched.
    func testAResetClearsTheOutcomeAndTheRecordedResult() {
        var completed: Set = ["a", "b"], failed = ["a": "Disk full"], skipped: Set<String> = ["a"]
        var values = ["processingResult_a": "failed", "processingResult_b": "success", "other": "x"]
        StepCompletion.reset(stepId: "a", completed: &completed, failed: &failed, skipped: &skipped, values: &values)
        XCTAssertEqual(completed, ["b"]); XCTAssertTrue(failed.isEmpty); XCTAssertTrue(skipped.isEmpty)
        XCTAssertNil(values["processingResult_a"])
        XCTAssertEqual(values["processingResult_b"], "success"); XCTAssertEqual(values["other"], "x")
    }

    func testAnOverrideIsTheConfirmation() throws {
        let steps = [try XCTUnwrap(try JSONDecoder().decode(InspectConfig.self, from: Data(
            #"{"preset":"5","introSteps":[{"id":"a","stepType":"processing","requireManualConfirm":true}]}"#.utf8)).introSteps?.first)]
        var completed = Set<String>(), failed = [String: String](), skipped = Set<String>(), values = [String: String]()
        let effect = StepCompletion.record(.failure(message: "Marked as failed by user"), stepId: "a", steps: steps, confirmed: true,
                                           completed: &completed, failed: &failed, skipped: &skipped, values: &values)
        XCTAssertEqual(effect, .completed, "the user chose it: no second click")
        XCTAssertEqual(completed, ["a"]); XCTAssertEqual(failed["a"], "Marked as failed by user")
    }
}

extension StepCompletionTests {
    func testTheOverrideIsOptIn() throws {
        let plain = try XCTUnwrap(try JSONDecoder().decode(InspectConfig.self, from: Data(
            #"{"preset":"5","introSteps":[{"id":"a","stepType":"processing","processingDuration":2}]}"#.utf8)).introSteps?.first)
        let optedIn = try XCTUnwrap(try JSONDecoder().decode(InspectConfig.self, from: Data(
            #"{"preset":"5","introSteps":[{"id":"a","stepType":"processing","processingDuration":2,"allowOverride":true}]}"#.utf8)).introSteps?.first)
        XCTAssertEqual(ProcessingFlow.overrideLevel(for: plain, waited: 120), .none, "no allowOverride: never offered (schema default false)")
        XCTAssertEqual(ProcessingFlow.overrideLevel(for: nil, waited: 120), .none)
        XCTAssertEqual(ProcessingFlow.overrideLevel(for: optedIn, waited: 5), .none)
        XCTAssertEqual(ProcessingFlow.overrideLevel(for: optedIn, waited: 12), .warning)
        XCTAssertEqual(ProcessingFlow.overrideLevel(for: optedIn, waited: 20), .small)
        XCTAssertEqual(ProcessingFlow.overrideLevel(for: optedIn, waited: 90), .large)
    }
}

// Navigation shared by Presets 5 and 6, and the IPC verbs that steer what a user can click.
final class SharedNavigationTests: XCTestCase {
    private func steps(_ json: String) throws -> [InspectConfig.IntroStep] {
        try JSONDecoder().decode(InspectConfig.self, from: Data(#"{"preset":"6","introSteps":[\#(json)]}"#.utf8)).introSteps ?? []
    }

    func testSkipIfCompleteSkipsASatisfiedStepUnlessRevisitable() throws {
        let s = try steps(#"{"id":"a","title":"a"},{"id":"b","title":"b","skipIfComplete":true},{"id":"c","title":"c","skipIfComplete":true,"revisitable":true},{"id":"d","title":"d"}"#)
        let done: Set<String> = ["b", "c"]
        XCTAssertEqual(StepVisibility.next(after: 0, in: s, values: [:], isSatisfied: { done.contains($0.id) }), 2,
                       "b is complete and skips; c is revisitable and shows")
        XCTAssertEqual(StepVisibility.next(after: 0, in: s, values: [:]), 1, "nothing satisfied: b shows")
        XCTAssertEqual(StepVisibility.previous(before: 3, in: s, values: [:], isSatisfied: { _ in true }), 2,
                       "Back: c is revisitable, so it shows even when satisfied")
        XCTAssertEqual(StepVisibility.previous(before: 2, in: s, values: [:], isSatisfied: { _ in true }), 0,
                       "Back: b is complete and passes over")
    }

    func testRecordedPicksSatisfyAChooser() throws {
        let s = try steps(#"{"id":"pick","stepType":"options","optionKey":"team","optionCards":[{"id":"x","label":"X"}]}"#)
        XCTAssertTrue(StepVisibility.hasRecordedPick(s[0], userValues: ["team": "x"], dockSelection: [:], wallpaperSelection: [:]))
        XCTAssertFalse(StepVisibility.hasRecordedPick(s[0], userValues: [:], dockSelection: [:], wallpaperSelection: [:]))
    }

    func testAutoAdvanceAfterCompletion() throws {
        let s = try steps(#"{"id":"a","stepType":"processing","autoAdvance":true},{"id":"b","stepType":"processing","autoAdvance":true,"requireManualConfirm":true},{"id":"c","stepType":"processing"}"#)
        XCTAssertTrue(ProcessingFlow.advancesAfterCompletion(s[0], result: .success(message: nil)))
        XCTAssertTrue(ProcessingFlow.advancesAfterCompletion(s[0], result: .cancelled))
        XCTAssertFalse(ProcessingFlow.advancesAfterCompletion(s[0], result: .failure(message: nil)), "a failure stays on screen")
        XCTAssertFalse(ProcessingFlow.advancesAfterCompletion(s[1], result: .success(message: nil)), "waits for the click")
        XCTAssertFalse(ProcessingFlow.advancesAfterCompletion(s[2], result: .success(message: nil)), "not opted in")
    }

    func testOverrideWords() {
        XCTAssertEqual(CommandRouter.overrideResult("success"), .success(message: nil))
        XCTAssertEqual(CommandRouter.overrideResult("FAILED"), .failure(message: "Marked as failed by user"))
        XCTAssertEqual(CommandRouter.overrideResult("skip"), .cancelled)
        XCTAssertNil(CommandRouter.overrideResult("maybe"))
    }
}

// The language rule both step presets share, and the icon loader for an app's bundle.
final class StepLanguageTests: XCTestCase {
    private func steps(_ json: String) throws -> [InspectConfig.IntroStep] {
        try JSONDecoder().decode(InspectConfig.self, from: Data(#"{"preset":"6","introSteps":[\#(json)]}"#.utf8)).introSteps ?? []
    }

    func testAPickFromOutsideTheFlowCounts() throws {
        let s = try steps(#"{"id":"a","title":"a"},{"id":"b","title":"b"}"#)
        XCTAssertEqual(StepLanguage.manualSelection(key: "preferredLanguage", steps: s,
                                                    userValues: ["preferredLanguage": "de"], formInputs: [:]), "de",
                       "IPC select: / MDM — Preset 6 used to ignore it")
        XCTAssertNil(StepLanguage.pickerIndex(key: "preferredLanguage", steps: s))
        XCTAssertTrue(StepLanguage.applies(isManual: true, pickerIndex: nil, stepIndex: 0),
                      "picked from outside: every step is translated")
    }

    func testAPickerInTheFlowTranslatesFromItsStep() throws {
        let s = try steps(#"{"id":"intro","title":"i"},{"id":"lang","stepType":"options","optionKey":"preferredLanguage","optionCards":[{"id":"de","label":"Deutsch"}]},{"id":"after","title":"a"}"#)
        XCTAssertEqual(StepLanguage.pickerIndex(key: "preferredLanguage", steps: s), 1, "an option step is a picker too")
        XCTAssertFalse(StepLanguage.applies(isManual: true, pickerIndex: 1, stepIndex: 0))
        XCTAssertTrue(StepLanguage.applies(isManual: true, pickerIndex: 1, stepIndex: 2))
        XCTAssertTrue(StepLanguage.applies(isManual: false, pickerIndex: 1, stepIndex: 0), "the default language translates all")
    }

    func testGridBeatsRecordedBeatsForm() throws {
        let s = try steps(#"{"id":"a","title":"a"}"#)
        XCTAssertEqual(StepLanguage.manualSelection(key: "k", steps: s, userValues: ["k": "fr"], formInputs: [:],
                                                    gridSelections: ["k": ["it"]]), "it")
    }

    @MainActor
    func testAnAppBundleLoadsAsItsIcon() {
        let app = "/System/Applications/Calculator.app"
        XCTAssertNil(NSImage(contentsOfFile: app), "why the row drew a placeholder")
        XCTAssertNotNil(ItemArt.image(at: app))
    }
}


// update_guidance on Presets 5 and 6: one parser, one store, one reader.
@MainActor
final class GuidanceUpdateCommandTests: XCTestCase {
    private func steps() throws -> [InspectConfig.IntroStep] {
        try JSONDecoder().decode(InspectConfig.self, from: Data(#"""
        {"preset":"6","introSteps":[
          {"id":"one","title":"1","content":[{"type":"text","content":"a"},{"type":"status-badge","id":"badge","label":"B"}]},
          {"id":"two","title":"2","content":[{"type":"prose","id":"answer","content":""}]}]}
        """#.utf8)).introSteps ?? []
    }

    private func resolve(_ c: String, current: Int = 0) throws -> GuidanceUpdateCommand.Resolved? {
        let s = try steps()
        if case .success(let r) = GuidanceUpdateCommand.resolve(c, steps: s, currentStep: s[current]) { return r }
        return nil
    }

    func testForms() throws {
        XCTAssertEqual(try resolve("update_guidance:one:badge:state=success"),
                       .init(stepId: "one", blockIndex: 1, operation: .setProperty("state", "success")))
        XCTAssertEqual(try resolve("update_guidance:_:answer:line=- item"),
                       .init(stepId: "two", blockIndex: 0, operation: .append("- item\n")), "_ finds the step holding the block")
        XCTAssertEqual(try resolve(#"update_guidance:one:0:content=a\nb"#)?.operation, .setProperty("content", "a\nb"))
        XCTAssertEqual(try resolve("update_guidance:one:0:Plain text")?.operation, .setProperty("content", "Plain text"))
        XCTAssertEqual(try resolve("update_guidance:typo:0:x=1", current: 1)?.stepId, "two",
                       "an id that matches no step means the current one (Preset 5's rule)")
    }

    func testFailures() throws {
        let s = try steps()
        XCTAssertEqual(GuidanceUpdateCommand.resolve("update_guidance:one:0", steps: s, currentStep: nil), .failure(.malformed))
        XCTAssertEqual(GuidanceUpdateCommand.resolve("update_guidance:one:nope:x=1", steps: s, currentStep: nil), .failure(.unknownBlock("nope")))
    }

    func testABatchContentShowsOnEveryPreset() throws {
        let state = InspectDynamicState()
        state.updateGuidancePropertiesBatch(stepId: "one", blocks: [0: ["content": "Replaced by batch"]])
        let block = try steps()[0].content![0]
        XCTAssertEqual(state.applied(to: block, blockIndex: 0, stepId: "one").content, "Replaced by batch",
                       "Preset 6 read content from a second store and never showed this")
    }
}

// set: on Presets 5 and 6: one handler, one store.
@MainActor
final class DynamicSetCommandTests: XCTestCase {
    private func steps() throws -> [InspectConfig.IntroStep] {
        try JSONDecoder().decode(InspectConfig.self, from: Data(#"""
        {"preset":"6","introSteps":[
          {"id":"one","title":"1","content":[{"type":"status-badge","id":"fv","label":"FileVault"},{"type":"phase-tracker","currentPhase":1}]},
          {"id":"two","title":"2","content":[{"type":"status-badge","label":"Firewall"}]}]}
        """#.utf8)).introSteps ?? []
    }

    private func set(_ state: InspectDynamicState, _ type: String, _ value: String, _ extra: String? = nil) throws -> String? {
        DynamicSetCommand.apply(type: type, value: value, extra: extra, steps: try steps(), currentStepId: "one", state: state)
    }

    func testStatusBadgeFindsItsBlockOnAnyStep() throws {
        let s = InspectDynamicState()
        _ = try set(s, "status-badge", "Firewall", "success")
        XCTAssertEqual(s.dynamicGuidanceProperties["two"]?[0]?["state"], "success",
                       "Preset 5 only searched the current step")
        _ = try set(s, "status-badge", "fv", "failed")
        XCTAssertEqual(s.dynamicGuidanceProperties["one"]?[0]?["state"], "failed")
    }

    func testPhaseTrackerReachesEveryTracker() throws {
        let s = InspectDynamicState()
        _ = try set(s, "phase-tracker", "3")
        let block = try steps()[0].content![1]
        XCTAssertEqual(s.applied(to: block, blockIndex: 1, stepId: "one").currentPhase, 3,
                       "Preset 6 looked for type 'phaseTracker' and never matched")
        _ = try set(s, "clear", "phase-tracker")
        XCTAssertEqual(s.applied(to: block, blockIndex: 1, stepId: "one").currentPhase, 1)
    }

    func testOverridesLiveInTheSharedStore() throws {
        let s = InspectDynamicState()
        _ = try set(s, "heroImage", "two", "SF=star")
        _ = try set(s, "iconBasePath", "/Library/Icons")
        XCTAssertEqual(s.heroImageOverrides["two"], "SF=star")
        XCTAssertEqual(s.iconBasePathOverride, "/Library/Icons")
        s.updateDisplayData(stepId: "two", key: "serial", value: "C02X")
        _ = try set(s, "clear", "heroImage")
        XCTAssertTrue(s.heroImageOverrides.isEmpty)
        XCTAssertEqual(s.customDataDisplay["two"]?.first?.1, "C02X",
                       "clearing heroes leaves display_data alone (Preset 6 wiped it)")
        _ = try set(s, "clear", "all")
        XCTAssertNil(s.iconBasePathOverride)
        XCTAssertNil(try set(s, "bogus", "x"))
    }
}

// MARK: - Window sizes

/// Preset 5 gets exactly 820×600 from the size table; a size name never re-decides the design.
/// Larger sizes come from explicit width/height, which resolve above the table.
final class SizeDoctrineTests: XCTestCase {
    func testPreset5IgnoresEveryFormerSizeMode() {
        for mode in ["compact", "large", "assistant", "portal", "setup", "standard", "overall", ""] {
            let size = InspectSizes.getSize(preset: "preset5", mode: mode)
            XCTAssertEqual(size.0, 820, "preset5 mode '\(mode)' widened the window")
            XCTAssertEqual(size.1, 600, "preset5 mode '\(mode)' changed the height")
        }
    }

    func testExplicitSizeStillResolvesAboveTheTable() {
        let resolved = InspectSizes.windowSize(width: 1200, height: 800, preset: "preset5",
                                               mode: "large", itemCount: 0, chrome: nil)
        XCTAssertEqual(resolved.size, CGSize(width: 1200, height: 800))
    }

    // MARK: - One size per construction

    /// One size per construction.
    func testConstructionSizes() {
        // Plain and card share 820×600; rail sits with sidebar at 920×620 because the column decides the footprint.
        XCTAssertEqual(InspectSizes.Construction.plain.size, CGSize(width: 820, height: 600))
        XCTAssertEqual(InspectSizes.Construction.sidebar.size, CGSize(width: 920, height: 620))
        XCTAssertEqual(InspectSizes.Construction.card.size, CGSize(width: 820, height: 600))
        XCTAssertEqual(InspectSizes.Construction.rail.size, CGSize(width: 920, height: 620))
        XCTAssertEqual(InspectSizes.Construction.toast.size, CGSize(width: 550, height: 110))
    }

    /// A preset that IS a construction takes its size, under every spelling of its name.
    func testPresetsResolveToTheirConstruction() {
        let expected: [(names: [String], w: CGFloat, h: CGFloat)] = [
            (["1", "preset1"], 820, 600),
            (["5", "preset5", "portal", "self-service", "webview-portal"], 820, 600),
            (["6", "preset6", "guidance", "modern-sidebar"], 920, 620),
            (["4", "preset4", "toast", "compact-installer"], 550, 110)
        ]
        for group in expected {
            for name in group.names {
                let size = InspectSizes.getSize(preset: name, mode: "standard")
                XCTAssertEqual(size.0, group.w, "\(name) width")
                XCTAssertEqual(size.1, group.h, "\(name) height")
            }
        }
    }

    /// No preset moves on a mode name: `size:"large"` grows none of them.
    func testLargeNeverResizesAnyPreset() {
        for preset in ["1", "2", "3", "4", "5", "6", "7"] {
            let large = InspectSizes.getSize(preset: preset, mode: "large")
            let standard = InspectSizes.getSize(preset: preset, mode: "standard")
            XCTAssertEqual(large.0, standard.0, "preset\(preset) widened on size:\"large\"")
            XCTAssertEqual(large.1, standard.1, "preset\(preset) grew on size:\"large\"")
        }
    }

    /// `compact` is retired everywhere, the toast included: no preset changes size on it.
    func testCompactChangesNoWindow() {
        for preset in ["1", "4", "5", "6", "7"] {
            let compact = InspectSizes.getSize(preset: preset, mode: "compact")
            let standard = InspectSizes.getSize(preset: preset, mode: "standard")
            XCTAssertEqual(compact.0, standard.0, "preset\(preset) shrank on size:\"compact\"")
            XCTAssertEqual(compact.1, standard.1, "preset\(preset) shrank on size:\"compact\"")
        }
    }

    /// No size name scales content; the Preset 4 toast has one size.
    func testNoSizeNameScales() {
        for mode in ["compact", "setup", "large", "assistant", "portal", "standard", "overall"] {
            XCTAssertEqual(InspectSizes.scale(mode: mode), 1.0,
                           "mode '\(mode)' still scales content")
        }
        XCTAssertEqual(InspectSizes.scale(mode: nil), 1.0)
    }

    /// Preset 4 has one window: `compact` no longer selects 480×100.
    func testTheToastHasOneSize() {
        let compact = InspectSizes.getSize(preset: "4", mode: "compact")
        let standard = InspectSizes.getSize(preset: "4", mode: "standard")
        XCTAssertEqual(compact.0, standard.0); XCTAssertEqual(compact.1, standard.1)
        XCTAssertEqual(standard.0, 550); XCTAssertEqual(standard.1, 110)
    }

    /// Retired size names (`setup`) still decode and are inert, so configs using them render at 1.0.
    func testRetiredSizeNamesStayDecodableAndInert() throws {
        let json = Data(#"{"preset":"5","title":"t","size":"setup"}"#.utf8)
        let config = try JSONDecoder().decode(InspectConfig.self, from: json)
        XCTAssertEqual(config.size, "setup", "the key must still decode")
        XCTAssertEqual(InspectSizes.scale(mode: config.size), 1.0, "but it must not scale")
    }

    /// Case cannot revive a retired name.
    func testSizeModeNamesAreCaseInsensitive() {
        XCTAssertEqual(InspectSizes.scale(mode: "COMPACT"), 1.0)
        XCTAssertEqual(InspectSizes.scale(mode: "Compact"), 1.0)
    }

    /// Preset 3 lists by default (the 3.1.1 look); `chrome: "grid"` opts in to tiles. The window
    /// height follows the layout: one 52pt row per item, or one 155pt row per five tiles.
    func testPreset3ListIsTheDefaultAndGridIsOptIn() {
        XCTAssertFalse(InspectSizes.preset3UsesGrid(chrome: nil))
        XCTAssertFalse(InspectSizes.preset3UsesGrid(chrome: "list"))
        XCTAssertFalse(InspectSizes.preset3UsesGrid(chrome: "plain"), "an unknown value lists, like absence")
        XCTAssertTrue(InspectSizes.preset3UsesGrid(chrome: " Grid "))

        let list = InspectSizes.getSize(preset: "3", mode: "standard", itemCount: 6)
        let grid = InspectSizes.getSize(preset: "3", mode: "standard", itemCount: 6, chrome: "grid")
        XCTAssertEqual(list.1, 330 + 6 * 52)
        XCTAssertEqual(grid.1, 330 + 2 * 155)
        XCTAssertEqual(InspectSizes.getSize(preset: "3", mode: "standard", itemCount: 40).1, 820, "capped")
    }

    /// Presets 2 and 3 have exactly one size each, with no mode ladder.
    func testLegacyPresetsHaveExactlyOneSizeEach() {
        let two = InspectSizes.getSize(preset: "preset2", mode: "standard")
        XCTAssertEqual(two.0, 860); XCTAssertEqual(two.1, 600)
        let three = InspectSizes.getSize(preset: "preset3", mode: "standard")
        XCTAssertEqual(three.0, 760); XCTAssertEqual(three.1, 820)
        // Preset 7 normalizes onto preset 5; see InspectDensityTests.
    }

    /// Preset 3 keeps the one content-adaptive height (its tile rows).
    func testPreset3HeightStillAdaptsToRows() {
        let short = InspectSizes.getSize(preset: "preset3", mode: "standard", itemCount: 3)
        let long = InspectSizes.getSize(preset: "preset3", mode: "standard", itemCount: 40)
        XCTAssertEqual(short.0, 760)
        XCTAssertLessThan(short.1, long.1, "fewer items should give a shorter window")
        XCTAssertLessThanOrEqual(long.1, 820, "never taller than the fixed max")
    }

    /// The card/rail rung reads the construction table; the origin wording is read by log tooling.
    func testChromeRungReadsTheConstructionTable() {
        let card = InspectSizes.windowSize(width: nil, height: nil, preset: "preset5",
                                           mode: nil, itemCount: 0, chrome: "card")
        XCTAssertEqual(card.size, InspectSizes.Construction.card.size)
        XCTAssertTrue(card.origin.contains("820×600"), "origin wording changed: \(card.origin)")
    }
}

// MARK: - Required pickers and selects

/// `required: true` on a picker or select block holds Continue until the user chooses. Pickers key
/// their answer off a resolved selection key, and may have no `guidanceFormInputs` entry.
@MainActor
final class RequiredSelectionValidationTests: XCTestCase {

    private func validate(_ json: String, on state: InspectState) throws -> Bool {
        let block = try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(json.utf8))
        return state.validateGuidanceInputs(content: [block], itemId: "step")
    }

    /// A required picker with nothing chosen blocks.
    func testRequiredOptionPickerBlocksUntilSomethingIsChosen() {
        let json = #"{"type": "option-picker", "required": true, "optionKey": "browser", "optionCards": [{"id": "safari", "label": "Safari"}]}"#
        let state = InspectState()
        XCTAssertFalse(try validate(json, on: state), "an unanswered required option-picker must block Continue")

        state.userValues["browser"] = "safari"
        XCTAssertTrue(try validate(json, on: state), "once answered it must pass")
    }

    /// The key is the resolved selection key, not `block.id`.
    func testTheFallbackKeyIsUsedWhenNoneIsAuthored() {
        let json = #"{"type": "option-picker", "required": true, "optionCards": [{"id": "a", "label": "A"}]}"#
        let state = InspectState()
        XCTAssertFalse(try validate(json, on: state))
        state.userValues["option"] = "a"          // the documented fallback
        XCTAssertTrue(try validate(json, on: state))
    }

    /// Each picker reads its own store.
    func testDockAndWallpaperPickersReadTheirOwnStores() {
        let dock = #"{"type": "dock-picker", "required": true, "dockSelectionKey": "d", "dockFlavors": [{"id": "x", "name": "X", "items": []}]}"#
        let state = InspectState()
        state.userValues["d"] = "x"
        XCTAssertFalse(try validate(dock, on: state), "dock-picker must read dockSelection, not userValues")
        state.dockSelection["d"] = "x"
        XCTAssertTrue(try validate(dock, on: state))

        let paper = #"{"type": "wallpaper-picker", "required": true, "wallpaperSelectionKey": "w", "wallpaperCategories": []}"#
        let state2 = InspectState()
        state2.userValues["w"] = "/a.heic"
        XCTAssertFalse(try validate(paper, on: state2), "wallpaper-picker must read wallpaperSelection")
        state2.wallpaperSelection["w"] = "/a.heic"
        XCTAssertTrue(try validate(paper, on: state2))
    }

    /// select-list/select-grid/multi-select validate through the form store.
    func testSelectBlocksValidateThroughTheFormStore() {
        let json = #"{"type": "select-list", "required": true, "id": "picks", "options": ["a", "b"]}"#
        let state = InspectState()
        state.initializeGuidanceFormState(for: "step")
        XCTAssertFalse(try validate(json, on: state), "an unanswered required select-list must block")

        state.guidanceFormInputs["step"]?.textfields["picks"] = "a"
        XCTAssertTrue(try validate(json, on: state))
    }

    /// A block that is not required never blocks.
    func testUnrequiredPickersNeverBlock() {
        let json = #"{"type": "option-picker", "optionKey": "browser", "optionCards": [{"id": "a", "label": "A"}]}"#
        XCTAssertTrue(try validate(json, on: InspectState()))
    }
}
