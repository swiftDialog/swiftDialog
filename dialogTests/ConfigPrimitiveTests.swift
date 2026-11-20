//
//  ConfigPrimitiveTests.swift
//  dialogTests
//
//  Value types of the config model: cadence estimates and external failures, splash picks,
//  gradient presets, phase backdrops and icon references.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog

// MARK: - totalTimeEstimate (CadenceProgress.entriesFillingEstimates)

/// A step's one `totalTimeEstimate` fills the entries that carry no estimate of their own.
final class CadenceEstimateSplitTests: XCTestCase {

    private func entry(_ id: String, estimate: Double? = nil) throws -> InspectConfig.CadenceEntry {
        var json = #"{"id":"\#(id)","message":"m","attribute":{"type":"file","path":"/tmp/x"}"#
        if let estimate { json += #","timeEstimate":\#(estimate)"# }
        json += "}"
        return try JSONDecoder().decode(InspectConfig.CadenceEntry.self, from: Data(json.utf8))
    }

    func testEvenSplitWhenNoEntryEstimates() throws {
        let out = CadenceProgress.entriesFillingEstimates([try entry("a"), try entry("b")], total: 240)
        XCTAssertEqual(out.map(\.timeEstimate), [120, 120])
    }

    func testAuthoredEstimatesWinAndTheRemainderSplits() throws {
        let out = CadenceProgress.entriesFillingEstimates([try entry("a", estimate: 60), try entry("b"), try entry("c")], total: 240)
        XCTAssertEqual(out.map(\.timeEstimate), [60, 90, 90])
    }

    func testATotalAlreadySpentLeavesBlanksBlank() throws {
        let out = CadenceProgress.entriesFillingEstimates([try entry("a", estimate: 300), try entry("b")], total: 240)
        XCTAssertEqual(out.map(\.timeEstimate), [300, nil], "nothing is invented when the authored estimates exceed the total")
    }

    func testNoTotalIsANoOp() throws {
        let entries = [try entry("a"), try entry("b", estimate: 30)]
        XCTAssertEqual(CadenceProgress.entriesFillingEstimates(entries, total: nil).map(\.timeEstimate), [nil, 30])
        XCTAssertEqual(CadenceProgress.entriesFillingEstimates(entries, total: 0).map(\.timeEstimate), [nil, 30])
    }
}

// The splash pick is reported so the launching script can open the flow for it. These pin the
// rule's three halves: what it is called, what it reports, and when there is nothing to report.
final class SplashPickTests: XCTestCase {

