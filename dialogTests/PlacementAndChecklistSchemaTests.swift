//
//  PlacementAndChecklistSchemaTests.swift
//  dialogTests
//
//  Schema-reading checks: placement defaults, the Setup Assistant checklist and the cadence
//  progressive disclosure.
//

import XCTest
import SwiftUI
import Synchronization
@testable import Dialog

// MARK: - Progressive disclosure
// `CadenceM.visibleWindow` shows as many cards as fit, the active one always among them, clamped at
// both ends. A static grid of every entry is not allowed.

final class CadenceProgressiveDisclosureTests: XCTestCase {

    /// At every count, the window never shows more than fits.
    func testTheWindowNeverShowsMoreThanFits() {
        let viewport = CadenceM.rowContentWidth
        let fits = CadenceM.cardsPerRow(viewport: viewport)
        for count in 1...24 {
            for active in 0..<max(count, 1) {
                let window = CadenceM.visibleWindow(count: count, active: active, viewport: viewport)
                XCTAssertLessThanOrEqual(window.count, max(fits, min(count, fits)),
                                         "count \(count), active \(active) showed \(window.count)")
                XCTAssertLessThanOrEqual(window.count, count)
                if count > fits {
                    XCTAssertEqual(window.count, fits,
                                   "an overflowing run must WINDOW, never grow the row")
                    XCTAssertTrue(window.contains(active),
                                  "the active card must be visible — a window that hides the cursor is worse than a grid")
                }
            }
        }
    }

    /// The window clamps rather than re-centring on every advance.
    func testTheWindowClampsRatherThanRecentring() {
        let v = CadenceM.rowContentWidth
        let fits = CadenceM.cardsPerRow(viewport: v)
        XCTAssertEqual(CadenceM.visibleWindow(count: 12, active: 0, viewport: v).first, 0)
        XCTAssertEqual(CadenceM.visibleWindow(count: 12, active: 11, viewport: v).last, 11)
        // Advancing within the window does not move it.
        let a = CadenceM.visibleWindow(count: 12, active: 0, viewport: v)
        let b = CadenceM.visibleWindow(count: 12, active: fits - 1, viewport: v)
        XCTAssertEqual(a, b, "the row must hold still while the cursor crosses it")
    }

    /// Every cadence component that iterates the run's entries bounds them. Only files in
    /// `Components/Cadence/` that enumerate entries are checked.
    func testNoCadenceComponentDrawsEveryEntryAtOnce() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let dir = root.appendingPathComponent("dialog/Views/Inspect/Core Framework/Components/Cadence")
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty, "found no cadence components — the walk is broken, not the tree")

        var offenders: [String] = []
        for f in files {
            let src = try String(contentsOf: f, encoding: .utf8)
            // Strip comments so prose about entries cannot trip this.
            let code = src.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            let enumerates = code.contains("ForEach") &&
                (code.contains("run.entries") || code.contains("entries.enumerated"))
            guard enumerates else { continue }
            // A component bounds a list by windowing (`CadenceM.visibleWindow`) or rolling up (`CadenceRollup`).
            if !code.contains("visibleWindow") && !code.contains("CadenceRollup") {
                offenders.append(f.lastPathComponent)
            }
        }
        XCTAssertEqual(offenders, [],
                       "these draw every cadence entry at once instead of windowing: \(offenders). "
                       + "A static grid of all items is the ruled anti-pattern — the "
                       + "row shows as many as fit and slides. Use CadenceM.visibleWindow.")
    }

    /// The static-grid cadence styles (`tiles`, `cards`, `gates`) stay out of the schema enum. `bento` is
    /// allowed because it windows through `CadenceM.visibleWindow`. Read from the source tree, since the
    /// schema is not in the app bundle.
    func testTheGridDesignsStayRetired() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let values = try XCTUnwrap(Self.schemaEnum(root, key: "cadenceStyle"))
        XCTAssertEqual(values, ["bento", "manifest", "spotlight"],
                       "'tiles' drew all twelve entries as a static grid and 'cards' a fixed pair with no "
                       + "progressive movement — both ruled an anti-pattern; 'gates' was ruled "
                       + "out on its appearance; 'line' and 'carousel' were cut with them. The two that "
                       + "words that stand all BOUND what they draw: 'bento' is the board, fed by the "
                       + "window model; 'manifest' and 'spotlight' roll up instead — three named "
                       + "receipts and two named waiting steps, the rest counted, so twelve steps draw "
                       + "the same rows as four. Adding another means "
                       + "stating how it bounds itself. Found: \(values)")
    }

    /// `manifest` and `spotlight` are the minimal designs; `bento` and the rest are not.
    func testTheMinimalKinds() {
        XCTAssertEqual(CadenceMinimalKind(authored: "Manifest"), .manifest)
        XCTAssertEqual(CadenceMinimalKind(authored: "spotlight"), .spotlight)
        XCTAssertNil(CadenceMinimalKind(authored: "bento"))
        XCTAssertNil(CadenceMinimalKind(authored: nil))
    }

    /// A cadence step with no or an unknown `cadenceStyle` draws the manifest.
    func testACadenceStepWithNoStyleDrawsTheManifest() {
        XCTAssertEqual(CadenceMinimalKind.forStep(authored: nil), .manifest)
        XCTAssertEqual(CadenceMinimalKind.forStep(authored: "gates"), .manifest)
        XCTAssertEqual(CadenceMinimalKind.forStep(authored: "spotlight"), .spotlight)
    }



    /// Depth-first search for `properties.<key>.enum`; the step properties sit several `oneOf` arms deep.
    private static func schemaEnum(_ node: Any, key: String) -> [String]? {
        if let dict = node as? [String: Any] {
            if let props = dict["properties"] as? [String: Any],
               let prop = props[key] as? [String: Any],
               let values = prop["enum"] as? [String] { return values }
            for (_, v) in dict { if let hit = schemaEnum(v, key: key) { return hit } }
        } else if let arr = node as? [Any] {
            for v in arr { if let hit = schemaEnum(v, key: key) { return hit } }
        }
        return nil
    }
}

