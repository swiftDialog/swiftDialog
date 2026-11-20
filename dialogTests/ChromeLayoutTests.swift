//
//  ChromeLayoutTests.swift
//  dialogTests
//
//  Chrome arithmetic: footer models, the provisioning row builder's lists and peeks, option plans,
//  the card footer rail, the card header rule and the top inset of the plain shells.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog

// MARK: - Schema coercion: one key, two types

/// `required` is a boolean in form blocks and a string in comparison-table rows; coercion skips `checks`.
final class SchemaCoercionContextTests: XCTestCase {

    /// The comparison-table case, at its own path.
    func testRequiredStaysAStringInsideChecks() {
        let raw: [String: Any] = ["checks": [
            ["check": "FileVault", "required": "ENABLED", "found": "ENABLED"],
            ["check": "Login window", "required": "YES", "found": "YES"]
        ]]
        let out = InspectConfigCoercion.coerceScalars(in: raw) as? [String: Any]
        let rows = out?["checks"] as? [[String: Any]]
        XCTAssertEqual(rows?[1]["required"] as? String, "YES",
                       "a check's required value is display text, not a flag")
        XCTAssertNil(rows?[1]["required"] as? Bool)
    }

    /// `required` still coerces to Bool outside `checks`.
    func testRequiredStillCoercesToBoolOutsideChecks() {
        let raw: [String: Any] = ["type": "textfield", "required": "true"]
        let out = InspectConfigCoercion.coerceScalars(in: raw) as? [String: Any]
        XCTAssertEqual(out?["required"] as? Bool, true,
                       "a form field's required IS a flag and must still coerce")
    }

    /// The `checks` exemption holds at any nesting depth.
    func testTheExemptionSurvivesNesting() {
        let raw: [String: Any] = ["introSteps": [["content": [["type": "comparison-table",
            "checks": [["check": "MDM", "required": "YES", "found": "NO"]]]]]]]
        let out = InspectConfigCoercion.coerceScalars(in: raw) as? [String: Any]
        let steps = out?["introSteps"] as? [[String: Any]]
        let content = steps?[0]["content"] as? [[String: Any]]
        let rows = content?[0]["checks"] as? [[String: Any]]
        XCTAssertEqual(rows?[0]["required"] as? String, "YES")
        XCTAssertEqual(rows?[0]["found"] as? String, "NO",
                       "`found` was never in the boolean list, and must stay text either way")
    }

    // MARK: - Footer vocabulary

    func testEmptyContinueTextDrawsNoPrimary() {
        // The "" -counts-as-absent rule, stated in the model rather than at the draw site.
        XCTAssertNil(FooterActionsModel(continueText: nil, onContinue: {}).resolvedPrimary)
        XCTAssertNil(FooterActionsModel(continueText: "", onContinue: {}).resolvedPrimary)
        XCTAssertEqual(FooterActionsModel(continueText: "Continue", onContinue: {}).resolvedPrimary,
                       "Continue")
    }

    func testDisabledPrimaryDimsLabelWithFill() {
        // A disabled action dims label and fill together.
        let text = Color.black
        XCTAssertEqual(FooterPrimaryInk.tint(disabled: false, accent: .blue, text: text), .blue)
        XCTAssertEqual(FooterPrimaryInk.tint(disabled: true, accent: .blue, text: text),
                       text.opacity(0.059))
        XCTAssertEqual(FooterPrimaryInk.label(disabled: false, text: text), .white)
        XCTAssertEqual(FooterPrimaryInk.label(disabled: true, text: text), text.opacity(0.31))
    }
}

// Multi-picks, `noneOf`, and cadence entries filtered by picks — the pieces that let a config
// state which tasks run (an umbrella pick expanding, one pick cancelling another) instead of a
// script deciding it.
@MainActor
final class MultiPickTests: XCTestCase {

    typealias Rule = InspectConfig.ShowWhenConfig

    func testAnyOfAndNoneOfTestEachPickedValue() {
        let picks = ["tasks": "clear_cache,erase_data"]
        XCTAssertTrue(Rule(key: "tasks", anyOf: ["erase_data", "uninstall"]).matches(picks))
        XCTAssertFalse(Rule(key: "tasks", anyOf: ["rebuild_index"]).matches(picks))
        XCTAssertFalse(Rule(key: "tasks", noneOf: ["clear_cache"]).matches(picks))
        XCTAssertTrue(Rule(key: "tasks", noneOf: ["uninstall"]).matches(picks))
        XCTAssertTrue(Rule(key: "tasks", noneOf: ["uninstall"]).matches([:]),
                      "only noneOf: an unanswered key excludes nothing")
        XCTAssertFalse(Rule(key: "tasks", anyOf: ["clear_cache"]).matches([:]))
    }

