//
//  CardChromeSizingTests.swift
//  dialogTests
//
//  Covers window sizing by chrome and construction, the band geometry, carousel metrics and
//  identifier truncation, and the Preset 4 info cards.
//

import XCTest
@testable import Dialog

final class CardChromeSizingTests: XCTestCase {

    func testCardChromeSizesWindow820x600() {
        let r = InspectSizes.windowSize(width: nil, height: nil, preset: "preset5",
                                        mode: nil, itemCount: 0, chrome: "card")
        XCTAssertEqual(r.size, CGSize(width: 820, height: 600))
    }

    func testExplicitSizeStillBeatsCardChrome() {
        let r = InspectSizes.windowSize(width: 900, height: 700, preset: "preset5",
                                        mode: nil, itemCount: 0, chrome: "card")
        XCTAssertEqual(r.size, CGSize(width: 900, height: 700))
    }

    /// Rail spends width on a column, so it takes the sidebar's 920×620, not the card's 820×600.
    func testRailChromeTakesTheSidebarFootprint() {
        let r = InspectSizes.windowSize(width: nil, height: nil, preset: "preset6",
                                        mode: nil, itemCount: 0, chrome: "rail")
        XCTAssertEqual(r.size, CGSize(width: 920, height: 620))
    }

    func testNoChromeIsUnchanged() {
        let r = InspectSizes.windowSize(width: nil, height: nil, preset: "preset5",
                                        mode: nil, itemCount: 0, chrome: nil)
        XCTAssertEqual(r.size, CGSize(width: 820, height: 600))   // card by preset default
    }

    // MARK: - Chrome rung is gated on the preset having a renderer

    /// The toast has no card adapter, so the rung must not resize it to a card it cannot draw.
    func testCardChromeIgnoredForToastPreset() {
        let r = InspectSizes.windowSize(width: nil, height: nil, preset: "4",
                                        mode: nil, itemCount: 0, chrome: "card")
        XCTAssertEqual(r.size, CGSize(width: 550, height: 110), "Preset 4 keeps its slim size")
    }

    /// Presets 1/2/3 have no card adapter either.
    func testCardChromeIgnoredForItemPresets() {
        for preset in ["1", "2", "3"] {
            let gated = InspectSizes.windowSize(width: nil, height: nil, preset: preset,
                                                mode: nil, itemCount: 0, chrome: "card")
            let plain = InspectSizes.windowSize(width: nil, height: nil, preset: preset,
                                                mode: nil, itemCount: 0, chrome: nil)
            XCTAssertEqual(gated.size, plain.size, "Preset \(preset) must be unaffected by card chrome")
        }
    }

    /// Rail renders only in Preset 6; elsewhere it falls through to the engine's default.
    func testRailChromeIgnoredOutsidePreset6() {
        for preset in ["4", "5", "7"] {
            let gated = InspectSizes.windowSize(width: nil, height: nil, preset: preset,
                                                mode: nil, itemCount: 0, chrome: "rail")
            let plain = InspectSizes.windowSize(width: nil, height: nil, preset: preset,
                                                mode: nil, itemCount: 0, chrome: nil)
            XCTAssertEqual(gated.size, plain.size, "Preset \(preset) has no rail adapter")
        }
    }

    /// Preset 7 aliases onto the Preset 5 engine, so it inherits the card adapter.
    func testCardChromeAppliesToGuidedSetup() {
        for preset in ["7", "guided-setup"] {
            let r = InspectSizes.windowSize(width: nil, height: nil, preset: preset,
                                            mode: "setup", itemCount: 0, chrome: "card")
            XCTAssertEqual(r.size, CGSize(width: 820, height: 600), "\(preset) renders card chrome")
        }
    }

    /// The rung is keyed off the canonical preset, so named aliases behave like short forms.
    func testChromeGateNormalizesPresetAliases() {
        let toast = InspectSizes.windowSize(width: nil, height: nil, preset: "toast",
                                            mode: nil, itemCount: 0, chrome: "card")
        XCTAssertEqual(toast.size, CGSize(width: 550, height: 110))

        let portal = InspectSizes.windowSize(width: nil, height: nil, preset: "self-service",
                                             mode: nil, itemCount: 0, chrome: "card")
        XCTAssertEqual(portal.size, CGSize(width: 820, height: 600))
    }

    func testUnknownChromeFallsThrough() {
        let r = InspectSizes.windowSize(width: nil, height: nil, preset: "preset5",
                                        mode: nil, itemCount: 0, chrome: "bogus")
        XCTAssertEqual(r.size, CGSize(width: 820, height: 600))
    }