// MARK: - Delivery journey on the gradient-hero shell

/// The provisioning rows as a translucent capsule on `SetupAssistantShell`: the capsule carries the
/// row model unchanged and takes its own scrim. The 632 window and the 420 scrim are the design's figures.
final class SetupAssistantChecklistTests: XCTestCase {

    private struct Item: MonitoredItem {
        let id: String
        let displayName: String
        var icon: String? { nil }
        var paths: [String] { [] }
        var plistKey: String? { nil }
        var expectedValue: String? { nil }
        var evaluation: String? { nil }
        var plistRecheckInterval: Int? { nil }
        var useUserDefaults: Bool? { nil }
        var jsonMonitors: [InspectConfig.JsonMonitor]? { nil }
        var requirements: [InspectConfig.ItemConfig.Requirement]? { nil }
        var satisfy: String? { nil }
        var showBundleInfo: String? { nil }
        var logAliases: [String]? { nil }
    }

    private func shell(_ capsule: SetupAssistantCapsule) -> SetupAssistantFullBleedShell<EmptyView> {
        SetupAssistantFullBleedShell(title: "Setting up your Mac",
                                 capsule: capsule,
                                 accent: .blue) { EmptyView() }
    }

    private func repoSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // dialogTests/
            .deletingLastPathComponent() // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    // MARK: - The capsule carries the rows

    /// The capsule seats `ProvisioningRowBuilder.itemRows`' model and re-decides none of it.
    func testTheChecklistCarriesTheRowsItIsGiven() {
        let rows = ProvisioningRowBuilder.itemRows(
            items: [Item(id: "figma", displayName: "Figma"),
                    Item(id: "obsidian", displayName: "Obsidian")],
            statuses: [.pending, .pending],
            removedIds: ["obsidian"],
            vocabulary: .packages)
        guard case .checklist(let carried) = SetupAssistantCapsule.checklist(rows: rows) else {
            return XCTFail("the checklist case must carry its rows")
        }
        XCTAssertEqual(carried, rows, "the capsule hands on exactly what the builder built")
    }

    /// A removed row arrives with the notice and a queued row without.
    func testARemovedRowArrivesWithTheNoticeAndAQueuedRowWithout() {
        let rows = ProvisioningRowBuilder.itemRows(
            items: [Item(id: "figma", displayName: "Figma"),
                    Item(id: "obsidian", displayName: "Obsidian")],
            statuses: [.pending, .pending],
            removedIds: ["obsidian"],
            vocabulary: .packages)
        guard case .checklist(let carried) = SetupAssistantCapsule.checklist(rows: rows) else {
            return XCTFail("the checklist case must carry its rows")
        }
        XCTAssertEqual(carried[0].trailing, .state("Queued", failed: false))
        XCTAssertEqual(carried[1].trailing, .notice("Removed"))
        // A removed row's glyph is a queued row's glyph; only the trailing word differs.
        XCTAssertEqual(carried[0].mark, .queued)
        XCTAssertEqual(carried[1].mark, .queued)
    }

