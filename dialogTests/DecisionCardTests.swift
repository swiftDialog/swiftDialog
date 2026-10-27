//
//  DecisionCardTests.swift
//  dialogTests
//
//  Decision cards (OptionCard fields, pre-selection, adornments), the slot picker's arithmetic
//  and emission rules, selection-key fallbacks, dock emission lines and slot-picker copy.
//

import SwiftUI
import XCTest
@testable import Dialog

final class DecisionCardTests: XCTestCase {

    private func decodeCard(_ json: String) throws -> InspectConfig.OptionCard {
        try JSONDecoder().decode(InspectConfig.OptionCard.self, from: Data(json.utf8))
    }

    func testAllSixFieldsDecode() throws {
        let card = try decodeCard("""
        {"id":"now","label":"Update now","effort":"~25 min · 1 restart",
         "exposure":"3 days unpatched","recommended":true,
         "recommendReason":"back soonest","action":"url",
         "url":"fleet://install-all?category_id=15"}
        """)
        XCTAssertEqual(card.effort, "~25 min · 1 restart")
        XCTAssertEqual(card.exposure, "3 days unpatched")
        XCTAssertEqual(card.recommended, true)
        XCTAssertEqual(card.recommendReason, "back soonest")
        XCTAssertEqual(card.action, "url")
        XCTAssertEqual(card.url, "fleet://install-all?category_id=15")
    }