    // MARK: - Band geometry

    /// Band geometry is a design decision; a change here is a deliberate edit.
    func testBandGeometryIsTheMeasuredSpec() {
        XCTAssertEqual(StepBandMetrics.header, 184,
                       "the header band's design height: the first-pass fallback before "
                       + "AnchoredStepContent measures the real header (BandHeaderHeightKey), and "
                       + "the cap that measurement is held to. Pinned because it decides the first "
                       + "frame and a changed design should be a deliberate edit")
        XCTAssertEqual(StepBandMetrics.actionBar, 76, "the action bar the payload centres against")
        XCTAssertEqual(StepBandMetrics.hero, 64, "the hero's VISIBLE mark")
    }

    /// The hero container is sized so its ~0.4x mark comes out at the band's 64pt.
    func testHeroContainerYieldsTheSixtyFourPointMark() {
        XCTAssertEqual(StepBandMetrics.heroContainer, 160)
        let impliedMark = StepBandMetrics.heroContainer * 0.4
        XCTAssertEqual(impliedMark, StepBandMetrics.hero, accuracy: 0.5,
                       "heroContainer must still produce a \(StepBandMetrics.hero)pt mark")
    }

    /// Source-level guard (nothing here can render): the bands stay inside the shell's ScrollView,
    /// and the payload band reserves free space as a minimum height, top-aligned, so a tall
    /// payload grows the stack and scrolls instead of drawing outside a fixed band.
    func testBandsKeepTheScrollShellAndReserveTheirHeight() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "dialog/Views/Inspect/Core Framework/Components/AnchoredStepContent.swift"),
            encoding: .utf8)

        XCTAssertTrue(source.contains("ScrollView {"),
                      "the shell's ScrollView is what makes an overflowing payload scrollable")
        XCTAssertTrue(source.contains("func bandedStack("),
                      "bands are a MODE of the stack, not a view nested inside it")
        XCTAssertTrue(source.contains("minHeight: max(0, viewportHeight - headerBand)"),
                      "the payload band must RESERVE the free space as a minimum, so a tall "
                      + "payload can grow the stack and scroll instead of drawing outside it")
        XCTAssertTrue(source.contains("alignment: .top)"),
                      "the payload band is top-aligned; a centred band opens dead air under "
                      + "the header on any payload shorter than the free space")
        XCTAssertTrue(source.contains(".padding(.top, metrics.sectionGap)"),
                      "top-aligned WITHOUT a gap ran the body straight into the subtitle "
                      + "(measured 170 and 170); the seam takes the composition's own 20pt "
                      + "spacing unit rather than a constant invented for it")
        XCTAssertFalse(source.contains(".frame(height: max(0, viewportHeight - headerBand))"),
                       "a FIXED height on the payload band is the bug this test exists to "
                       + "prevent — it pins the band, and an over-tall payload then draws "
                       + "outside it and cannot be scrolled to at all")
    }

    // MARK: - Carousel row width

    //  The carousel's progress bar takes its width from the card row.

    func testCarouselRowWidthIsTheCardsPlusTheGapsBetweenThem() {
        // 4 x 142 + 3 x 12
        XCTAssertEqual(CarouselM.rowWidth(cards: 4), 604)
    }

    func testASingleCardRowIsJustTheCard() {
        XCTAssertEqual(CarouselM.rowWidth(cards: 1), CarouselM.cardOuterWidth)
    }

    func testAnEmptyRowHasNoWidth() {
        XCTAssertEqual(CarouselM.rowWidth(cards: 0), 0)
    }

    func testTheRowScalesWithTheWindow() {
        XCTAssertEqual(CarouselM.rowWidth(cards: 3, scale: 0.5),
                       CarouselM.rowWidth(cards: 3) * 0.5, accuracy: 0.01)
    }

    /// Padding is layout width; leaving it out overcounts visible cards and clips the right arrow.
    func testCardOuterWidthIncludesItsPadding() {
        XCTAssertEqual(CarouselM.cardOuterWidth, CarouselM.cardWidth + CarouselM.cardPadding)
    }

    // MARK: - The identifier truncates from the left

    //  Every bundle id starts "com."; the tail is what tells them apart, so the prefix is clipped.

    func testAShortIdentifierIsLeftAlone() {
        XCTAssertEqual(CarouselM.truncatedIdentifier("com.docker.docker", maxChars: 30),
                       "com.docker.docker")
    }

    func testALongIdentifierKeepsItsTail() {
        let out = CarouselM.truncatedIdentifier("com.agilebits.onepassword8", maxChars: 16)
        XCTAssertTrue(out.hasSuffix("onepassword8"), out)
        XCTAssertTrue(out.hasPrefix("…"), out)
        XCTAssertEqual(out.count, 16)
    }

    func testTheReverseDNSPrefixIsWhatGetsClipped() {
        let out = CarouselM.truncatedIdentifier("com.microsoft.VSCode", maxChars: 12)
        XCTAssertFalse(out.contains("com."), out)
        XCTAssertTrue(out.hasSuffix("VSCode"), out)
    }

    func testAnIdentifierExactlyAtTheLimitIsNotTouched() {
        let id = "com.figma.Desktop"          // 17 characters
        XCTAssertEqual(CarouselM.truncatedIdentifier(id, maxChars: 17), id)
    }

    // MARK: - Card metrics

    func testTheWideCardIsThreePerPage() {
        XCTAssertEqual(CarouselM.wideCardWidth, 224)
        XCTAssertEqual(CarouselM.wideRowWidth(cards: 3), 3 * 224 + 2 * CarouselM.cardSpacing)
    }

    func testTheTwoIconTreatmentsAreTheTwoDesignedVariants() {
        XCTAssertEqual(CarouselM.glyphSize, 30)
        XCTAssertEqual(CarouselM.appIconSize, 64)
    }

    // MARK: - The manifest form

    //  The form is authored, never inferred from the item count.

    func testCardsAreTheDefaultForm() {
        XCTAssertEqual(CarouselM.form(nil), .cards)
    }

    func testTheManifestFormIsAuthored() {
        XCTAssertEqual(CarouselM.form("manifest"), .manifest)
        XCTAssertEqual(CarouselM.form("cards"), .cards)
    }

    func testAnUnknownFormFallsThroughToCards() {
        XCTAssertEqual(CarouselM.form("Manifesto"), .cards)
    }

    func testTheFormIsCaseInsensitive() {
        XCTAssertEqual(CarouselM.form("Manifest"), .manifest)
    }

    func testTheManifestClaimHasAMeasure() {
        XCTAssertEqual(CarouselM.manifestClaimWidth, 300)
    }

    // MARK: - The construction resolver

    /// Row by row: unauthored → engine default; authored and accepted; authored and refused →
    /// engine default; retired or junk → engine default.
    func testResolverCoversItsWholeInputDomain() {
        typealias C = InspectSizes.Construction
        let rows: [(preset: String, chrome: String?, expected: C?)] = [
            // unauthored → the engine's default
            ("1", nil, .plain), ("preset1", nil, .plain),
            ("2", nil, nil), ("3", nil, nil),                    // the legacy size table
            ("4", nil, .toast), ("toast", nil, .toast),
            ("5", nil, .card), ("preset5", nil, .card),
            ("7", nil, .card), ("guided-setup", nil, .card),     // P7 aliases onto the P5 engine
            ("6", nil, .sidebar), ("guidance", nil, .sidebar),
            // authored, registry accepts
            ("5", "card", .card),
            ("6", "card", .card),
            ("6", "rail", .rail),
            ("5", "provisioning", .provisioning),
            // `fixture` decodes but names no construction, so it resolves like junk chrome
            ("5", "fixture", .card),
            ("5", "plain", .plain),      // the authored escape hatch from the card default
            ("1", "plain", .plain),
            ("6", "sidebar", .sidebar),
            ("4", "toast", .toast),      // schema forbids it; the resolver need not care
            // authored, registry refuses → the engine's default, never a resized empty shell
            ("1", "card", .plain), ("4", "card", .toast),
            ("5", "rail", .card), ("7", "rail", .card),
            ("6", "fixture", .sidebar),
            ("5", "sidebar", .card),
            ("5", "toast", .card),
            ("2", "card", nil), ("3", "rail", nil),
            // junk resolves like absence: a typo must not pick a different surface
            ("5", "bogus", .card), ("6", "", .sidebar)
        ]
        for row in rows {
            XCTAssertEqual(C.resolve(preset: row.preset, authoredChrome: row.chrome), row.expected,
                           "resolve(\(row.preset), \(row.chrome ?? "nil"))")
        }
    }

    /// The toast has one size whatever retired size name a config still carries.
    func testTheToastIgnoresTheRetiredCompactMode() {
        let r = InspectSizes.windowSize(width: nil, height: nil, preset: "4",
                                        mode: "compact", itemCount: 0, chrome: nil)
        XCTAssertEqual(r.size, CGSize(width: 550, height: 110))
    }

    /// Log-reading tooling depends on the origin wording: preset phrasing when defaulted, chrome
    /// phrasing when authored.
    func testDefaultedConstructionKeepsThePresetOriginWording() {
        let r = InspectSizes.windowSize(width: nil, height: nil, preset: "5",
                                        mode: nil, itemCount: 0, chrome: nil)
        XCTAssertEqual(r.origin, "5 standard (820×600)")
    }
    func testAuthoredChromeKeepsTheChromeOriginWording() {
        let r = InspectSizes.windowSize(width: nil, height: nil, preset: "5",
                                        mode: nil, itemCount: 0, chrome: "card")
        XCTAssertEqual(r.origin, "card chrome (820×600)")
    }

    /// The defaulted construction is resolved at launch too, so band growth applies there.
    func testDefaultedCardStillGrowsForABand() {
        let r = InspectSizes.windowSize(width: nil, height: nil, preset: "5",
                                        mode: nil, itemCount: 0, chrome: nil, bandGrowth: 80)
        XCTAssertEqual(r.size, CGSize(width: 820, height: 680))
    }
}