    // MARK: - Journey scrim

    /// The journey takes its own 420 scrim; `scrimTall` (380) is unchanged.
    func testTheJourneyTakesItsOwnScrim() {
        XCTAssertEqual(SetupAssistantM.scrimJourney, 420)
        XCTAssertEqual(shell(.checklist(rows: [])).scrimHeight, SetupAssistantM.scrimJourney)
    }

    /// The existing capsules keep their scrims.
    func testTheExistingCapsulesKeepTheirScrims() {
        XCTAssertEqual(SetupAssistantM.scrimTall, 380)
        XCTAssertEqual(SetupAssistantM.scrimShort, 360)
        XCTAssertEqual(shell(.marks(lines: ["Apps", "Settings"], met: false)).scrimHeight,
                       SetupAssistantM.scrimTall)
        XCTAssertEqual(shell(.none).scrimHeight, SetupAssistantM.scrimTall)
        XCTAssertEqual(shell(.progress(text: "Installing", count: nil, fraction: 0.4)).scrimHeight,
                       SetupAssistantM.scrimShort)
    }

    // MARK: - Arrangements

    /// The shell defaults to the stack; centred and status are opt-in. The rail's active dot is wide, the rest short.
    func testTheArrangementDefaultsToTheStackAndTheRailKeepsItsNumbers() {
        XCTAssertEqual(shell(.none).arrangement, .stack)
        XCTAssertNil(shell(.none).dots?.count)
        XCTAssertEqual(SetupAssistantMetrics.dotsBottom,
                       SetupAssistantM.footerHeight + SetupAssistantM.footerClearance,
                       "the rail sits at the footer's own clearance — 'all rails aligned at the "
                       + "same bottom offset across screens'")
        XCTAssertEqual(SetupAssistantMetrics.dotActiveWidth, 22)
        XCTAssertEqual(SetupAssistantMetrics.dotWidth, 10)
        XCTAssertEqual(SetupAssistantMetrics.dotHeight, 4)
        // A column with a tile carries a 34pt title; one without either sits 10 lower.
        XCTAssertEqual(SetupAssistantMetrics.columnTopWithTile, 180)
        XCTAssertEqual(SetupAssistantMetrics.columnTop, 190)
        XCTAssertEqual(SetupAssistantMetrics.titleWithTile, 34)
        XCTAssertEqual(SetupAssistantMetrics.title, 32)
        // The status arrangement's pill and bar.
        XCTAssertEqual(SetupAssistantMetrics.statusTop, 52)
        XCTAssertEqual(SetupAssistantMetrics.columnTopStatus, 280)
        XCTAssertEqual(SetupAssistantMetrics.barWidth, 340)
    }

    // MARK: - Banded ground

    /// Only `banded` selects the brand-colour band; every other value, nil included, is the ramp.
    func testBandedIsTheOnlyWordThatSelectsTheBand() {
        XCTAssertEqual(SetupAssistantGroundStyle.resolve("banded"), .banded)
        XCTAssertEqual(SetupAssistantGroundStyle.resolve(" Banded "), .banded)
        XCTAssertEqual(SetupAssistantGroundStyle.resolve(nil), .ramp)
        // "plain" is the white minimal ground; gradient names still mean the ramp.
        XCTAssertEqual(SetupAssistantGroundStyle.resolve("plain"), .plain)
        XCTAssertEqual(SetupAssistantGroundStyle.resolve("gradient"), .ramp)
        XCTAssertEqual(SetupAssistantGroundStyle.resolve("ethereal"), .ramp)
    }

    /// The shell defaults to the ramp.
    func testTheShellDefaultsToTheRamp() {
        XCTAssertEqual(shell(.none).groundStyle, .ramp)
    }