    func testCadenceEntriesStateTheDependencyRules() throws {
        // `full_reset` is an umbrella that includes `clear_cache` and `sign_out`; `sign_out`
        // supersedes the narrower `forget_token`; `uninstall` cancels every reset.
        let step = try JSONDecoder().decode(InspectConfig.IntroStep.self, from: Data(#"""
        {"id":"run","stepType":"cadence","cadence":[
          {"id":"clear_cache","message":"Cache","attribute":{"source":"ipc"},
           "showWhen":{"key":"tasks","anyOf":["clear_cache","full_reset"],"noneOf":["uninstall"]}},
          {"id":"forget_token","message":"Token","attribute":{"source":"ipc"},
           "showWhen":{"key":"tasks","anyOf":["forget_token"],"noneOf":["sign_out","full_reset","uninstall"]}},
          {"id":"sign_out","message":"Sign out","attribute":{"source":"ipc"},
           "showWhen":{"key":"tasks","anyOf":["sign_out","full_reset"],"noneOf":["uninstall"]}},
          {"id":"uninstall","message":"Uninstall","attribute":{"source":"ipc"},
           "showWhen":{"key":"tasks","anyOf":["uninstall"]}}]}
        """#.utf8))
        func run(_ picks: String) -> [String] {
            let values = ["tasks": picks]
            return (CadenceMonitorService.resolveEntriesForDisplay(
                step: step, include: { $0.showWhen?.matches(values) ?? true }) ?? []).map(\.id)
        }
        XCTAssertEqual(run("full_reset"), ["clear_cache", "sign_out"], "an umbrella pick expands")
        XCTAssertEqual(run("forget_token,sign_out"), ["sign_out"], "the broader task supersedes the narrower")
        XCTAssertEqual(run("clear_cache,uninstall"), ["uninstall"], "uninstall cancels every reset")
    }

    func testMultiOptionRowsAndValue() throws {
        let cards = try JSONDecoder().decode([InspectConfig.OptionCard].self, from: Data(#"""
        [{"id":"clear_cache","label":"Clear the cache","subtitle":"Rebuilds on next launch","differentiator":"Reset"},
         {"id":"erase_data","label":"Erase local data","subtitle":"Offline copies",
          "differentiator":"Data loss","exposure":"Permanently deletes anything not yet synced"}]
        """#.utf8))
        let rows = ProvisioningRowBuilder.multiOptionSections(cards: cards, picked: ["erase_data"], switches: false).flatMap(\.rows)
        XCTAssertEqual(rows.map(\.mark), [.check(selected: false), .check(selected: true)])
        XCTAssertEqual(rows[1].detail, "Permanently deletes anything not yet synced", "exposure replaces the subtitle")
        XCTAssertEqual(rows[1].trailing, .state("Data loss", failed: true))
        XCTAssertEqual(ProvisioningRowBuilder.multiOptionValue(cards: cards, selected: ["erase_data", "clear_cache"]),
                       "clear_cache,erase_data", "stored in card order")
    }
}

// A scrolling row list shows a half row at its edge, so the overflow is visible before anyone
// scrolls; a list that fits keeps its height.
final class ScrollingListPeekTests: XCTestCase {

    func testAScrollingListEndsOnAHalfRow() {
        for height in [CGFloat(600), 640, 720] {
            let metrics = ProvisioningM(width: 820, height: height)
            let list = metrics.scrollingListHeight()
            XCTAssertEqual(list.truncatingRemainder(dividingBy: ProvisioningM.rowHeight), ProvisioningM.rowHeight / 2,
                           "at \(height) the last visible row is cut in half")
            XCTAssertLessThanOrEqual(list, metrics.listRegionHeight - ProvisioningM.minimumBandSlack,
                                     "at \(height) the peek stays clear of the band")
        }
    }

    func testTheBandCountsTheWholeList() {
        XCTAssertEqual(ProvisioningRowBuilder.multiOptionBand(count: 0, total: 13),
                       .consequence(text: "Nothing selected · 13 options", detail: nil, swatch: nil))
        XCTAssertEqual(ProvisioningRowBuilder.multiOptionBand(count: 2, total: 13),
                       .consequence(text: "2 of 13 selected", detail: nil, swatch: nil))
    }
}

// The rules on the cards — `includes` and `cancels` — and the one resolver every screen reads.
final class OptionPlanTests: XCTestCase {

    // `everything` includes two resets; `broad` supersedes `narrow`; `rebuild` cancels the resets.
    private var cards: [InspectConfig.OptionCard] { get throws { try JSONDecoder().decode(
        [InspectConfig.OptionCard].self, from: Data(#"""
        [{"id":"everything","label":"Everything","category":"Quick","includes":["reset_a","reset_b"]},
         {"id":"reset_a","label":"Reset A","category":"Quick","sfSymbol":"a.circle"},
         {"id":"reset_b","label":"Reset B","category":"Quick"},
         {"id":"narrow","label":"Narrow","category":"Sign-in"},
         {"id":"broad","label":"Broad","category":"Sign-in","cancels":["narrow"]},
         {"id":"rebuild","label":"Rebuild","category":"Removes","exposure":"Deletes local data",
          "differentiator":"Data loss","cancels":["everything","reset_a","reset_b","narrow","broad"]}]
        """#.utf8)) } }

    func testIncludesExpandAndCancelsWin() throws {
        let umbrella = OptionPlan.resolve(cards: try cards, picked: ["everything"])
        XCTAssertEqual(umbrella.run, ["everything", "reset_a", "reset_b"])
        XCTAssertEqual(umbrella.includedBy["reset_a"], "everything")

        let both = OptionPlan.resolve(cards: try cards, picked: ["narrow", "broad"])
        XCTAssertEqual(both.run, ["broad"])
        XCTAssertEqual(both.cancelledBy["narrow"], "broad")

        let removal = OptionPlan.resolve(cards: try cards, picked: ["everything", "broad", "rebuild"])
        XCTAssertEqual(removal.run, ["rebuild"], "a cancel beats a pick and an include")
    }

    func testRowsShowTheStatesInTheirSections() throws {
        let sections = ProvisioningRowBuilder.multiOptionSections(cards: try cards, picked: ["everything", "narrow", "broad"],
                                                                  switches: true)
        XCTAssertEqual(sections.map(\.title), ["Quick", "Sign-in", "Removes"])
        XCTAssertEqual(sections.map(\.warns), [false, false, true], "the group holding exposure warns")
        let a = sections[0].rows[1]
        XCTAssertEqual(a.mark, .symbol("a.circle", on: true))
        XCTAssertEqual(a.trailing, .toggle(on: true))
        XCTAssertEqual(a.detail, "Included in Everything")
        XCTAssertFalse(a.enabled, "an included option is fixed on")
        let narrow = sections[1].rows[0]
        XCTAssertEqual(narrow.trailing, .toggle(on: false))
        XCTAssertEqual(narrow.detail, "Cancelled by Broad")
        XCTAssertFalse(narrow.enabled)
    }

    func testTheReviewListsWhatRunsThenWhatIsSkipped() throws {
        let picked: Set<String> = ["everything", "narrow", "rebuild"]
        let plan = OptionPlan.resolve(cards: try cards, picked: picked)
        let rows = ProvisioningRowBuilder.reviewRows(cards: try cards, picked: picked, plan: plan)
        XCTAssertEqual(rows.map(\.id), ["rebuild", "everything", "narrow"])
        XCTAssertEqual(rows[0].trailing, .state("Data loss", failed: true))
        XCTAssertEqual(rows[1].trailing, .state("Skipped", failed: false))
        XCTAssertEqual(rows[1].detail, "Cancelled by Rebuild")
        XCTAssertEqual(ProvisioningRowBuilder.multiOptionBand(count: 3, total: 6, runs: 1),
                       .consequence(text: "3 of 6 selected · 1 will run", detail: nil, swatch: nil))
    }
}


// A sectioned list's viewport cuts a row through its middle wherever the headers fall, and a
// scrolling list leaves the scroller its own lane.
final class SectionedListPeekTests: XCTestCase {

    private func rows(_ n: Int, _ prefix: String) -> [ProvisioningRowModel] {
        (0..<n).map { ProvisioningRowModel(id: "\(prefix)\($0)", name: "\($0)") }
    }

    func testThePeekEndsMidRowUnderAHeader() {
        let sections = [ProvisioningRowSection(id: "a", title: "Quick", warns: false, rows: rows(7, "a")),
                        ProvisioningRowSection(id: "b", title: "More", warns: false, rows: rows(3, "b"))]
        let room: CGFloat = 300
        let peek = ProvisioningSectionedList.peekHeight(sections, room: room)
        let spans = ProvisioningSectionedList.rowSpans(sections)
        XCTAssertLessThanOrEqual(peek, room)
        XCTAssertTrue(spans.contains { $0.top + $0.height / 2 == peek },
                      "the viewport ends through the middle of a row, not on a boundary")
        XCTAssertEqual(spans[0].top, ProvisioningSectionedList.headerHeight, "the header takes its 30")
    }

    func testTheScrollerHasALane() {
        XCTAssertEqual(ProvisioningSectionedList.scrollerGutter, 16)
    }

    func testASwitchRowCarriesTheCardsIcon() throws {
        let cards = try JSONDecoder().decode([InspectConfig.OptionCard].self, from: Data(#"""
        [{"id":"a","label":"A","sfSymbol":"a.circle","iconPath":"/System/Library/CoreServices/Finder.app"},
         {"id":"b","label":"B","sfSymbol":"b.circle"}]
        """#.utf8))
        let switches = ProvisioningRowBuilder.multiOptionSections(cards: cards, picked: [], switches: true)[0].rows
        XCTAssertEqual(switches.map(\.art), ["/System/Library/CoreServices/Finder.app", nil])
        let boxes = ProvisioningRowBuilder.multiOptionSections(cards: cards, picked: [], switches: false)[0].rows
        XCTAssertEqual(boxes.map(\.art), [nil, nil], "a checkbox row has no icon slot")
    }
}


// One rail per flow (`flowFooterRail`): every footer of a step flow puts the primary the same
// distance from the window edge — 44 for a card flow, 40 for every other.
final class CardFooterRailTests: XCTestCase {
    func testTheRailFollowsTheFlowsConstruction() {
        XCTAssertEqual(FooterBandM.flowRail(card: true), InspectMetrics.unit.cardEdge)
        XCTAssertEqual(InspectMetrics.unit.cardEdge, 44, "card chrome keeps its 44pt card edge")
        XCTAssertEqual(FooterBandM.flowRail(card: false), InspectMetrics.unit.cardEdge, "one edge for every step flow")
        XCTAssertEqual(FooterBandM.rail, 40, "the band's own rail, for the presets that set no flow rail")
    }

    func testEveryBandHasTheSameAirAndTheRailColumnMatchesIt() {
        XCTAssertEqual(FooterBandM.air(), 28)
        XCTAssertEqual(InspectMetrics.unit.railContentBottom, FooterBandM.air(),
                       "the Preset 6 rail's primary sat 26 up; it sits 28 up like every band")
        XCTAssertEqual(PlainBrandedM.pillTrailing, FooterBandM.rail, "plain-branded sat 20 in; it sits 40 in")
        XCTAssertEqual(PlainBrandedM.pillBottom, FooterBandM.air())
    }
}

/// The plain-branded column keeps the reference's 66pt top inset while its card fits, and tightens to
/// 36 once the card would not fit: a long list gets its rows, a short one keeps its air.
final class BrandedTopInsetTests: XCTestCase {
    func testTheInsetTightensOnlyWhenTheCardWouldOverflow() {
        XCTAssertEqual(PlainBrandedM.topOffset(forRowCount: 1), PlainBrandedM.topOffset, "the reference's one row")
        XCTAssertEqual(PlainBrandedM.topOffset(forRowCount: 6), PlainBrandedM.topOffset, "still fits")
        XCTAssertEqual(PlainBrandedM.topOffset(forRowCount: 7), PlainBrandedM.tightTopOffset, "one more would overflow")
        XCTAssertEqual(PlainBrandedM.topOffset(forRowCount: 8), PlainBrandedM.tightTopOffset)
    }
}


/// The card header's one rule: the title is at the same y on every card screen. The hero tile
/// sits at the trailing end of the title row, drawn over the header, so a step with a hero and a
/// step without one lay out their header the same height; and no key or policy can move it.
final class CardHeaderRuleTests: XCTestCase {

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("dialog/Views/Inspect/" + path), encoding: .utf8)
    }

    func testTheHeroTakesNoHeightInTheHeader() throws {
        let shell = try source("Core Framework/Components/CardStepShell.swift")
        XCTAssertTrue(shell.contains(".overlay(alignment: .topTrailing)"), "the hero is drawn over the header")
        XCTAssertFalse(shell.contains("reserveHeroSpace"), "no empty seat is reserved for it")
        XCTAssertFalse(shell.contains("BalancedScroll"), "the body is top-anchored on every card step")
    }

    func testNoConfigKeyMovesTheCardHeader() throws {
        let known = try source("Core Framework/InspectConfigKnownKeys.swift")
        XCTAssertFalse(known.contains("\"headerStyle\""), "headerStyle is gone")
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(
            #"{"preset":"5","headerStyle":"compact","introSteps":[{"id":"a","headerStyle":"compact"}]}"#.utf8))
        XCTAssertEqual(config.introSteps?.count, 1, "an old config with the key still decodes; the key does nothing")
    }
}