    private func step(_ fields: String) throws -> InspectConfig.IntroStep {
        try JSONDecoder().decode(InspectConfig.IntroStep.self,
                                 from: Data(#"{"id":"splash","stepType":"intro"\#(fields)}"#.utf8))
    }

    func testKeyIsAuthoredOrEnvironment() throws {
        XCTAssertEqual(SplashPick.key(for: try step(#","environmentKey":"team""#)), "team")
        XCTAssertEqual(SplashPick.key(for: try step("")), "environment")
        XCTAssertEqual(SplashPick.key(for: try step(#","environmentKey":"""#)), "environment",
                       "an empty key falls back rather than reporting under \"\"")
    }

    func testDefaultIsTheFirstDestinationsIdElseItsTitle() throws {
        let withIds = try step(#","environments":[{"id":"workstations","title":"Workstations"},{"id":"engineering","title":"Engineering"}]"#)
        XCTAssertEqual(SplashPick.defaultValue(for: withIds), "workstations")
        let titlesOnly = try step(#","environments":[{"title":"Production"},{"title":"Staging"}]"#)
        XCTAssertEqual(SplashPick.defaultValue(for: titlesOnly), "Production")
        XCTAssertEqual(withIds.environments?[1].value, "engineering")
    }

    func testAMarkStandingAloneReportsNothing() throws {
        XCTAssertNil(SplashPick.defaultValue(for: try step("")))
        XCTAssertNil(SplashPick.defaultValue(for: try step(#","environments":[{"id":"only","title":"Only"}]"#)),
                     "one destination is no choice, so there is no pick to report")
    }
}

// Gradient presets: picked by id, expanded before decoding.
final class GradientPresetsTests: XCTestCase {

    func testTheBundledSetDecodes() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let bundled = try Data(contentsOf: repo.appendingPathComponent("dialog/Views/Inspect/Extras/gradients.json"))
        XCTAssertFalse(bundled.isEmpty)
        XCTAssertEqual(GradientPresets.ids.count, 14)
    }

    func testAReferenceExpandsToItsStopsByAppearance() throws {
        let g01 = try XCTUnwrap(GradientPresets.all.first { $0.id == "g01" })
        XCTAssertEqual(GradientPresets.expand(["preset:g01"], dark: false), g01.colors)
        XCTAssertEqual(GradientPresets.expand(["preset:g01"], dark: true), g01.darkColors)
        XCTAssertEqual(GradientPresets.expand(["#112233", "preset:nope"], dark: false), ["#112233", "preset:nope"],
                       "hex and unknown references pass through")
    }

    func testExpansionReachesNestedPaletteKeysAndLintFindsUnknowns() throws {
        let g09 = try XCTUnwrap(GradientPresets.all.first { $0.id == "g09" })
        let json: [String: Any] = [
            "phaseBackgroundPalette": ["preset:g09"],
            "phaseBackgroundPaletteDark": ["preset:g09"],
            "introSteps": [["id": "s", "showcase": ["gradientColors": ["preset:g09"]],
                            "bentoCells": [["gradientPalette": ["preset:g42"]]]]]
        ]
        let out = try XCTUnwrap(GradientPresets.expandReferences(in: json) as? [String: Any])
        XCTAssertEqual(out["phaseBackgroundPalette"] as? [String], g09.colors)
        XCTAssertEqual(out["phaseBackgroundPaletteDark"] as? [String], g09.darkColors)
        let step = try XCTUnwrap((out["introSteps"] as? [[String: Any]])?.first)
        XCTAssertEqual((step["showcase"] as? [String: Any])?["gradientColors"] as? [String], g09.colors)
        let unknown = GradientPresets.unknownReferences(in: json)
        XCTAssertEqual(unknown.map(\.value), ["preset:g42"])
        XCTAssertEqual(unknown.first?.path, "introSteps[0].bentoCells[0].gradientPalette")
    }
}

// `cadence:fail:<id>` — the script tried the work and it did not succeed: the entry reads as
// failed (never a done tick) and the run moves on.
@MainActor
final class CadenceExternalFailTests: XCTestCase {
    func testAFailedEntryIsNotCountedAndTheRunMovesOn() throws {
        let svc = CadenceMonitorService(now: { Date(timeIntervalSince1970: 1_000) })
        let attr = try XCTUnwrap(try? JSONDecoder().decode(
            InspectConfig.CadenceAttribute.self, from: Data(#"{"source": "ipc"}"#.utf8)))
        func entry(_ id: String) -> InspectConfig.CadenceEntry {
            InspectConfig.CadenceEntry(id: id, message: id, attribute: attr, minDwell: 0,
                timeout: 600, sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil,
                subtitle: nil, timeEstimate: nil, size: nil)
        }
        svc.startWithEntries(entries: [entry("a"), entry("b"), entry("c")], stepId: "s", interval: 3600, onCompletion: nil)
        svc.satisfyExternally(id: "a")
        svc.failExternally(id: "c")                      // not reached yet: ignored
        XCTAssertEqual(svc.currentIndex, 1)
        XCTAssertTrue(svc.failedIndices.isEmpty)
        svc.failExternally(id: "b")
        XCTAssertEqual(svc.currentIndex, 2, "a failed entry moves the run on")
        XCTAssertEqual(svc.failedIndices, [1])
        XCTAssertEqual(svc.timedOutIndices, [1], "and it does not count as done")
        svc.satisfyExternally(id: "c")
        XCTAssertTrue(svc.isComplete)
        XCTAssertEqual(svc.failedIndices, [1], "the run completes with its failure on record")
    }
}

// MARK: - Phase backdrop resolution

@MainActor
final class PhaseBackdropResolutionTests: XCTestCase {

    var tempBase: URL!

    override func setUp() {
        super.setUp()
        tempBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("managed-prefs-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
        CadenceMonitorService.managedPreferencesBase = tempBase.path
    }

    override func tearDown() {
        CadenceMonitorService.managedPreferencesBase = "/Library/Managed Preferences"
        try? FileManager.default.removeItem(at: tempBase)
        super.tearDown()
    }

    private func writeDomain(_ domain: String, _ dict: [String: Any]) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: tempBase.appendingPathComponent("\(domain).plist"))
    }

    private func config(_ json: String) throws -> InspectConfig {
        // Inject the keys InspectConfig requires so tests can stay minimal.
        var dict = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [String: Any]
        if dict["preset"] == nil { dict["preset"] = "2" }
        if dict["items"] == nil { dict["items"] = [] }
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(InspectConfig.self, from: data)
    }

    func testDefaultsToPlain() {
        XCTAssertEqual(resolvePhaseBackdrop(config: nil).style, "plain")
        XCTAssertEqual(resolvePhaseBackdrop(config: try config("{}")).style, "plain")
    }

    func testConfigStyleAndPaletteApply() throws {
        let spec = resolvePhaseBackdrop(config: try config(
            ##"{"phaseBackground": "gradient", "phaseBackgroundPalette": ["#112233", "#445566"]}"##))
        XCTAssertEqual(spec.style, "gradient")
        XCTAssertEqual(spec.palette, ["#112233", "#445566"])
    }

    func testManagedStyleOverridesConfig() throws {
        try writeDomain(dialogManagedLookDomain, ["PhaseBackground": "ethereal",
                                              "PhaseBackgroundPalette": ["#AA0000"]])
        let spec = resolvePhaseBackdrop(config: try config(##"{"phaseBackground": "plain"}"##))
        XCTAssertEqual(spec.style, "ethereal")
        XCTAssertEqual(spec.palette, ["#AA0000"])
    }

    func testInvalidManagedStyleFallsBackToConfig() throws {
        try writeDomain(dialogManagedLookDomain, ["PhaseBackground": "disco-lasers"])
        let spec = resolvePhaseBackdrop(config: try config(##"{"phaseBackground": "gradient"}"##))
        XCTAssertEqual(spec.style, "gradient")
    }

    func testInvalidConfigStyleFallsBackToPlain() {
        XCTAssertEqual(resolvePhaseBackdrop(config: try config(##"{"phaseBackground": "sparkles"}"##)).style, "plain")
    }

    /// The splash ground as the flow's backdrop, from the config and from a profile.
    func testSplashIsABackdropStyle() throws {
        let spec = resolvePhaseBackdrop(config: try config(
            ##"{"phaseBackground": "splash", "phaseBackgroundPalette": ["#6A67FE", "#3DB67B"]}"##))
        XCTAssertEqual(spec.style, "splash")
        XCTAssertEqual(spec.palette, ["#6A67FE", "#3DB67B"])
    }

    func testAProfileCanPutAFlowOnTheSplashGround() throws {
        try writeDomain(dialogManagedLookDomain, ["PhaseBackground": "splash"])
        XCTAssertEqual(resolvePhaseBackdrop(config: try config(##"{"phaseBackground": "plain"}"##)).style, "splash")
    }

    func testCustomSourceDomainAndKey() throws {
        try writeDomain("com.example.brand", ["Look": "vivid", "LookPalette": ["#00FF00"]])
        let spec = resolvePhaseBackdrop(config: try config(
            ##"{"phaseBackgroundSource": {"domain": "com.example.brand", "key": "Look"}}"##))
        XCTAssertEqual(spec.style, "vivid")
        XCTAssertEqual(spec.palette, ["#00FF00"])
    }

    func testDarkPaletteLadder() throws {
        try writeDomain(dialogManagedLookDomain, ["PhaseBackground": "gradient",
                                              "PhaseBackgroundPaletteDark": ["#010203"]])
        let spec = resolvePhaseBackdrop(config: try config(
            ##"{"phaseBackgroundPalette": ["#AABBCC"]}"##))
        XCTAssertEqual(spec.palette, ["#AABBCC"])       // config palette (no managed light palette)
        XCTAssertEqual(spec.darkPalette, ["#010203"])   // managed dark palette wins
    }
}

// MARK: - IconRef
// The one resolver for `SF=` references, with a strict and a lenient policy.
final class IconRefTests: XCTestCase {

    /// `computer` is this Mac's icon in every hero (card band and bookend), in any case; it is not
    /// an SF Symbol, so a hero that fed it to `Image(systemName:)` drew an empty tile.
    func testComputerKeywordIsRecognisedInAnyCase() {
        for form in ["computer", "Computer", "COMPUTER"] { XCTAssertTrue(IconRef.isComputer(form), form) }
        XCTAssertFalse(IconRef.isComputer("SF=desktopcomputer"))
        XCTAssertFalse(IconRef.isComputer("/tmp/computer.png"))
    }

    /// Strict: a symbol only when prefixed, since the field may hold a file.
    func testStrictPolicyRequiresThePrefix() {
        XCTAssertEqual(IconRef.symbol("SF=globe"), "globe")
        XCTAssertNil(IconRef.symbol("globe"), "a bare name is a FILE under the strict policy")
        XCTAssertNil(IconRef.symbol("SF="), "a prefix with no name is not a symbol")
    }

    /// The `SF=` prefix matches in any case.
    func testPrefixIsCaseInsensitive() {
        for form in ["SF=lock", "sf=lock", "Sf=lock", "sF=lock"] {
            XCTAssertEqual(IconRef.symbol(form), "lock", "\(form) should resolve")
            XCTAssertTrue(IconRef.isSymbolReference(form))
        }
    }

    /// Lenient: a bare name is a symbol where the field only holds a mark (rail glyph, option-row icons).
    func testLenientPolicyAcceptsABareName() {
        XCTAssertEqual(IconRef.symbolOrBareName("SF=globe"), "globe")
        XCTAssertEqual(IconRef.symbolOrBareName("globe"), "globe")
        XCTAssertNil(IconRef.symbolOrBareName("logo.png"), "file-shaped strings are not symbols")
        XCTAssertNil(IconRef.symbolOrBareName(""))
    }

    /// A dotted SF Symbol name is not a file path.
    func testDottedSymbolsAreNotFiles() {
        for symbol in ["gear.badge", "checkmark.seal", "lock.open", "arrow.down.circle.fill"] {
            XCTAssertFalse(IconRef.isFilePath(symbol), "\(symbol) is a symbol, not a file")
            XCTAssertEqual(IconRef.symbolOrBareName(symbol), symbol)
        }
    }

    func testFilePathsAreRecognised() {
        for path in ["/Library/logo.png", "~/icon.jpg", "logo.PNG",
                     "https://example.com/a.png", "brand/fleet-logo-dark-rgb.png"] {
            XCTAssertTrue(IconRef.isFilePath(path), "\(path) should be a file")
        }
        XCTAssertFalse(IconRef.isFilePath("SF=folder"), "an SF reference is never a file")
    }
}