    /// `banded` is in the schema's closed enum.
    func testBandedIsInTheSchemaEnum() throws {
        let source = try repoSource("dialog/Views/Inspect/inspect-config.schema.json")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(source.utf8)) as? [String: Any])
        let props = try XCTUnwrap(json["properties"] as? [String: Any])
        let phase = try XCTUnwrap(props["phaseBackground"] as? [String: Any])
        let values = try XCTUnwrap(phase["enum"] as? [String])
        XCTAssertTrue(values.contains("banded"), "phaseBackground enum: \(values)")
    }

    /// An authored 820 × 632 window is the frame the shell already draws (`recommended` + `windowChrome`).
    func testTheFrameIsAlreadyNsWindow() {
        XCTAssertEqual(SetupAssistantM.recommended.width, 820)
        XCTAssertEqual(SetupAssistantM.hostHeight, 632)
    }

    // MARK: - Shared with the provisioning shell

    /// The footer band is 84 and the door the shared 28 (`FooterBandM.primaryHeight`).
    func testTheFooterBandIsMsAndTheDoorIsTheRepos() {
        XCTAssertEqual(SetupAssistantM.footerHeight, 84)
        XCTAssertEqual(SetupAssistantM.footerDoorHeight, FooterBandM.primaryHeight)
    }

    /// The checklist row is `ProvisioningM`'s 52 (name, status word, chip), not the marks row's 28.
    func testTheChecklistRowIsMsRowNotTheMarksRow() {
        XCTAssertEqual(ProvisioningM.rowHeight, 52)
        XCTAssertEqual(SetupAssistantM.markRowHeight, 28)
    }

    /// A list capsule takes the tighter `marksPadV`.
    func testAListCapsuleTakesTheTighterPadding() {
        XCTAssertEqual(SetupAssistantM.marksPadV, 12)
        XCTAssertEqual(SetupAssistantM.capsulePadH, 20)
    }

    // MARK: - Cap, follow rule and total
    // The capsule grows upward from the footer, so the list caps at five rows, scrolls past that, holds
    // the active row in the middle, and moves the total into the footer. `JourneyScroll` is that arithmetic.

    private func rows(_ statuses: [StepStatus], names: [String]? = nil)
    -> [ProvisioningRowModel] {
        let ids = names ?? (0..<statuses.count).map { "app\($0)" }
        return ProvisioningRowBuilder.itemRows(
            items: ids.map { Item(id: $0, displayName: $0) },
            statuses: statuses,
            vocabulary: .packages)
    }

    /// The cap is five provisioning rows.
    func testTheCapIsFiveOfMsRows() {
        XCTAssertEqual(SetupAssistantM.journeyRowsVisible, 5)
        XCTAssertEqual(SetupAssistantM.journeyRowsHeight, 5 * ProvisioningM.rowHeight)
        XCTAssertEqual(SetupAssistantM.journeyRowsHeight, 260)
    }

    /// The active row is held in the middle (`.center`), so finished rows show above and upcoming below.
    func testAnActiveRowIsHeldInTheMiddle() {
        let list = rows([.completed, .completed, .active, .pending, .pending, .pending])
        XCTAssertEqual(JourneyScroll.target(rows: list),
                       JourneyScroll.Target(id: "app2", anchor: .center))
    }

    /// With two active rows the first wins, so the list only moves forward.
    func testTheFirstActiveRowWinsWhenTwoAreRunning() {
        let list = rows([.completed, .active, .active, .pending])
        XCTAssertEqual(JourneyScroll.target(rows: list)?.id, "app1")
    }

    /// Nothing active with work remaining: the list stays where it is.
    func testNothingActiveWithWorkRemainingDoesNotChase() {
        XCTAssertNil(JourneyScroll.target(rows: rows([.completed, .pending, .pending])))
        XCTAssertNil(JourneyScroll.target(rows: rows([.pending, .pending, .pending])))
        XCTAssertNil(JourneyScroll.target(rows: []))
    }

    /// When everything is terminal (failed included), the list shows its end.
    func testACompletedRunScrollsToItsOwnEnd() {
        XCTAssertEqual(JourneyScroll.target(rows: rows([.completed, .completed, .completed])),
                       JourneyScroll.Target(id: "app2", anchor: .bottom))
        XCTAssertEqual(JourneyScroll.target(rows: rows([.completed, .failed, .completed])),
                       JourneyScroll.Target(id: "app2", anchor: .bottom))
    }

    /// A skipped item is outstanding to both the counter and the scroll.
    func testASkippedItemIsOutstandingToTheCounterAndTheScrollAlike() {
        let list = rows([.completed, .completed, .skipped])
        XCTAssertEqual(list[2].trailing, .state("Queued", failed: false))
        XCTAssertNil(JourneyScroll.target(rows: list))
        XCTAssertEqual(JourneyScroll.progressLine(rows: list, noun: "installed"),
                       "2 of 3 installed")
    }

    /// The footer carries "N of M installed", M being the item count, never an authored count.
    func testTheFooterCarriesTheTotalWhileWorkRemains() {
        let list = rows(Array(repeating: StepStatus.completed, count: 7)
                        + [.active]
                        + Array(repeating: StepStatus.pending, count: 15))
        XCTAssertEqual(list.count, 23)
        XCTAssertEqual(JourneyScroll.progressLine(rows: list, noun: "installed"),
                       "7 of 23 installed")
    }

    /// A failed install still advances the counter.
    func testAFailedInstallAdvancesTheCounter() {
        XCTAssertEqual(JourneyScroll.progressLine(rows: rows([.completed, .failed, .pending]),
                                                  noun: "installed"),
                       "2 of 3 installed")
    }

    /// When nothing is left to report the line is nil, so the footer falls back to `footerNote`.
    func testTheLineRevertsToTheClaimWhenTheRunIsDone() {
        XCTAssertNil(JourneyScroll.progressLine(rows: rows([.completed, .completed]),
                                                noun: "installed"))
        XCTAssertNil(JourneyScroll.progressLine(rows: rows([.completed, .failed]),
                                                noun: "installed"))
        // An empty manifest reports on nothing rather than reading "0 of 0".
        XCTAssertNil(JourneyScroll.progressLine(rows: [], noun: "installed"))
        // The support line's address is found, not invented, and excludes the trailing full stop.
        XCTAssertEqual(SupportLineText.emails(in: "Setup installs required apps. • If it takes over 60 minutes, contact help@example.com."),
                       ["help@example.com"])
        XCTAssertEqual(SupportLineText.emails(in: "ask a@b.co or c.d@e.f.org today"),
                       ["a@b.co", "c.d@e.f.org"])
        XCTAssertTrue(SupportLineText.emails(in: "This runs in the background — nothing to do.").isEmpty,
                      "a line with no address is left alone")
        // `showProgressLine: false`: no line, so the footer falls through to `footerNote`.
        XCTAssertNil(JourneyScroll.progressLine(rows: rows([.completed, .pending]),
                                                noun: "installed", enabled: false),
                     "showProgressLine: false silences the footer count")
        XCTAssertEqual(JourneyScroll.progressLine(rows: rows([.completed, .pending]),
                                                  noun: "installed", enabled: true),
                       "1 of 2 installed", "the default stays today's line")
    }
}