// MARK: - Carousel fit

/// CarouselM.wideCardsThatFit takes the measured width, already inside the shell's 44pt inset;
/// subtracting the paddings again would show two cards where three fit.
final class CarouselFitTests: XCTestCase {
    func testAnEightHundredTwentyPointWindowShowsThreeCards() {
        XCTAssertEqual(CarouselM.wideCardsThatFit(contentWidth: 820 - 2 * 44), 3)
    }

    func testTheNineHundredPointWindowStillShowsThree() {
        XCTAssertEqual(CarouselM.wideCardsThatFit(contentWidth: 900 - 2 * 44), 3)
    }

    func testTheCountClampsToOneAndFive() {
        XCTAssertEqual(CarouselM.wideCardsThatFit(contentWidth: 100), 1)
        XCTAssertEqual(CarouselM.wideCardsThatFit(contentWidth: 5000), 5)
    }

    func testThreeCardsNeedTheirRowWidthPlusSlack() {
        let three = CarouselM.wideRowWidth(cards: 3)
        XCTAssertEqual(CarouselM.wideCardsThatFit(contentWidth: three + 8), 3)
        XCTAssertEqual(CarouselM.wideCardsThatFit(contentWidth: three + 7), 2)
    }
}

// MARK: - Preset 4 info cards

