//
//  Preset5ArmTests.swift
//  dialogTests
//
//  Preset 5 arms: the splash doors, the cadence failure display and artwork, showWhen, the
//  select store, the brand allow-list note, the visible step counter, the form wire contract,
//  the provisioning tile row, the dark surface palette and the phase tracker style passthrough.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog

// The splash's doors: which are drawn, and which one defers.
final class SplashDoorsTests: XCTestCase {

    private func step(_ fields: String) throws -> InspectConfig.IntroStep {
        try JSONDecoder().decode(InspectConfig.IntroStep.self,
                                 from: Data(#"{"id":"s","stepType":"splash"\#(fields)}"#.utf8))
    }

    func testTheLastOfTwoOrMoreDefers() throws {
        let three = try step(#","continueButtonText":"Begin","secondaryButtonText":"Why?","backButtonText":"Later""#)
        XCTAssertEqual(SplashDoors.titles(for: three), ["Begin", "Why?", "Later"])
        XCTAssertEqual(SplashDoors.deferIndex(for: three), 2)
        XCTAssertNil(SplashDoors.deferIndex(for: try step(#","continueButtonText":"Begin""#)),
                     "a lone door always advances")
    }

    func testHidingTheBackDoorHidesTheDeferral() throws {
        let hidden = try step(#","continueButtonText":"Begin","secondaryButtonText":"Why?","backButtonText":"Later","showBackButton":false"#)
        XCTAssertEqual(SplashDoors.titles(for: hidden), ["Begin", "Why?"])
        XCTAssertNil(SplashDoors.deferIndex(for: hidden),
                     "the middle door must not become 'later' just by being last")
    }
}

// A failed step is named, never folded into "done", and the run reports a warning.
final class CadenceFailureDisplayTests: XCTestCase {
    private func entries(_ ids: [String]) throws -> [InspectConfig.CadenceEntry] {
        let attr = try XCTUnwrap(try? JSONDecoder().decode(
            InspectConfig.CadenceAttribute.self, from: Data(#"{"source": "ipc"}"#.utf8)))
        return ids.map { InspectConfig.CadenceEntry(id: $0, message: $0, attribute: attr, minDwell: 0,
            timeout: 600, sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil,
            subtitle: nil, timeEstimate: nil, size: nil) }
    }

    func testFailedEntriesLeaveTheDoneCountAndAreNamed() throws {
        let all = try entries(["a", "b", "c"])
        let done = CadenceRollup.finished(all, position: 3, failed: [0])
        XCTAssertEqual(done.total, 2)
        XCTAssertEqual(done.shown.map(\.id), ["b", "c"])
        XCTAssertEqual(CadenceRollup.failures(all, position: 3, failed: [0]).map(\.id), ["a"])
        XCTAssertEqual(CadenceRollup.finished(all, position: 3).total, 3, "no failures: unchanged")
    }

    func testTheCountLineSaysHowManyFailed() throws {
        let all = try entries(["a", "b", "c"])
        var run = CadenceProgress(entries: all, position: 3, satisfied: 2, timedOut: [0], failed: [0],
                                  isComplete: true, heldByStay: false, heldElapsedSeconds: 0)
        run.messages = [0: "a: failed (exit 3)"]
        XCTAssertEqual(CadenceMinimalMeter.countLine(run), "2 of 3 complete · 1 failed")
        XCTAssertEqual(run.message(at: 0), "a: failed (exit 3)")
        XCTAssertEqual(run.message(at: 1), "b")
    }

    func testAFinishedRunWithAFailureHoldsNothingBack() throws {
        let all = try entries(["a", "b", "c"])
        let done = CadenceProgress(entries: all, position: 3, satisfied: 2, timedOut: [0], failed: [0],
                                   isComplete: true, heldByStay: false, heldElapsedSeconds: 0)
        XCTAssertEqual(done.pending, 0, "Continue goes straight on")
        let running = CadenceProgress(entries: all, position: 1, satisfied: 1, timedOut: [], failed: [],
                                      isComplete: false, heldByStay: false, heldElapsedSeconds: 0)
        XCTAssertEqual(running.pending, 2, "the running entry and the one behind it")
    }

    func testAFinishedRunWithFailuresIsAWarning() {
        XCTAssertEqual(CadenceCopy.completionResult(message: nil, failed: 0, total: 3), .success(message: nil))
        XCTAssertEqual(CadenceCopy.completionResult(message: nil, failed: 1, total: 3),
                       .warning(message: "1 of 3 did not finish"))
    }
}

// `showWhen` is what lets one window carry the splash and each team's own steps behind it.
@MainActor
final class ShowWhenTests: XCTestCase {

    private func step(_ json: String) throws -> InspectConfig.IntroStep {
        try JSONDecoder().decode(InspectConfig.IntroStep.self, from: Data(json.utf8))
    }

    func testMatchesOnlyAListedValue() {
        let rule = InspectConfig.ShowWhenConfig(key: "team", anyOf: ["engineering", "design"])
        XCTAssertTrue(rule.matches(["team": "design"]))
        XCTAssertFalse(rule.matches(["team": "workstations"]))
        XCTAssertFalse(rule.matches([:]), "no pick yet means the step is for a choice not made")
    }

    func testAStepIsSkippedUntilThePickMatches() throws {
        let state = InspectState()
        let view = Preset5View(inspectState: state)
        let engineering = try step(#"{"id":"eng","stepType":"cadence","showWhen":{"key":"team","anyOf":["engineering"]}}"#)
        let everyone = try step(#"{"id":"all","stepType":"cadence"}"#)

        XCTAssertTrue(view.shouldSkipStep(engineering))
        state.userValues["team"] = "workstations"
        XCTAssertTrue(view.shouldSkipStep(engineering))
        state.userValues["team"] = "engineering"
        XCTAssertFalse(view.shouldSkipStep(engineering))
        XCTAssertFalse(view.shouldSkipStep(everyone), "a step without showWhen is never skipped by it")
    }

    func testSplashIsAStepTypeOfItsOwn() throws {
        XCTAssertEqual(try step(#"{"id":"s","stepType":"splash"}"#).resolvedStepType, "splash")
    }
}

// `select:` writes the store of the picker that owns the key — the splash's pick included, so a
// script (or a self-running demo) can choose the team the way a click does.
@MainActor
final class SelectStoreTests: XCTestCase {

    private func steps(_ json: String) throws -> [InspectConfig.IntroStep] {
        try JSONDecoder().decode([InspectConfig.IntroStep].self, from: Data(json.utf8))
    }

    func testEachKeyGoesToItsOwner() throws {
        let flow = try steps(#"""
        [{"id":"splash","stepType":"splash","environmentKey":"team",
          "environments":[{"id":"a","title":"A"},{"id":"b","title":"B"}]},
         {"id":"browser","stepType":"options","optionKey":"browser"},
         {"id":"dock-a","stepType":"dock","dockSelectionKey":"dock-a"}]
        """#)
        XCTAssertEqual(Preset5View.selectStore(for: "team", in: flow), .userValues)
        XCTAssertEqual(Preset5View.selectStore(for: "browser", in: flow), .userValues)
        XCTAssertEqual(Preset5View.selectStore(for: "dock-a", in: flow), .dock)
        XCTAssertEqual(Preset5View.selectStore(for: "nobody", in: flow), .grid)
    }

    /// A dropdown/radio block's key goes to its step's form state, the value the block draws; in the
    /// grid store a scripted language pick translated the flow while the radio kept the old choice.
    func testAFormBlockKeyGoesToItsStepsFormState() throws {
        let flow = try steps(#"""
        [{"id":"language","content":[{"type":"radio","id":"preferredLanguage","options":["English","Deutsch"]}]},
         {"id":"prefs","content":[{"type":"dropdown","id":"browser","options":["Safari","Firefox"]}]}]
        """#)
        XCTAssertEqual(Preset5View.selectStore(for: "preferredLanguage", in: flow), .form(stepId: "language"))
        XCTAssertEqual(Preset5View.selectStore(for: "browser", in: flow), .form(stepId: "prefs"))
    }

    func testASplashWithOneDestinationOwnsNoKey() throws {
        let flow = try steps(#"[{"id":"splash","stepType":"splash","environments":[{"id":"only","title":"Only"}]}]"#)
        XCTAssertEqual(Preset5View.selectStore(for: "environment", in: flow), .grid)
    }
}

// A progress step that follows a pick borrows each entry's icon from its option card.
@MainActor
final class CadenceArtworkTests: XCTestCase {

    func testAnEntryTakesItsCardsIconUnlessItHasItsOwn() throws {
        let steps = try JSONDecoder().decode([InspectConfig.IntroStep].self, from: Data(#"""
        [{"id":"choose","stepType":"options","optionMultiSelect":true,"optionKey":"tasks",
          "optionCards":[{"id":"a","label":"A","iconPath":"/System/Library/CoreServices/Finder.app"},
                         {"id":"b","label":"B","iconPath":"/System/Library/CoreServices/Dock.app"}]},
         {"id":"run","stepType":"cadence","cadenceSelectionKey":"tasks","cadence":[
          {"id":"a","message":"A","attribute":{"source":"ipc"}},
          {"id":"b","message":"B","attribute":{"source":"ipc"},"imagePath":"/tmp/own.png"},
          {"id":"c","message":"C","attribute":{"source":"ipc"}}]}]
        """#.utf8))
        let state = InspectState()
        let view = Preset5View(inspectState: state)
        state.runtimeSteps = steps
        let run = steps[1]
        let entries = run.cadenceEntries ?? []
        XCTAssertEqual(entries.map { view.cadenceEntryArtwork($0, in: run).imagePath },
                       ["/System/Library/CoreServices/Finder.app", "/tmp/own.png", nil])
    }
}

/// The brand picker's allow-list note is singular for one hidden brand and plural for more.
@MainActor
final class BrandAllowListNoteTests: XCTestCase {

    func testOneHiddenBrandReadsSingular() {
        XCTAssertEqual(Preset5View.brandAllowListNote(hidden: 1),
                       "1 other brand exists but is not in your managed allow-list, so it is hidden rather than greyed out.")
    }

    func testSeveralHiddenBrandsReadPlural() {
        XCTAssertEqual(Preset5View.brandAllowListNote(hidden: 3),
                       "3 other brands exist but are not in your managed allow-list, so they are hidden rather than greyed out.")
    }

    func testALanguagePackSentenceIsUsedForItsCount() {
        XCTAssertEqual(Preset5View.brandAllowListNote(hidden: 1, one: "Eine Marke ausgeblendet", many: "{n} Marken ausgeblendet"),
                       "Eine Marke ausgeblendet")
        XCTAssertEqual(Preset5View.brandAllowListNote(hidden: 4, one: "Eine Marke ausgeblendet", many: "{n} Marken ausgeblendet"),
                       "4 Marken ausgeblendet")
    }
}


// The step counter counts what will show.
@MainActor
final class VisibleStepCounterTests: XCTestCase {

    func testHiddenBranchesAreNotCounted() throws {
        let steps = try JSONDecoder().decode([InspectConfig.IntroStep].self, from: Data(#"""
        [{"id":"pick","stepType":"options","optionKey":"recipe"},
         {"id":"a1","stepType":"intro","showWhen":{"key":"recipe","anyOf":["a"]}},
         {"id":"b1","stepType":"intro","showWhen":{"key":"recipe","anyOf":["b"]}},
         {"id":"b2","stepType":"intro","showWhen":{"key":"recipe","anyOf":["b"]}},
         {"id":"end","stepType":"outro"}]
        """#.utf8))
        let a = ["recipe": "a"]
        XCTAssertEqual(Preset5View.visiblePosition(steps: steps, values: a, index: 0).total, 3, "pick, a1, end")
        XCTAssertEqual(Preset5View.visiblePosition(steps: steps, values: a, index: 4).current, 2)
        XCTAssertEqual(Preset5View.visiblePosition(steps: steps, values: ["recipe": "b"], index: 3).current, 2)
        XCTAssertEqual(Preset5View.visiblePosition(steps: steps, values: [:], index: 0).total, 2, "nothing picked yet: the always-shown steps")
    }
}

// MARK: - Preset 5 form wire contract
// Frozen: the 3-part interaction-log line `type:fieldId:value`, and `legacyFormValues`, the flat
// `fieldId → String` shape every exit surface reads. `FormWire` is where each shape is spelled.
@MainActor
final class Preset5FormWireContractTests: XCTestCase {

    private var view: Preset5View!
    private var state: InspectState!

    override func setUpWithError() throws {
        try super.setUpWithError()
        state = InspectState()
        view = Preset5View(inspectState: state)
        state.runtimeSteps = [try Self.decodeStep(Self.formStepJSON)]
        state.initializeGuidanceFormState(for: "prefs")
        truncateInteractionLog()
    }

    // MARK: Wire lines

    private let wire = FormWire(dialect: .step3Part)

    /// The interaction log is a shared file in /tmp: a secure field's value never reaches it.
    func testASecureFieldNeverPutsItsValueOnTheInteractionLog() {
        XCTAssertEqual(FormWire.loggedValue("hunter2", secure: true), "<redacted>")
        XCTAssertEqual(FormWire.loggedValue("line one\nline two", secure: false), "line one\\nline two")
    }

    func testStringFieldsEmitThreePartLines() {
        for (type, fieldId, value) in [("dropdown", "browser", "Safari"),
                                       ("radio", "theme", "Dark"),
                                       ("textfield", "hostname", "mac-1042")] {
            XCTAssertEqual(wire.line(type: type, owner: "prefs", field: fieldId, value: value),
                           "\(type):\(fieldId):\(value)",
                           "\(type) wire line changed shape — this is the frozen contract")
        }
    }

    func testBoolFieldsEmitThreePartLinesWithLowercaseBools() {
        for (type, fieldId) in [("checkbox", "analytics"), ("toggle", "notifications")] {
            XCTAssertEqual(wire.line(type: type, owner: "prefs", field: fieldId, value: String(true)),
                           "\(type):\(fieldId):true")
            XCTAssertEqual(wire.line(type: type, owner: "prefs", field: fieldId, value: String(false)),
                           "\(type):\(fieldId):false")
        }
    }

    /// The 3-part line carries no owner id (not `dropdown:prefs:browser:Safari`).
    func testThreePartLineCarriesNoOwnerId() {
        let line = wire.line(type: "dropdown", owner: "prefs", field: "browser", value: "Chrome")
        let parts = line.split(separator: ":", omittingEmptySubsequences: false)
        XCTAssertEqual(parts.count, 3, "expected type:fieldId:value, got \(line)")
        XCTAssertEqual(String(parts[1]), "browser", "part 2 must be the FIELD id, not the step id")
        XCTAssertEqual(FormWire().line(type: "dropdown", owner: "prefs", field: "browser", value: "Chrome"),
                       "dropdown:prefs:browser:Chrome", "the shared blocks keep the 4-part line")
    }

    /// Preset 5 coerces a slider to Int on the wire; the shared blocks keep the Double.
    func testSliderValueIsAnIntOnTheThreePartWire() {
        XCTAssertEqual(wire.sliderWireValue(50), "50")
        XCTAssertEqual(FormWire().sliderWireValue(50), "50.0")
    }

    // MARK: legacyFormValues

    func testLegacyFormValuesFlattensAllSixTypes() {
        state.guidanceFormInputs["prefs"] = {
            var s = GuidanceFormInputState()
            s.dropdowns["browser"] = "Safari"
            s.radios["theme"] = "Auto"
            s.textfields["hostname"] = "mac-1042"
            s.checkboxes["analytics"] = true
            s.toggles["notifications"] = false
            s.sliders["volume"] = 40
            return s
        }()

        XCTAssertEqual(view.legacyFormValues(for: try Self.decodeStep(Self.formStepJSON)),
                       ["browser": "Safari", "theme": "Auto", "hostname": "mac-1042",
                        "analytics": "true", "notifications": "false", "volume": "40"])
    }

    /// The pickers that keep their value in `textfields` reach the outputs too; several values join with ",".
    func testLegacyFormValuesIncludeEveryTextfieldBackedPicker() throws {
        let step = try Self.decodeStep(#"""
        {"id": "prefs", "content": [
          {"type": "drop-zone", "id": "files"}, {"type": "color-picker", "id": "accent"},
          {"type": "stepper", "id": "copies"}, {"type": "search", "id": "printer"},
          {"type": "multi-select", "id": "apps"}, {"type": "select-list", "id": "langs"},
          {"type": "select-grid", "id": "tiles"}]}
        """#)
        var s = GuidanceFormInputState()
        s.textfields["files"] = "/tmp/a.pdf\n/tmp/b.pdf"
        s.textfields["accent"] = "#0A84FF"
        s.textfields["copies"] = "3"
        s.textfields["printer"] = "Floor 2"
        s.textfields["apps"] = "Slack\u{001F}Zoom"
        s.textfields["langs"] = "en\u{001F}de"
        s.textfields["tiles"] = "mail"
        state.guidanceFormInputs["prefs"] = s

        XCTAssertEqual(view.legacyFormValues(for: step),
                       ["files": "/tmp/a.pdf,/tmp/b.pdf", "accent": "#0A84FF", "copies": "3", "printer": "Floor 2",
                        "apps": "Slack,Zoom", "langs": "en,de", "tiles": "mail"])
    }

    /// Integral slider values flatten to "40", fractional ones keep the decimal.
    func testSliderFlatteningDropsTheDecimalOnlyWhenIntegral() {
        var s = GuidanceFormInputState()
        s.sliders["volume"] = 40
        state.guidanceFormInputs["prefs"] = s
        XCTAssertEqual(view.legacyFormValues(for: try Self.decodeStep(Self.formStepJSON))["volume"], "40")

        s.sliders["volume"] = 40.5
        state.guidanceFormInputs["prefs"] = s
        XCTAssertEqual(view.legacyFormValues(for: try Self.decodeStep(Self.formStepJSON))["volume"], "40.5")
    }

    /// An untouched field is absent, not empty; consumers test for the key.
    func testUnsetFieldsAreAbsentRatherThanEmpty() throws {
        var s = GuidanceFormInputState()
        s.dropdowns["browser"] = "Safari"
        state.guidanceFormInputs["prefs"] = s

        let values = view.legacyFormValues(for: try Self.decodeStep(Self.formStepJSON))
        XCTAssertEqual(values, ["browser": "Safari"])
        XCTAssertNil(values["hostname"])
    }

    /// Non-form blocks never contribute, even when they carry an id.
    func testNonFormBlocksDoNotLeakIntoFormValues() {
        var s = GuidanceFormInputState()
        s.textfields["a-text-block"] = "should not appear"
        state.guidanceFormInputs["prefs"] = s

        XCTAssertTrue(view.legacyFormValues(for: try Self.decodeStep(Self.formStepJSON)).isEmpty)
    }

    /// Whole-config variant merges every step, last step wins on a duplicate field id.
    func testLegacyFormValuesMergesStepsLastWins() throws {
        state.runtimeSteps = [try Self.decodeStep(Self.formStepJSON),
                              try Self.decodeStep(Self.secondStepJSON)]
        var first = GuidanceFormInputState()
        first.dropdowns["browser"] = "Safari"
        state.guidanceFormInputs["prefs"] = first
        var second = GuidanceFormInputState()
        second.dropdowns["browser"] = "Chrome"
        state.guidanceFormInputs["more"] = second

        XCTAssertEqual(view.legacyFormValues["browser"], "Chrome")
    }

    // MARK: Helpers

    private static let formStepJSON = """
    {"id": "prefs", "stepType": "intro", "content": [
      {"type": "dropdown", "id": "browser", "options": ["Safari", "Chrome", "Firefox"]},
      {"type": "radio", "id": "theme", "options": ["Light", "Dark", "Auto"]},
      {"type": "textfield", "id": "hostname"},
      {"type": "checkbox", "id": "analytics"},
      {"type": "toggle", "id": "notifications"},
      {"type": "slider", "id": "volume", "min": 0, "max": 100},
      {"type": "text", "id": "a-text-block", "content": "not a form field"}
    ]}
    """

    /// `segmented` lives in the dropdowns bucket and flattens like a dropdown.
    func testSegmentedFlattensLikeADropdown() {
        var s = GuidanceFormInputState()
        s.dropdowns["appearance"] = "Auto"
        state.guidanceFormInputs["prefs"] = s

        XCTAssertEqual(view.legacyFormValues(for: try Self.decodeStep(Self.segmentedStepJSON)),
                       ["appearance": "Auto"])
    }

    private static let segmentedStepJSON = """
    {"id": "prefs", "stepType": "intro", "content": [
      {"type": "segmented", "id": "appearance", "options": ["Light", "Dark", "Auto"], "value": "Auto"}
    ]}
    """

    private static let secondStepJSON = """
    {"id": "more", "stepType": "intro", "content": [
      {"type": "dropdown", "id": "browser", "options": ["Safari", "Chrome"]}
    ]}
    """

    private static func decodeStep(_ json: String) throws -> InspectConfig.IntroStep {
        try JSONDecoder().decode(InspectConfig.IntroStep.self, from: Data(json.utf8))
    }

    private func truncateInteractionLog() {
        for path in [interactionLogPath, legacyInteractionLogPath] {
            try? Data().write(to: URL(fileURLWithPath: path))
        }
    }

    private func lastInteractionLine() -> String {
        let text = (try? String(contentsOfFile: interactionLogPath, encoding: .utf8)) ?? ""
        return text.split(separator: "\n").last.map(String.init) ?? ""
    }
}

// One row of tiles never runs past the column: past three, the screen draws the row list.
@MainActor
final class ProvisioningTileRowTests: XCTestCase {

    private func step(_ json: String) throws -> InspectConfig.IntroStep {
        try JSONDecoder().decode(InspectConfig.IntroStep.self, from: Data(json.utf8))
    }

    private let flavors = #"[{"id":"a","name":"A","items":[]},{"id":"b","name":"B","items":[]},{"id":"c","name":"C","items":[]}]"#

    func testThreeTilesCloseTheColumn() {
        XCTAssertEqual(ProvisioningM.maxTiles, 3)
        XCTAssertEqual(ProvisioningM.tileGridWidth(ProvisioningM.maxTiles), 732)
    }

    func testAFourthTileDrawsTheRowListInstead() throws {
        let view = Preset5View(inspectState: InspectState())
        let metrics = ProvisioningM(width: 820, height: 600)
        let three = try step(#"{"id":"d","stepType":"dock","optionLayout":"cards","dockFlavors":"# + flavors + "}")
        let four = try step(#"{"id":"d","stepType":"dock","optionLayout":"cards","dockFlavors":"# + flavors
                            + #","dockDecline":{"label":"Keep my Dock as it is","value":"keep"}}"#)
        XCTAssertTrue(view.wantsTiles(three, metrics: metrics))
        XCTAssertFalse(view.wantsTiles(four, metrics: metrics), "a fourth tile would overflow the 740 column")
    }
}

// MARK: - Palette on a photograph surface

/// The journey capsule is dark in both appearances, so it takes `ResolvedPalette.onDarkSurface`:
/// the surface decides, not the window's appearance. A `colorScheme` override cannot reach the
/// palette, which is resolved once at the preset root.
@MainActor
final class DarkSurfacePaletteTests: XCTestCase {

    /// A config with both palettes authored.
    private func config() throws -> InspectConfig {
        try JSONDecoder().decode(InspectConfig.self, from: Data("""
        {
          "preset": "5",
          "brandPalette":     { "notice": "#111111", "textPrimary": "#222222" },
          "brandPaletteDark": { "notice": "#eeeeee", "textPrimary": "#dddddd" }
        }
        """.utf8))
    }

    /// The window's own palette, for comparison.
    private func window(_ config: InspectConfig?, _ scheme: ColorScheme) -> ResolvedPalette {
        ResolvedPalette(from: config?.brandPalette, dark: config?.brandPaletteDark,
                        scheme: scheme, primaryColor: .blue)
    }

    /// In a light window the chip's notice is `#eeeeee` on the dark surface, not `#111111`.
    func testTheChipTakesTheDarkNoticeInALightWindow() throws {
        let cfg = try config()
        XCTAssertEqual(window(cfg, .light).notice, Color(hex: "#111111"),
                       "the window install is unchanged — a light window still resolves light")
        XCTAssertEqual(ResolvedPalette.onDarkSurface(config: cfg, primaryColor: .blue).notice,
                       Color(hex: "#eeeeee"),
                       "the α ground is dark whatever the window is, so the chip takes the dark value")
    }

    /// The chip's fill follows the dark notice.
    func testTheChipsFillFollowsTheDarkNotice() throws {
        let surface = ResolvedPalette.onDarkSurface(config: try config(), primaryColor: .blue)
        XCTAssertEqual(surface.noticeBackground, Color(hex: "#eeeeee").opacity(0.16))
    }

    /// An authored light neutral takes its dark value on this ground.
    func testAnAuthoredNeutralTakesItsDarkValueOnThisGround() throws {
        let cfg = try config()
        XCTAssertEqual(window(cfg, .light).text, Color(hex: "#222222"))
        XCTAssertEqual(ResolvedPalette.onDarkSurface(config: cfg, primaryColor: .blue).text,
                       Color(hex: "#dddddd"))
    }

    /// Unbranded, the surface still resolves the dark default.
    func testAnUnbrandedConfigStillResolvesTheDarkDefault() {
        XCTAssertEqual(ResolvedPalette.onDarkSurface(config: nil, primaryColor: .blue).notice,
                       Color(hex: "#e0b378"))
        XCTAssertNotEqual(ResolvedPalette.onDarkSurface(config: nil, primaryColor: .blue).notice,
                          window(nil, .light).notice)
    }

    /// The window's appearance is not an input.
    func testTheWindowsAppearanceIsNotConsulted() throws {
        let cfg = try config()
        let once = ResolvedPalette.onDarkSurface(config: cfg, primaryColor: .blue)
        XCTAssertEqual(once.notice, window(cfg, .dark).notice,
                       "a dark surface in a light window resolves exactly as a dark window does")
        XCTAssertEqual(once.text, window(cfg, .dark).text)
    }

    /// Only the two α arms install the dark-surface palette, both conditionally; β follows the window.
    func testOnlyTheAlphaArmsTakeTheDarkSurfacePalette() throws {
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Preset Layouts/Preset5+Migration.swift"),
                                encoding: .utf8)
        // Both α grounds can be light, so each installs the palette conditionally.
        let unconditional = source.components(separatedBy: ".inspectPaletteOnDarkSurface(").count - 1
        let conditional = source.components(separatedBy: "DarkSurfaceIfNeeded(").count - 1
        XCTAssertEqual(unconditional + conditional, 2,
                       "one per α arm — the journey and the marks/progress screen, and no more")
        XCTAssertEqual(unconditional, 0,
                       "no α arm installs the dark palette unconditionally any more: both grounds "
                       + "can be light, and the palette has to follow the ground")
        guard let betaStart = source.range(of: "func setupAssistantBeta"),
              let betaEnd = source.range(of: "func setupAssistantAlpha") else {
            return XCTFail("the two arms must both still exist for this to mean anything")
        }
        let beta = source[betaStart.lowerBound..<betaEnd.lowerBound]
        XCTAssertFalse(beta.contains(".inspectPaletteOnDarkSurface("),
                       "β is a card on the window's ground and follows the window")
        XCTAssertFalse(beta.contains("DarkSurfaceIfNeeded("),
                       "and it does not need the conditional form either — β has no dark ground "
                       + "to condition on")
    }
}

// MARK: - Hosts pass the block's style through

final class PhaseTrackerStylePassthroughTests: XCTestCase {

    private func repoSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // dialogTests/
            .deletingLastPathComponent() // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// No host hardcodes the tracker `style`, which would make "progress" unreachable.
    func testNoHostHardcodesTheTrackerStyle() throws {
        let hosts = ["dialog/Views/Inspect/Core Framework/Components/GuidanceContentView.swift",
                     "dialog/Views/Inspect/Preset Layouts/Preset5+ContentBlocks.swift"]
        for host in hosts {
            let source = try repoSource(host)
            XCTAssertFalse(source.contains("style: \"stepper\","),
                           "\(host) passes a literal style to PhaseTrackerView, so a config "
                           + "authoring style: \"progress\" there silently gets the track")
        }
    }
}