// MARK: - One key, one behaviour

/// A key means the same thing on every surface it is authored on; where it must differ, the
/// difference is stated here.
final class PlacementDefaultsTests: XCTestCase {

    /// `bentoCells` has one geometry on a bento step, a `bento-grid` block and a summary screen:
    /// 2 columns, 140pt rows, a 12pt gap.
    func testTheBentoGridHasOneGeometryOnEverySurface() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
                                    as? [String: Any])
        var geometries: [[String: Double]] = []
        func walk(_ node: Any) {
            if let dict = node as? [String: Any] {
                if let props = dict["properties"] as? [String: Any],
                   let columns = (props["bentoColumns"] as? [String: Any])?["default"] as? Double {
                    geometries.append([
                        "columns": columns,
                        "rowHeight": ((props["bentoRowHeight"] as? [String: Any])?["default"] as? Double) ?? -1,
                        "gap": ((props["bentoGap"] as? [String: Any])?["default"] as? Double) ?? -1
                    ])
                }
                for value in dict.values { walk(value) }
            } else if let array = node as? [Any] {
                for value in array { walk(value) }
            }
        }
        walk(root)
        XCTAssertEqual(geometries.count, 3, "three types declare a bento geometry; found \(geometries.count)")
        for geometry in geometries {
            XCTAssertEqual(geometry["columns"], 2, "columns differ by placement again: \(geometries)")
            XCTAssertEqual(geometry["rowHeight"], 140, "row height differs by placement again: \(geometries)")
            XCTAssertEqual(geometry["gap"], 12, "gap differs by placement again: \(geometries)")
        }
    }

    /// Every `showBackButton` default sits beside `canGoBack`, so a first step never draws a dead back door.
    /// Walks the preset sources, since these are `@ViewBuilder` methods.
    func testEveryBackDoorAsksWhetherBackIsPossible() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Preset Layouts")
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty, "found no preset sources — the walk is broken, not the tree")

        var offenders: [String] = []
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() where line.contains("showBackButton ??") {
                // The guard may sit on this line or the one above when a long call wraps.
                let window = [index - 1, index].compactMap { $0 >= 0 ? lines[$0] : nil }.joined()
                if !window.contains("canGoBack") {
                    offenders.append("\(file.lastPathComponent):\(index + 1)  \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty,
                      "a `showBackButton` default with no `canGoBack` beside it draws a door that "
                      + "`goToPreviousStep` refuses to open on the first step:\n"
                      + offenders.joined(separator: "\n"))
    }

    /// `heroImageShape` offers the same four values on the step and both bookend screens.
    func testHeroImageShapeOffersTheSameValuesOnEverySurface() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
                                    as? [String: Any])
        var found: [[String]] = []
        func walk(_ node: Any) {
            if let dict = node as? [String: Any] {
                if let props = dict["properties"] as? [String: Any],
                   let hero = props["heroImageShape"] as? [String: Any],
                   let values = hero["enum"] as? [String] {
                    found.append(values)
                }
                for value in dict.values { walk(value) }
            } else if let array = node as? [Any] {
                for value in array { walk(value) }
            }
        }
        walk(root)
        XCTAssertEqual(found.count, 3, "three types declare heroImageShape; found \(found.count)")
        let expected = ["circle", "roundedSquare", "square", "none"]
        for values in found {
            XCTAssertEqual(values.sorted(), expected.sorted(),
                           "every declaration offers what IntroHeroImage renders. Found: \(values)")
        }
    }

    /// `heroImageShape` defaults to `"none"` in every schema declaration and every Swift fallback.
    func testHeroImageShapeDefaultsToNoneOnEverySurface() throws {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let schema = repo.appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: try Data(contentsOf: schema))
                                    as? [String: Any])
        var defaults: [String] = []
        func walk(_ node: Any) {
            if let dict = node as? [String: Any] {
                if let props = dict["properties"] as? [String: Any],
                   let hero = props["heroImageShape"] as? [String: Any] {
                    defaults.append(hero["default"] as? String ?? "<none declared>")
                }
                for value in dict.values { walk(value) }
            } else if let array = node as? [Any] {
                for value in array { walk(value) }
            }
        }
        walk(root)
        XCTAssertEqual(defaults.count, 3, "three types declare heroImageShape (the step, and the two bookend screens); found \(defaults.count)")
        XCTAssertEqual(Set(defaults), ["none"], "a surface brought its own default back: \(defaults)")

        // Every Swift fallback seat, found by walking the tree.
        let sources = repo.appendingPathComponent("dialog/Views/Inspect")
        let walker = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        var seats = 0
        var offenders: [String] = []
        for case let file as URL in walker where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for line in text.components(separatedBy: .newlines) where line.contains("heroImageShape ?? \"") {
                seats += 1
                if !line.contains("heroImageShape ?? \"none\"") {
                    offenders.append("\(file.lastPathComponent): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertGreaterThan(seats, 0, "found no fallback seats — the walk is broken, not the tree")
        XCTAssertTrue(offenders.isEmpty, "a hero fallback that is not \"none\":\n" + offenders.joined(separator: "\n"))
    }

    /// A present help button or step overlay is shown unless `enabled: false`; every seat reads `isShown`.
    func testAPresentHelpButtonOrOverlayIsShownUnlessDisabled() throws {
        func help(_ json: String) throws -> InspectConfig.HelpButtonConfig {
            try JSONDecoder().decode(InspectConfig.HelpButtonConfig.self, from: Data(json.utf8))
        }
        func overlay(_ json: String) throws -> InspectConfig.DetailOverlayConfig {
            try JSONDecoder().decode(InspectConfig.DetailOverlayConfig.self, from: Data(json.utf8))
        }
        XCTAssertTrue(try help("{}").isShown)
        XCTAssertFalse(try help(#"{"enabled": false}"#).isShown)
        XCTAssertTrue(try overlay("{}").isShown)
        XCTAssertFalse(try overlay(#"{"enabled": false}"#).isShown)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Preset Layouts")
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty, "found no preset sources — the walk is broken, not the tree")
        var offenders: [String] = []
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines)
            for (index, line) in lines.enumerated()
            where line.range(of: #"(helpButton\w*|stepOverlay|overlay\w*)\??\.enabled\b"#,
                             options: [.regularExpression, .caseInsensitive]) != nil {
                offenders.append("\(file.lastPathComponent):\(index + 1)  \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertTrue(offenders.isEmpty, "read `isShown`, not the raw key:\n" + offenders.joined(separator: "\n"))
    }

    /// The schema declares no single logo `maxHeight`, `maxWidth` or `padding` default: each seat sizes its own mark.
    func testLogoSizingDeclaresNoSingleDefault() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
                                    as? [String: Any])
        let definitions = try XCTUnwrap(root["definitions"] as? [String: Any])
        let logoConfig = try XCTUnwrap(definitions["LogoConfig"] as? [String: Any])
        let logo = try XCTUnwrap(logoConfig["properties"] as? [String: Any])
        for key in ["maxHeight", "maxWidth", "padding"] {
            let entry = try XCTUnwrap(logo[key] as? [String: Any], key)
            XCTAssertNil(entry["default"], "\(key) has no single default — each seat has its own")
            XCTAssertFalse((entry["description"] as? String ?? "").isEmpty, "\(key) must say what the seats do")
        }
    }

    /// The active section header drops a trailing "..." or "…" from `downloadingStatus`.
    func testTheActiveSectionHeaderDropsEitherEllipsis() {
        XCTAssertEqual(DeploymentItemList.activeSectionHeader(downloadingStatus: nil), "Currently Installing")
        XCTAssertEqual(DeploymentItemList.activeSectionHeader(downloadingStatus: "Installing..."), "Currently Installing")
        XCTAssertEqual(DeploymentItemList.activeSectionHeader(downloadingStatus: "Installing…"), "Currently Installing")
        XCTAssertEqual(DeploymentItemList.activeSectionHeader(downloadingStatus: "Installing"), "Currently Installing",
                       "what every corpus config authors")
    }

    /// `imageWidth` defaults to 400 for a picture and 128 for the device mark (`content: "computer"`).
    func testImageWidthIsFourHundredForAPictureAndOneTwentyEightForTheMark() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect")
        let walker = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        var pictures = 0
        var marks = 0
        var offenders: [String] = []
        for case let file as URL in walker where file.pathExtension == "swift" {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                guard let range = line.range(of: #"imageWidth(: CGFloat =| \?\?) *[0-9]+"#, options: .regularExpression)
                else { continue }
                let value = line[range].split(whereSeparator: { !$0.isNumber }).last.map(String.init) ?? ""
                // The branch this seat sits in: the nearest `if` above it.
                let branch = lines[max(0, index - 25)..<index].last { $0.contains("if ") } ?? ""
                let site = "\(file.lastPathComponent):\(index + 1)  \(line.trimmingCharacters(in: .whitespaces))"
                switch value {
                case "400": pictures += 1
                case "128" where branch.contains("\"computer\""): marks += 1
                default: offenders.append(site)
                }
            }
        }
        XCTAssertGreaterThanOrEqual(pictures, 4, "found \(pictures) picture seats — the walk is broken, not the tree")
        XCTAssertEqual(marks, 1, "the device mark is the one 128 seat")
        XCTAssertTrue(offenders.isEmpty, "an imageWidth default that is neither a picture (400) nor the "
                      + "device mark (128):\n" + offenders.joined(separator: "\n"))
    }

    /// The cadence poll defaults to the 0.6 s dwell, through `monitorRefreshInterval` when authored.
    func testTheCadencePollFallsBackThroughTheMonitorKeyToTheDwell() throws {
        func step(_ keys: String) throws -> InspectConfig.IntroStep {
            let json = "{\"id\": \"c\", \"title\": \"C\"\(keys)}"
            return try JSONDecoder().decode(InspectConfig.IntroStep.self, from: Data(json.utf8))
        }
        XCTAssertEqual(CadenceMonitorService.pollInterval(for: try step("")), 0.6,
                       "unauthored: the poll matches the default dwell")
        XCTAssertEqual(CadenceMonitorService.pollInterval(for: try step(", \"monitorRefreshInterval\": 2")), 2,
                       "the monitor key is the middle rung — one key, two clocks")
        XCTAssertEqual(CadenceMonitorService.pollInterval(
                           for: try step(", \"monitorRefreshInterval\": 2, \"cadenceInterval\": 0.25")), 0.25,
                       "an authored cadenceInterval wins over both")
    }
}