/// The info message style shows one card per item; with no items, one card from the intro screen
/// plus the root message.
final class InfoCardContentTests: XCTestCase {
    private func config(_ json: String) throws -> InspectConfig {
        try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
    }

    func testMessageStyleDecodes() throws {
        XCTAssertEqual(try config(#"{"preset":"4","messageStyle":"info"}"#).messageStyle, "info")
        XCTAssertNil(try config(#"{"preset":"4"}"#).messageStyle)
    }

    func testEachItemIsOneCard() throws {
        let c = try config(#"""
        {"preset":"4","messageStyle":"info","items":[
          {"id":"a","displayName":"Latest macOS","subtitle":"MacBook","icon":"SF=exclamationmark.circle","claim":"Tops out at **Ventura**","guiIndex":0,"paths":[]},
          {"id":"b","displayName":"Help","guiIndex":1,"paths":[],"continueButtonText":"Done"}]}
        """#)
        let cards = InfoCardContent.cards(for: c, items: c.items)
        XCTAssertEqual(cards.map(\.id), ["a", "b"])
        XCTAssertEqual(cards[0].title, "Latest macOS")
        XCTAssertEqual(cards[0].context, "MacBook")
        XCTAssertEqual(cards[0].glyph, "SF=exclamationmark.circle")
        XCTAssertEqual(cards[0].answer, "Tops out at **Ventura**")
        XCTAssertEqual(cards[0].buttonText, "Got it", "the door defaults to Got it")
        XCTAssertEqual(cards[1].buttonText, "Done")
    }

    func testNoItemsIsOneCardFromTheIntroScreenAndMessage() throws {
        let c = try config(#"""
        {"preset":"4","messageStyle":"info","message":"The **answer**",
          "introScreen":{"title":"Title","subtitle":"Context","heroImage":"SF=info.circle","buttonText":"OK"}}
        """#)
        let cards = InfoCardContent.cards(for: c, items: [])
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].title, "Title")
        XCTAssertEqual(cards[0].context, "Context")
        XCTAssertEqual(cards[0].glyph, "SF=info.circle")
        XCTAssertEqual(cards[0].answer, "The **answer**")
        XCTAssertEqual(cards[0].buttonText, "OK")
    }
}
