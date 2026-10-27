//
//  CardChromeConfigTests.swift
//  dialogTests
//
//  Covers the card chrome vocabulary: chrome and construction gates, step arm routing, card
//  panel and brand-mark decoding, the plain-branded block allowlist, footer and band metrics,
//  cadence and auto-close rules, and the schema/source parity guards that keep them aligned.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog

final class CardChromeConfigTests: XCTestCase {

    private func decode(_ json: String) throws -> InspectConfig {
        try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
    }

    // MARK: - The accent ribbon

    /// The accent ribbon is opt-in (absent is off) and never drawn by a construction that owns
    /// its footer band.
    @MainActor func testTheAccentRibbonIsOptIn() throws {
        let bare = try decode(#"{"preset": "5"}"#)
        XCTAssertNil(bare.showAccentBorder, "absent stays absent through the decoder")
        XCTAssertFalse(bare.showAccentBorder ?? false, "absent resolves OFF — the default is false")

        let authored = try decode(#"{"preset": "5", "showAccentBorder": true}"#)
        XCTAssertEqual(authored.showAccentBorder, true, "the key still turns it on")

        for owning in [InspectSizes.Construction.card, .provisioning, .migration, .setupAssistant] {
            XCTAssertTrue(Preset5View.constructionOwnsItsFooter(owning),
                          "\(owning) draws its own footer band, so the ribbon stays away")
        }
        for free in [InspectSizes.Construction.plain, .splash] {
            XCTAssertFalse(Preset5View.constructionOwnsItsFooter(free),
                           "\(free) has no band of its own — an authored ribbon reaches it")
        }
    }

    // MARK: - The arm gate

    func testAssistantAndMediaAreCardEligible() throws {
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [
            {"id": "a", "title": "T", "stepType": "assistant"},
            {"id": "m", "title": "T", "stepType": "media"}
        ]}
        """#)
        for step in config.introSteps ?? [] {
            XCTAssertTrue(Preset5View.cardEligible(step, construction: config.construction),
                          "\(step.id) should render through the card chrome")
        }
    }

    /// Payload beats stepType: the prose arm would drop the picker.
    func testWallpaperAssistantStepsRouteToTheWallpaperArm() throws {
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [{
            "id": "wallpaper-select", "title": "T", "stepType": "assistant",
            "wallpaper": {"categories": [{"title": "Seasonal", "images": []}], "layout": "categories"}
        }]}
        """#)
        let step = try XCTUnwrap(config.introSteps?.first)
        // canonicalizeStep consumes the grouped container, so routing reads the flat key.
        XCTAssertNil(step.wallpaper, "the grouped container is consumed at decode")
        XCTAssertNotNil(step.wallpaperCategories,
                        "the payload survives on the CANONICAL flat key")
        XCTAssertTrue(Preset5View.cardEligible(step, construction: config.construction))
        XCTAssertEqual(Preset5View.cardArm(for: step), .chooserWallpaper,
                       "payload beats stepType — the prose arm would drop the picker")
    }

    /// Every chooser class has a card arm; no legacy fallthrough is left.
    func testChooserRoutingCoversEveryChooserClass() throws {
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [
            {"id": "o", "title": "T", "stepType": "options"},
            {"id": "w", "title": "T", "stepType": "wallpaper"},
            {"id": "b", "title": "T", "stepType": "brandPicker"},
            {"id": "d", "title": "T", "stepType": "dock"},
            {"id": "s", "title": "T", "stepType": "substeps"}
        ]}
        """#)
        let steps = try XCTUnwrap(config.introSteps)
        XCTAssertEqual(Preset5View.cardArm(for: steps[0]), .chooserOptions)
        XCTAssertEqual(Preset5View.cardArm(for: steps[1]), .chooserWallpaper)
        XCTAssertEqual(Preset5View.cardArm(for: steps[2]), .chooserBrands)
        XCTAssertEqual(Preset5View.cardArm(for: steps[3]), .chooserDock)
        XCTAssertEqual(Preset5View.cardArm(for: steps[4]), .substepsWizard)
        for step in steps {
            XCTAssertTrue(Preset5View.cardEligible(step, construction: config.construction),
                          "\(step.id): every chooser class now renders through the card")
        }
    }

    // MARK: - The standard step type

    /// `standard` is what resolvedStepType fills in for a step that names no type.
    func testStandardIsCardEligible() throws {
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [
            {"id": "plain", "title": "T"},
            {"id": "named", "title": "T", "stepType": "standard"}
        ]}
        """#)
        for step in config.introSteps ?? [] {
            XCTAssertEqual(step.resolvedStepType, "standard",
                           "\(step.id): canonicalization fills the renderer axis")
            XCTAssertTrue(Preset5View.cardEligible(step, construction: config.construction),
                          "\(step.id) should render through the card chrome")
        }
    }