    func testCardWithoutNewFieldsDecodesWithAllNil() throws {
        let card = try decodeCard(#"{"id":"a","label":"A"}"#)
        XCTAssertNil(card.effort)
        XCTAssertNil(card.exposure)
        XCTAssertNil(card.recommended)
        XCTAssertNil(card.recommendReason)
        XCTAssertNil(card.action)
        XCTAssertNil(card.url)
    }

    /// Templating tools emit booleans as quoted strings; coercion runs before Codable.
    func testRecommendedIsRegisteredForStringCoercion() {
        XCTAssertTrue(InspectConfigCoercion.booleanFields.contains("recommended"),
                      "\"recommended\": \"true\" must coerce, or every templated config fails to decode")
    }

    private func card(_ id: String, recommended: Bool? = nil, state: String? = nil,
                      effort: String? = nil, exposure: String? = nil,
                      reason: String? = nil, value: String? = nil) throws -> InspectConfig.OptionCard {
        var obj: [String: Any] = ["id": id, "label": id.capitalized]
        if let recommended { obj["recommended"] = recommended }
        if let state { obj["state"] = state }
        if let effort { obj["effort"] = effort }
        if let exposure { obj["exposure"] = exposure }
        if let reason { obj["recommendReason"] = reason }
        if let value { obj["value"] = value }
        let data = try JSONSerialization.data(withJSONObject: obj)
        return try JSONDecoder().decode(InspectConfig.OptionCard.self, from: data)
    }

    func testNoNewFieldsPreselectsNothing() throws {
        let cards = [try card("a"), try card("b")]
        XCTAssertNil(DecisionCard.preselectedCard(from: cards),
                     "off-by-default: a config using none of the new fields must behave as today")
        XCTAssertEqual(DecisionCard.adornments(for: cards[0], recommendedId: nil),
                       DecisionCard.Adornments(effort: nil, exposure: nil, showBadge: false, reason: nil))
    }

    func testSingleRecommendationPreselectsAndBadges() throws {
        let cards = [try card("later"), try card("now", recommended: true, reason: "back soonest")]
        XCTAssertEqual(DecisionCard.preselectedCard(from: cards), "now")
        let a = DecisionCard.adornments(for: cards[1], recommendedId: "now")
        XCTAssertTrue(a.showBadge)
        XCTAssertEqual(a.reason, "back soonest")
        XCTAssertFalse(DecisionCard.adornments(for: cards[0], recommendedId: "now").showBadge)
    }

    /// Preselection returns the emitted `value`, which the picker selects on.
    func testPreselectionUsesEmittedValueNotId() throws {
        let cards = [try card("now", recommended: true, value: "install-now")]
        XCTAssertEqual(DecisionCard.preselectedCard(from: cards), "install-now")
    }

    func testTwoRecommendationsFirstWins() throws {
        let cards = [try card("a", recommended: true), try card("b", recommended: true)]
        XCTAssertEqual(DecisionCard.preselectedCard(from: cards), "a")
        XCTAssertTrue(DecisionCard.adornments(for: cards[0], recommendedId: "a").showBadge)
        XCTAssertFalse(DecisionCard.adornments(for: cards[1], recommendedId: "a").showBadge,
                       "two badges is not a design, it is a bug rendered")
    }

    func testRecommendedUnavailableIsDropped() throws {
        let cards = [try card("a", recommended: true, state: "unavailable"), try card("b")]
        XCTAssertNil(DecisionCard.preselectedCard(from: cards),
                     "never pre-select a card the user cannot choose")
        XCTAssertFalse(DecisionCard.adornments(for: cards[0], recommendedId: nil).showBadge)
    }

    /// An unavailable recommendation does not consume the win.
    func testRecommendationFallsThroughUnavailableToNextValid() throws {
        let cards = [try card("a", recommended: true, state: "unavailable"),
                     try card("b", recommended: true)]
        XCTAssertEqual(DecisionCard.preselectedCard(from: cards), "b")
    }

    func testEffortAndExposureRenderIndependently() throws {
        let effortOnly = try card("a", effort: "~25 min")
        XCTAssertEqual(DecisionCard.adornments(for: effortOnly, recommendedId: nil).effort, "~25 min")
        XCTAssertNil(DecisionCard.adornments(for: effortOnly, recommendedId: nil).exposure)

        let exposureOnly = try card("b", exposure: "3 days unpatched")
        XCTAssertEqual(DecisionCard.adornments(for: exposureOnly, recommendedId: nil).exposure,
                       "3 days unpatched")
        XCTAssertNil(DecisionCard.adornments(for: exposureOnly, recommendedId: nil).effort)
    }

    func testReasonWithoutRecommendedIsNotShown() throws {
        let c = try card("a", reason: "back soonest")
        let a = DecisionCard.adornments(for: c, recommendedId: nil)
        XCTAssertFalse(a.showBadge)
        XCTAssertNil(a.reason, "a reason with no badge is an orphan clause")
    }

    func testConsequencePrefersTheRecommendationSentence() throws {
        let a = DecisionCard.Adornments(effort: "~25 min", exposure: "3 days unpatched",
                                        showBadge: true, reason: "back soonest")
        let c = try XCTUnwrap(DecisionCard.consequence(for: a))
        XCTAssertEqual(c.text, "back soonest")
        XCTAssertTrue(c.isRecommendation, "the recommendation is the row's consequence, in accent")
    }

    func testConsequenceFallsToExposureThenEffort() throws {
        let exposureOnly = DecisionCard.Adornments(effort: "~25 min", exposure: "3 days unpatched",
                                                   showBadge: false, reason: nil)
        XCTAssertEqual(DecisionCard.consequence(for: exposureOnly)?.text, "3 days unpatched")
        XCTAssertEqual(DecisionCard.consequence(for: exposureOnly)?.isRecommendation, false)

        let effortOnly = DecisionCard.Adornments(effort: "~25 min", exposure: nil,
                                                 showBadge: false, reason: nil)
        XCTAssertEqual(DecisionCard.consequence(for: effortOnly)?.text, "~25 min")
    }

    func testRowWithNothingToSayHasNoConsequence() {
        let bare = DecisionCard.Adornments(effort: nil, exposure: "", showBadge: true, reason: "")
        XCTAssertNil(DecisionCard.consequence(for: bare),
                     "empty strings are schema-legal and must not produce a blank line")
    }

    func testDifferentiatorDecodes() throws {
        let card = try JSONDecoder().decode(
            InspectConfig.OptionCard.self,
            from: Data(#"{"id":"a","label":"A","differentiator":"12 GB"}"#.utf8))
        XCTAssertEqual(card.differentiator, "12 GB")
    }

    func testSlotPickerBlockDecodes() throws {
        let json = """
        {"type":"slot-picker","id":"installSlot","windowHours":72,
         "granularityMinutes":30,"deadline":"2026-08-14T17:00:00+02:00",
         "deadlineNote":"Anything after Friday 17:00 installs itself.",
         "defaultAt":"2026-08-12T21:00:00+02:00",
         "quickPicks":[{"label":"Now","at":"now"},{"label":"Last slot","at":"deadline"}],
         "facts":[{"label":"Duration","value":"About 25 minutes, one restart"}],
         "continueFormat":"Schedule for {time}","continueAtNow":"Install now",
         "secondaryAtLater":"Install now instead"}
        """
        let b = try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(json.utf8))
        XCTAssertEqual(b.type, "slot-picker")
        XCTAssertEqual(b.windowHours, 72)
        XCTAssertEqual(b.granularityMinutes, 30)
        XCTAssertEqual(b.deadline, "2026-08-14T17:00:00+02:00")
        XCTAssertEqual(b.deadlineNote, "Anything after Friday 17:00 installs itself.")
        XCTAssertEqual(b.defaultAt, "2026-08-12T21:00:00+02:00")
        XCTAssertEqual(b.quickPicks?.count, 2)
        XCTAssertEqual(b.quickPicks?.first?.at, "now")
        XCTAssertEqual(b.facts?.first?.label, "Duration")
        XCTAssertEqual(b.continueFormat, "Schedule for {time}")
        XCTAssertEqual(b.continueAtNow, "Install now")
        XCTAssertEqual(b.secondaryAtLater, "Install now instead")
    }

    func testBlockWithoutSlotFieldsIsUnaffected() throws {
        let b = try JSONDecoder().decode(InspectConfig.GuidanceContent.self,
                                         from: Data(#"{"type":"text","content":"hi"}"#.utf8))
        XCTAssertNil(b.windowHours)
        XCTAssertNil(b.quickPicks)
        XCTAssertNil(b.continueFormat)
    }

    /// Templating tools emit numbers as quoted strings; coercion runs before Codable.
    func testSlotIntegersAreRegisteredForCoercion() {
        XCTAssertTrue(InspectConfigCoercion.integerFields.contains("windowHours"))
        XCTAssertTrue(InspectConfigCoercion.integerFields.contains("granularityMinutes"))
    }

    private func iso(_ s: String) -> Date {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)!
    }

    func testSnapClampsToWindowAndRoundsToNearest() {
        let start = iso("2026-08-12T09:00:00+02:00")
        let deadline = iso("2026-08-14T17:00:00+02:00")
        // before the window
        XCTAssertEqual(SlotPicker.snap(iso("2026-08-12T08:00:00+02:00"), start: start,
                                       deadline: deadline, granularityMinutes: 30), start)
        // after the deadline
        XCTAssertEqual(SlotPicker.snap(iso("2026-08-15T09:00:00+02:00"), start: start,
                                       deadline: deadline, granularityMinutes: 30), deadline)
        // nearest, down
        XCTAssertEqual(SlotPicker.snap(iso("2026-08-12T21:07:00+02:00"), start: start,
                                       deadline: deadline, granularityMinutes: 30),
                       iso("2026-08-12T21:00:00+02:00"))
        // nearest, up
        XCTAssertEqual(SlotPicker.snap(iso("2026-08-12T21:23:00+02:00"), start: start,
                                       deadline: deadline, granularityMinutes: 30),
                       iso("2026-08-12T21:30:00+02:00"))
    }

    func testSnapNeverExceedsDeadlineWhenRoundingUp() {
        let start = iso("2026-08-12T09:00:00+02:00")
        let deadline = iso("2026-08-14T17:20:00+02:00")   // 20 min past the grid, so rounding up is reachable
        let snapped = SlotPicker.snap(iso("2026-08-14T17:19:00+02:00"), start: start,
                                      deadline: deadline, granularityMinutes: 30)
        XCTAssertEqual(snapped, deadline,
                       "nearest-rounding would land at 17:30, past the deadline — the re-clamp must pull it back")
    }

    func testSnapTieBreaksToTheLaterBoundary() {
        let start = iso("2026-08-12T09:00:00+02:00")
        let deadline = iso("2026-08-14T17:00:00+02:00")
        // exactly 15 min past a boundary: half-away-from-zero rounds up
        XCTAssertEqual(SlotPicker.snap(iso("2026-08-12T21:15:00+02:00"), start: start,
                                       deadline: deadline, granularityMinutes: 30),
                       iso("2026-08-12T21:30:00+02:00"))
    }

    func testPositionIsProportionalAndGuarded() {
        let start = iso("2026-08-12T00:00:00+02:00")
        XCTAssertEqual(SlotPicker.position(of: start, start: start, windowHours: 72), 0, accuracy: 0.001)
        XCTAssertEqual(SlotPicker.position(of: iso("2026-08-13T12:00:00+02:00"),
                                           start: start, windowHours: 72), 0.5, accuracy: 0.001)
        // outside clamps, and a zero window does not divide by zero
        XCTAssertEqual(SlotPicker.position(of: iso("2026-08-20T00:00:00+02:00"),
                                           start: start, windowHours: 72), 1, accuracy: 0.001)
        XCTAssertEqual(SlotPicker.position(of: start, start: start, windowHours: 0), 0, accuracy: 0.001)
    }

    func testExposureHoursFloorsAndNeverGoesNegative() {
        let start = iso("2026-08-12T12:00:00+02:00")
        XCTAssertEqual(SlotPicker.exposureHours(from: start, to: iso("2026-08-12T21:59:00+02:00")), 9)
        XCTAssertEqual(SlotPicker.exposureHours(from: start, to: start), 0)
        XCTAssertEqual(SlotPicker.exposureHours(from: start, to: iso("2026-08-12T09:00:00+02:00")), 0)
    }

    func testResolveKeywordsInstantsAndRubbish() {
        let now = iso("2026-08-12T09:00:00+02:00")
        let deadline = iso("2026-08-14T17:00:00+02:00")
        XCTAssertEqual(SlotPicker.resolve("now", now: now, deadline: deadline), now)
        XCTAssertEqual(SlotPicker.resolve("deadline", now: now, deadline: deadline), deadline)
        XCTAssertEqual(SlotPicker.resolve("2026-08-13T12:00:00+02:00", now: now, deadline: deadline),
                       iso("2026-08-13T12:00:00+02:00"))
        XCTAssertNil(SlotPicker.resolve("tomorrow-ish", now: now, deadline: deadline),
                     "an unparseable pick must be dropped, never silently placed at zero")
    }

    func testPrimaryLabelSwitchesAtNow() {
        let now = iso("2026-08-12T09:00:00+02:00")
        XCTAssertEqual(SlotPicker.primaryLabel(chosen: now, now: now,
                                               format: "Schedule for {time}", atNow: "Install now",
                                               timeText: "09:00"), "Install now")
        XCTAssertEqual(SlotPicker.primaryLabel(chosen: iso("2026-08-12T21:00:00+02:00"), now: now,
                                               format: "Schedule for {time}", atNow: "Install now",
                                               timeText: "21:00"), "Schedule for 21:00")
    }

    // MARK: - floorToGranularity / instant(atPosition:) / midpoint

    func testFloorToGranularityFloorsToTheEpochGridNotUpAndNotToItsInput() {
        XCTAssertEqual(SlotPicker.floorToGranularity(iso("2026-08-12T09:17:43+02:00"),
                                                      granularityMinutes: 30),
                       iso("2026-08-12T09:00:00+02:00"))
        XCTAssertEqual(SlotPicker.floorToGranularity(iso("2026-08-12T09:44:00+02:00"),
                                                      granularityMinutes: 30),
                       iso("2026-08-12T09:30:00+02:00"))
        XCTAssertEqual(SlotPicker.floorToGranularity(iso("2026-08-12T09:30:00+02:00"),
                                                      granularityMinutes: 30),
                       iso("2026-08-12T09:30:00+02:00"))
    }

    func testFloorToGranularityIsANoOpForNonPositiveGranularity() {
        let messy = iso("2026-08-12T09:17:43+02:00")
        XCTAssertEqual(SlotPicker.floorToGranularity(messy, granularityMinutes: 0), messy)
        XCTAssertEqual(SlotPicker.floorToGranularity(messy, granularityMinutes: -5), messy)
    }

    func testInstantAtPositionIsThePositionInverse() {
        let start = iso("2026-08-12T00:00:00+02:00")
        XCTAssertEqual(SlotPicker.instant(atPosition: 0, start: start, windowHours: 72), start)
        XCTAssertEqual(SlotPicker.instant(atPosition: 0.5, start: start, windowHours: 72),
                       iso("2026-08-13T12:00:00+02:00"))
        XCTAssertEqual(SlotPicker.instant(atPosition: 1, start: start, windowHours: 72),
                       iso("2026-08-15T00:00:00+02:00"))
        XCTAssertEqual(SlotPicker.instant(atPosition: -0.5, start: start, windowHours: 72), start)
        XCTAssertEqual(SlotPicker.instant(atPosition: 1.5, start: start, windowHours: 72),
                       iso("2026-08-15T00:00:00+02:00"))
        // A negative window discriminates the guard; a zero window would pass unguarded.
        XCTAssertEqual(SlotPicker.instant(atPosition: 0.5, start: start, windowHours: -1), start)
    }

    func testMidpointIsHalfwayAcrossTheWindow() {
        let start = iso("2026-08-12T00:00:00+02:00")
        XCTAssertEqual(SlotPicker.midpoint(start: start, windowHours: 72),
                       iso("2026-08-13T12:00:00+02:00"))
        // A negative window discriminates the guard; a zero window would pass unguarded.
        XCTAssertEqual(SlotPicker.midpoint(start: start, windowHours: -1), start)
    }

    /// A grid-aligned instant survives floor, position, instant and snap unchanged, even when
    /// the launch instant it floors from is not aligned.
    func testAlreadyAlignedInstantRoundTripsThroughFloorPositionInstantSnapUnchanged() {
        let messyLaunch = iso("2026-08-12T09:17:43+02:00")
        let start = SlotPicker.floorToGranularity(messyLaunch, granularityMinutes: 30)
        XCTAssertEqual(start, iso("2026-08-12T09:00:00+02:00"),
                       "floors DOWN to the grid, relative to the epoch — not to messyLaunch itself")

        let deadline = iso("2026-08-14T17:00:00+02:00")
        let authored = iso("2026-08-12T21:00:00+02:00")

        let fraction = SlotPicker.position(of: authored, start: start, windowHours: 72)
        let roundTripped = SlotPicker.instant(atPosition: fraction, start: start, windowHours: 72)
        let snapped = SlotPicker.snap(roundTripped, start: start, deadline: deadline,
                                      granularityMinutes: 30)

        XCTAssertEqual(snapped.timeIntervalSince1970, authored.timeIntervalSince1970, accuracy: 0.001,
                       "an already-aligned instant must round-trip through floor -> position -> " +
                       "instant -> snap unchanged, or the exact drift 0d6cdbf4 fixed is back")
    }

    // MARK: - SelectionEmission.shouldEmit

    /// Nothing recorded emits: accepting the pre-selection still produces a `select:` line.
    func testShouldEmitWhenNothingIsRecordedYet() {
        XCTAssertTrue(SelectionEmission.shouldEmit(newValue: "now", recorded: nil, trigger: .committed))
    }

    /// The value already on the wire is suppressed.
    func testShouldSuppressAValueTheWireAlreadyCarries() {
        XCTAssertFalse(SelectionEmission.shouldEmit(newValue: "now", recorded: "now", trigger: .committed))
    }

    /// A changed value emits, so a restore re-snapped against a moved deadline corrects the wire.
    func testShouldEmitACorrectedValue() {
        XCTAssertTrue(SelectionEmission.shouldEmit(newValue: "later", recorded: "now", trigger: .committed))
    }

    /// A drag frame never emits, whatever the values.
    func testADragFrameNeverEmitsEvenWhenTheValueIsNewOrNothingIsRecorded() {
        XCTAssertFalse(SelectionEmission.shouldEmit(newValue: "now", recorded: nil, trigger: .dragFrame),
                       "an empty wire does not make a mid-drag pointer sample an answer")
        XCTAssertFalse(SelectionEmission.shouldEmit(newValue: "later", recorded: "now", trigger: .dragFrame),
                       "nor does a changed value — the drag has not ended")
        XCTAssertFalse(SelectionEmission.shouldEmit(newValue: "now", recorded: "now", trigger: .dragFrame))
    }

    /// `userValues` holds an empty string for a cleared key; a real answer still gets through.
    func testAnEmptyRecordedValueDoesNotSuppress() {
        XCTAssertTrue(SelectionEmission.shouldEmit(newValue: "now", recorded: "", trigger: .committed))
        XCTAssertFalse(SelectionEmission.shouldEmit(newValue: "", recorded: "", trigger: .committed))
    }

    /// The multi-select wire value is a comma-joined sorted list compared whole.
    func testAJoinedMultiSelectValueIsComparedWhole() {
        XCTAssertFalse(SelectionEmission.shouldEmit(newValue: "a,b", recorded: "a,b", trigger: .committed))
        XCTAssertTrue(SelectionEmission.shouldEmit(newValue: "a,b", recorded: "a", trigger: .committed))
    }

    /// A drag replayed as pointer samples plus one release emits one line.
    func testAWholeDragProducesExactlyOneLine() {
        let start = iso("2026-08-12T09:00:00+02:00")
        let deadline = iso("2026-08-14T17:00:00+02:00")
        var recorded: String?
        var emitted: [String] = []

        func offer(_ value: String, _ trigger: SelectionEmission.Trigger) {
            guard SelectionEmission.shouldEmit(newValue: value, recorded: recorded, trigger: trigger) else { return }
            emitted.append(value)
            recorded = value
        }

        for index in 0...400 {
            let raw = SlotPicker.instant(atPosition: Double(index) / 400.0, start: start, windowHours: 72)
            let snapped = SlotPicker.snap(raw, start: start, deadline: deadline, granularityMinutes: 30)
            offer(SlotPicker.isoString(snapped), .dragFrame)
        }
        offer(SlotPicker.isoString(deadline), .committed)

        XCTAssertEqual(emitted, [SlotPicker.isoString(deadline)],
                       "401 pointer samples are ONE answer; unguarded this wrote 401 `select:` "
                       + "lines, 802 synchronous file handles and 401 notifications")
    }

    func testASecondIdenticalDragAddsNothing() {
        let value = SlotPicker.isoString(iso("2026-08-12T21:00:00+02:00"))
        XCTAssertTrue(SelectionEmission.shouldEmit(newValue: value, recorded: nil, trigger: .committed))
        XCTAssertFalse(SelectionEmission.shouldEmit(newValue: value, recorded: value, trigger: .committed))
    }

    func testIsoStringAndIsoDateRoundTrip() {
        let date = iso("2026-08-14T17:00:00+02:00")
        XCTAssertEqual(SlotPicker.isoDate(SlotPicker.isoString(date)), date)
        XCTAssertNil(SlotPicker.isoDate("not a date"),
                     "an unparseable restored value is dropped, never read as the epoch")
    }

    // MARK: - SelectionEmission.resolveKey

    func testAnAuthoredKeyIsUsedAndFlaggedAsAuthored() {
        let resolved = SelectionEmission.resolveKey("browser", fallback: "option")
        XCTAssertEqual(resolved.key, "browser")
        XCTAssertFalse(resolved.usedFallback)
    }

    func testAMissingKeyFallsBackAndSaysSo() {
        let resolved = SelectionEmission.resolveKey(nil, fallback: "option")
        XCTAssertEqual(resolved.key, "option")
        XCTAssertTrue(resolved.usedFallback, "the caller cannot derive the key without being "
                      + "handed the reason to log — that is the point of the tuple")
    }

    /// An empty key is schema-legal but would write an answer nothing can read.
    func testAnEmptyKeyCountsAsMissing() {
        let resolved = SelectionEmission.resolveKey("", fallback: "dock")
        XCTAssertEqual(resolved.key, "dock")
        XCTAssertTrue(resolved.usedFallback)
    }

    // MARK: - Duplicate emitted values

    func testDuplicateEmittedValuesAreReportedOncePerValueInFirstSeenOrder() throws {
        let cards = [try card("later"), try card("now"), try card("later2", value: "later"),
                     try card("now2", value: "now"), try card("later3", value: "later")]
        XCTAssertEqual(DecisionCard.duplicateEmittedValues(in: cards), ["later", "now"],
                       "one report per colliding value, in the order the collision first appears")
    }

    func testDistinctEmittedValuesReportNothing() throws {
        let cards = [try card("a"), try card("b"), try card("c", value: "see")]
        XCTAssertEqual(DecisionCard.duplicateEmittedValues(in: cards), [])
        XCTAssertEqual(DecisionCard.duplicateEmittedValues(in: []), [])
    }

    /// `id` and `value` share one namespace: a card without `value` emits its id.
    func testAnIdCollidesWithAnotherCardsExplicitValue() throws {
        let cards = [try card("later"), try card("friday", value: "later")]
        XCTAssertEqual(DecisionCard.duplicateEmittedValues(in: cards), ["later"])
    }

    /// `adornments` matches on the emitted value, so duplicate values badge two cards; that is
    /// why the duplicate is logged as a config error.
    func testDuplicateEmittedValuesMakeTwoCardsBadgeAtOnce() throws {
        let cards = [try card("now", recommended: true, reason: "back soonest"),
                     try card("tonight", reason: "later", value: "now")]
        let winner = DecisionCard.preselectedCard(from: cards)
        XCTAssertEqual(winner, "now")
        XCTAssertTrue(DecisionCard.adornments(for: cards[0], recommendedId: winner).showBadge)
        XCTAssertTrue(DecisionCard.adornments(for: cards[1], recommendedId: winner).showBadge,
                      "the second card badges too — 'first wins' cannot be expressed per-card "
                      + "when two cards emit the same value, so this must be logged as a config "
                      + "error rather than silently rendered")
        XCTAssertEqual(DecisionCard.duplicateEmittedValues(in: cards), ["now"],
                       "…and it IS reported")
    }

    func testEmittedValuePrefersValueOverId() throws {
        XCTAssertEqual(DecisionCard.emittedValue(of: try card("a")), "a")
        XCTAssertEqual(DecisionCard.emittedValue(of: try card("a", value: "alpha")), "alpha")
    }

    // MARK: - Fallback selection keys

    private func block(_ json: String) throws -> InspectConfig.GuidanceContent {
        try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(json.utf8))
    }

    func testAnAuthoredSelectionKeyEarnsNoWarning() throws {
        let blocks = [try block(#"{"type":"option-picker","optionKey":"browser"}"#),
                      try block(#"{"type":"wallpaper-picker","wallpaperSelectionKey":"wp"}"#),
                      try block(#"{"type":"dock-picker","dockSelectionKey":"dk"}"#),
                      try block(#"{"type":"text","content":"hi"}"#)]
        XCTAssertEqual(GuidanceSelectionKeys.fallbackWarnings(in: blocks), [])
    }

    func testEveryPickerTypeWarnsWhenItTakesItsSharedFallbackKey() throws {
        let blocks = [try block(#"{"type":"option-picker"}"#),
                      try block(#"{"type":"wallpaper-picker"}"#),
                      try block(#"{"type":"dock-picker"}"#)]
        XCTAssertEqual(GuidanceSelectionKeys.fallbackWarnings(in: blocks),
                       [.init(blockType: "option-picker", key: "option", sharedWith: 0),
                        .init(blockType: "wallpaper-picker", key: "wallpaper", sharedWith: 0),
                        .init(blockType: "dock-picker", key: "dock", sharedWith: 0)])
    }

    /// Two id-less blocks of one type overwrite each other from `onAppear`, so they are a collision.
    func testTwoIdLessBlocksOfTheSameTypeAreReportedAsACollision() throws {
        let blocks = [try block(#"{"type":"option-picker"}"#),
                      try block(#"{"type":"option-picker"}"#),
                      try block(#"{"type":"dock-picker"}"#)]
        let warnings = GuidanceSelectionKeys.fallbackWarnings(in: blocks)
        XCTAssertEqual(warnings.map(\.sharedWith), [1, 1, 0],
                       "both option-pickers must know the other exists; the dock-picker is alone")
        XCTAssertTrue(GuidanceSelectionKeys.message(for: warnings[0]).contains("2 blocks"),
                      "a collision must read as data loss, not as tidiness: \(GuidanceSelectionKeys.message(for: warnings[0]))")
        XCTAssertFalse(GuidanceSelectionKeys.message(for: warnings[2]).contains("blocks on this step now share"),
                       "a lone fallback is a warning about the future, not a report of loss")
    }

    /// An empty string is not an authored key.
    func testAnEmptySelectionKeyCountsAsAFallback() throws {
        let warnings = try GuidanceSelectionKeys.fallbackWarnings(
            in: [block(#"{"type":"option-picker","optionKey":""}"#)])
        XCTAssertEqual(warnings, [.init(blockType: "option-picker", key: "option", sharedWith: 0)])
    }

    /// `SlotPickerView` logs its own fallback, so the step-level scan skips `slot-picker`.
    func testSlotPickerIsLeftToItsOwnWarning() throws {
        XCTAssertEqual(try GuidanceSelectionKeys.fallbackWarnings(in: [block(#"{"type":"slot-picker"}"#)]), [])
    }

    // MARK: - Selected-row tint from the backdrop palette

    // Precedence must match `PhaseBackdrop.activePalette`, or the row is washed from a different
    // palette than the ground under it.

    private func palette(light: [String], dark: [String]) -> ResolvedPalette {
        var spec = PhaseBackdropSpec()
        spec.palette = light
        spec.darkPalette = dark
        return ResolvedPalette(from: nil, backdrop: spec)
    }

    func testBackdropTintPrefersTheDarkPaletteInDarkAppearance() {
        let p = palette(light: ["#EEF4FD", "#DDE8FB"], dark: ["#243044", "#1B2233"])
        XCTAssertEqual(p.backdropTint(for: .dark), Color(hex: "#243044"))
        XCTAssertEqual(p.backdropTint(for: .light), Color(hex: "#EEF4FD"))
    }

    /// The dark palette wins only when non-empty.
    func testBackdropTintFallsBackToTheLightPaletteWhenNoDarkOneIsAuthored() {
        let p = palette(light: ["#EEF4FD"], dark: [])
        XCTAssertEqual(p.backdropTint(for: .dark), Color(hex: "#EEF4FD"))
        XCTAssertEqual(p.backdropTint(for: .light), Color(hex: "#EEF4FD"))
    }

    /// No palette yields nil, which tells the use site to fall back to the brand accent.
    func testBackdropTintIsNilWhenNoPaletteIsAuthored() {
        let p = palette(light: [], dark: [])
        XCTAssertNil(p.backdropTint(for: .light))
        XCTAssertNil(p.backdropTint(for: .dark))
        XCTAssertNil(ResolvedPalette.default.backdropTint(for: .dark),
                     "the default palette authors no backdrop")
    }

    /// Config JSON reaches the row tint through `resolvePhaseBackdrop` and `ResolvedPalette`.
    /// `phaseBackgroundSource` points at an absent domain so a managed preference on the test
    /// machine cannot win the first rung of the ladder.
    @MainActor
    func testTheConfigKeysReachTheTintThroughTheResolvedBackdrop() throws {
        let json = """
        {"preset":"5","title":"t","phaseBackground":"gradient",
         "phaseBackgroundSource":{"domain":"com.example.absent.test","key":"PhaseBackground"},
         "phaseBackgroundPalette":["#2FB37A","#8FE0BE"],
         "phaseBackgroundPaletteDark":["#B3452F","#E08F7F"],
         "introSteps":[{"id":"a","stepType":"intro"}]}
        """
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.phaseBackgroundPalette, ["#2FB37A", "#8FE0BE"], "decodes")
        XCTAssertEqual(config.phaseBackgroundPaletteDark, ["#B3452F", "#E08F7F"], "decodes")

        let spec = resolvePhaseBackdrop(config: config)
        XCTAssertEqual(spec.style, "gradient")
        XCTAssertEqual(spec.palette, ["#2FB37A", "#8FE0BE"], "the ladder carries the config palette")
        XCTAssertEqual(spec.darkPalette, ["#B3452F", "#E08F7F"])

        let resolved = ResolvedPalette(from: config.brandPalette, backdrop: spec)
        XCTAssertEqual(resolved.backdropTint(for: .light), Color(hex: "#2FB37A"))
        XCTAssertEqual(resolved.backdropTint(for: .dark), Color(hex: "#B3452F"),
                       "a selected row in dark appearance washes from the dark backdrop palette")
    }

    /// The tint is the first entry, where the gradient starts.
    func testBackdropTintTakesTheFirstEntryOfTheActivePalette() {
        let p = palette(light: ["#112233", "#445566"], dark: ["#AABBCC", "#DDEEFF"])
        XCTAssertEqual(p.backdropTint(for: .light), Color(hex: "#112233"))
        XCTAssertEqual(p.backdropTint(for: .dark), Color(hex: "#AABBCC"))
    }

    // MARK: - Option-picker layout

    func testTheOptionPickerDefaultsToRowsWhenUnauthored() {
        XCTAssertEqual(OptionPickerLayout(nil), .rows,
                       "rows is the decision arrangement: one full-width row per option, so "
                       + "cost lines are not truncated")
    }

    func testEachAuthoredLayoutIsHonoured() {
        XCTAssertEqual(OptionPickerLayout("rows"), .rows)
        XCTAssertEqual(OptionPickerLayout("grid"), .grid)
        XCTAssertEqual(OptionPickerLayout("cards"), .cards)
    }

    /// An unrecognised value renders the documented default.
    func testAnUnknownLayoutFallsBackToTheDocumentedDefault() {
        XCTAssertEqual(OptionPickerLayout("bogus"), .rows)
        XCTAssertEqual(OptionPickerLayout(""), .rows)
        XCTAssertEqual(OptionPickerLayout("Rows"), .rows)
    }

    /// The layout default lives in `OptionPickerLayout` only, never at a call site.
    func testNoSourceFileReintroducesAStringlyOptionLayoutDefault() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect")

        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return XCTFail("cannot walk \(root.path)")
        }

        var offenders: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in text.components(separatedBy: .newlines).enumerated()
            where line.contains("optionLayout ??") {
                offenders.append("\(url.lastPathComponent):\(index + 1)")
            }
        }

        XCTAssertEqual(offenders, [],
                       "optionLayout's default belongs in OptionPickerLayout, not at a call site")
    }
}

// MARK: - Dock emission

/// The dock picker emits a `select:` line with the chosen flavour id beside the `dock:` line,
/// because the `dock:` payload cannot be reverse-matched to a template.
final class DockEmissionTests: XCTestCase {

    /// Consumers split the `dock:` line on ":" then ","; its shape is frozen.
    func testTheDockLineKeepsItsExactShape() {
        let lines = DockEmission.lines(selectionKey: "dock", applyMode: "additive",
                                       answer: .flavor("corp-basic"),
                                       payload: "/Applications/Safari.app,~/Downloads")
        XCTAssertEqual(lines.dock, "dock:dock:additive:/Applications/Safari.app,~/Downloads")
    }

    func testAChosenFlavourReportsItsId() {
        let lines = DockEmission.lines(selectionKey: "dock", applyMode: "replace",
                                       answer: .flavor("corp-basic"), payload: "/Applications/Safari.app")
        XCTAssertEqual(lines.ordered, ["select:dock:corp-basic",
                                       "dock:dock:replace:/Applications/Safari.app"])
    }

    /// A decline is an answer, distinct from never reaching the step.
    func testADeclineIsAnAnswerAndSaysSo() {
        let lines = DockEmission.lines(selectionKey: "dock", applyMode: "additive",
                                       answer: .decline("none"), payload: "none")
        XCTAssertEqual(lines.ordered, ["select:dock:none", "dock:dock:additive:none"])
    }

    /// A hand-built Dock has no flavour id; the absence is the signal.
    func testAHandBuiltDockEmitsNoIdentity() {
        let lines = DockEmission.lines(selectionKey: "dock", applyMode: "additive",
                                       answer: .built, payload: "/Applications/Safari.app")
        XCTAssertNil(lines.select)
        XCTAssertEqual(lines.ordered, ["dock:dock:additive:/Applications/Safari.app"])
    }

    /// Every answer with an identity emits it beside the dock line; the emission is not
    /// deduplicated, or a later `dock:` line would read as hand-built.
    func testOnlyTheHandBuiltCaseOmitsTheIdentityLine() {
        let answers: [(DockEmission.Answer, Bool)] = [
            (.flavor("a"), true), (.decline("none"), true), (.built, false)
        ]
        for (answer, expectsIdentity) in answers {
            let lines = DockEmission.lines(selectionKey: "k", applyMode: "additive",
                                           answer: answer, payload: "p")
            XCTAssertEqual(lines.select != nil, expectsIdentity, "\(answer)")
            XCTAssertEqual(lines.ordered.last, "dock:k:additive:p", "the dock line is always last")
        }
    }
}

// MARK: - SlotPickerCopy

/// The `slot-picker` copy keys shape the step footer; a step without them changes nothing.
final class SlotPickerCopyTests: XCTestCase {

    private func block(_ json: String) throws -> InspectConfig.GuidanceContent {
        try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(json.utf8))
    }
    private let l10n: (String, String) -> String = { $1 }
    private let now = ISO8601DateFormatter().date(from: "2026-08-12T09:00:00Z")!

    func testChosenNowTakesContinueAtNowAndNoSecondary() throws {
        let b = try block(#"{"type":"slot-picker","id":"when","deadline":"2026-08-15T18:00:00Z","continueFormat":"Schedule for {time}","continueAtNow":"Install now","secondaryAtLater":"Install now instead"}"#)
        let copy = SlotPickerCopy.resolve(block: b, chosen: now, now: now, selectionKey: "when", l10n: l10n)
        XCTAssertTrue(copy.isNow)
        XCTAssertEqual(copy.continueText, "Install now")
        XCTAssertNil(copy.secondaryText, "no 'install now instead' when now is already chosen")
    }

    func testASlotFlooredBehindTheClockStillCountsAsNow() throws {
        let b = try block(#"{"type":"slot-picker","id":"when","deadline":"2026-08-15T18:00:00Z","continueAtNow":"Install now","continueFormat":"Schedule for {time}"}"#)
        let copy = SlotPickerCopy.resolve(block: b, chosen: now.addingTimeInterval(-25 * 60), now: now, selectionKey: "when", l10n: l10n)
        XCTAssertTrue(copy.isNow, "the picker floors its opening slot to the granularity grid; that is still 'now'")
        XCTAssertEqual(copy.continueText, "Install now")
    }

    func testALaterSlotFormatsTheTimeAndOffersNowAsSecondary() throws {
        let b = try block(#"{"type":"slot-picker","id":"when","deadline":"2026-08-15T18:00:00Z","continueFormat":"Schedule for {time}","continueAtNow":"Install now","secondaryAtLater":"Install now instead"}"#)
        let later = now.addingTimeInterval(6 * 3600)
        let copy = SlotPickerCopy.resolve(block: b, chosen: later, now: now, selectionKey: "when", l10n: l10n)
        XCTAssertFalse(copy.isNow)
        let expectedTime = SlotPickerReadout.readout(later, now: now, l10n: l10n)
        XCTAssertEqual(copy.continueText, "Schedule for \(expectedTime)")
        XCTAssertFalse(expectedTime.contains("{time}"))
        XCTAssertEqual(copy.secondaryText, "Install now instead")
    }

    func testMissingKeysLeaveTheStepsOwnText() throws {
        let b = try block(#"{"type":"slot-picker","id":"when","deadline":"2026-08-15T18:00:00Z"}"#)
        XCTAssertNil(SlotPickerCopy.resolve(block: b, chosen: now, now: now, selectionKey: "when", l10n: l10n).continueText)
        XCTAssertNil(SlotPickerCopy.resolve(block: b, chosen: now.addingTimeInterval(3600), now: now, selectionKey: "when", l10n: l10n).continueText)
        XCTAssertNil(SlotPickerCopy.resolve(block: b, chosen: now.addingTimeInterval(3600), now: now, selectionKey: "when", l10n: l10n).secondaryText)
    }

    func testStepWithoutAPickerOrWithoutARecordedSlotResolvesToNil() throws {
        let step = try JSONDecoder().decode(InspectConfig.IntroStep.self, from: Data(#"""
        {"id":"s","title":"t","content":[{"type":"slot-picker","id":"when","deadline":"2026-08-15T18:00:00Z","continueAtNow":"Install now"}]}
        """#.utf8))
        XCTAssertNil(SlotPickerCopy.resolve(step: step, userValues: [:], now: now, l10n: l10n),
                     "before the block records its opening slot there is nothing to word")
        let copy = SlotPickerCopy.resolve(step: step, userValues: ["when": SlotPicker.isoString(now)], now: now, l10n: l10n)
        XCTAssertEqual(copy?.continueText, "Install now")
        let plain = try JSONDecoder().decode(InspectConfig.IntroStep.self, from: Data(#"{"id":"p","title":"t","content":[{"type":"text","content":"x"}]}"#.utf8))
        XCTAssertNil(SlotPickerCopy.resolve(step: plain, userValues: ["slot": SlotPicker.isoString(now)], now: now, l10n: l10n))
    }
}