    /// Phase decides the arm: a standard closer on the prose arm would lose badge and receipt.
    func testStandardRoutesByPhaseNotByName() throws {
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [
            {"id": "open", "title": "T", "stepType": "standard"},
            {"id": "close", "title": "T", "stepType": "standard", "phase": "outro"}
        ]}
        """#)
        let steps = try XCTUnwrap(config.introSteps)
        XCTAssertEqual(Preset5View.cardArm(for: steps[0]), .prose)
        XCTAssertEqual(Preset5View.cardArm(for: steps[1]), .outro,
                       "a standard step in the outro phase is a closer")
    }

    func testStandardWithAPickerPayloadStillRoutesToTheChooser() throws {
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [{
            "id": "pick", "title": "T", "stepType": "standard",
            "optionCards": [{"id": "a", "label": "A"}]
        }]}
        """#)
        let step = try XCTUnwrap(config.introSteps?.first)
        XCTAssertEqual(Preset5View.cardArm(for: step), .chooserOptions)
    }

    /// A preset-5 flow declines the card by naming another construction, not by staying silent.
    func testStandardWithoutChromeTakesThePresetDefaultCard() throws {
        let defaulted = try decode(#"""
        {"preset": "5", "introSteps": [{"id": "plain", "title": "T"}]}
        """#)
        let step = try XCTUnwrap(defaulted.introSteps?.first)
        XCTAssertTrue(Preset5View.cardEligible(step, construction: defaulted.construction),
                      "preset 5's default construction is the card")

        let optedOut = try decode(#"""
        {"preset": "5", "chrome": "plain", "introSteps": [{"id": "plain", "title": "T"}]}
        """#)
        let outStep = try XCTUnwrap(optedOut.introSteps?.first)
        XCTAssertFalse(Preset5View.cardEligible(outStep, construction: optedOut.construction),
                       "`chrome: \"plain\"` is the authored way off the card")
    }

    func testAnEngineWithoutTheCardAdapterIsNeverCardEligible() throws {
        for json in [#"{"preset": "1", "introSteps": [{"id": "a", "title": "T", "stepType": "assistant"}]}"#,
                     #"{"preset": "1", "chrome": "card", "introSteps": [{"id": "a", "title": "T", "stepType": "assistant"}]}"#] {
            let config = try decode(json)
            let step = try XCTUnwrap(config.introSteps?.first)
            XCTAssertFalse(Preset5View.cardEligible(step, construction: config.construction),
                           "preset 1 has no card adapter; the registry refuses it")
        }
    }

    func testScreensIsTheCanonicalKey() throws {
        InspectConfig.unknownKeyWarnings = []
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [{
            "id": "paged", "title": "Paged", "stepType": "guide",
            "screens": [{"id": "one", "title": "First"}, {"id": "two", "title": "Second"}]
        }]}
        """#)
        let step = try XCTUnwrap(config.introSteps?.first)
        XCTAssertEqual(step.screens?.count, 2)
        XCTAssertEqual(step.screens?[1].title, "Second")
        XCTAssertEqual(InspectConfig.unknownKeyWarnings.filter { $0.contains("screens") }, [],
                       "screens must be in knownStepKeys or every load logs a false warning")
    }

    /// Bands group in first-seen order; uncategorized cards form a header-less last band.
    func testOptionCardCategoryDecodesAndBandsPreserveOrder() throws {
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [{
            "id": "pick", "title": "T", "stepType": "options", "optionLayout": "grid",
            "optionCards": [
                {"id": "a", "label": "A", "sfSymbol": "sparkles", "category": "Wizards"},
                {"id": "b", "label": "B", "sfSymbol": "checklist", "category": "Checklists"},
                {"id": "c", "label": "C", "sfSymbol": "bag", "category": "Wizards"},
                {"id": "d", "label": "D", "sfSymbol": "gear"}
            ]
        }]}
        """#)
        let cards = try XCTUnwrap(config.introSteps?.first?.optionCards)
        XCTAssertEqual(cards[0].category, "Wizards")
        let bands = DecisionCard.categoryBands(cards)
        XCTAssertEqual(bands.map(\.title), ["Wizards", "Checklists", ""],
                       "first-seen order, uncategorized last as a header-less band")
        XCTAssertEqual(bands[0].cards.map(\.cardId), ["a", "c"])
        XCTAssertEqual(bands[2].cards.map(\.cardId), ["d"])
    }

    func testMediaViewerVocabularyDecodes() throws {
        InspectConfig.unknownKeyWarnings = []
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [{
            "id": "tour", "title": "Your new Mac", "stepType": "media",
            "media": {"layout": "viewer", "items": [
                {"url": "/tmp/front.png", "title": "MacBook Pro 14-inch, M4 Pro",
                 "caption": "Silver, 24 GB memory, 512 GB storage."},
                {"url": "/tmp/ports.png", "title": "Ports, right side"}
            ]}
        }]}
        """#)
        let step = try XCTUnwrap(config.introSteps?.first)
        XCTAssertEqual(step.mediaLayout, "viewer", "grouped media.layout folds onto the flat key")
        XCTAssertEqual(step.mediaItems?.count, 2)
        XCTAssertEqual(step.mediaItems?.first?.caption, "Silver, 24 GB memory, 512 GB storage.")
        XCTAssertEqual(InspectConfig.unknownKeyWarnings.filter { $0.contains("mediaLayout") }, [])
    }

    // MARK: - Export

    func testExportPayloadDecodesRoutesAndIsRegistered() throws {
        InspectConfig.unknownKeyWarnings = []
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [{
            "id": "take-away", "title": "Create these files and open them", "stepType": "export",
            "export": {
                "items": [{"source": "/tmp/demo.json"}, {"source": "~/assets", "note": "6 icons"}],
                "destination": "~/Documents/Showmaster/demo",
                "editors": ["com.microsoft.VSCode", "com.barebones.bbedit"]
            }
        }]}
        """#)
        let step = try XCTUnwrap(config.introSteps?.first)
        let payload = try XCTUnwrap(step.export, "single-spelling family: the container survives decode")
        XCTAssertEqual(payload.items?.count, 2)
        XCTAssertEqual(payload.editors?.first, "com.microsoft.VSCode")
        XCTAssertEqual(Preset5View.cardArm(for: step), .export)
        XCTAssertTrue(Preset5View.cardEligible(step, construction: config.construction))
        XCTAssertEqual(InspectConfig.unknownKeyWarnings.filter { $0.contains("export") }, [],
                       "export must be in knownStepKeys or every load logs a false warning")
    }

    /// performExport creates the destination, replaces same-named files and skips missing sources.
    func testPerformExportWritesReplacesAndSkips() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("export-test-\(UUID().uuidString)")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let src = base.appendingPathComponent("demo.json")
        try Data("{\"a\":1}".utf8).write(to: src)
        let dest = base.appendingPathComponent("out").path
        let items = [InspectConfig.IntroStep.ExportItem(source: src.path, name: nil, note: nil),
                     InspectConfig.IntroStep.ExportItem(source: base.appendingPathComponent("missing.txt").path,
                                                        name: nil, note: nil)]
        let destDir = try CardExportEngine.performExport(items: items, destination: dest)
        let written = destDir.appendingPathComponent("demo.json")
        XCTAssertEqual(try String(contentsOf: written, encoding: .utf8), "{\"a\":1}")
        XCTAssertFalse(fm.fileExists(atPath: destDir.appendingPathComponent("missing.txt").path),
                       "a missing source is skipped, never invented")
        try Data("{\"a\":2}".utf8).write(to: src)
        _ = try CardExportEngine.performExport(items: items, destination: dest)
        XCTAssertEqual(try String(contentsOf: written, encoding: .utf8), "{\"a\":2}")
    }

    func testChromeFlagDecodes() throws {
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [{"id": "s1", "title": "T"}]}
        """#)
        XCTAssertEqual(config.chrome, "card")
    }

    /// A directory source is copied whole and measured recursively (a flat folder would pass a
    /// shallow sum too).
    func testPerformExportCopiesADirectoryWholeAndMeasuresItRecursively() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("export-dir-\(UUID().uuidString)")
        let nested = base.appendingPathComponent("kit/vector")
        try fm.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        try Data(repeating: 0x41, count: 100).write(to: base.appendingPathComponent("kit/a.png"))
        try Data(repeating: 0x42, count: 50).write(to: nested.appendingPathComponent("b.svg"))

        let kit = InspectConfig.IntroStep.ExportItem(
            source: base.appendingPathComponent("kit").path, name: nil, note: nil)

        let m = CardExportEngine.measure(kit)
        XCTAssertEqual(m.size, 150, "a directory is summed recursively, subfolders included")
        XCTAssertEqual(m.name, "kit/", "a directory states that it is one")

        let dest = base.appendingPathComponent("out").path
        let out = try CardExportEngine.performExport(items: [kit], destination: dest)
        XCTAssertEqual(try String(contentsOf: out.appendingPathComponent("kit/a.png"), encoding: .utf8),
                       String(repeating: "A", count: 100))
        XCTAssertTrue(fm.fileExists(atPath: out.appendingPathComponent("kit/vector/b.svg").path),
                      "the nested file survives the copy")
    }

    // MARK: - Where the step counter sits (card chrome)

    /// stepCounterPlacement moves the counter; it never duplicates it. Default is header.
    func testStepCounterPlacementDefaultsToHeader() {
        XCTAssertEqual(CardStepCounterPlacement(nil), .header)
        XCTAssertEqual(CardStepCounterPlacement("header"), .header)
    }

    func testStepCounterPlacementReadsFooter() {
        XCTAssertEqual(CardStepCounterPlacement("footer"), .footer)
        XCTAssertEqual(CardStepCounterPlacement("Footer"), .footer, "case cannot matter")
    }

    func testStepCounterPlacementFailsClosedToHeader() {
        XCTAssertEqual(CardStepCounterPlacement("bottomLeft"), .header)
        XCTAssertEqual(CardStepCounterPlacement(""), .header)
    }

    func testStepCounterPlacementDecodesAndIsAKnownRootKey() throws {
        InspectConfig.unknownKeyWarnings = []
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "stepCounterPlacement": "footer",
         "introSteps": [{"id": "a", "title": "T"}]}
        """#)
        XCTAssertEqual(config.stepCounterPlacement, "footer")
        XCTAssertEqual(InspectConfig.unknownKeyWarnings.filter { $0.contains("stepCounterPlacement") }, [],
                       "a new root key must be registered or every load logs a false warning")
    }

    // MARK: - Export: the shared name column

    private func exportItem(_ name: String) -> CardExportEngine.MeasuredItem {
        CardExportEngine.MeasuredItem(name: name, note: nil, size: 0)
    }

    /// Rows are independent HStacks, so the name column is derived from the widest filename
    /// (monospaced font metrics) rather than negotiated per row.
    func testNameColumnWidthComesFromTheWidestName() {
        let narrow = CardExportEngine.nameColumnWidth([exportItem("a.png"), exportItem("b.png")])
        let wide = CardExportEngine.nameColumnWidth([exportItem("a.png"),
                                                     exportItem("fleet-logo-white-rgb.png")])
        XCTAssertGreaterThan(wide, narrow, "the widest name sets the column for every row")
    }

    func testNameColumnWidthIsIndependentOfOrder() {
        let a = CardExportEngine.nameColumnWidth([exportItem("short.svg"),
                                                  exportItem("fleet-logo-white-rgb.png")])
        let b = CardExportEngine.nameColumnWidth([exportItem("fleet-logo-white-rgb.png"),
                                                  exportItem("short.svg")])
        XCTAssertEqual(a, b, accuracy: 0.01)
    }

    func testNameColumnWidthIsZeroWithoutItems() {
        XCTAssertEqual(CardExportEngine.nameColumnWidth([]), 0)
    }

    /// The cap keeps a long filename from pushing the note and size columns off the card.
    func testNameColumnWidthIsCapped() {
        let huge = [exportItem(String(repeating: "x", count: 400))]
        XCTAssertEqual(CardExportEngine.nameColumnWidth(huge, limit: 240), 240, accuracy: 0.01)
    }

    func testNameColumnWidthUnderTheCapIsTheContentWidth() {
        let w = CardExportEngine.nameColumnWidth([exportItem("a.png")], limit: 240)
        XCTAssertGreaterThan(w, 0)
        XCTAssertLessThan(w, 240)
    }

    func testChromeAbsentIsNil() throws {
        let config = try decode(#"""
        {"preset": "5", "introSteps": [{"id": "s1", "title": "T"}]}
        """#)
        XCTAssertNil(config.chrome)
    }

    func testCardPanelFactsShapeDecodes() throws {
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [{
            "id": "s1", "title": "T",
            "cardPanel": {
                "caption": "TAKES ABOUT", "stat": "2 minutes",
                "pairs": [{"label": "Deadline set by IT", "value": "Mar 15, 2026"}]
            },
            "footerNote": "Something looks wrong? [Contact IT](https://example.com)"
        }]}
        """#)
        let step = try XCTUnwrap(config.introSteps?.first)
        let panel = try XCTUnwrap(step.cardPanel)
        XCTAssertEqual(panel.caption, "TAKES ABOUT")
        XCTAssertEqual(panel.stat, "2 minutes")
        XCTAssertEqual(panel.pairs?.first?.label, "Deadline set by IT")
        XCTAssertNil(panel.image)
        XCTAssertEqual(step.footerNote?.isEmpty, false)
    }

    func testItemConfigCardKeysDecode() throws {
        let config = try decode(#"""
        {"preset": "6", "chrome": "card", "items": [{
            "id": "complete", "displayName": "Complete", "stepType": "outro",
            "cardPanel": {"caption": "FINISHED IN", "stat": "2 minutes"},
            "footerNote": "Something wrong? [Contact IT](https://example.com)"
        }]}
        """#)
        let item = try XCTUnwrap(config.items.first)
        XCTAssertEqual(item.cardPanel?.stat, "2 minutes")
        XCTAssertEqual(item.footerNote?.isEmpty, false)
    }

    func testCardPanelScreenshotAndReassuranceShapes() throws {
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [
            {"id": "s2", "title": "T",
             "cardPanel": {"image": "/tmp/shot.png", "video": "/tmp/clip.mp4", "imageTitle": "Privacy & Security"}},
            {"id": "s3", "title": "T",
             "cardPanel": {"caption": "SAFE TO DO RIGHT NOW", "paragraphs": ["Keep using your Mac.", "Avoid sleeping it."]}}
        ]}
        """#)
        XCTAssertEqual(config.introSteps?[0].cardPanel?.imageTitle, "Privacy & Security")
        XCTAssertEqual(config.introSteps?[0].cardPanel?.video, "/tmp/clip.mp4")
        XCTAssertEqual(config.introSteps?[1].cardPanel?.paragraphs?.count, 2)
    }

    /// Item-level guidanceContent is canonicalized like step content.
    func testItemGuidanceContentIsCanonicalizedLikeStepContent() throws {
        let config = try decode(#"""
        {"preset":"6","title":"t","items":[{"id":"i1","displayName":"I1",
          "guidanceContent":[{"type":"comparison-table","expected":"1","actual":"2"}]}]}
        """#)
        let block = try XCTUnwrap(config.items.first?.guidanceContent?.first)
        XCTAssertNotNil(block.checks,
                        "item-level comparison-table did not fold its singular spelling into checks")
    }

    /// The plain-branded allowlist advises, it never filters: every authored block survives
    /// decode, and a type outside the vocabulary gets a named advisory in unknownKeyWarnings.
    func testPlainBrandedKeepsEveryBlockAndAdvisesTheOnesOutsideItsVocabulary() throws {
        InspectConfig.unknownKeyWarnings = []
        let config = try decode(#"""
        {"preset":"1","chrome":"plain-branded","title":"t","guidanceContent":[
          {"type":"text","content":"kept"},
          {"type":"bullets","items":["a","b"]},
          {"type":"info","content":"chip form, kept"},
          {"type":"image","content":"SF=photo"},
          {"type":"image-carousel","images":["a.png","b.png"]},
          {"type":"button","content":"Continue"},
          {"type":"stepper","content":"Count","value":"1"},
          {"type":"compliance-header","label":"Baseline","passed":5,"total":7},
          {"type":"findings-list"}
        ]}
        """#)
        let warnings = InspectConfig.unknownKeyWarnings
        InspectConfig.unknownKeyWarnings = []

        let kept = try XCTUnwrap(config.guidanceContent)
        XCTAssertEqual(kept.map(\.type),
                        ["text", "bullets", "info", "image", "image-carousel", "button", "stepper",
                         "compliance-header", "findings-list"],
                        "every authored block must survive — the allowlist advises, it does not filter")

        XCTAssertEqual(warnings.filter { $0.contains("guidanceContent[7]") }.count, 1,
                       "'compliance-header' is outside the vocabulary and must still be advised")
        XCTAssertEqual(warnings.filter { $0.contains("guidanceContent[8]") }.count, 1,
                       "'findings-list' is outside the vocabulary and must still be advised")
        XCTAssertTrue(warnings.allSatisfy { $0.contains("RENDERED ANYWAY") },
                      "the advisory must tell the author the block is drawn, not removed — "
                      + "an advisory that reads as a removal is the old behaviour in words")
        XCTAssertTrue(warnings.allSatisfy { $0.contains("plain-branded") },
                     "the advisory must name the construction, not just read as an unknown key")
    }

    /// The admitted content families, as one fixture so a narrowing of the allowlist is visible.
    /// warning and success carry a semantic hue, not the accent, so they stay admitted.
    func testPlainBrandedAdmitsTheCatalogueCalloutListAndTableFamilies() throws {
        InspectConfig.unknownKeyWarnings = []
        let config = try decode(#"""
        {"preset":"1","chrome":"plain-branded","title":"t","guidanceContent":[
          {"type":"highlight","content":"a lede"},
          {"type":"explainer","label":"Why","content":"reasoning"},
          {"type":"warning","title":"Your Mac will restart","content":"once configuration completes"},
          {"type":"success","content":"disk encryption is on"},
          {"type":"status-badge","label":"Management agent","state":"success","actual":"Running"},
          {"type":"advisory","state":"warning","label":"Two things to fix",
           "findings":[{"state":"error","title":"macOS is behind"}]},
          {"type":"checklist","checklist":[{"text":"Open System Settings"}]},
          {"type":"install-list","installItems":[{"title":"Company VPN","status":"pending"}]},
          {"type":"handoff-list","handoffs":[{"id":"ss","title":"Self Service","detail":"browse"}]},
          {"type":"label-value","label":"Serial number","value":"C02XX0000XY"},
          {"type":"label-value","content":"Status: OK","style":"success"},
          {"type":"stat-row","stats":[{"value":"7","label":"checks run"}]},
          {"type":"comparison-table","checks":[{"check":"FileVault","required":"On","found":"On"}]},
          {"type":"feature-table","columns":[{"label":"Compatible"}],
           "rows":[{"feature":"Safari","values":[true]}]},
          {"type":"compliance-card","categoryName":"OS Security","passed":3,"total":4}
        ]}
        """#)
        let warnings = InspectConfig.unknownKeyWarnings
        InspectConfig.unknownKeyWarnings = []

        let kept = try XCTUnwrap(config.guidanceContent)
        XCTAssertEqual(kept.map(\.type), [
            "highlight", "explainer", "warning", "success", "status-badge", "advisory",
            "checklist", "install-list", "handoff-list", "label-value", "label-value",
            "stat-row", "comparison-table", "feature-table", "compliance-card"
        ], "every admitted family type must survive plain-branded's filter — each was captured at 500pt")

        XCTAssertTrue(warnings.filter { $0.contains("guidanceContent") }.isEmpty,
                      "an admitted type must not also produce a dropped-block advisory: \(warnings)")
    }

    /// The three status blocks outside the vocabulary: compliance-header draws a second, larger
    /// header pair under the shell's own; compliance-summary and findings-list are unjudged at
    /// the 500pt column. None is a width failure.
    func testPlainBrandedAdvisesTheThreeStatusBlocksButStillRendersThem() throws {
        for (type, why) in [
            ("compliance-header", "it draws a second, larger header pair below the shell's own"),
            ("compliance-summary", "it is outside the vocabulary judged at the 500pt column"),
            ("findings-list", "it is outside the vocabulary judged at the 500pt column")
        ] {
            InspectConfig.unknownKeyWarnings = []
            let json = """
            {"preset":"1","chrome":"plain-branded","title":"t","guidanceContent":[
              {"type":"\(type)","label":"L","passed":5,"total":7}
            ]}
            """
            let config = try decode(json)
            let warnings = InspectConfig.unknownKeyWarnings
            InspectConfig.unknownKeyWarnings = []

            XCTAssertEqual(config.guidanceContent?.count, 1,
                           "'\(type)' must still RENDER — \(why) is a note to the author, not a veto")
            XCTAssertEqual(warnings.filter { $0.contains("guidanceContent[0]") }.count, 1,
                           "'\(type)' must carry exactly one named advisory, never silence")
            XCTAssertTrue(warnings.contains { $0.contains(type) },
                          "the advisory must name the type it is about")
        }
    }

    /// The admitted interactive families. Four captions are authored as `label` on purpose: the
    /// label-to-content fold must fire, or the control floats beside an empty label column.
    func testPlainBrandedAdmitsTheCatalogueInteractiveFamilies() throws {
        InspectConfig.unknownKeyWarnings = []
        let config = try decode(#"""
        {"preset":"1","chrome":"plain-branded","title":"t","guidanceContent":[
          {"type":"form-section","sectionLabel":"Assignment","note":"everything here is optional"},
          {"type":"textfield","id":"fullname","content":"Assigned to","placeholder":"Ada Lovelace"},
          {"type":"dropdown","id":"site","content":"Office","options":["Berlin","Munich","Remote"]},
          {"type":"radio","id":"shift","content":"Working pattern","options":["Office","Hybrid"]},
          {"type":"checkbox","id":"analytics","content":"Share diagnostics with IT"},
          {"type":"slider","id":"lock","label":"Lock screen after","min":1,"max":20,"value":"5"},
          {"type":"toggle","id":"allusers","content":"Install for every account","value":"true"},
          {"type":"segmented","id":"mode","label":"Management mode","options":["Standard","Managed"]},
          {"type":"search","id":"appsearch","label":"Find an app","placeholder":"Search"},
          {"type":"multi-select","id":"bundles","label":"App bundles","options":["Design","Legal"]},
          {"type":"grid-picker","gridSelectionKey":"desk","gridColumns":3,
           "gridItems":[{"id":"laptop","sfSymbol":"laptopcomputer","title":"Laptop only"}]},
          {"type":"slot-picker","id":"slot","deadline":"2026-09-04T18:00:00Z","windowHours":96},
          {"type":"select-list","id":"apps","options":["Google Chrome","Slack"],
           "optionDetails":["Recommended · 210 MB","Recommended · 180 MB"],"value":"Google Chrome"},
          {"type":"select-grid","id":"kit","options":["Magic Trackpad","Magic Keyboard"],
           "optionIcons":["SF=rectangle","SF=keyboard"],"value":"Magic Trackpad"},
          {"type":"portal-webview","portalURL":"https://sofa.macadmins.io"},
          {"type":"webcontent","content":"https://fleetdm.com/docs"},
          {"type":"action-rows","id":"permissions","options":["Zoom","Microsoft Teams"],
           "optionDetails":["Granted in Screen Recording","Not granted yet"],
           "optionActions":["","settings"]},
          {"type":"identity","label":"Alex Morgan","note":"alex.morgan@example.com"},
          {"type":"signature-preview","label":"Alex Morgan","content":"Platform Engineer"}
        ]}
        """#)
        let warnings = InspectConfig.unknownKeyWarnings
        InspectConfig.unknownKeyWarnings = []

        let kept = try XCTUnwrap(config.guidanceContent)
        XCTAssertEqual(kept.map(\.type), [
            "form-section", "textfield", "dropdown", "radio", "checkbox", "slider", "toggle",
            "segmented", "search", "multi-select", "grid-picker", "slot-picker",
            "select-list", "select-grid", "portal-webview", "webcontent", "action-rows",
            "identity", "signature-preview"
        ], "every admitted interactive type must survive — each was captured at 500pt")

        // Matched on the message, not the channel: the label fold also writes to unknownKeyWarnings.
        XCTAssertTrue(warnings.filter { $0.contains("RENDERED ANYWAY") }.isEmpty,
                      "an admitted type must not also produce an out-of-vocabulary advisory: \(warnings)")
        XCTAssertFalse(warnings.filter { $0.contains("is an alias of 'content' — folded") }.isEmpty,
                       "the fixture authors `label` on four of these types, so the fold must fire — "
                       + "if this goes silent the alias has stopped being honoured")
    }

    /// option-picker and dock-picker draw their selection in highlightColor, the action pill's
    /// own colour, so they are advised (not width failures) and the advisory must say why.
    func testPlainBrandedAdvisesTheTwoChoosersThatDrawInThePillsColour() throws {
        for type in ["option-picker", "dock-picker"] {
            InspectConfig.unknownKeyWarnings = []
            let json = """
            {"preset":"1","chrome":"plain-branded","title":"t","guidanceContent":[
              {"type":"\(type)","optionKey":"browser","dockSelectionKey":"dock",
               "optionCards":[{"id":"safari","label":"Safari"}],
               "dockFlavors":[{"id":"essentials","name":"Essentials",
                               "items":[{"label":"Slack","path":"/Applications/Slack.app"}]}]}
            ]}
            """
            let config = try decode(json)
            let warnings = InspectConfig.unknownKeyWarnings
            InspectConfig.unknownKeyWarnings = []

            XCTAssertEqual(config.guidanceContent?.count, 1,
                           "'\(type)' must still RENDER — the allowlist advises, it never filters")
            XCTAssertEqual(warnings.filter { $0.contains("guidanceContent[0]") }.count, 1,
                           "'\(type)' must carry exactly one named advisory, never silence")
            XCTAssertTrue(warnings.contains { $0.contains(type) },
                          "the advisory must name the type it is about")
            XCTAssertTrue(warnings.contains { $0.contains("highlightColor") },
                          "'\(type)' is not a width failure — the advisory must say WHY, or the "
                          + "next author restores it by symmetry with grid-picker: \(warnings)")
        }
    }

    /// writeItemPresetResultFile publishes both guidanceFormInputs and userValues; a secure
    /// textfield's value never reaches the file.
    @MainActor
    func testItemPresetResultFilePublishesGuidanceFormValuesButNeverSecureOnes() throws {
        let path = NSTemporaryDirectory() + "plain-branded-result-\(UUID().uuidString).json"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let state = InspectState()
        state.config = try decode("""
        {"preset":"1","chrome":"plain-branded","title":"t","resultFile":"\(path)",
         "guidanceContent":[
           {"type":"textfield","id":"fullname","content":"Assigned to"},
           {"type":"textfield","id":"unlockcode","content":"Unlock code","secure":true}
         ]}
        """)
        state.userValues["browser"] = "safari"
        var form = GuidanceFormInputState()
        form.textfields["fullname"] = "Alex Morgan"
        form.textfields["unlockcode"] = "hunter2-must-not-be-written"
        form.checkboxes["analytics"] = true
        state.guidanceFormInputs["plain-branded-guidance"] = form

        writeItemPresetResultFile(state: state, exitCode: 0)

        let raw = try Data(contentsOf: URL(fileURLWithPath: path))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: raw) as? [String: Any])
        let values = try XCTUnwrap(json["formValues"] as? [String: Any])

        XCTAssertEqual(values["plain-branded-guidance.fullname"] as? String, "Alex Morgan",
                       "a textfield answered in the plain-branded column must reach the result file")
        XCTAssertEqual(values["plain-branded-guidance.analytics"] as? String, "true",
                       "a checkbox answered in the plain-branded column must reach the result file")
        XCTAssertEqual(values["browser"] as? String, "safari",
                       "the picker store this writer already published must keep working")
        XCTAssertNil(values["plain-branded-guidance.unlockcode"],
                     "a secure textfield's value must never be written to disk")
        XCTAssertFalse(try XCTUnwrap(String(bytes: raw, encoding: .utf8)).contains("hunter2"),
                       "the secure value must be absent from the FILE, not merely from one key")
    }

    /// Each item is a result entry of type "item": completed/success, completed/failure with its
    /// reason, or pending.
    @MainActor
    func testItemPresetResultFileReportsEachItemAsAnEntry() throws {
        let path = NSTemporaryDirectory() + "item-preset-result-\(UUID().uuidString).json"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let state = InspectState()
        let config = try decode("""
        {"preset":"1","title":"t","resultFile":"\(path)","items":[
          {"id":"a","displayName":"A","guiIndex":0,"paths":["/nonexistent/a"]},
          {"id":"b","displayName":"B","guiIndex":1,"paths":["/nonexistent/b"]},
          {"id":"c","displayName":"C","guiIndex":2,"paths":["/nonexistent/c"]}
        ]}
        """)
        state.config = config
        state.items = config.items
        state.completedItems = ["a"]
        state.failedItems = ["c"]
        state.logMonitorStatuses["c"] = "Not detected"

        writeItemPresetResultFile(state: state, exitCode: 0)

        let raw = try Data(contentsOf: URL(fileURLWithPath: path))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: raw) as? [String: Any])
        let entries = try XCTUnwrap(json["steps"] as? [[String: Any]])
        let byId = Dictionary(uniqueKeysWithValues: entries.map { ($0["id"] as? String ?? "", $0) })

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(json["totalSteps"] as? Int, 3)
        XCTAssertEqual(byId["a"]?["stepType"] as? String, "item")
        XCTAssertEqual(byId["a"]?["status"] as? String, "completed")
        XCTAssertEqual(byId["a"]?["result"] as? String, "success")
        XCTAssertEqual(byId["b"]?["status"] as? String, "pending")
        XCTAssertEqual(byId["c"]?["status"] as? String, "completed")
        XCTAssertEqual(byId["c"]?["result"] as? String, "failure")
        XCTAssertEqual(byId["c"]?["failureReason"] as? String, "Not detected")
    }

    /// plainBrandedPermits routes `info` through its resolved form and every other type through
    /// this set; a type absent from it is advised and still rendered.
    func testPlainBrandedAllowlistHoldsTheAdmittedTypesAndNotTheRejectedOnes() {
        let list = InspectConfig.plainBrandedAllowedBlockTypes
        for admitted in ["text", "paragraph", "bullets", "image", "image-carousel", "button",
                         "stepper", "status-badge", "advisory", "warning", "success", "highlight",
                         "explainer", "checklist", "install-list", "handoff-list", "label-value",
                         "stat-row", "comparison-table", "feature-table", "compliance-card",
                         "form-section", "textfield", "dropdown", "radio", "checkbox", "slider",
                         "toggle", "segmented", "search", "multi-select", "grid-picker",
                         "slot-picker", "select-list", "select-grid", "portal-webview",
                         "webcontent", "action-rows", "identity", "signature-preview"] {
            XCTAssertTrue(list.contains(admitted), "'\(admitted)' must be on plain-branded's allowlist")
        }
        for rejected in ["compliance-header", "compliance-summary", "findings-list",
                         // both draw their selection in the action pill's colour
                         "option-picker", "dock-picker",
                         // hero/summary arms unjudged; the grid arm breaks the void rule and drops actionLabel
                         "bento-grid"] {
            XCTAssertFalse(list.contains(rejected),
                           "'\(rejected)' is kept off the allowlist — judged, or not yet judged, against the 500pt column")
        }
        XCTAssertFalse(list.contains("info"),
                       "'info' is decided on its resolved FORM by plainBrandedPermits, not by this set")
    }

    /// The bento-grid advisory carries both halves of the reason: hero/summary arms render but
    /// are unjudged; the grid arm is refused on composition and drops actionLabel.
    func testPlainBrandedAdvisesBentoGridWithoutDroppingIt() throws {
        let layouts: [String?] = ["hero", "summary", nil]
        for layout in layouts {
            InspectConfig.unknownKeyWarnings = []
            let layoutKey = layout.map { "\"bentoLayout\":\"\($0)\"," } ?? ""
            let config = try decode("""
            {"preset":"1","chrome":"plain-branded","title":"t","guidanceContent":[
              {"type":"bento-grid",\(layoutKey)"bentoCells":[
                {"id":"hero","column":0,"row":0,"contentType":"mixed","surface":"accent",
                 "title":"Managed by Fleet","subtitle":"Policy arrives from your IT team."},
                {"id":"apps","column":0,"row":1,"contentType":"mixed","surface":"cool",
                 "title":"Self Service","meta":"62 apps","actionLabel":"Open"}
              ]}
            ]}
            """)
            let warnings = InspectConfig.unknownKeyWarnings
            InspectConfig.unknownKeyWarnings = []

            let kept = try XCTUnwrap(config.guidanceContent)
            XCTAssertEqual(kept.map(\.type), ["bento-grid"],
                           "'bento-grid' must still RENDER — the allowlist advises, it never filters")
            XCTAssertEqual(kept.first?.bentoCells?.count, 2,
                           "the advisory must not disturb the cells the author wrote")
            XCTAssertEqual(warnings.filter { $0.contains("guidanceContent[0]") }.count, 1,
                           "'bento-grid' must carry exactly one named advisory, never silence")
            XCTAssertTrue(warnings.contains { $0.contains("bento-grid") },
                          "the advisory must name the type it is about")
            XCTAssertTrue(warnings.contains { $0.contains("RENDERED ANYWAY") },
                          "the allowlist advises and the block renders; an advisory must not read as a removal")

            XCTAssertTrue(warnings.contains { $0.contains("hero") && $0.contains("summary") },
                          "the advisory must separate the ARMS by name — otherwise an author "
                          + "reads 'does not fit' and tries bentoLayout next: \(warnings)")
            XCTAssertTrue(warnings.contains { $0.contains("untried rather than") },
                          "an advisory that calls a working arm broken is as misleading as one "
                          + "that calls an unjudged arm approved: \(warnings)")
            XCTAssertTrue(warnings.contains { $0.contains("rule 6") },
                          "the advisory must name the VOID — the grid arm renders correctly and "
                          + "is refused on composition, which is not guessable: \(warnings)")
            XCTAssertTrue(warnings.contains { $0.contains("actionLabel") },
                          "the advisory must name the dropped button — content that silently "
                          + "vanishes is the half an author cannot see: \(warnings)")
        }
    }

    /// A titled `info` (the card form) is admitted without an advisory.
    func testPlainBrandedAdmitsTitledInfoCard() throws {
        InspectConfig.unknownKeyWarnings = []
        let config = try decode(#"""
        {"preset":"1","chrome":"plain-branded","title":"t","guidanceContent":[
          {"type":"info","content":"titled info, now kept","title":"Heads up"}
        ]}
        """#)
        let warnings = InspectConfig.unknownKeyWarnings
        InspectConfig.unknownKeyWarnings = []

        let kept = try XCTUnwrap(config.guidanceContent)
        XCTAssertEqual(kept.map(\.type), ["info"],
                       "a titled 'info' block (the .card form) must survive the task-34 widened filter")
        XCTAssertEqual(kept.first?.title, "Heads up",
                       "the surviving block must be the actual titled/card block, not a stripped-down chip")
        XCTAssertTrue(warnings.isEmpty,
                     "a now-permitted titled info block must not produce a dropped-block advisory")
    }

    func testGuidanceContentIsUnfilteredWhenChromeIsNotPlainBranded() throws {
        InspectConfig.unknownKeyWarnings = []
        let config = try decode(#"""
        {"preset":"1","title":"t","guidanceContent":[
          {"type":"warning","content":"not plain-branded, so not filtered"}
        ]}
        """#)
        let warnings = InspectConfig.unknownKeyWarnings
        InspectConfig.unknownKeyWarnings = []

        XCTAssertEqual(config.guidanceContent?.map(\.type), ["warning"])
        XCTAssertTrue(warnings.filter { $0.contains("guidanceContent") }.isEmpty)
    }

    // MARK: - Brand-mark placement (three-value vocabulary)

    /// BrandPosition is the one case-insensitive, fail-open resolution of logoConfig.position.
    func testBrandPositionResolvesTheThreeAuthorableValues() {
        XCTAssertEqual(BrandPosition(authored: "footer"), .footer)
        XCTAssertEqual(BrandPosition(authored: "header"), .header)
        XCTAssertEqual(BrandPosition(authored: "none"), .none)
        XCTAssertEqual(BrandPosition(authored: nil), .footer, "absent must resolve to the default")
    }

    /// Legacy corner spellings map forward case-insensitively, so no existing config needs editing.
    func testBrandPositionMigratesLegacyCornerSpellingsForward() {
        for bottomSpelling in ["bottomleft", "bottomLeft", "bottom", "bottomCenter", "bottomright",
                                "BOTTOMLEFT", "BottomLeft"] {
            XCTAssertEqual(BrandPosition(authored: bottomSpelling), .footer,
                           "'\(bottomSpelling)' must still land on .footer — the seat it already "
                           + "rendered in, since a bottom* value was already load-bearing")
        }
        for topSpelling in ["topleft", "topright", "TOPLEFT", "top"] {
            XCTAssertEqual(BrandPosition(authored: topSpelling), .header,
                           "'\(topSpelling)' must land on .header")
        }
        XCTAssertEqual(BrandPosition(authored: "Header"), .header, "matching stays case-insensitive")
        XCTAssertEqual(BrandPosition(authored: "NONE"), .none, "matching stays case-insensitive")
    }

    /// Unknown values fail open to footer; the footer has no centred seat left to author.
    func testBrandPositionFallsBackToFooterOnUnknownValue() {
        for bogus in ["bogus", "sidebar", "buttonBarCenter", ""] {
            XCTAssertEqual(BrandPosition(authored: bogus), .footer,
                           "'\(bogus)' must fail open to .footer")
        }
    }

    /// BrandSlot routes through BrandPosition; footer maps to actionLeading, the one footer seat.
    func testBrandSlotMapsTheThreeValueVocabulary() {
        XCTAssertEqual(BrandSlot(position: "header"), .header)
        XCTAssertEqual(BrandSlot(position: "Header"), .header)
        XCTAssertEqual(BrandSlot(position: "none"), .none)
        XCTAssertEqual(BrandSlot(position: "footer"), .actionLeading)
        for footerSpelling in [nil, "bottomleft", "bottomLeft", "bottom", "bottomright", "bogus"] {
            XCTAssertEqual(BrandSlot(position: footerSpelling), .actionLeading,
                           "'\(footerSpelling ?? "nil")' must resolve through .footer to the "
                           + "leading cluster")
        }
    }

    /// Only three slots are reachable from `position`; the rail, payload and centred seats are
    /// selected by chrome, never authored.
    func testBrandSlotIsAOneForOneRenameOfTheThreeCardSeatsExceptCentered() {
        XCTAssertEqual(BrandSlot(position: nil), .actionLeading)
        XCTAssertEqual(BrandSlot(position: "bottomLeft"), .actionLeading)
        XCTAssertEqual(BrandSlot(position: "header"), .header)
        XCTAssertEqual(BrandSlot(position: "bottomCenter"), .actionLeading)

        let reachable: Set<BrandSlot> = [.actionLeading, .header, .none]
        for spelling in [nil, "header", "bottomCenter", "none", "railfoot", "railhead", "payload"] {
            XCTAssertTrue(reachable.contains(BrandSlot(position: spelling)),
                          "'\(spelling ?? "nil")' reached a slot outside the three authorable seats")
        }
    }

    /// LogoConfig.resolvedPosition is the model-level entry point for readers other than BrandSlot.
    func testLogoConfigResolvedPositionMatchesTheThreeValueVocabulary() throws {
        XCTAssertEqual(try logoConfigFixture(position: "footer").resolvedPosition, .footer)
        XCTAssertEqual(try logoConfigFixture(position: "header").resolvedPosition, .header)
        XCTAssertEqual(try logoConfigFixture(position: "none").resolvedPosition, .none)
        XCTAssertEqual(try logoConfigFixture(position: nil).resolvedPosition, .footer)
        XCTAssertEqual(try logoConfigFixture(position: "bottomLeft").resolvedPosition, .footer)
        XCTAssertEqual(try logoConfigFixture(position: "bottomCenter").resolvedPosition, .footer)
    }

    /// footerPath is non-nil only for a footer-seated mark; header and none never draw there.
    func testLogoConfigFooterPathGatesOnResolvedFooterOnly() throws {
        XCTAssertNotNil(try logoConfigFixture(position: "bottomLeft").footerPath(isDark: false))
        XCTAssertNotNil(try logoConfigFixture(position: nil).footerPath(isDark: false))
        XCTAssertNil(try logoConfigFixture(position: "header").footerPath(isDark: false),
                     "a header-seated mark must not also draw in the footer")
        XCTAssertNil(try logoConfigFixture(position: "none").footerPath(isDark: false),
                     "a suppressed mark must draw nowhere, including the footer")
    }

    /// showGridCounter and showProgressLine are independent switches; absent means shown.
    func testTheTwoJourneyCountsAreSwitchedIndependently() throws {
        let config = try decode(#"""
        {"preset": "5", "introSteps": [
          {"id": "a", "stepType": "carousel", "layout": "grid", "showGridCounter": false},
          {"id": "b", "stepType": "carousel", "layout": "grid", "showProgressLine": false},
          {"id": "c", "stepType": "carousel", "layout": "grid"}
        ]}
        """#)
        let steps = try XCTUnwrap(config.introSteps)
        XCTAssertEqual(steps[0].showGridCounter, false)
        XCTAssertNil(steps[0].showProgressLine, "one switch never sets the other")
        XCTAssertEqual(steps[1].showProgressLine, false)
        XCTAssertNil(steps[1].showGridCounter, "one switch never sets the other")
        XCTAssertNil(steps[2].showGridCounter, "absent = drawn, as every shipped deck expects")
        XCTAssertNil(steps[2].showProgressLine)
    }

    /// Every seat reads InspectMetrics.unit; this walks the inspect tree for a second spelling.
    func testTheUnitMetricsPinIsStatedOnce() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThan(files.count, 200, "the walk found the tree")
        let offenders = try files.filter { $0.lastPathComponent != "InspectMetrics.swift" }
            .filter { try String(contentsOf: $0, encoding: .utf8).contains("InspectMetrics(scale: 1.0)") }
            .map(\.lastPathComponent)
        XCTAssertEqual(offenders, [], "a second pin of the unit metrics — use InspectMetrics.unit")
        XCTAssertEqual(InspectMetrics.unit, InspectMetrics(scale: 1.0))
    }

    /// Every seat reads LogoConfig.clearSpace (raw; draw sites clamp) rather than the knob by hand.
    func testTheClearSpaceKnobIsReadOnce() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        let offenders = try files.filter { $0.lastPathComponent != "InspectConfig+CommonTypes.swift" }
            .filter { try String(contentsOf: $0, encoding: .utf8).contains("logoClearSpace ?? 0") }
            .map(\.lastPathComponent)
        XCTAssertEqual(offenders, [], "a hand-spelled clear-space reading — use logoConfig.clearSpace")
        let config = try decode(#"{"preset": "5", "logoConfig": {"imagePath": "/tmp/l.png", "logoClearSpace": 0.12}}"#)
        XCTAssertEqual(try XCTUnwrap(config.logoConfig).clearSpace, 0.12, accuracy: 0.0001)
        let absent = try decode(#"{"preset": "5", "logoConfig": {"imagePath": "/tmp/l.png"}}"#)
        XCTAssertEqual(try XCTUnwrap(absent.logoConfig).clearSpace, 0, "absent reads as 0, not as a missing value")
    }

    /// FooterBandM.band owns the footer height; the shells' constants are aliases of it.
    func testTheFooterBandHasOneOwner() throws {
        XCTAssertEqual(FooterBandM.band, 84)
        XCTAssertEqual(ProvisioningM.footerBandHeight, FooterBandM.band)
        XCTAssertEqual(PlainCenteredM.footerHeight, FooterBandM.band)
        XCTAssertEqual(SetupAssistantM.footerHeight, FooterBandM.band)
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        let literal = try NSRegularExpression(pattern: "static let footer[A-Za-z]*(Height|Band)[A-Za-z]*: CGFloat = 84\\b")
        let offenders = try files.filter { $0.lastPathComponent != "FooterBand.swift" }.filter {
            let text = try String(contentsOf: $0, encoding: .utf8)
            return literal.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }.map(\.lastPathComponent)
        XCTAssertEqual(offenders, [], "a second owner of the footer height — alias FooterBandM.band")
    }

    /// FooterBandM also owns the compact rung and the rule width; air is one arithmetic.
    func testTheCompactRungAndTheRuleWidthHaveOneOwner() throws {
        XCTAssertEqual(FooterBandM.compact, 60)
        XCTAssertEqual(DetailSheetMetrics.footerHeight, FooterBandM.compact)
        XCTAssertEqual(FooterBandM.ruleWidth, 0.5)
        XCTAssertEqual(SetupAssistantM.footerRuleWidth, FooterBandM.ruleWidth)
        XCTAssertEqual(PlainCenteredM.footerHorizontalPadding, FooterBandM.rail, "the band's rail under the shell's name")
        XCTAssertEqual(FooterBandM.air(), 28, "paint over the band costs nothing")
        XCTAssertEqual(FooterBandM.air(hairline: FooterBandM.ruleWidth), 27.75, "furniture inside it costs the half point")
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        let literal = try NSRegularExpression(pattern: "static let (footer[A-Za-z]*Height|[A-Za-z]*[Rr]uleWidth): CGFloat = (60|0\\.5)\\b")
        let offenders = try files.filter { $0.lastPathComponent != "FooterBand.swift" }.filter {
            let text = try String(contentsOf: $0, encoding: .utf8)
            return literal.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }.map(\.lastPathComponent)
        XCTAssertEqual(offenders, [], "a second owner of the compact rung or the rule width — alias FooterBandM")
    }

    private func logoConfigFixture(position: String?) throws -> InspectConfig.LogoConfig {
        let positionJSON = position.map { "\"\($0)\"" } ?? "null"
        let config = try decode(#"""
        {"preset": "5", "logoConfig": {"imagePath": "/tmp/logo.png", "position": \#(positionJSON)}}
        """#)
        return try XCTUnwrap(config.logoConfig)
    }

    /// Reads inspect-config.schema.json as a raw JSON object.
    private func loadLogoConfigSchemaObject() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // dialogTests/
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("inspect-config.schema.json is not a JSON object")
            return [:]
        }
        return object
    }

    /// The schema enum is the three authorable values, defaults to footer, and notes that legacy
    /// spellings resolve.
    func testLogoConfigPositionSchemaIsTheThreeValueVocabulary() throws {
        let schema = try loadLogoConfigSchemaObject()
        let definitions = try XCTUnwrap(schema["definitions"] as? [String: Any])
        let logoConfigSchema = try XCTUnwrap(definitions["LogoConfig"] as? [String: Any])
        let properties = try XCTUnwrap(logoConfigSchema["properties"] as? [String: Any])
        let position = try XCTUnwrap(properties["position"] as? [String: Any])
        let enumValues = try XCTUnwrap(position["enum"] as? [String])
        XCTAssertEqual(Set(enumValues), ["footer", "header", "none"],
                       "the stale four-corner enum must be replaced by exactly the three "
                       + "authorable values")
        XCTAssertEqual(position["default"] as? String, "footer")
        let description = try XCTUnwrap(position["description"] as? String)
        for word in ["footer", "header", "none"] {
            XCTAssertTrue(description.contains(word),
                          "the description must name the authorable value '\(word)'")
        }
        XCTAssertTrue(description.lowercased().contains("legacy"),
                      "the description must still note that legacy corner spellings resolve, so "
                      + "an author reading an old config is not confused")
    }

    private func cardSource() throws -> String {
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Core Framework/Components")
        return try ["CardStepShell.swift", "CardChromePieces.swift"]
            .map { try String(contentsOf: folder.appendingPathComponent($0), encoding: .utf8) }
            .joined(separator: "\n")
    }

    /// Each position resolves; anything unknown keeps the band-leading overlay.
    func testBookendChipPlacementMapsThePositionVocabulary() {
        XCTAssertEqual(BookendChipPlacement(position: "bandTrailing"), .bandTrailing)
        XCTAssertEqual(BookendChipPlacement(position: "footerLeading"), .footerLeading)
        for unchanged in [nil, "bandLeading", "topLeft", "bogus"] {
            XCTAssertEqual(BookendChipPlacement(position: unchanged), .bandLeading,
                           "'\(unchanged ?? "nil")' must keep the band-leading overlay")
        }
    }

    /// Source guard: the shell draws each logo placement once, gated on its slot.
    func testCardShellRendersEveryLogoPlacement() throws {
        let source = try cardSource()
        XCTAssertTrue(source.contains("brandSlot == .header, let logo = footer.logoPath"),
                      "the header brand cluster is gone")
        XCTAssertTrue(source.contains("footer.logoPath, brandSlot == .actionLeading"),
                      "the leading footer logo no longer checks its slot — a header or "
                      + "centred config would draw the mark twice")
        XCTAssertTrue(source.contains("brandSlot == .actionCentered, let logo = footer.logoPath"),
                      "the centred action-bar mark is gone")
    }

    /// The top band is flow-level: it decodes at the root, never per step.
    func testTopBandDecodesAtRoot() throws {
        let config = try decode(#"""
        {"preset": "5", "chrome": "card",
         "topBand": {"flavor": "device", "height": 160, "image": "mac.png",
                     "ground": "image", "groundPalette": ["#111111", "#222222"],
                     "groundImage": "sky.png"},
         "introSteps": [{"id": "a", "title": "T"}]}
        """#)
        let band = try XCTUnwrap(config.topBand)
        XCTAssertEqual(band.flavor, "device")
        XCTAssertEqual(band.height, 160)
        XCTAssertEqual(band.image, "mac.png")
        XCTAssertEqual(band.ground, "image")
        XCTAssertEqual(band.groundPalette, ["#111111", "#222222"])
        XCTAssertEqual(band.groundImage, "sky.png")
        XCTAssertNil(try decode(#"{"preset": "5", "introSteps": []}"#).topBand)
    }

    /// The claim flavour takes a third of the window (clamped 100–220); additive flavours share
    /// the banded window's 118pt budget (clamped 100–118).
    func testTopBandHeightsClaimThirdsAdditiveBudget() {
        XCTAssertEqual(cardTopBandResolvedHeight(flavor: "claim", override: nil), 200)
        XCTAssertEqual(cardTopBandResolvedHeight(flavor: "device", override: nil), 118)
        XCTAssertEqual(cardTopBandResolvedHeight(flavor: "logo", override: nil), 118)
        XCTAssertEqual(cardTopBandResolvedHeight(flavor: "claim", override: 50), 100)
        XCTAssertEqual(cardTopBandResolvedHeight(flavor: "claim", override: 300), 220)
        XCTAssertEqual(cardTopBandResolvedHeight(flavor: "logo", override: 300), 118,
                       "an additive band can never outgrow the banded window's budget")
        XCTAssertEqual(cardTopBandResolvedHeight(flavor: "device", override: 110), 110)
    }

    /// One blocking step suppresses the band on every step, so the window never jumps mid-flow.
    /// Media blocks categorically (the viewer owns its bands).
    func testTopBandLegalityIsFlowLevel() throws {
        let prose = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [
            {"id": "a", "title": "T"},
            {"id": "z", "title": "T", "stepType": "outro"}
        ]}
        """#).introSteps ?? []
        XCTAssertNil(topBandBlockingStep(in: prose, claim: true))
        XCTAssertNil(topBandBlockingStep(in: prose, claim: false))

        let withProcessing = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [
            {"id": "a", "title": "T"},
            {"id": "p", "title": "T", "stepType": "processing"}
        ]}
        """#).introSteps ?? []
        XCTAssertNil(topBandBlockingStep(in: withProcessing, claim: true),
                     "the claim flavour absorbs the header, so processing carries it")
        XCTAssertNil(topBandBlockingStep(in: withProcessing, claim: false),
                     "additive bands ride the processing arm since the banded-flow "
                     + "compression — the standard header keeps its banner")

        let withMedia = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [
            {"id": "a", "title": "T"},
            {"id": "m", "title": "T", "stepType": "media"}
        ]}
        """#).introSteps ?? []
        XCTAssertEqual(topBandBlockingStep(in: withMedia, claim: true)?.id, "m")
        XCTAssertEqual(topBandBlockingStep(in: withMedia, claim: false)?.id, "m")
    }

    /// Additive bands grow the window by bandHeight − 38 (to the one 820×680 banded window); the
    /// claim flavour and a blocked flow grow nothing; explicit size still wins.
    func testTopBandGrowsTheWindowForAdditiveFlavoursOnly() throws {
        func cfg(_ flavor: String, steps: String = #"[{"id": "a", "title": "T"}]"#) throws -> InspectConfig {
            try decode(#"{"preset": "5", "chrome": "card", "topBand": {"flavor": ""# + flavor
                       + #""}, "introSteps": "# + steps + "}")
        }
        XCTAssertEqual(InspectSizes.cardBandGrowth(config: try cfg("device")), 80,
                       "118 − 38: every additive flavour lands on the one 820×680 banded window")
        XCTAssertEqual(InspectSizes.cardBandGrowth(config: try cfg("logo")), 80)
        XCTAssertEqual(InspectSizes.cardBandGrowth(config: try cfg("claim")), 0,
                       "absorb mode pays with the header, never with the window")
        XCTAssertEqual(InspectSizes.cardBandGrowth(config: try cfg(
            "device", steps: #"[{"id": "m", "title": "T", "stepType": "media"}]"#)), 0,
            "a blocked flow renders no band, so it must not grow the window either")

        let grown = InspectSizes.windowSize(width: nil, height: nil, preset: "5",
                                            mode: nil, itemCount: 0, chrome: "card",
                                            bandGrowth: 80)
        XCTAssertEqual(grown.size.height, 680)
        XCTAssertEqual(grown.size.width, 820)
        let explicit = InspectSizes.windowSize(width: 800, height: 500, preset: "5",
                                               mode: nil, itemCount: 0, chrome: "card",
                                               bandGrowth: 80)
        XCTAssertEqual(explicit.size.height, 500,
                       "explicit height is rung 1 — band growth never overrides it")
    }

    /// Sizes are human strings (leading number, GB×1024); time-left sums unfinished estimates with
    /// the active row scaled by its remaining fraction; no estimates means no time-left row.
    func testInstallMathSummarizesTheEstimates() {
        let items = [
            InstallationItemData(id: "a", displayName: "A", status: .completed,
                                 size: "210 MB", timeEstimate: 40),
            InstallationItemData(id: "b", displayName: "B", status: .active, progress: 60,
                                 size: "1 GB", timeEstimate: 90),
            InstallationItemData(id: "c", displayName: "C", size: "junk")
        ]
        let s = InstallMath.summarize(items)
        XCTAssertEqual(s.completed, 1)
        XCTAssertEqual(s.total, 3)
        XCTAssertEqual(s.activeName, "B")
        XCTAssertEqual(s.totalMB, 210 + 1024, accuracy: 0.01)
        XCTAssertEqual(s.downloadedMB, 210 + 1024 * 0.6, accuracy: 0.01)
        XCTAssertEqual(s.secondsLeft ?? -1, 90 * 0.4, accuracy: 0.01)
        XCTAssertNil(InstallMath.megabytes("fast"))
        XCTAssertEqual(InstallMath.friendlyTime(36), "under a minute")
        XCTAssertEqual(InstallMath.friendlyTime(91), "~2 minutes")
        XCTAssertNil(InstallMath.summarize([items[2]]).secondsLeft,
                     "no estimates anywhere → no time-left row")
    }

    /// An entry passed on timeout is not installed: it must not count, and a late satisfy
    /// clears the marker.
    @MainActor
    func testTimedOutEntriesDoNotCountAsInstalled() throws {
        var clock = Date(timeIntervalSince1970: 1_000)
        let svc = CadenceMonitorService(now: { clock })
        let attr = try XCTUnwrap(try? JSONDecoder().decode(
            InspectConfig.CadenceAttribute.self,
            from: Data(#"{"source": "ipc"}"#.utf8)))
        func entry(_ id: String) -> InspectConfig.CadenceEntry {
            InspectConfig.CadenceEntry(id: id, message: id, attribute: attr, minDwell: 0,
                timeout: 60, sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil,
                subtitle: nil, timeEstimate: nil, size: nil)
        }
        svc.startWithEntries(entries: [entry("a"), entry("b"), entry("c")], stepId: "s",
                             interval: 3600, onCompletion: nil)

        svc.satisfyExternally(id: "a")
        XCTAssertEqual(svc.currentIndex, 1)
        XCTAssertTrue(svc.timedOutIndices.isEmpty)
        clock = clock.addingTimeInterval(61)
        svc.evaluateOnce()
        XCTAssertEqual(svc.currentIndex, 2, "timeout force-advances the position")
        XCTAssertEqual(svc.timedOutIndices, [1],
                       "…but records the entry as unproven, not installed")
        XCTAssertEqual(svc.timedOutCount, 1)

        XCTAssertEqual(max(0, svc.currentIndex - svc.timedOutIndices.count), 1)

        svc.satisfyExternally(id: "b")
        XCTAssertTrue(svc.timedOutIndices.isEmpty,
                      "late satisfy removes the fiction marker")
        XCTAssertEqual(svc.timedOutCount, 0)

        clock = clock.addingTimeInterval(61)
        svc.evaluateOnce()
        XCTAssertTrue(svc.isComplete)
        XCTAssertEqual(svc.timedOutIndices, [2],
                       "a timeout-completed cadence must not read as all-installed")
    }

    /// Satisfies and gotos that arrive before the step starts are buffered and seeded at
    /// startWithEntries; foreign ids stay buffered.
    @MainActor
    func testCadenceSatisfyBuffersBeforeTheStepStarts() throws {
        let svc = CadenceMonitorService()
        svc.satisfyExternally(id: "a")
        svc.satisfyExternally(id: "zz")         // some other step's id
        let attr = try XCTUnwrap(try? JSONDecoder().decode(
            InspectConfig.CadenceAttribute.self,
            from: Data(#"{"source": "ipc"}"#.utf8)))
        let entries = [
            InspectConfig.CadenceEntry(id: "a", message: "A", attribute: attr, minDwell: 0,
                timeout: nil, sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil,
                subtitle: nil, timeEstimate: nil, size: nil),
            InspectConfig.CadenceEntry(id: "b", message: "B", attribute: attr, minDwell: 0,
                timeout: nil, sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil,
                subtitle: nil, timeEstimate: nil, size: nil)
        ]
        var completed = false
        svc.startWithEntries(entries: entries, stepId: "s", interval: 60,
                             onCompletion: { _, _ in completed = true })
        XCTAssertEqual(svc.currentIndex, 1,
                       "the buffered satisfy for 'a' must advance past entry 0 at start")
        let svc2 = CadenceMonitorService()
        svc2.goto(index: 1)
        svc2.setMessage(index: 1, text: "Installing Edge…")
        svc2.startWithEntries(entries: entries, stepId: "s2", interval: 60,
                              onCompletion: nil)
        XCTAssertEqual(svc2.currentIndex, 1, "pre-arrival goto must seed the card index")
        XCTAssertEqual(svc2.currentMessage, "Installing Edge…",
                       "pre-arrival message overlays must survive the step start")
        svc2.stop()
        XCTAssertFalse(completed)
        svc.satisfyExternally(id: "b")
        XCTAssertTrue(svc.isComplete, "live satisfy still completes the run")
        svc.stop()
    }

    /// Every "N installed" claim reads `satisfied`; only the active highlight reads `position`.
    @MainActor
    func testCadenceProgressCountsProvenEntriesNotThePassedCursor() throws {
        let attr = try XCTUnwrap(try? JSONDecoder().decode(
            InspectConfig.CadenceAttribute.self,
            from: Data(#"{"source": "ipc"}"#.utf8)))
        func entry(_ id: String, timeout: Double?) -> InspectConfig.CadenceEntry {
            InspectConfig.CadenceEntry(id: id, message: id, attribute: attr, minDwell: 0,
                timeout: timeout, sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil,
                subtitle: nil, timeEstimate: nil, size: nil)
        }
        var clock = Date(timeIntervalSince1970: 0)
        let svc = CadenceMonitorService(now: { clock })
        let entries = [entry("a", timeout: nil), entry("b", timeout: 10), entry("c", timeout: nil)]
        let step = try XCTUnwrap(try? JSONDecoder().decode(
            InspectConfig.IntroStep.self,
            from: Data(#"{"id": "s", "stepType": "cadence"}"#.utf8)))

        svc.startWithEntries(entries: entries, stepId: "s", interval: 60, onCompletion: nil)
        svc.satisfyExternally(id: "a")
        clock = clock.addingTimeInterval(11)
        svc.evaluateOnce()
        svc.satisfyExternally(id: "c")

        let run = CadenceProgress(monitor: svc, step: step)
        XCTAssertTrue(run.isComplete, "all three entries were passed")
        XCTAssertEqual(run.position, 3, "the cursor passed every entry")
        XCTAssertEqual(run.satisfied, 2, "but only TWO proved — 'b' was forced past its timeout")
        XCTAssertEqual(run.timedOut, [1], "and the timed-out index is named, so it renders waiting")
        XCTAssertEqual(run.total, 3)
        XCTAssertEqual(run.fraction, 2.0 / 3.0, accuracy: 0.001,
                       "the measure follows the PROVEN count, never the cursor")
        XCTAssertNil(run.current, "a complete run has no current entry to narrate")
        svc.stop()
    }

    /// One monitor serves every cadence step and the incoming view appears before the outgoing
    /// one disappears, so the outgoing step may only stop a monitor it still owns.
    @MainActor
    func testOutgoingCadenceStepMustNotStopTheIncomingStepsMonitor() throws {
        let attr = try XCTUnwrap(try? JSONDecoder().decode(
            InspectConfig.CadenceAttribute.self,
            from: Data(#"{"source": "ipc"}"#.utf8)))
        func entry(_ id: String) -> InspectConfig.CadenceEntry {
            InspectConfig.CadenceEntry(id: id, message: id, attribute: attr, minDwell: 60,
                timeout: nil, sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil,
                subtitle: nil, timeEstimate: nil, size: nil)
        }
        let first = [entry("a1")]
        let second = [entry("b1"), entry("b2"), entry("b3")]

        let bug = CadenceMonitorService()
        bug.startWithEntries(entries: first, stepId: "cadence-line", interval: 60, onCompletion: nil)
        bug.startWithEntries(entries: second, stepId: "cadence-carousel", interval: 60, onCompletion: nil)
        bug.stop()                                   // unguarded stop from the outgoing step
        XCTAssertFalse(bug.isMonitoring,
                       "pins WHY the guard exists: an unguarded stop kills the incoming monitor")

        let svc = CadenceMonitorService()
        svc.startWithEntries(entries: first, stepId: "cadence-line", interval: 60, onCompletion: nil)
        svc.startWithEntries(entries: second, stepId: "cadence-carousel", interval: 60, onCompletion: nil)
        svc.stop(ifOwnedBy: "cadence-line")          // must be a no-op
        XCTAssertTrue(svc.isMonitoring,
                      "the second cadence step must still be ticking after the first disappears")
        XCTAssertEqual(svc.entries.count, 3, "and it must still hold the INCOMING step's entries")
        XCTAssertFalse(svc.isComplete)

        svc.stop(ifOwnedBy: "cadence-carousel")
        XCTAssertFalse(svc.isMonitoring, "the owning step still stops its own monitor")
    }

    func testAutoCloseAfterDecodesAndTheClockFormats() throws {
        XCTAssertEqual(Countdown.mmss(0), "0:00")
        XCTAssertEqual(Countdown.mmss(119), "1:59")
        XCTAssertEqual(Countdown.mmss(3661), "1:01:01")
        let cfg = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [
          {"id": "done", "title": "T", "stepType": "outro", "autoCloseAfter": 120}]}
        """#)
        XCTAssertEqual(cfg.introSteps?.first?.autoCloseAfter, 120)
    }

    /// `quit:` routes to onClose unless isFlowHeld says the step holds its door, in which case it
    /// is deferred; `close` is never deferred; the bare verb `quit` is unknown.
    @MainActor func testOrbitsQuitClosesTheDialogUnlessTheDoorIsHeld() {
        let router = CommandRouter()
        var closes = 0
        router.onClose = { closes += 1 }
        router.processCommand("quit:")
        XCTAssertEqual(closes, 1, "no host wired the hold: quit: opens the supervised door")
        router.isFlowHeld = { true }
        router.processCommand("quit:")
        XCTAssertEqual(closes, 1, "the step holds its door: quit: is deferred")
        router.processCommand("close")
        XCTAssertEqual(closes, 2, "close is never deferred — it is the supervisor's own verb")
        router.isFlowHeld = { false }
        router.processCommand("quit:")
        XCTAssertEqual(closes, 3, "the door released: quit: closes")
        router.processCommand("quit")
        XCTAssertEqual(closes, 3, "the bare verb stays unknown")
    }

    /// The auto-close clock starts when the door opens, so a held door yields no model.
    func testAutoCloseModelIsWithheldWhileTheDoorIsHeld() {
        let model = CardAutoCloseModel(seconds: 30, onFire: {})
        XCTAssertNil(CardAutoCloseGate.model(model, doorHeld: true), "held: no model, no clock")
        XCTAssertEqual(CardAutoCloseGate.model(model, doorHeld: false)?.seconds, 30, "released: the clock starts")
        XCTAssertNil(CardAutoCloseGate.model(nil, doorHeld: false), "a step authoring no autoCloseAfter never closes itself")
    }

    /// version and timeEstimate decode on both row types (ListItem and ItemConfig).
    func testVersionAndTimeEstimateDecodeOnBothRowTypes() throws {
        let rootShape = try decode(#"""
        {"preset": "6",
         "items": [{"id": "r", "displayName": "R", "version": "2.0", "timeEstimate": 12}]}
        """#)
        XCTAssertEqual(rootShape.items.first?.version, "2.0")
        XCTAssertEqual(rootShape.items.first?.timeEstimate, 12)
        let stepShape = try decode(#"""
        {"preset": "5", "chrome": "card",
         "introSteps": [{"id": "s", "title": "T", "stepType": "installation",
            "items": [{"id": "i", "displayName": "I", "version": "1.0", "timeEstimate": 30}]}]}
        """#)
        let stepItem = try XCTUnwrap(stepShape.introSteps?.first?.items?.first)
        XCTAssertEqual(stepItem.version, "1.0")
        XCTAssertEqual(stepItem.timeEstimate, 30)
    }

    // MARK: - Bento hero arrangement

    /// With no authored spans, cell 0 is the full-width hero and the rest divide row 1.
    func testHeroArrangementSpansTheFirstCellAcrossTheRemainder() throws {
        let cells = try (0..<3).map { try Self.heroTestCell(id: "c\($0)") }
        let placements = BentoHeroArrangement.placements(for: cells)
        XCTAssertEqual(placements, [
            BentoHeroPlacement(cellIndex: 0, row: 0, columnSpan: 2),
            BentoHeroPlacement(cellIndex: 1, row: 1, columnSpan: 1),
            BentoHeroPlacement(cellIndex: 2, row: 1, columnSpan: 1)
        ])
    }

    /// "hero" is a default arrangement, never an override of authored spans.
    func testHeroArrangementHonoursAuthoredSpansVerbatim() throws {
        let cells = [
            try Self.heroTestCell(id: "a", row: 0, columnSpan: 1),
            try Self.heroTestCell(id: "b", row: 0, columnSpan: 3),
            try Self.heroTestCell(id: "c", row: 1, columnSpan: 4)
        ]
        XCTAssertEqual(BentoHeroArrangement.placements(for: cells), [
            BentoHeroPlacement(cellIndex: 0, row: 0, columnSpan: 1),
            BentoHeroPlacement(cellIndex: 1, row: 0, columnSpan: 3),
            BentoHeroPlacement(cellIndex: 2, row: 1, columnSpan: 4)
        ])
    }

    func testHeroArrangementWithOneCellHasNoSupportingRow() {
        XCTAssertEqual(BentoHeroArrangement.placements(for: [try Self.heroTestCell(id: "only")]),
                       [BentoHeroPlacement(cellIndex: 0, row: 0, columnSpan: 1)])
    }

    func testHeroArrangementWithNoCellsIsEmpty() {
        XCTAssertEqual(BentoHeroArrangement.placements(for: []), [])
    }

    /// Past the soft max every cell still renders and one advisory names the grid alternative.
    func testHeroArrangementPastTheSoftMaxStillRendersEveryCell() throws {
        let cells = try (0..<7).map { try Self.heroTestCell(id: "c\($0)") }
        let placements = BentoHeroArrangement.placements(for: cells)
        XCTAssertEqual(placements.count, 7)
        XCTAssertEqual(placements.filter { $0.row == 1 }.count, 6)
        XCTAssertGreaterThan(placements.filter { $0.row == 1 }.count,
                             BentoHeroArrangement.supportingSoftMax,
                             "this fixture must exceed the soft max or it tests nothing")

        let advisories = BentoHeroArrangement.advisories(for: cells)
        XCTAssertEqual(advisories.count, 1,
                       "the past-soft-max case must produce exactly one advisory")
        XCTAssertTrue(advisories.first?.contains("grid") ?? false,
                      "the advisory must name bentoLayout \"grid\" as the alternative")
    }

    func testHeroArrangementAdvisoryOnlyForUnauthoredSpans() throws {
        let authoredCells = [
            try Self.heroTestCell(id: "a", row: 0, columnSpan: 1),
            try Self.heroTestCell(id: "b", row: 0, columnSpan: 3),
            try Self.heroTestCell(id: "c", row: 1, columnSpan: 4),
            try Self.heroTestCell(id: "d", row: 1, columnSpan: 1),
            try Self.heroTestCell(id: "e", row: 1, columnSpan: 1),
            try Self.heroTestCell(id: "f", row: 1, columnSpan: 1),
            try Self.heroTestCell(id: "g", row: 1, columnSpan: 1)
        ]
        XCTAssertTrue(BentoHeroArrangement.advisories(for: authoredCells).isEmpty,
                      "authored spans override the soft-max advisory")

        let smallUnauthored = try (0..<3).map { try Self.heroTestCell(id: "c\($0)") }
        XCTAssertTrue(BentoHeroArrangement.advisories(for: smallUnauthored).isEmpty,
                      "3 cells (2 supporting) stays within soft max, no advisory")
    }

    /// bentoColumns is read by the grid layout only; authoring it on hero or summary is advised.
    func testBentoColumnsAdvisoryOnlyFiresForHeroAndSummaryWhenAuthored() throws {
        XCTAssertNil(BentoHeroArrangement.bentoColumnsAdvisory(layout: "hero", bentoColumns: nil),
                     "no bentoColumns authored — nothing to advise about")
        XCTAssertNil(BentoHeroArrangement.bentoColumnsAdvisory(layout: "grid", bentoColumns: 4),
                     "grid actually reads bentoColumns — no advisory needed")
        XCTAssertNil(BentoHeroArrangement.bentoColumnsAdvisory(layout: "split", bentoColumns: 4),
                     "split does not use bentoColumns, but this advisory is scoped to hero/summary")

        let hero = try XCTUnwrap(
            BentoHeroArrangement.bentoColumnsAdvisory(layout: "hero", bentoColumns: 3))
        XCTAssertTrue(hero.contains("hero"))
        XCTAssertTrue(hero.contains("ignored"))

        let summary = try XCTUnwrap(
            BentoHeroArrangement.bentoColumnsAdvisory(layout: "summary", bentoColumns: 2))
        XCTAssertTrue(summary.contains("summary"))
        XCTAssertTrue(summary.contains("ignored"))
    }

    /// A bento payload meets both band edges: the top inset corrects the shell's prose gap and the
    /// bottom clears the action bar, asserted relative to `cardBodyTop`.
    func testBentoBandInsetsCorrectTheShellsProseGapAndClearTheActionBar() {
        XCTAssertEqual(BentoHeroArrangement.bandTop, 22, "padding-top")
        XCTAssertEqual(BentoHeroArrangement.bandBottom, 32, "margin-top 18 + padding-top 14")

        let bandless = BentoHeroArrangement.bandTopAdjustment(shellInset: InspectMetrics.unit.cardBodyTop)
        XCTAssertEqual(bandless, BentoHeroArrangement.bandTop - InspectMetrics.unit.cardBodyTop, accuracy: 0.001)
        XCTAssertLessThan(bandless, 0,
                          "the shell's prose inset is the larger one — the band gives some back")

        let banded = BentoHeroArrangement.bandTopAdjustment(shellInset: InspectMetrics.unit.cardBandBodyTop)
        XCTAssertEqual(banded, BentoHeroArrangement.bandTop - InspectMetrics.unit.cardBandBodyTop, accuracy: 0.001)
        XCTAssertGreaterThan(banded, bandless,
                             "a banded card already compresses its body gap, so it gives back less")
    }

    // MARK: - Band the module claims unproposed

    /// `PlainBrandedScreen` and `BookendScreenView` propose no height, so `minimumBandHeight` sizes a
    /// 1.35 : 1 band so the smaller share still clears the tile floor.
    func testHeroRowBandIsSizedSoTheSMALLERShareStillClearsTheTileFloor() throws {
        let cells = try (0..<3).map { try Self.heroTestCell(id: "c\($0)") }
        let band = BentoHeroArrangement.minimumBandHeight(for: cells, kind: .heroRow)

        let weightSum = BentoHeroArrangement.heroRowWeight + BentoHeroArrangement.supportingRowWeight
        let available = band - BentoHeroArrangement.bandGap
        let heroShare = available * BentoHeroArrangement.heroRowWeight / weightSum
        let supportingShare = available * BentoHeroArrangement.supportingRowWeight / weightSum

        XCTAssertEqual(supportingShare, BentoHeroArrangement.rowTileFloor, accuracy: 0.001,
                       "the supporting row is the smaller share, so it is what the band is sized by")
        XCTAssertGreaterThan(heroShare, BentoHeroArrangement.rowTileFloor,
                             "the hero row rides above the floor for free — sizing the band by IT "
                             + "would starve the supporting row, which is the collapse in miniature")
    }

    /// A lone cell is one tile, with no gap and no split.
    func testHeroRowBandWithOneCellIsOneTileAndNoGap() throws {
        let band = BentoHeroArrangement.minimumBandHeight(
            for: [try Self.heroTestCell(id: "only")], kind: .heroRow)
        XCTAssertEqual(band, BentoHeroArrangement.rowTileFloor, accuracy: 0.001)
    }

    /// `.heroColumn` puts hero and stack side by side, so the band grows with the stack, not the hero.
    func testHeroColumnBandGrowsWithTheSTACKBecauseTheTwoColumnsShareAHeight() throws {
        func band(_ count: Int) throws -> CGFloat {
            BentoHeroArrangement.minimumBandHeight(
                for: try (0..<count).map { try Self.heroTestCell(id: "c\($0)") }, kind: .heroColumn)
        }
        let two = try band(3) // hero + 2 stacked
        let three = try band(4) // hero + 3 stacked
        XCTAssertEqual(two, 2 * BentoHeroArrangement.statTileFloor + BentoHeroArrangement.bandGap,
                       accuracy: 0.001)
        XCTAssertEqual(three, 3 * BentoHeroArrangement.statTileFloor + 2 * BentoHeroArrangement.bandGap,
                       accuracy: 0.001)
        XCTAssertGreaterThan(three, two, "one more tile in the stack is one more tile of band")
    }

    /// With nothing to stack, the band is the prominent tile alone.
    func testHeroColumnBandWithNoStackIsTheProminentTileAlone() throws {
        let band = BentoHeroArrangement.minimumBandHeight(
            for: [try Self.heroTestCell(id: "only")], kind: .heroColumn)
        XCTAssertEqual(band, BentoHeroArrangement.statHeroTileFloor, accuracy: 0.001)
    }

    /// No cells claim a zero band, with no division by a zero weight sum.
    func testNoCellsClaimNoBandInEitherArrangement() {
        XCTAssertEqual(BentoHeroArrangement.minimumBandHeight(for: [], kind: .heroRow), 0)
        XCTAssertEqual(BentoHeroArrangement.minimumBandHeight(for: [], kind: .heroColumn), 0)
    }

    /// The band the module claims on its own never exceeds the card host's measured hero band.
    func testTheClaimedBandDoesNotExceedTheCardHostsMeasuredHeroBand() throws {
        let cells = try (0..<3).map { try Self.heroTestCell(id: "c\($0)") }
        let claimed = BentoHeroArrangement.minimumBandHeight(for: cells, kind: .heroRow)
        XCTAssertLessThanOrEqual(claimed, 353.5,
                                 "measured on ax-preset5-bento at 820x632: the card host's hero "
                                 + "band draws 353.5pt. A claim above that would mean the module "
                                 + "wants more room than the shipped step gives it.")
    }

    // MARK: - Hero column arrangement

    /// The hero takes the left column and the supporting tiles stack beside it.
    func testHeroColumnPutsTheHeroLeftAndStacksTheRest() throws {
        let cells = try (0..<3).map { try Self.heroTestCell(id: "c\($0)") }
        let placements = BentoHeroArrangement.placements(for: cells, kind: .heroColumn)
        XCTAssertEqual(placements, [
            BentoHeroPlacement(cellIndex: 0, row: 0, columnSpan: 1),
            BentoHeroPlacement(cellIndex: 1, row: 1, columnSpan: 1),
            BentoHeroPlacement(cellIndex: 2, row: 2, columnSpan: 1)
        ], "hero on its own, then one placement per stacked tile — the renderer reads row as "
         + "stack position in this kind")
    }

    /// The default kind is heroRow.
    func testPlacementsDefaultsToHeroRow() throws {
        let cells = try (0..<3).map { try Self.heroTestCell(id: "c\($0)") }
        XCTAssertEqual(BentoHeroArrangement.placements(for: cells),
                       BentoHeroArrangement.placements(for: cells, kind: .heroRow))
    }

    /// Authored spans still win in the column arrangement.
    func testHeroColumnHonoursAuthoredSpans() throws {
        let cells = [try Self.heroTestCell(id: "a", row: 0, columnSpan: 2),
                     try Self.heroTestCell(id: "b", row: 1, columnSpan: 1)]
        XCTAssertEqual(BentoHeroArrangement.placements(for: cells, kind: .heroColumn), [
            BentoHeroPlacement(cellIndex: 0, row: 0, columnSpan: 2),
            BentoHeroPlacement(cellIndex: 1, row: 1, columnSpan: 1)
        ])
    }

    /// One cell is just the hero, in either arrangement.
    func testHeroColumnWithOneCell() {
        XCTAssertEqual(BentoHeroArrangement.placements(for: [try Self.heroTestCell(id: "only")],
                                                       kind: .heroColumn),
                       [BentoHeroPlacement(cellIndex: 0, row: 0, columnSpan: 1)])
    }

    /// The soft-max advisory fires the same way in both arrangements.
    func testAdvisoryIsArrangementIndependent() throws {
        let cells = try (0..<7).map { try Self.heroTestCell(id: "c\($0)") }
        XCTAssertEqual(BentoHeroArrangement.advisories(for: cells).count, 1)
    }

    /// The hero layout's cell keys (`actionLabel` + `action`/`url`/`requestId`, `badge`) decode and
    /// load cleanly. Cell-level keys are not unknown-key validated, so the decode round-trip guards them.
    func testHeroCellKeysDecodeAndLoadCleanly() throws {
        let config = try decode(#"""
        {"preset": "5", "chrome": "card", "introSteps": [{
            "id": "bundles", "stepType": "bento", "bentoLayout": "hero",
            "title": "Do more with your Mac",
            "bentoCells": [
                {"id": "m365", "column": 0, "row": 0, "contentType": "mixed",
                 "surface": "accent", "title": "Microsoft 365",
                 "subtitle": "Analyse data, build decks and triage your inbox.",
                 "imagePath": "/tmp/shot.png",
                 "rows": [{"title": "Excel", "stateLabel": "installed"},
                          {"title": "Word", "progress": 62}]},
                {"id": "design", "column": 0, "row": 1, "contentType": "text",
                 "title": "Design tools", "badge": "Beta",
                 "subtitle": "Figma, Sketch and the shared component library.",
                 "actionLabel": "Install", "action": "request", "requestId": "install-design",
                 "meta": "1.4 GB"},
                {"id": "mobile", "column": 0, "row": 1, "contentType": "text",
                 "title": "Mobile", "actionLabel": "Send link",
                 "action": "url", "url": "https://example.invalid/mobile",
                 "meta": "iOS · Android"}
            ]
        }]}
        """#)
        let step = try XCTUnwrap(config.introSteps?.first)
        XCTAssertEqual(step.bentoLayout, "hero")
        let cells = try XCTUnwrap(step.bentoCells)
        XCTAssertEqual(cells.count, 3)

        XCTAssertEqual(cells[0].rows?.count, 2)
        XCTAssertEqual(cells[0].rows?[0].stateLabel, "installed")
        XCTAssertEqual(cells[0].rows?[1].progress, 62)

        XCTAssertEqual(cells[1].badge, "Beta")
        XCTAssertEqual(cells[1].meta, "1.4 GB")
        XCTAssertEqual(cells[1].actionLabel, "Install")
        XCTAssertEqual(cells[1].action, "request")
        XCTAssertEqual(cells[1].requestId, "install-design")

        XCTAssertEqual(cells[2].url, "https://example.invalid/mobile")
        XCTAssertNil(cells[2].badge, "an unauthored badge stays nil rather than defaulting")
    }

    /// The `bento-grid` block carries `bentoLayout` with the step's meaning, so `BentoModule` loads in any preset's content.
    func testBentoGridBlockDecodesBentoLayoutSummary() throws {
        let config = try decode(#"""
        {"preset": "6", "steps": [{
            "id": "s1", "stepType": "intro", "title": "T",
            "guidanceContent": [{
                "type": "bento-grid", "bentoLayout": "summary",
                "bentoCells": [
                    {"id": "applications", "column": 0, "row": 0, "contentType": "icon",
                     "surface": "accent", "sfSymbol": "square.grid.2x2.fill",
                     "label": "APPLICATIONS", "title": "Fixture value"}
                ]
            }]
        }]}
        """#)
        // `guidanceContent` folds into `content` at decode.
        let block = try XCTUnwrap(config.steps?.first?.content?.first)
        XCTAssertEqual(block.type, "bento-grid")
        XCTAssertEqual(block.bentoLayout, "summary")
    }

    /// A `bento-grid` block with no `bentoLayout` decodes nil, keeping its default grid.
    func testBentoGridBlockWithNoBentoLayoutDecodesNil() throws {
        let config = try decode(#"""
        {"preset": "6", "steps": [{
            "id": "s1", "stepType": "intro", "title": "T",
            "guidanceContent": [{
                "type": "bento-grid",
                "bentoCells": [
                    {"id": "c1", "column": 0, "row": 0, "contentType": "icon",
                     "sfSymbol": "gearshape", "title": "T"}
                ]
            }]
        }]}
        """#)
        let block = try XCTUnwrap(config.steps?.first?.content?.first)
        XCTAssertNil(block.bentoLayout)
    }

    // MARK: - Expand-in-place detail

    /// The bento expands in place only; an authored `detailPresentation` still decodes and is advised once.
    func testDetailPresentationAdvisoryFiresOnlyWhenAuthored() throws {
        XCTAssertNil(BentoHeroArrangement.detailPresentationAdvisory(for: []),
                     "no cells — nothing to advise about")
        XCTAssertNil(BentoHeroArrangement.detailPresentationAdvisory(for: [try Self.heroTestCell(id: "a")]),
                     "no cell authors detailPresentation — nothing to advise about")

        let withOverlayOnly = try Self.heroTestCellWithDetail(id: "b", detailPresentation: nil)
        XCTAssertNil(BentoHeroArrangement.detailPresentationAdvisory(for: [withOverlayOnly]),
                     "detailOverlay alone (no detailPresentation) is exactly what the new bento wants")

        let authored = try Self.heroTestCellWithDetail(id: "c", detailPresentation: "popover")
        let advisory = try XCTUnwrap(
            BentoHeroArrangement.detailPresentationAdvisory(for: [Self.heroTestCell(id: "a"), authored]))
        XCTAssertTrue(advisory.contains("detailPresentation"))
        XCTAssertTrue(advisory.contains("ignored"))
    }

    /// A cell without `detailOverlay` is not expandable, so `.tileTap(enabled:)` gives it no tap affordance.
    func testCellWithoutDetailOverlayHasNoTapAffordance() throws {
        let plain = try Self.heroTestCell(id: "plain")
        XCTAssertNil(plain.detailOverlay)
        XCTAssertFalse(BentoHeroArrangement.isExpandable(plain),
                       "no detailOverlay authored — the cell must not become tappable")

        let withDetail = try Self.heroTestCellWithDetail(id: "withDetail", detailPresentation: nil)
        XCTAssertNotNil(withDetail.detailOverlay)
        XCTAssertTrue(BentoHeroArrangement.isExpandable(withDetail),
                      "an authored detailOverlay is the only thing that makes a cell tappable")
    }

    /// The expanded header prefers `detailOverlay`'s title/subtitle/icon, falling back to the cell's.
    func testExpandedCellHeaderPrefersOverlayFieldsFallingBackToCell() throws {
        let overlayAuthored = try JSONDecoder().decode(
            InspectConfig.GuidanceContent.BentoCellConfig.self, from: Data("""
            {"id": "c", "column": 0, "row": 0, "contentType": "text",
             "title": "Cell Title", "subtitle": "Cell Subtitle", "sfSymbol": "gearshape",
             "detailOverlay": {"title": "Overlay Title", "subtitle": "Overlay Subtitle",
                                "icon": "square.grid.2x2.fill"}}
            """.utf8))
        let authoredOverlay = try XCTUnwrap(overlayAuthored.detailOverlay)

        XCTAssertEqual(BentoExpandedCellHeader.title(cell: overlayAuthored, overlay: authoredOverlay),
                       "Overlay Title")
        XCTAssertEqual(BentoExpandedCellHeader.subtitle(cell: overlayAuthored, overlay: authoredOverlay),
                       "Overlay Subtitle")
        XCTAssertEqual(BentoExpandedCellHeader.sfSymbol(cell: overlayAuthored, overlay: authoredOverlay),
                       "square.grid.2x2.fill")
        // Distinct from the cell's own fields, so a reversed preference fails.
        XCTAssertNotEqual(BentoExpandedCellHeader.title(cell: overlayAuthored, overlay: authoredOverlay),
                          overlayAuthored.title)
        XCTAssertNotEqual(BentoExpandedCellHeader.subtitle(cell: overlayAuthored, overlay: authoredOverlay),
                          overlayAuthored.subtitle)
        XCTAssertNotEqual(BentoExpandedCellHeader.sfSymbol(cell: overlayAuthored, overlay: authoredOverlay),
                          overlayAuthored.sfSymbol)

        let overlayOmits = try JSONDecoder().decode(
            InspectConfig.GuidanceContent.BentoCellConfig.self, from: Data("""
            {"id": "d", "column": 0, "row": 0, "contentType": "text",
             "title": "Cell Title", "subtitle": "Cell Subtitle", "sfSymbol": "gearshape",
             "detailOverlay": {}}
            """.utf8))
        let emptyOverlay = try XCTUnwrap(overlayOmits.detailOverlay)
        XCTAssertNil(emptyOverlay.title, "fixture must actually omit the field or this tests nothing")
        XCTAssertNil(emptyOverlay.icon, "fixture must actually omit the field or this tests nothing")

        // Without the `?? cell.X` fallback these would be nil.
        XCTAssertEqual(BentoExpandedCellHeader.title(cell: overlayOmits, overlay: emptyOverlay), "Cell Title")
        XCTAssertEqual(BentoExpandedCellHeader.subtitle(cell: overlayOmits, overlay: emptyOverlay), "Cell Subtitle")
        XCTAssertEqual(BentoExpandedCellHeader.sfSymbol(cell: overlayOmits, overlay: emptyOverlay), "gearshape")

        // An empty overlay string counts as omitted.
        let overlayEmptyString = try JSONDecoder().decode(
            InspectConfig.GuidanceContent.BentoCellConfig.self, from: Data("""
            {"id": "e", "column": 0, "row": 0, "contentType": "text",
             "title": "Cell Title", "sfSymbol": "gearshape", "detailOverlay": {"title": ""}}
            """.utf8))
        let blankOverlay = try XCTUnwrap(overlayEmptyString.detailOverlay)
        XCTAssertEqual(BentoExpandedCellHeader.title(cell: overlayEmptyString, overlay: blankOverlay),
                       "Cell Title")
    }

    /// Minimal cell; `contentType` is the only required field besides id/column/row.
    private static func heroTestCell(id: String, row: Int = 0,
                                     columnSpan: Int? = nil)
        throws -> InspectConfig.GuidanceContent.BentoCellConfig {
        let json = """
        {"id": "\(id)", "column": 0, "row": \(row), "contentType": "text"\
        \(columnSpan.map { ", \"columnSpan\": \($0)" } ?? "")}
        """
        return try JSONDecoder().decode(
            InspectConfig.GuidanceContent.BentoCellConfig.self, from: Data(json.utf8))
    }

    /// A cell with a minimal `detailOverlay`, optionally with legacy `detailPresentation`.
    private static func heroTestCellWithDetail(id: String, detailPresentation: String?) throws
        -> InspectConfig.GuidanceContent.BentoCellConfig {
        let json = """
        {"id": "\(id)", "column": 0, "row": 0, "contentType": "text",
         "title": "T"\
         \(detailPresentation.map { ", \"detailPresentation\": \"\($0)\"" } ?? ""),
         "detailOverlay": {"title": "Detail"}}
        """
        return try JSONDecoder().decode(
            InspectConfig.GuidanceContent.BentoCellConfig.self, from: Data(json.utf8))
    }

    /// A cell authoring every key the tile renderers disagree about.
    private static func heroTestCellWithFurniture(id: String, row: Int, subtitle: Bool = true) throws
        -> InspectConfig.GuidanceContent.BentoCellConfig {
        let json = """
        {"id": "\(id)", "column": 0, "row": \(row), "contentType": "icon",
         "title": "T"\(subtitle ? ", \"subtitle\": \"S\"" : ""),
         "label": "EYEBROW", "sfSymbol": "star", "badge": "BETA", "meta": "1.4 GB",
         "actionLabel": "Open", "imagePath": "/tmp/x.png"}
        """
        return try JSONDecoder().decode(
            InspectConfig.GuidanceContent.BentoCellConfig.self, from: Data(json.utf8))
    }

    // MARK: - The fixed brand slot

    /// The slot sizes are pinned.
    func testBrandSlotMetricsAreTheSketchesBoxes() {
        XCTAssertEqual(BrandSlotMetrics.columnSlot, CGSize(width: 176, height: 20))
        XCTAssertEqual(BrandSlotMetrics.actionSlot, CGSize(width: 220, height: 22))
        XCTAssertEqual(BrandSlotMetrics.claimFontSize, 11.5)
        XCTAssertEqual(BrandSlotMetrics.claimLineLimit, 2)
    }

    // MARK: - Footer step dots

    // MARK: - Step counter vocabulary

    /// Both placeholder spellings (`{n}` and `{current}`) resolve on every surface.
    func testStepCounterAcceptsBothPlaceholderSpellings() {
        XCTAssertEqual(StepCounterLabel.format("Step {n} of {total}", current: 2, total: 5),
                       "Step 2 of 5")
        XCTAssertEqual(StepCounterLabel.format("Step {current} of {total}", current: 2, total: 5),
                       "Step 2 of 5")
    }

    /// A translation may reorder the halves, so the default is a template.
    func testStepCounterTemplateMayReorder() {
        XCTAssertEqual(StepCounterLabel.format("Von {total} Schritten: {n}", current: 3, total: 7),
                       "Von 7 Schritten: 3")
    }

    /// An unknown placeholder is left visible, not blanked.
    func testStepCounterLeavesUnknownPlaceholders() {
        XCTAssertEqual(StepCounterLabel.format("Step {nn} of {total}", current: 1, total: 4),
                       "Step {nn} of 4")
    }

    /// `_ui.stepCounterFormat`, the key sidecars carry, wins over `stepProgress`.
    func testStepCounterPrefersTheKeyAuthorsWrite() {
        XCTAssertEqual(StepCounterLabel.sidecarKeys.first, "_ui.stepCounterFormat")
        let authored = ["_ui.stepCounterFormat": "Schritt {current} von {total}",
                        "stepProgress": "NICHT DIESER"]
        XCTAssertEqual(StepCounterLabel.template { authored[$0] }, "Schritt {current} von {total}")
    }

    /// The documented flow-header key still resolves when it is the only one authored.
    func testStepCounterFallsBackToTheHeaderKey() {
        let authored = ["stepProgress": "Schritt {n} von {total}"]
        XCTAssertEqual(StepCounterLabel.template { authored[$0] }, "Schritt {n} von {total}")
        XCTAssertEqual(StepCounterLabel.template { _ in nil }, StepCounterLabel.fallback,
                       "nothing authored → the English default")
        XCTAssertEqual(StepCounterLabel.template { _ in "" }, StepCounterLabel.fallback,
                       "an EMPTY sidecar value is not a translation — it would blank the counter")
    }

    // MARK: - The counter's ONE resolution entry point

    /// Sites with only the environment resolve the counter through one `(key, fallback) -> String`
    /// entry point; a German format reaches them.
    func testCounterResolvesAGermanFormatThroughALocalizer() {
        let de: InspectLocalizer = { key, fallback in
            key == "_ui.stepCounterFormat" ? "Schritt {current} von {total}" : fallback
        }
        XCTAssertEqual(StepCounterLabel.text(current: 2, total: 4, localizer: de),
                       "Schritt 2 von 4")
    }

    /// With no sidecar, the counter is byte-identical to the plain English interpolation.
    func testUnauthoredCounterIsByteIdenticalToTheWeldedEnglish() {
        let none: InspectLocalizer = { _, fallback in fallback }
        let welded = "Step \(2) of \(4)" // the plain English interpolation
        XCTAssertEqual(StepCounterLabel.text(current: 2, total: 4, localizer: none), welded)
        XCTAssertEqual(StepCounterLabel.text(current: 2, total: 4, localizer: none), "Step 2 of 4")
    }

    /// An empty sidecar value does not blank the counter.
    func testEmptyAuthoredValueDoesNotBlankTheCounter() {
        let blank: InspectLocalizer = { _, _ in "" }
        XCTAssertEqual(StepCounterLabel.text(current: 3, total: 9, localizer: blank), "Step 3 of 9")
    }

    /// Both brace spellings resolve through the entry point.
    func testBothBraceSpellingsResolveThroughTheEntryPoint() {
        let withN: InspectLocalizer = { key, fallback in
            key == "_ui.stepCounterFormat" ? "Schritt {n} von {total}" : fallback
        }
        XCTAssertEqual(StepCounterLabel.text(current: 5, total: 6, localizer: withN),
                       "Schritt 5 von 6")
    }

    /// An injected template (P6's sidecar plus config `labels`) wins over the environment.
    func testAnInjectedTemplateWinsOverTheEnvironment() {
        let sidecar: InspectLocalizer = { _, _ in "AUS DEM SIDECAR {current}/{total}" }
        XCTAssertEqual(StepCounterLabel.text(current: 2, total: 4,
                                             template: "Schritt {current} von {total}",
                                             localizer: sidecar),
                       "Schritt 2 von 4",
                       "the caller's own chain already resolved — do not resolve again")
    }

    /// With nothing injected, the counter falls through to the environment.
    func testNoInjectedTemplateStillResolvesThroughTheEnvironment() {
        let de: InspectLocalizer = { key, fallback in
            key == "_ui.stepCounterFormat" ? "Schritt {current} von {total}" : fallback
        }
        XCTAssertEqual(StepCounterLabel.text(current: 2, total: 4, template: nil, localizer: de),
                       "Schritt 2 von 4")
    }

    /// A one-step flow draws no dots but still reads "Step 1 of 1".
    func testWordsSurviveAFlowTooShortForAnIndicator() {
        XCTAssertEqual(StepDotIndicator.form(total: 1), StepDotIndicator.Form.none)
        XCTAssertEqual(StepCounterLabel.text(current: 1, total: 1,
                                             localizer: { _, f in f }), "Step 1 of 1")
    }

    /// The two carousel counters and the showcase's accessibility label reach the authored format.
    func testWeldedCountersReachTheAuthoredFormat() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Core Framework/Components")
        for file in ["MediaComponents.swift", "CardShowcaseView.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            XCTAssertFalse(source.contains("\"Step \\("),
                           "\(file) welds the English counter — a translated flow cannot reach it")
            XCTAssertTrue(source.contains("StepCounterLabel.text"),
                          "\(file) resolves the counter through the shared entry point")
        }
    }

    /// The rail counter substitutes through the shared brace vocabulary.
    func testRailCounterSubstitutesThroughTheSharedVocabulary() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Preset Layouts/Preset6+RailSteps.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(source.contains("StepCounterLabel.format"),
                      "the rail substitutes through the shared vocabulary, so {n} works here too")
        XCTAssertFalse(source.contains("replacingOccurrences(of: \"{current}\""),
                       "a private substitution is how the vocabulary drifted in the first place")
    }

    /// P6's footer counter resolves through the sidecar keys.
    func testPreset6FooterCounterIsLocalizable() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Preset Layouts/Preset6+FooterAndIntroOutro.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(source.contains("StepCounterLabel.template"),
                      "P6's counter resolves through the sidecar keys, not a hardcoded string")
        XCTAssertFalse(source.contains("metaText: \"Step \\("),
                       "the bare interpolation must not come back")
    }

    /// Every counter substitutes through `StepCounterLabel`, directly or by assembling a `StepCounter`.
    func testAllStepCountersUseTheSharedVocabulary() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Preset Layouts")
        // Preset5.swift states no counter; the card's is in `Preset5+CardSteps.swift`.
        for file in ["Preset5+CardSteps.swift", "Preset6+FooterAndIntroOutro.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            XCTAssertTrue(source.contains("StepCounterLabel.format") || source.contains("StepCounter("),
                          "\(file) substitutes through the shared vocabulary, directly or via the module")
        }
    }

    /// Step dots draw only up to the cap; past it the "N of M" text carries position alone.
    func testStepDotsDrawOnlyUpToTheCap() {
        XCTAssertEqual(StepDotIndicator.maximumDots, 8,
                       "the cap is a design decision — changing it is a design change")

        XCTAssertTrue(StepDotIndicator.drawsDots(total: 6), "a short flow gets dots")
        XCTAssertTrue(StepDotIndicator.drawsDots(total: 8), "the cap itself still draws")
        XCTAssertFalse(StepDotIndicator.drawsDots(total: 9), "one past the cap stops")
        XCTAssertFalse(StepDotIndicator.drawsDots(total: 20),
                       "capability-tour's 20 steps would be a second navigation, not a glance")

        // One step: a lone dot states nothing.
        XCTAssertFalse(StepDotIndicator.drawsDots(total: 1))
        XCTAssertFalse(StepDotIndicator.drawsDots(total: 0))
    }

    // MARK: - heroColumn splits into hero + stack

    /// Hero and stack together hold every placement exactly once, including a second cell at `row: 0`.
    func testHeroColumnSplitPlacesEveryCellIncludingASecondRowZero() throws {
        // A columnSpan sends `placements` down the authored branch, where a cell's own `row` is honoured.
        let cells = [
            try Self.heroTestCell(id: "alpha",   row: 0, columnSpan: 1),
            try Self.heroTestCell(id: "bravo",   row: 0),
            try Self.heroTestCell(id: "charlie", row: 1),
            try Self.heroTestCell(id: "delta",   row: 2)
        ]
        let placements = BentoHeroArrangement.placements(for: cells, kind: .heroColumn)
        XCTAssertEqual(placements.count, 4, "every authored cell must get a placement")

        let hero = try XCTUnwrap(BentoHeroArrangement.heroPlacement(in: placements))
        let stacked = BentoHeroArrangement.stackedPlacements(in: placements)

        XCTAssertEqual(hero.cellIndex, 0, "the FIRST row-0 cell is the hero")
        XCTAssertEqual(stacked.count, 3, "the other three all belong to the stack")

        let placed = Set([hero.cellIndex] + stacked.map(\.cellIndex))
        XCTAssertEqual(placed, [0, 1, 2, 3], "no cell may be dropped by the split")
        XCTAssertFalse(stacked.contains { $0.cellIndex == hero.cellIndex },
                       "the hero must not also be stacked")
    }

    /// The ordinary path still behaves: one hero, the rest stacked in row order.
    func testHeroColumnSplitOnTheUnauthoredPath() throws {
        let cells = try (0..<3).map { try Self.heroTestCell(id: "c\($0)", row: $0) }
        let placements = BentoHeroArrangement.placements(for: cells, kind: .heroColumn)
        let hero = BentoHeroArrangement.heroPlacement(in: placements)
        let stacked = BentoHeroArrangement.stackedPlacements(in: placements)

        XCTAssertEqual(hero?.cellIndex, 0)
        XCTAssertEqual(stacked.map(\.cellIndex), [1, 2], "stack stays top-to-bottom by row")
    }

    // MARK: - Dropped-key advisory

    /// Which renderer each arrangement and row maps to.
    func testRendererMappingPerArrangementAndRow() {
        XCTAssertEqual(BentoHeroArrangement.renderer(row: 0, kind: .heroRow), .hero)
        XCTAssertEqual(BentoHeroArrangement.renderer(row: 1, kind: .heroRow), .supporting)
        XCTAssertEqual(BentoHeroArrangement.renderer(row: 0, kind: .heroColumn), .statProminent)
        XCTAssertEqual(BentoHeroArrangement.renderer(row: 2, kind: .heroColumn), .statStacked)
    }

    /// Each renderer ignores a different set of fields, asserted per renderer.
    func testIgnoredFieldsDifferPerRenderer() throws {
        let cell = try Self.heroTestCellWithFurniture(id: "c", row: 0)

        // heroCell draws title/subtitle/rows/image — the furniture is dropped.
        XCTAssertEqual(Set(BentoHeroArrangement.ignoredFields(cell, renderer: .hero)),
                       ["label", "sfSymbol", "badge", "meta", "actionLabel"])
        // supportingCell is the one tile that draws badge/meta/actionLabel.
        XCTAssertEqual(Set(BentoHeroArrangement.ignoredFields(cell, renderer: .supporting)),
                       ["label", "sfSymbol", "imagePath"])
        // statTile draws the chip and eyebrow, and no furniture at all.
        XCTAssertEqual(Set(BentoHeroArrangement.ignoredFields(cell, renderer: .statProminent)),
                       ["badge", "meta", "actionLabel", "imagePath"])
    }

    /// A stacked stat tile drops `subtitle`; the prominent one keeps it.
    func testStackedStatTileAlsoDropsSubtitle() throws {
        let withSubtitle = try Self.heroTestCellWithFurniture(id: "c", row: 1)
        XCTAssertTrue(BentoHeroArrangement.ignoredFields(withSubtitle, renderer: .statStacked)
            .contains("subtitle"))
        XCTAssertFalse(BentoHeroArrangement.ignoredFields(withSubtitle, renderer: .statProminent)
            .contains("subtitle"))

        // No subtitle authored, nothing dropped.
        let without = try Self.heroTestCellWithFurniture(id: "c", row: 1, subtitle: false)
        XCTAssertFalse(BentoHeroArrangement.ignoredFields(without, renderer: .statStacked)
            .contains("subtitle"))
    }

    /// The advisory names offending cells by id and is silent for a clean config.
    func testDroppedFieldAdvisoryNamesCellsAndIsSilentWhenClean() throws {
        let hero = try Self.heroTestCellWithFurniture(id: "heroCell", row: 0)
        let advisory = BentoHeroArrangement.droppedFieldAdvisory(for: [hero], kind: .heroRow)
        let text = try XCTUnwrap(advisory)
        XCTAssertTrue(text.contains("heroCell"), "advisory must name the cell: \(text)")
        XCTAssertTrue(text.contains("actionLabel"), "advisory must name the key: \(text)")

        // In a supporting row actionLabel draws, so it is not named. With no spans, row is derived from
        // index, so a plain lead cell takes the hero slot.
        let supporting = try Self.heroTestCellWithFurniture(id: "supportCell", row: 1)
        let supportingText = try XCTUnwrap(BentoHeroArrangement.droppedFieldAdvisory(
            for: [Self.heroTestCell(id: "leadCell"), supporting], kind: .heroRow))
        XCTAssertTrue(supportingText.contains("supportCell"),
                      "the supporting cell still drops label/sfSymbol: \(supportingText)")
        XCTAssertFalse(supportingText.contains("actionLabel"),
                       "actionLabel draws on a supporting cell: \(supportingText)")

        // A cell authoring only what every tile draws gets no advisory.
        XCTAssertNil(BentoHeroArrangement.droppedFieldAdvisory(
            for: [try Self.heroTestCell(id: "plain")], kind: .heroRow))
    }

    /// The advisory is logged once and latches.
    func testDroppedFieldAdvisoryLatchesAfterFirstSay() throws {
        let previous = BentoHeroArrangement.droppedFieldAdvisoryLogged
        defer { BentoHeroArrangement.droppedFieldAdvisoryLogged = previous }

        BentoHeroArrangement.droppedFieldAdvisoryLogged = false
        let cell = try Self.heroTestCellWithFurniture(id: "c", row: 0)
        BentoHeroArrangement.logDroppedFieldAdvisoryOnce(cells: [cell], kind: .heroRow)
        XCTAssertTrue(BentoHeroArrangement.droppedFieldAdvisoryLogged,
                      "an advisory that had something to say must latch")

        // A clean config does not latch, so a later offending step is still reported.
        BentoHeroArrangement.droppedFieldAdvisoryLogged = false
        BentoHeroArrangement.logDroppedFieldAdvisoryOnce(
            cells: [try Self.heroTestCell(id: "plain")], kind: .heroRow)
        XCTAssertFalse(BentoHeroArrangement.droppedFieldAdvisoryLogged)
    }

    // MARK: - Semantic bento surfaces

    /// The semantic tints parse by name.
    func testSemanticSurfacesParse() {
        XCTAssertEqual(BentoSurface(configValue: "success"), .success)
        XCTAssertEqual(BentoSurface(configValue: "warning"), .warning)
        XCTAssertEqual(BentoSurface(configValue: "info"), .info)
        XCTAssertEqual(BentoSurface(configValue: "accent"), .accent)
        XCTAssertEqual(BentoSurface(configValue: "nonsense"), .neutral,
                       "an unrecognised surface must fall back, never blank the cell")
    }

    /// Rotation cycles only the original four surfaces, so unstyled cells keep their tints.
    func testRotationStillCyclesTheOriginalFourOnly() {
        let got = (0..<8).map { BentoSurface.rotating(index: $0) }
        XCTAssertEqual(got, [.accent, .cool, .warm, .neutral,
                             .accent, .cool, .warm, .neutral],
                       "adding semantic surfaces must NOT change what an unauthored cell gets")
    }

    /// `tint(accent:palette:)` hue-shifts `cool`/`warm` like `fill`. Compared via NSColor sRGB components.
    func testTintHueShiftsCoolAndWarmLikeFill() {
        let accent = Color(red: 0.20, green: 0.45, blue: 0.85)
        let palette = ResolvedPalette.default

        func components(_ color: Color) -> (CGFloat, CGFloat, CGFloat) {
            let c = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
            return (c.redComponent, c.greenComponent, c.blueComponent)
        }

        let accentTint = components(BentoSurface.accent.tint(accent: accent, palette: palette))
        let coolTint = components(BentoSurface.cool.tint(accent: accent, palette: palette))
        let warmTint = components(BentoSurface.warm.tint(accent: accent, palette: palette))

        XCTAssertTrue(coolTint != accentTint,
                      "cool must be a hue-shifted sibling of accent, not the raw accent")
        XCTAssertTrue(warmTint != accentTint,
                      "warm must be a hue-shifted sibling of accent, not the raw accent")

        let successTint = components(BentoSurface.success.tint(accent: accent, palette: palette))
        let expectedSuccess = components(palette.success)
        XCTAssertEqual(successTint.0, expectedSuccess.0, accuracy: 0.001)
        XCTAssertEqual(successTint.1, expectedSuccess.1, accuracy: 0.001)
        XCTAssertEqual(successTint.2, expectedSuccess.2, accuracy: 0.001)
    }

    // MARK: - plain-simple construction

    func testPlainSimpleResolvesOnPreset1WithItsOwnSize() {
        let c = InspectSizes.Construction(rawValue: "plain-simple")
        XCTAssertEqual(c, .plainSimple, "the raw value is hyphenated and must be declared explicitly")
        XCTAssertEqual(c?.size, CGSize(width: 800, height: 600),
                       "600: the shell hosts the migration bodies "
                       + "too, and the list's card ceiling is derived from the window, so the "
                       + "688 that once kept two-line rows off the band is no longer needed")
        XCTAssertTrue(c?.engines.contains("preset1") ?? false,
                      "a case without its engines row resolves to the default and the size stays put — "
                      + "a failure with no symptom")
    }

    func testPlainSimpleIsNotAnyEnginesDefault() {
        for engine in ["preset1", "preset4", "preset5", "preset6"] {
            XCTAssertNotEqual(InspectSizes.Construction.defaultConstruction(forEngine: engine),
                              .plainSimple,
                              "plain-simple is opt-in; no existing flow may move to it")
        }
    }

    // MARK: - plain-centered construction

    /// plain-centered resolves on Preset 1 with its own size and engines row.
    func testPlainCenteredResolvesOnPreset1WithItsOwnSize() {
        let c = InspectSizes.Construction(rawValue: "plain-centered")
        XCTAssertEqual(c, .plainCentered, "the raw value is hyphenated and must be declared explicitly")
        XCTAssertEqual(c?.size, CGSize(width: 800, height: 688),
                       "the design's own number (its artboards are titled \"800 × 688\"); "
                       + "plain-simple is 800 × 600, a different design")
        XCTAssertTrue(c?.engines.contains("preset1") ?? false,
                      "a case without its engines row resolves to the default and the size stays "
                      + "put — a failure with no symptom")
    }

    /// plain-centered is not any engine's default.
    func testPlainCenteredIsNotAnyEnginesDefault() {
        for engine in ["preset1", "preset4", "preset5", "preset6"] {
            XCTAssertNotEqual(InspectSizes.Construction.defaultConstruction(forEngine: engine),
                              .plainCentered,
                              "plain-centered is opt-in; no existing flow may move to it")
        }
    }

    // MARK: - plain-branded construction

    /// plain-branded resolves on Preset 1 with its own size and engines row.
    func testPlainBrandedResolvesOnPreset1WithItsOwnSize() {
        let c = InspectSizes.Construction(rawValue: "plain-branded")
        XCTAssertEqual(c, .plainBranded, "the raw value is hyphenated and must be declared explicitly")
        XCTAssertEqual(InspectSizes.Construction(rawValue: "plain-fruitcorp"), .plainBranded,
                       "the name this construction shipped under still decodes")
        XCTAssertEqual(c?.size, CGSize(width: 800, height: 600), "the measured window")
        XCTAssertTrue(c?.engines.contains("preset1") ?? false,
                      "a case without its engines row resolves to the default and the size stays "
                      + "put — a failure with no symptom")
    }

    /// plain-branded is not any engine's default.
    func testPlainBrandedIsNotAnyEnginesDefault() {
        for engine in ["preset1", "preset4", "preset5", "preset6"] {
            XCTAssertNotEqual(InspectSizes.Construction.defaultConstruction(forEngine: engine),
                              .plainBranded,
                              "plain-branded is opt-in; no existing flow may move to it")
        }
    }

    // MARK: - GradientTileRamp
    // The pure HSB derivation behind `GradientIconTile`.

    /// The hero ramp has three stops, the row ramp two.
    func testHeroRampHasThreeStopsRowRampHasTwo() {
        let accent = Color(hex: "#2f4ec9")
        XCTAssertEqual(GradientTileRamp.hero(from: accent).count, 3)
        XCTAssertEqual(GradientTileRamp.row(from: accent).count, 2)
    }

    /// sRGB components, 0...1.
    private func srgb(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        return (c.redComponent, c.greenComponent, c.blueComponent)
    }

    /// Each ramp darkens monotonically (by `.luminance`).
    func testRampDarkensMonotonically() throws {
        for accentHex in ["#2f4ec9", "#c9432f", "#2fc96b"] {
            let accent = Color(hex: accentHex)
            let hero = GradientTileRamp.hero(from: accent).map(\.luminance)
            XCTAssertGreaterThan(hero[0], hero[1], "\(accentHex): hero stop 0→52% must darken")
            XCTAssertGreaterThan(hero[1], hero[2], "\(accentHex): hero stop 52%→100% must darken")

            let row = GradientTileRamp.row(from: accent).map(\.luminance)
            XCTAssertGreaterThan(row[0], row[1], "\(accentHex): row stop 0→100% must darken")
        }
    }

    /// The design's accent `#2f4ec9` reproduces the design's stops: endpoints exactly, the
    /// interpolated hero 52% stop within a wider tolerance.
    func testMidBlueAccentMatchesDesignLiteralsWithinTolerance() throws {
        let accent = Color(hex: "#2f4ec9")
        let hero = GradientTileRamp.hero(from: accent)
        let row = GradientTileRamp.row(from: accent)

        func assertClose(_ got: Color, hex: String, tolerance: CGFloat, _ label: String) {
            let g = srgb(got)
            let t = srgb(Color(hex: hex))
            XCTAssertEqual(g.r, t.r, accuracy: tolerance, "\(label) red")
            XCTAssertEqual(g.g, t.g, accuracy: tolerance, "\(label) green")
            XCTAssertEqual(g.b, t.b, accuracy: tolerance, "\(label) blue")
        }

        // Endpoints: tight tolerance.
        assertClose(hero[0], hex: "#3f7ff2", tolerance: 0.004, "hero 0%")
        assertClose(hero[2], hex: "#0d2a72", tolerance: 0.004, "hero 100%")
        assertClose(row[0], hex: "#2f5fc4", tolerance: 0.004, "row 0%")
        assertClose(row[1], hex: "#0d2a72", tolerance: 0.004, "row 100%")

        // The interpolated stop drifts ~0.029 in the worst channel.
        assertClose(hero[1], hex: "#1c47a8", tolerance: 0.04, "hero 52%")
    }


    // MARK: - Language picker seed

    /// A localized flow whose first step carries the language picker (`value: "English"`).
    @MainActor
    private func languagePickerState(defaultLanguage: String?, pickerValue: String?,
                                     pickerType: String = "dropdown") throws -> InspectState {
        let state = InspectState()
        let def = defaultLanguage.map { ",\"defaultLanguage\":\"\($0)\"" } ?? ""
        let val = pickerValue.map { ",\"value\":\"\($0)\"" } ?? ""
        state.config = try JSONDecoder().decode(InspectConfig.self, from: Data("""
        {"preset":6,"chrome":"card",
         "localization":{"languages":{"English":"/tmp/en.json","Deutsch":"/tmp/de.json"},
                         "selectionKey":"preferredLanguage"\(def)},
         "introSteps":[{"id":"detected","title":"Welcome","content":[
            {"type":"\(pickerType)","id":"preferredLanguage","content":"Language",
             "options":["English","Deutsch"]\(val)},
            {"type":"dropdown","id":"browser","content":"Browser",
             "options":["Safari","Chrome"],"value":"Chrome"}]}]}
        """.utf8))
        state.initializeGuidanceFormState(for: "detected")
        return state
    }

    /// The picker seeds the resolved `defaultLanguage`, not its authored value.
    @MainActor
    func testLanguagePickerSeedsResolvedDefaultOverAuthoredValue() throws {
        let state = try languagePickerState(defaultLanguage: "Deutsch", pickerValue: "English")
        XCTAssertEqual(state.guidanceFormInputs["detected"]?.dropdowns["preferredLanguage"], "Deutsch")
        XCTAssertEqual(state.guidanceFormInputs["detected"]?.dropdowns["browser"], "Chrome",
                       "a dropdown that is not the language picker keeps its authored value")
    }

    @MainActor
    func testLanguagePickerSeedsDefaultWhenNoValueAuthored() throws {
        let state = try languagePickerState(defaultLanguage: "Deutsch", pickerValue: nil)
        XCTAssertEqual(state.guidanceFormInputs["detected"]?.dropdowns["preferredLanguage"], "Deutsch")
    }

    @MainActor
    func testLanguagePickerKeepsAuthoredValueWithoutDefault() throws {
        let state = try languagePickerState(defaultLanguage: nil, pickerValue: "English")
        XCTAssertEqual(state.guidanceFormInputs["detected"]?.dropdowns["preferredLanguage"], "English")
    }

    /// A default that is not among the picker's options (including `auto`) leaves the authored value.
    @MainActor
    func testLanguagePickerIgnoresDefaultNotAmongOptions() throws {
        let state = try languagePickerState(defaultLanguage: "Français", pickerValue: "English")
        XCTAssertEqual(state.guidanceFormInputs["detected"]?.dropdowns["preferredLanguage"], "English")
    }

    @MainActor
    func testLanguageRadioSeedsResolvedDefault() throws {
        let state = try languagePickerState(defaultLanguage: "Deutsch", pickerValue: "English",
                                            pickerType: "radio")
        XCTAssertEqual(state.guidanceFormInputs["detected"]?.radios["preferredLanguage"], "Deutsch")
        XCTAssertNil(state.guidanceFormInputs["detected"]?.dropdowns["preferredLanguage"])
    }

}

private func != (lhs: (CGFloat, CGFloat, CGFloat), rhs: (CGFloat, CGFloat, CGFloat)) -> Bool {
    abs(lhs.0 - rhs.0) > 0.001 || abs(lhs.1 - rhs.1) > 0.001 || abs(lhs.2 - rhs.2) > 0.001
}


// MARK: - Unknown-key detector

/// A key the decoder does not read is reported, naming key and owner, at each of the seven scopes
/// routed through `unknownKeys(in:against:)`. The known-key sets are also held against the source.
final class ConfigUnknownKeyTests: XCTestCase {

    private func decodeCollectingWarnings(_ json: String) throws -> [String] {
        InspectConfig.unknownKeyWarnings = []
        _ = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let warnings = InspectConfig.unknownKeyWarnings
        InspectConfig.unknownKeyWarnings = []
        return warnings
    }

    // MARK: behavioral

    func testUnknownKeysAreReportedAtRootStepAndBlockScope() throws {
        let warnings = try decodeCollectingWarnings("""
        { "preset": "5", "bogusRootKey": 1,
          "introSteps": [
            { "id": "s1", "stepType": "intro", "bogusStepKey": "wrong-model key",
              "content": [ { "type": "text", "content": "hi", "bogusBlockKey": true } ] } ] }
        """)
        XCTAssertTrue(warnings.contains { $0.contains("bogusRootKey") && $0.contains("root") }, "\(warnings)")
        XCTAssertTrue(warnings.contains { $0.contains("bogusStepKey") && $0.contains("step 's1'") }, "\(warnings)")
        XCTAssertTrue(warnings.contains { $0.contains("bogusBlockKey") && $0.contains("step 's1'") }, "\(warnings)")
    }

    /// `preset` is a root key: on an item it is reported like any other key nothing reads, while
    /// at root it stays silent.
    func testPresetOnAnItemIsReportedAsUnknown() throws {
        let warnings = try decodeCollectingWarnings("""
        { "preset": "1", "items": [ { "id": "a", "title": "A", "preset": "1" } ] }
        """)
        XCTAssertEqual(warnings.filter { $0.contains("'preset'") }, ["Unknown key 'preset' in item 'a'"])
    }

    /// Unknown keys are reported on root `steps[]` and the `guidanceContent[]` spelling too.
    func testUnknownKeysAreReportedOnStepsAndTheGuidanceContentSpelling() throws {
        let warnings = try decodeCollectingWarnings("""
        { "preset": "6",
          "steps": [
            { "id": "s1", "stepType": "intro", "bogusStepKey": 1,
              "guidanceContent": [ { "type": "text", "content": "hi", "bogusBlockKey": true } ] } ] }
        """)
        XCTAssertTrue(warnings.contains { $0.contains("bogusStepKey") && $0.contains("step 's1'") }, "\(warnings)")
        XCTAssertTrue(warnings.contains { $0.contains("bogusBlockKey") && $0.contains("step 's1'") }, "\(warnings)")
    }

    /// Unknown keys are reported on `introScreen` and inside its content blocks.
    func testUnknownKeysAreReportedOnTheIntroScreen() throws {
        let warnings = try decodeCollectingWarnings("""
        { "preset": "2", "title": "t",
          "introScreen": { "title": "Welcome", "userBadg": true,
                           "content": [ { "type": "text", "content": "hi", "bogusBlockKey": 1 } ] } }
        """)
        XCTAssertTrue(warnings.contains { $0.contains("userBadg") && $0.contains("introScreen") },
                      "screen-level typo on introScreen not reported: \(warnings)")
        XCTAssertTrue(warnings.contains { $0.contains("bogusBlockKey") && $0.contains("introScreen") },
                      "block-level typo inside introScreen.content not reported: \(warnings)")
    }

    /// Unknown keys are reported on `summaryScreen`.
    func testUnknownKeysAreReportedOnTheSummaryScreen() throws {
        let warnings = try decodeCollectingWarnings("""
        { "preset": "2", "title": "t",
          "summaryScreen": { "title": "Done", "dockDeclne": {"label": "typo"} } }
        """)
        XCTAssertTrue(warnings.contains { $0.contains("dockDeclne") && $0.contains("summaryScreen") },
                      "\(warnings)")
    }

    /// Underscore-prefixed keys (`_comment`, `_ui.*`) are tolerated at every scope.
    func testUnderscorePrefixedKeysAreToleratedAtEveryScope() throws {
        let warnings = try decodeCollectingWarnings("""
        { "preset": "2", "title": "t", "_comment": "root note", "_ui.title": "ignored",
          "summaryScreen": { "title": "Done", "_comment": "outro note",
                             "content": [ { "type": "text", "content": "hi", "_comment": "block note" } ] },
          "items": [ { "id": "i1", "displayName": "One", "_comment": "item note",
                       "guidanceContent": [ { "type": "text", "content": "hi", "_comment": "item block" } ] } ],
          "steps": [ { "id": "s1", "stepType": "intro", "_comment": "step note",
                       "items": [ { "id": "r1", "displayName": "Row", "_comment": "row note" } ],
                       "guidanceContent": [ { "type": "text", "content": "hi", "_comment": "step block" } ] } ] }
        """)
        XCTAssertTrue(warnings.isEmpty, "underscore-prefixed keys still warn somewhere: \(warnings)")
    }

    /// `guidanceTitle` on a step folds into `title` and is not unknown.
    func testStepLevelGuidanceAliasesAreNoLongerUnknownKeys() throws {
        let warnings = try decodeCollectingWarnings("""
        { "preset": "5",
          "introSteps": [ { "id": "s1", "stepType": "intro", "guidanceTitle": "Hello" } ] }
        """)
        XCTAssertFalse(warnings.contains { $0.contains("guidanceTitle") },
                       "guidanceTitle is a folded alias now, not an unknown key: \(warnings)")
    }

    func testUnknownKeysAreReportedAtItemAndItemBlockScope() throws {
        let warnings = try decodeCollectingWarnings("""
        { "preset": "6",
          "items": [
            { "id": "i1", "displayName": "One", "bogusItemKey": 2,
              "guidanceContent": [ { "type": "text", "content": "hi", "bogusBlockKey": 4 } ] } ] }
        """)
        XCTAssertTrue(warnings.contains { $0.contains("bogusItemKey") && $0.contains("item 'i1'") }, "\(warnings)")
        XCTAssertTrue(warnings.contains { $0.contains("bogusBlockKey") && $0.contains("item 'i1'") }, "\(warnings)")
    }

    /// `chrome` (root) and `group` (item) are real keys and must not warn.
    func testChromeAndGroupAreKnownKeys() throws {
        let warnings = try decodeCollectingWarnings("""
        { "preset": "6", "chrome": "card",
          "items": [ { "id": "i1", "displayName": "One", "group": "Text" } ] }
        """)
        XCTAssertTrue(warnings.isEmpty, "clean config warned: \(warnings)")
    }

    /// `bentoLayout` is a known block key.
    func testBentoLayoutIsAKnownBlockKey() throws {
        let warnings = try decodeCollectingWarnings("""
        { "preset": "6", "steps": [
            { "id": "s1", "stepType": "intro", "title": "T",
              "guidanceContent": [ { "type": "bento-grid", "bentoLayout": "summary",
                "bentoCells": [ { "id": "c1", "column": 0, "row": 0, "contentType": "icon",
                                   "sfSymbol": "gearshape", "title": "T" } ] } ] } ] }
        """)
        XCTAssertTrue(warnings.isEmpty, "bentoLayout on a block warned: \(warnings)")
    }

    // MARK: parity against source

    private func repoSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // dialogTests/
            .deletingLastPathComponent() // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Body of the first `{...}` after `marker`, brace-matched.
    private func braceBody(of source: String, after marker: String) -> Substring? {
        guard let declRange = source.range(of: marker),
              let open = source[declRange.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 1
        var i = source.index(after: open)
        let start = i
        while depth > 0, i < source.endIndex {
            if source[i] == "{" { depth += 1 } else if source[i] == "}" { depth -= 1 }
            i = source.index(after: i)
        }
        return source[start..<source.index(before: i)]
    }

    /// Stored `let`/`var` names at 8-space indent, skipping nested types and computed properties.
    private func storedPropertyNames(in source: String, structName: String) throws -> Set<String> {
        guard let body = braceBody(of: source, after: "struct \(structName)") else { return [] }
        let re = try NSRegularExpression(pattern: "^ {8}(?:let|var) ([A-Za-z_][A-Za-z0-9_]*)\\s*:")
        var names = Set<String>()
        var nestedDepth = 0
        for rawLine in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if nestedDepth == 0,
               !line.trimmingCharacters(in: .whitespaces).hasSuffix("{"),
               let match = re.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let nameRange = Range(match.range(at: 1), in: line) {
                names.insert(String(line[nameRange]))
            }
            let opens = line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count
            nestedDepth = max(0, nestedDepth + opens)
        }
        return names
    }

    /// JSON key per `case` of the first `enum CodingKeys` after `structName` (raw value if
    /// present, else the case name; multi-case lines supported).
    private func codingKeyNames(in source: String, afterStruct structName: String) -> Set<String> {
        guard let structLoc = source.range(of: "struct \(structName)"),
              let enumLoc = source.range(of: "enum CodingKeys",
                                         range: structLoc.upperBound..<source.endIndex),
              let body = braceBody(of: String(source[enumLoc.lowerBound...]), after: "enum CodingKeys")
        else { return [] }
        var names = Set<String>()
        for rawLine in body.split(separator: "\n") {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("case ") else { continue }
            if let comment = line.range(of: "//") { line = String(line[..<comment.lowerBound]) }
            for entry in line.dropFirst(5).split(separator: ",") {
                let piece = entry.trimmingCharacters(in: .whitespaces)
                if let eq = piece.range(of: "=") {
                    let raw = piece[eq.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: " \""))
                    if !raw.isEmpty { names.insert(raw) }
                } else if !piece.isEmpty {
                    names.insert(piece)
                }
            }
        }
        return names
    }

    func testKnownStepKeysMatchIntroStepDeclarationsExactly() throws {
        let source = try repoSource("dialog/Views/Inspect/Core Framework/InspectConfig+Steps.swift")
        let declared = try storedPropertyNames(in: source, structName: "IntroStep")
        XCTAssertFalse(declared.isEmpty)
        let missing = declared.subtracting(InspectConfig.knownStepKeys)
        let stale = InspectConfig.knownStepKeys.subtracting(declared)
        XCTAssertTrue(missing.isEmpty, "IntroStep fields missing from knownStepKeys: \(missing.sorted())")
        XCTAssertTrue(stale.isEmpty, "knownStepKeys entries with no IntroStep field: \(stale.sorted())")
    }

    /// The intro-screen known keys equal its stored properties, in both directions.
    func testKnownIntroScreenKeysMatchDeclarationsExactly() throws {
        let source = try repoSource("dialog/Views/Inspect/Core Framework/InspectConfig+CommonTypes.swift")
        let declared = try storedPropertyNames(in: source, structName: "PresetIntroScreen")
        XCTAssertFalse(declared.isEmpty, "no stored properties parsed out of PresetIntroScreen")
        let missing = declared.subtracting(InspectConfig.knownIntroScreenKeys)
        let stale = InspectConfig.knownIntroScreenKeys.subtracting(declared)
        XCTAssertTrue(missing.isEmpty,
                      "PresetIntroScreen fields missing from knownIntroScreenKeys: \(missing.sorted())")
        XCTAssertTrue(stale.isEmpty,
                      "knownIntroScreenKeys entries with no PresetIntroScreen field: \(stale.sorted())")
    }

    /// The summary-screen known keys equal its stored properties, in both directions.
    func testKnownSummaryScreenKeysMatchDeclarationsExactly() throws {
        let source = try repoSource("dialog/Views/Inspect/Core Framework/InspectConfig+CommonTypes.swift")
        let declared = try storedPropertyNames(in: source, structName: "PresetSummaryScreen")
        XCTAssertFalse(declared.isEmpty, "no stored properties parsed out of PresetSummaryScreen")
        let missing = declared.subtracting(InspectConfig.knownSummaryScreenKeys)
        let stale = InspectConfig.knownSummaryScreenKeys.subtracting(declared)
        XCTAssertTrue(missing.isEmpty,
                      "PresetSummaryScreen fields missing from knownSummaryScreenKeys: \(missing.sorted())")
        XCTAssertTrue(stale.isEmpty,
                      "knownSummaryScreenKeys entries with no PresetSummaryScreen field: \(stale.sorted())")
    }

    func testKnownBlockKeysMatchGuidanceContentDeclarationsExactly() throws {
        let source = try repoSource("dialog/Views/Inspect/Core Framework/InspectConfig+GuidanceContent.swift")
        let declared = try storedPropertyNames(in: source, structName: "GuidanceContent")
        XCTAssertFalse(declared.isEmpty)
        let missing = declared.subtracting(InspectConfig.knownBlockKeys)
        let stale = InspectConfig.knownBlockKeys.subtracting(declared)
        XCTAssertTrue(missing.isEmpty, "GuidanceContent fields missing from knownBlockKeys: \(missing.sorted())")
        XCTAssertTrue(stale.isEmpty, "knownBlockKeys entries with no GuidanceContent field: \(stale.sorted())")
    }

    func testEveryRootCodingKeyIsKnown() throws {
        let source = try repoSource("dialog/Views/Inspect/Core Framework/InspectConfig.swift")
        let keys = codingKeyNames(in: source, afterStruct: "InspectConfig")
        XCTAssertFalse(keys.isEmpty)
        let missing = keys.subtracting(InspectConfig.knownRootKeys)
        XCTAssertTrue(missing.isEmpty, "root CodingKeys missing from knownRootKeys: \(missing.sorted())")
    }

    func testEveryItemCodingKeyIsKnown() throws {
        let source = try repoSource("dialog/Views/Inspect/Core Framework/InspectConfig+Items.swift")
        let keys = codingKeyNames(in: source, afterStruct: "ItemConfig")
        XCTAssertFalse(keys.isEmpty)
        let missing = keys.subtracting(InspectConfig.knownItemKeys)
        XCTAssertTrue(missing.isEmpty, "item CodingKeys missing from knownItemKeys: \(missing.sorted())")
    }

    /// Every `ListItem` CodingKey is known (one-directional: its decoder accepts extras).
    func testEveryListItemCodingKeyIsKnown() throws {
        let source = try repoSource("dialog/Views/Inspect/Core Framework/InspectConfig+ListItem.swift")
        let keys = codingKeyNames(in: source, afterStruct: "ListItem")
        XCTAssertFalse(keys.isEmpty, "ListItem CodingKeys were not found — did the struct move?")
        let missing = keys.subtracting(InspectConfig.knownListItemKeys)
        XCTAssertTrue(missing.isEmpty,
                      "ListItem CodingKeys missing from knownListItemKeys: \(missing.sorted())")
    }

    /// The two accepted aliases (`title`, `stepType`) stay known.
    func testListItemKnownKeysCarryTheTwoDeliberateAliases() {
        XCTAssertTrue(InspectConfig.knownListItemKeys.contains("title"),
                      "'title' is the displayName alias every item type accepts")
        XCTAssertTrue(InspectConfig.knownListItemKeys.contains("stepType"),
                      "'stepType' stays known while its row-kind spellings fold into 'kind'")
    }

    // MARK: parity against the schema

    // MARK: - Root-key parity

    /// Every known root key is declared in the schema except `buttonStyle` (deprecated, discarded at
    /// decode) and `button2disabled` (a classic CLI argument tolerated at root).
    func testEveryKnownRootKeyIsInTheSchemaExceptTheTwoDeliberateExtras() throws {
        let schema = try schemaObject()
        let props = Set((schema["properties"] as? [String: Any] ?? [:]).keys)
        XCTAssertFalse(props.isEmpty, "root properties must be readable for this to mean anything")

        let tolerated: Set<String> = ["buttonStyle", "button2disabled"]
        let missing = InspectConfig.knownRootKeys.subtracting(props).subtracting(tolerated)
        XCTAssertEqual(missing, [],
                       "root keys the decoder accepts but the schema never mentions — add them to "
                       + "the schema, or to the tolerated list with a reason: \(missing.sorted())")
    }

    /// Every schema root property is a known root key.
    func testEverySchemaRootPropertyIsAKnownRootKey() throws {
        let schema = try schemaObject()
        let props = Set((schema["properties"] as? [String: Any] ?? [:]).keys)
        let unknown = props.subtracting(InspectConfig.knownRootKeys)
        XCTAssertEqual(unknown, [],
                       "the schema advertises root keys the decoder warns about: \(unknown.sorted())")
    }

    /// Every stepType has exactly one schema branch, and `standard` alone matches an absent stepType.
    func testEveryStepTypeHasExactlyOneSchemaBranch() throws {
        let defs = try schemaObject()["definitions"] as? [String: Any] ?? [:]
        let base = (defs["StepBase"] as? [String: Any])?["properties"] as? [String: Any]
        let types = Set((base?["stepType"] as? [String: Any])?["enum"] as? [String] ?? [])
        let branches = (defs["IntroStep"] as? [String: Any])?["oneOf"] as? [[String: Any]] ?? []
        XCTAssertFalse(types.isEmpty || branches.isEmpty, "the step definitions must be readable")

        let consts = branches.compactMap {
            (($0["properties"] as? [String: Any])?["stepType"] as? [String: Any])?["const"] as? String
        }
        XCTAssertEqual(consts.sorted(), types.sorted(), "one branch per stepType, no more, no less")
        let acceptsAbsent = branches.filter { !(($0["required"] as? [String]) ?? []).contains("stepType") }
        XCTAssertEqual(acceptsAbsent.count, 1, "only the 'standard' branch may match a step without stepType")
    }

    private func schemaPath() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // dialogTests/
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
    }

    private func schemaObject() throws -> [String: Any] {
        let data = try Data(contentsOf: schemaPath())
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("inspect-config.schema.json is not a JSON object")
            return [:]
        }
        return object
    }

    // MARK: - plain-simple construction

    /// "plain-simple" is in the parsed `chrome` enum (its description also names it in prose).
    func testPlainSimpleIsAuthorableInTheSchema() throws {
        let schema = try schemaObject()
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let chrome = try XCTUnwrap(properties["chrome"] as? [String: Any])
        let enumValues = try XCTUnwrap(chrome["enum"] as? [String])
        XCTAssertTrue(enumValues.contains("plain-simple"),
                      "a chrome value missing from the closed enum fails validation silently")
        let previousValues = ["plain", "sidebar", "card", "rail", "fixture"]
        for value in previousValues {
            XCTAssertTrue(enumValues.contains(value),
                          "adding plain-simple must not drop an existing chrome value: \(value)")
        }
    }

    // MARK: - plain-centered construction

    /// "plain-centered" is in the parsed `chrome` enum.
    func testPlainCenteredIsAuthorableInTheSchema() throws {
        let schema = try schemaObject()
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let chrome = try XCTUnwrap(properties["chrome"] as? [String: Any])
        let enumValues = try XCTUnwrap(chrome["enum"] as? [String])
        XCTAssertTrue(enumValues.contains("plain-centered"),
                      "a chrome value missing from the closed enum fails validation silently")
        let previousValues = ["plain", "plain-simple", "sidebar", "card", "rail", "fixture"]
        for value in previousValues {
            XCTAssertTrue(enumValues.contains(value),
                          "adding plain-centered must not drop an existing chrome value: \(value)")
        }
        let description = try XCTUnwrap(chrome["description"] as? String)
        XCTAssertTrue(description.contains("plain-centered"),
                      "the description prose must name every enum value, per the schema rule")
    }

    // MARK: - plain-branded construction

    /// "plain-branded" is in the parsed `chrome` enum.
    func testPlainBrandedIsAuthorableInTheSchema() throws {
        let schema = try schemaObject()
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let chrome = try XCTUnwrap(properties["chrome"] as? [String: Any])
        let enumValues = try XCTUnwrap(chrome["enum"] as? [String])
        XCTAssertTrue(enumValues.contains("plain-branded"),
                      "a chrome value missing from the closed enum fails validation silently")
        let previousValues = ["plain", "plain-simple", "plain-centered", "sidebar", "card", "rail", "fixture"]
        for value in previousValues {
            XCTAssertTrue(enumValues.contains(value),
                          "adding plain-branded must not drop an existing chrome value: \(value)")
        }
        let description = try XCTUnwrap(chrome["description"] as? String)
        XCTAssertTrue(description.contains("plain-branded"),
                      "the description prose must name every enum value, per the schema rule")
    }

    // MARK: - Chrome enum parity

    /// The schema's `chrome` enum equals `Construction.allCases` except `toast` (Preset 4's own,
    /// never authored) and `fixture` (retired, still decodes).
    func testChromeEnumMatchesConstructionAllCasesExceptTheDocumentedExceptions() throws {
        let schema = try schemaObject()
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let chrome = try XCTUnwrap(properties["chrome"] as? [String: Any])
        let schemaEnum = Set(try XCTUnwrap(chrome["enum"] as? [String]))

        let constructionValues = Set(InspectSizes.Construction.allCases.map(\.rawValue))

        let notAuthorable: Set<String> = ["toast"]
        let retiredButStillDecodes: Set<String> = ["fixture"]
        let expected = constructionValues.subtracting(notAuthorable).union(retiredButStillDecodes)

        XCTAssertEqual(schemaEnum, expected,
                       "schema chrome enum drifted from Construction.allCases — missing from "
                       + "schema: \(expected.subtracting(schemaEnum).sorted()), present in "
                       + "schema but not expected: \(schemaEnum.subtracting(expected).sorted())")
    }

    /// Every property name declared anywhere in the schema, at any depth. Flat on purpose: it answers
    /// whether a key is discoverable, not where.
    private func schemaDeclaredPropertyNames() throws -> Set<String> {
        var names = Set<String>()
        func walk(_ node: Any) {
            if let dict = node as? [String: Any] {
                for (key, value) in dict {
                    if key == "properties", let properties = value as? [String: Any] {
                        names.formUnion(properties.keys)
                    }
                    walk(value)
                }
            } else if let array = node as? [Any] {
                array.forEach(walk)
            }
        }
        walk(try schemaObject())
        return names
    }

    /// The closed block-type enum at its exact path.
    private func schemaBlockTypeEnum() throws -> Set<String> {
        guard let definitions = try schemaObject()["definitions"] as? [String: Any],
              let guidance = definitions["GuidanceContent"] as? [String: Any],
              let properties = guidance["properties"] as? [String: Any],
              let type = properties["type"] as? [String: Any],
              let values = type["enum"] as? [String]
        else { return [] }
        return Set(values)
    }

    private func structFile(for structName: String) -> String {
        switch structName {
        case "GuidanceContent": return "dialog/Views/Inspect/Core Framework/InspectConfig+GuidanceContent.swift"
        case "IntroStep":       return "dialog/Views/Inspect/Core Framework/InspectConfig+Steps.swift"
        default:                return ""
        }
    }

    /// Fields canonicalization writes and authors never set, each with a reason. Empty: the computed
    /// properties are already excluded by `storedPropertyNames`.
    private let introStepInternalFields: [String: String] = [:]
    private let guidanceContentInternalFields: [String: String] = [:]

    /// Keys `ItemConfig` accepts for tolerance, not as capabilities, each with a reason.
    private let itemConfigToleranceKeys: [String: String] = [
        "windowPosition": "per-item window override tolerance; the authorable key is documented at root",
        "windowPositionOffset": "per-item window override tolerance; the authorable key is documented at root"
    ]

    /// Every stored property `GuidanceContent` and `IntroStep` decode is declared somewhere in the
    /// schema, reported by name. The match is flat and one-directional.
    func testEveryDecodedPropertyIsDeclaredInTheSchema() throws {
        let schema = try schemaDeclaredPropertyNames()
        XCTAssertFalse(schema.isEmpty, "no properties parsed out of the schema — did its shape change?")
        for (structName, exempt) in [("GuidanceContent", guidanceContentInternalFields),
                                     ("IntroStep", introStepInternalFields)] {
            let declared = try storedPropertyNames(in: try repoSource(structFile(for: structName)),
                                               structName: structName)
            XCTAssertFalse(declared.isEmpty, "no stored properties parsed out of \(structName)")
            let missing = declared.subtracting(schema).subtracting(exempt.keys)
            XCTAssertTrue(missing.isEmpty,
                          "\(structName) properties the decoder reads and the schema never declares: "
                          + missing.sorted().joined(separator: ", "))

            // An exemption for a key the schema now declares is stale.
            let stale = Set(exempt.keys).intersection(schema)
            XCTAssertTrue(stale.isEmpty,
                          "\(structName) schema exemptions the schema now declares — delete them: "
                          + stale.sorted().joined(separator: ", "))
        }
    }

    /// Every key `knownItemKeys` accepts is declared on `ItemConfig`'s own definition.
    func testItemConfigAcceptedKeysAreDeclaredOnItsOwnSchemaDefinition() throws {
        guard let definitions = try schemaObject()["definitions"] as? [String: Any],
              let item = definitions["ItemConfig"] as? [String: Any],
              let properties = item["properties"] as? [String: Any]
        else { XCTFail("definitions.ItemConfig.properties did not parse — did it move?"); return }
        let missing = InspectConfig.knownItemKeys
            .subtracting(properties.keys)
            .subtracting(itemConfigToleranceKeys.keys)
        XCTAssertTrue(missing.isEmpty,
                      "keys the item decoder accepts that ItemConfig's own definition never "
                      + "declares: " + missing.sorted().joined(separator: ", "))
    }

    /// `StepBase` does not declare the item-only check keys that `knownStepKeys` rejects.
    func testStepBaseDoesNotDeclareItemOnlyCheckVocabulary() throws {
        guard let definitions = try schemaObject()["definitions"] as? [String: Any],
              let stepBase = definitions["StepBase"] as? [String: Any],
              let properties = stepBase["properties"] as? [String: Any]
        else { XCTFail("definitions.StepBase.properties did not parse — did it move?"); return }
        let ghosts = ["managedPrefDomain", "managedPrefKey", "requirements", "satisfy"]
            .filter { properties.keys.contains($0) }
        XCTAssertTrue(ghosts.isEmpty,
                      "StepBase declares keys no step decodes: \(ghosts.sorted()). They belong to "
                      + "ItemConfig and ListItem, which decode and render them.")
        // The receivers that decode them still declare them.
        for defn in ["ItemConfig", "ListItem"] {
            guard let target = definitions[defn] as? [String: Any],
                  let targetProps = target["properties"] as? [String: Any] else {
                XCTFail("definitions.\(defn).properties did not parse"); return
            }
            let absent = ["managedPrefDomain", "managedPrefKey", "requirements", "satisfy"]
                .filter { !targetProps.keys.contains($0) }
            XCTAssertTrue(absent.isEmpty, "\(defn) lost check vocabulary it decodes: \(absent.sorted())")
        }
    }

    /// The nested row shapes reference real definitions, asserted by the full `$ref` value.
    func testNestedRowShapesReferenceRealDefinitions() throws {
        let schema = try schemaObject()
        guard let definitions = schema["definitions"] as? [String: Any] else {
            XCTFail("definitions did not parse"); return
        }
        // (definition, property, expected $ref target, nested under `items`?)
        let expectations: [(String, String, String, Bool)] = [
            ("GuidanceContent", "checks", "ComparisonCheck", true),
            ("GuidanceContent", "findings", "AdvisoryFinding", true),
            ("StepBase", "receipt", "ReceiptRow", true),
            ("StepBase", "cardPanel", "CardPanel", false),
            ("ItemConfig", "cardPanel", "CardPanel", false)
        ]
        for (defn, property, target, underItems) in expectations {
            guard let owner = definitions[defn] as? [String: Any],
                  let properties = owner["properties"] as? [String: Any],
                  let declaration = properties[property] as? [String: Any] else {
                XCTFail("\(defn).properties.\(property) did not parse"); continue
            }
            let carrier = underItems ? declaration["items"] as? [String: Any] : declaration
            XCTAssertEqual(carrier?["$ref"] as? String, "#/definitions/\(target)",
                           "\(defn).\(property) no longer points at \(target) — a bare "
                           + "{\"type\": \"object\"} here means a typo inside the row validates green")
            XCTAssertNotNil(definitions[target], "definitions.\(target) is missing")
        }
        // Each row shape is closed.
        for target in ["AdvisoryFinding", "CardPanel", "CardPanelPair", "ComparisonCheck", "ReceiptRow"] {
            guard let definition = definitions[target] as? [String: Any] else {
                XCTFail("definitions.\(target) missing"); continue
            }
            XCTAssertEqual(definition["additionalProperties"] as? Bool, false,
                           "\(target) must be closed — it mirrors a synthesized-Codable struct "
                           + "with no aliases, so its key list is complete by construction")
        }
    }

    /// Every exemption carries a non-blank reason (`.whitespacesAndNewlines`).
    func testSchemaExemptionsAllCarryAReason() {
        let allExemptions = introStepInternalFields
            .merging(guidanceContentInternalFields, uniquingKeysWith: { first, _ in first })
            .merging(itemConfigToleranceKeys, uniquingKeysWith: { first, _ in first })
        for (field, reason) in allExemptions {
            XCTAssertFalse(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           "schema exemption `\(field)` has no reason — the reason is the whole point")
        }
    }

    /// `StepBase` itself declares both container spellings with the full `$ref`, so blocks under
    /// `guidanceContent[]` on a step are validated.
    func testStepBaseDeclaresBothContentSpellings() throws {
        guard let definitions = try schemaObject()["definitions"] as? [String: Any],
              let stepBase = definitions["StepBase"] as? [String: Any],
              let properties = stepBase["properties"] as? [String: Any]
        else {
            XCTFail("StepBase has no properties object — did the schema's shape change?")
            return
        }
        for spelling in ["content", "guidanceContent"] {
            guard let container = properties[spelling] as? [String: Any] else {
                XCTFail("StepBase does not declare `\(spelling)` — blocks authored there are "
                        + "unvalidated, not loosely validated")
                continue
            }
            XCTAssertEqual(container["type"] as? String, "array",
                           "StepBase.\(spelling) must be an array of blocks")
            XCTAssertEqual((container["items"] as? [String: Any])?["$ref"] as? String,
                           "#/definitions/GuidanceContent",
                           "StepBase.\(spelling) must $ref GuidanceContent — without the $ref it is "
                           + "declared and still unchecked")
        }
    }

    /// `PresetSummaryScreen`'s stored properties are declared on its own definition (one-directional).
    /// Nested `NextStep` members are not attributed to the parent.
    func testPresetSummaryScreenIsPinnedToItsOwnSchemaDefinition() throws {
        let declared = try storedPropertyNames(
            in: try repoSource("dialog/Views/Inspect/Core Framework/InspectConfig+CommonTypes.swift"),
            structName: "PresetSummaryScreen")
        XCTAssertFalse(declared.isEmpty, "no stored properties parsed out of PresetSummaryScreen")
        XCTAssertFalse(declared.contains("action"),
                       "nested NextStep members leaked into the parent's property set — the "
                       + "depth tracking in storedPropertyNames regressed")

        guard let definitions = try schemaObject()["definitions"] as? [String: Any],
              let summary = definitions["PresetSummaryScreen"] as? [String: Any],
              let properties = summary["properties"] as? [String: Any]
        else {
            XCTFail("definitions.PresetSummaryScreen.properties did not parse — did it move?")
            return
        }
        let missing = declared.subtracting(properties.keys)
        XCTAssertTrue(missing.isEmpty,
                      "PresetSummaryScreen properties the decoder reads and its OWN schema "
                      + "definition never declares: " + missing.sorted().joined(separator: ", "))
    }

    /// String `case` labels at the top level of every `switch` on the block type; nested switches are skipped.
    /// `switchExpression` differs per host (`block.type`, `effectiveBlock.type`).
    private func blockTypeCaseLabels(in source: String,
                                     switchExpression: String = "switch block.type") -> Set<String> {
        var labels = Set<String>()
        var searchStart = source.startIndex
        while let marker = source.range(of: switchExpression, range: searchStart..<source.endIndex) {
            searchStart = marker.upperBound
            guard let body = braceBody(of: String(source[marker.lowerBound...]),
                                       after: switchExpression) else { continue }
            var nestedDepth = 0
            for rawLine in body.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = String(rawLine)
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if nestedDepth == 0, trimmed.hasPrefix("case ") {
                    let head = trimmed.split(separator: ":", maxSplits: 1).first.map(String.init) ?? trimmed
                    for (index, piece) in head.split(separator: "\"", omittingEmptySubsequences: false)
                        .enumerated() where index % 2 == 1 {
                        labels.insert(String(piece))
                    }
                }
                nestedDepth = max(0, nestedDepth
                                  + line.filter { $0 == "{" }.count
                                  - line.filter { $0 == "}" }.count)
            }
        }
        return labels
    }

    /// Every block type with a render arm is in the schema enum (one-directional; `detail-rows`
    /// renders before the switch).
    func testEveryRenderedBlockTypeIsInTheSchemaEnum() throws {
        // All four block hosts: an arm added to one host alone would otherwise go unchecked.
        let hosts: [(file: String, switchExpression: String)] = [
            ("Core Framework/Components/GuidanceContentView.swift", "switch block.type"),
            ("Preset Layouts/Preset5+ContentBlocks.swift", "switch effectiveBlock.type"),
            ("Core Framework/Components/CardStepScreen.swift", "switch block.type"),
            ("Core Framework/Components/MediaComponents.swift", "switch block.type")
        ]
        let enumValues = try schemaBlockTypeEnum()
        XCTAssertFalse(enumValues.isEmpty,
                       "definitions.GuidanceContent.properties.type.enum did not parse — did it move?")
        for host in hosts {
            let arms = blockTypeCaseLabels(
                in: try repoSource("dialog/Views/Inspect/" + host.file),
                switchExpression: host.switchExpression)
            XCTAssertFalse(arms.isEmpty,
                           "no `\(host.switchExpression)` arms found in \(host.file) — did the host move?")
            let missing = arms.subtracting(enumValues)
            XCTAssertTrue(missing.isEmpty,
                          "\(host.file): block types that render but are not in the schema's type enum: "
                          + missing.sorted().joined(separator: ", "))
        }
    }
}

// `"watch": true` — a reloaded step list keeps the author on the step they were editing.
@MainActor
final class WatchReloadTests: XCTestCase {

    func testTheCursorFollowsTheStepById() {
        XCTAssertEqual(Preset5View.reloadedStepIndex(oldIds: ["a", "b", "c"], newIds: ["x", "a", "b", "c"], current: 2), 3,
                       "a step inserted before the cursor does not move the author off their step")
        XCTAssertEqual(Preset5View.reloadedStepIndex(oldIds: ["a", "b", "c"], newIds: ["a", "c"], current: 1), 0,
                       "the step being edited was removed: land on the nearest earlier one")
        XCTAssertEqual(Preset5View.reloadedStepIndex(oldIds: ["a", "b"], newIds: ["z"], current: 1), 0)
        XCTAssertEqual(Preset5View.reloadedStepIndex(oldIds: [], newIds: [], current: 3), 0)
    }

    func testWatchAndSchemaAreKnownRootKeys() throws {
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(#"""
        {"$schema":"./inspect-config.schema.json","watch":true,"preset":"5","introSteps":[{"id":"a","stepType":"intro"}]}
        """#.utf8))
        XCTAssertEqual(config.watch, true)
        XCTAssertTrue(InspectConfig.knownRootKeys.contains("$schema"))
        XCTAssertTrue(InspectConfig.knownRootKeys.contains("watch"))
    }
}

/// Lint reads inside `portalConfig`: unknown keys are named, and earlier sign-in keys say they are no longer read.
@MainActor
final class PortalConfigLintTests: XCTestCase {

    private func messages(_ json: String) -> [String] {
        InspectLint.lint(data: Data(json.utf8)).map(\.message)
    }

    func testRootPortalKeysThatAreNoLongerReadAreNamed() {
        let found = messages(#"""
        {"preset": "5", "portalConfig": {"portalURL": "https://portal.example.com",
                                         "authSources": [], "customHeaders": {}, "portalURl": "typo"},
         "introSteps": [{"id": "p", "stepType": "portal"}]}
        """#)
        XCTAssertTrue(found.contains { $0.contains("'authSources' in portalConfig is no longer read") }, "\(found)")
        XCTAssertTrue(found.contains { $0.contains("'customHeaders' in portalConfig is no longer read") }, "\(found)")
        XCTAssertTrue(found.contains { $0.contains("Unknown key 'portalURl' in portalConfig") }, "\(found)")
    }

    func testABlockPortalConfigIsCheckedToo() {
        let found = messages(#"""
        {"preset": "5", "introSteps": [{"id": "s", "content": [
          {"type": "portal-webview", "portalConfig": {"portalURL": "https://portal.example.com", "userAgent": "x"}}]}]}
        """#)
        XCTAssertTrue(found.contains { $0.contains("'userAgent' in portalConfig is no longer read") }, "\(found)")
    }

    func testAPortalConfigOfKnownKeysRaisesNothing() {
        let found = messages(#"""
        {"preset": "5", "portalConfig": {"portalURL": "https://portal.example.com", "selfServicePath": "/apps",
                                         "selfServiceOnly": true, "openExternalLinksInBrowser": false},
         "introSteps": [{"id": "p", "stepType": "portal"}]}
        """#)
        XCTAssertFalse(found.contains { $0.contains("portalConfig") }, "\(found)")
    }
}
