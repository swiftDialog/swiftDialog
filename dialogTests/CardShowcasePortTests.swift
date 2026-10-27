//  CardShowcasePortTests.swift
//  dialogTests
//
//  Covers the pure showcase-stage rules: fraction, height, fill precedence, mark/artwork split
//  and the retired-key advisory.

import XCTest
import SwiftUI
@testable import Dialog

final class CardShowcasePortTests: XCTestCase {

    // MARK: - the fraction

    func testFractionDefaultsToTheMeasuredValue() {
        XCTAssertEqual(ShowcaseStage.fraction(nil), 0.6, accuracy: 0.0001)
    }

    func testFractionHonoursAuthoredValue() {
        XCTAssertEqual(ShowcaseStage.fraction(0.45), 0.45, accuracy: 0.0001)
    }

    func testFractionRejectsNonsenseAndFallsBackToDefault() {
        XCTAssertEqual(ShowcaseStage.fraction(0), 0.6, accuracy: 0.0001)
        XCTAssertEqual(ShowcaseStage.fraction(-1), 0.6, accuracy: 0.0001)
    }

    func testFractionClampsToTheUsableRange() {
        XCTAssertEqual(ShowcaseStage.fraction(0.05), 0.2, accuracy: 0.0001)
        XCTAssertEqual(ShowcaseStage.fraction(3.0), 0.9, accuracy: 0.0001)
    }

    // MARK: - the floor and the ceiling

    func testHeightIsTheFractionAtTheFixtureWindow() {
        XCTAssertEqual(ShowcaseStage.height(windowHeight: 632, fraction: 0.6), 379.2, accuracy: 0.01)
    }

    /// The floor keeps room for the 88pt mark, the 28pt gap and a title line.
    func testHeightNeverFallsBelowTheFloor() {
        XCTAssertEqual(ShowcaseStage.height(windowHeight: 500, fraction: 0.3),
                       ShowcaseStage.minimumHeight, accuracy: 0.01)
    }

    /// Chrome (caption band and action bar) wins over the floor.
    func testChromeIsReservedEvenWhenTheFloorCannotBeMet() {
        let h = ShowcaseStage.height(windowHeight: 260, fraction: 0.9)
        XCTAssertEqual(h, 260 - ShowcaseStage.reservedChrome, accuracy: 0.01)
    }

    func testTallWindowStillLeavesTheChromeItsSpace() {
        let h = ShowcaseStage.height(windowHeight: 700, fraction: 0.9)
        XCTAssertLessThanOrEqual(h, 700 - ShowcaseStage.reservedChrome)
    }

    // MARK: - the fill, one resolver with stated precedence

    func testFlatHeroBackgroundBeatsEveryGradient() {
        let fill = ShowcaseStage.fill(heroBackground: "#101820",
                                      stepGradient: ["#FF0000", "#00FF00"],
                                      configGradient: ["#0000FF"],
                                      brand: .orange)
        guard case .flat = fill else { return XCTFail("expected a flat fill, got \(fill)") }
    }

    func testStepGradientBeatsConfigGradient() {
        let fill = ShowcaseStage.fill(heroBackground: nil,
                                      stepGradient: ["#FF0000", "#00FF00"],
                                      configGradient: ["#0000FF"],
                                      brand: .orange)
        guard case .gradient(let colors) = fill else { return XCTFail("expected a gradient") }
        XCTAssertEqual(colors.count, 2)
    }

    func testConfigGradientIsTheSecondTier() {
        let fill = ShowcaseStage.fill(heroBackground: nil,
                                      stepGradient: nil,
                                      configGradient: ["#0000FF", "#000088"],
                                      brand: .orange)
        guard case .gradient(let colors) = fill else { return XCTFail("expected a gradient") }
        XCTAssertEqual(colors.count, 2)
    }

    /// Last tier: the brand colour as a three-stop gradient.
    func testBrandingIsTheLastTier() {
        let fill = ShowcaseStage.fill(heroBackground: nil, stepGradient: nil,
                                      configGradient: nil, brand: .orange)
        guard case .gradient(let colors) = fill else { return XCTFail("expected a gradient") }
        XCTAssertEqual(colors.count, 3)
    }

    /// The hex initializer cannot fail (it falls back to black), so an unparseable value still
    /// wins its tier; the resolver does no validation.
    func testUnparseableHexStillWinsItsTierBecauseTheInitCannotFail() {
        let fill = ShowcaseStage.fill(heroBackground: "not-a-colour",
                                      stepGradient: ["also-not"],
                                      configGradient: nil,
                                      brand: .orange)
        guard case .flat = fill else { return XCTFail("expected the authored flat tier, got \(fill)") }
    }

    func testEmptyGradientArrayFallsBackToTheBrandGradient() {
        let fill = ShowcaseStage.fill(heroBackground: nil, stepGradient: [],
                                      configGradient: nil, brand: .orange)
        guard case .gradient(let colors) = fill else { return XCTFail("expected the brand tier") }
        XCTAssertEqual(colors.count, 3)
    }

    // MARK: - the advisory

    /// assistantImageHeight belongs to the assistant step; the showcase reads showcaseImageHeight.
    func testBorrowedAssistantKeyIsReportedWhenAuthored() {
        XCTAssertEqual(CardShowcaseAdvice.ignoredKeys(assistantImageHeight: 0.4),
                       ["assistantImageHeight"])
    }

    func testNothingIsReportedWhenTheBorrowedKeyIsAbsent() {
        XCTAssertTrue(CardShowcaseAdvice.ignoredKeys(assistantImageHeight: nil).isEmpty)
    }

    /// Hero-geometry keys are reported via CardHeroAdvice.ignoredKeys, not a second list.
    func testHeroGeometryKeysAreComposedFromCardHeroAdvice() {
        let keys = CardShowcaseAdvice.ignoredKeys(assistantImageHeight: nil,
                                                   heroImageShape: "circle",
                                                   heroImageSize: 140,
                                                   heroImagePadding: 8,
                                                   heroBadge: "check",
                                                   showProgressDots: false)
        XCTAssertEqual(keys, ["heroImageShape", "heroImageSize", "heroImagePadding",
                              "heroBadge", "showProgressDots"])
    }

    /// The mark's weight is fixed; an authored weight is reported, not silently dropped.
    func testSFSymbolWeightIsReportedWhenAuthored() {
        XCTAssertEqual(CardShowcaseAdvice.ignoredKeys(assistantImageHeight: nil,
                                                       heroImageSFSymbolWeight: "bold"),
                       ["heroImageSFSymbolWeight"])
    }

    /// The mark's ink is stageInk, never an authored colour (it could match the ground).
    func testSFSymbolColorIsReportedWhenAuthored() {
        XCTAssertEqual(CardShowcaseAdvice.ignoredKeys(assistantImageHeight: nil,
                                                       heroImageSFSymbolColor: "#0A84FF"),
                       ["heroImageSFSymbolColor"])
    }

    /// No card arm reads contentAnchor; the caption band owns its anchoring.
    func testContentAnchorIsReportedWhenAuthored() {
        XCTAssertEqual(CardShowcaseAdvice.ignoredKeys(assistantImageHeight: nil,
                                                       contentAnchor: "top"),
                       ["contentAnchor"])
    }

    /// An authored `showcaseTextColor` is reported: the key is retired and `stageInk` sets that colour.
    func testShowcaseTextColorIsReportedWhenAuthored() {
        XCTAssertEqual(CardShowcaseAdvice.ignoredKeys(assistantImageHeight: nil,
                                                       showcaseTextColor: "#FFFFFF"),
                       ["showcaseTextColor"])
    }

    /// The advisory promises a stable key order.
    func testAllRetiredKeysComposeInOneStableOrder() {
        let keys = CardShowcaseAdvice.ignoredKeys(assistantImageHeight: 0.4,
                                                   heroImageShape: "circle",
                                                   heroImageSize: 140,
                                                   heroImagePadding: 8,
                                                   heroBadge: "check",
                                                   showProgressDots: false,
                                                   heroImageSFSymbolWeight: "bold",
                                                   heroImageSFSymbolColor: "#0A84FF",
                                                   contentAnchor: "top",
                                                   showcaseTextColor: "#FFFFFF")
        XCTAssertEqual(keys, ["assistantImageHeight", "heroImageShape", "heroImageSize",
                              "heroImagePadding", "heroBadge", "showProgressDots",
                              "heroImageSFSymbolWeight", "heroImageSFSymbolColor",
                              "contentAnchor", "showcaseTextColor"])
    }

    // MARK: - the mark/artwork split

    func testMarkWithNoHeroFallsBackToSparkles() {
        let result = ShowcaseStage.mark(hero: nil)
        XCTAssertEqual(result.mark, "sparkles")
        XCTAssertNil(result.artwork)
    }

    func testMarkWithResolvedSFReferenceBecomesTheMark() {
        let result = ShowcaseStage.mark(hero: "SF=sparkles.rectangle.stack")
        XCTAssertEqual(result.mark, "sparkles.rectangle.stack")
        XCTAssertNil(result.artwork)
    }

    /// A bare prefix must not become a file path that fails to load.
    func testMarkWithDegenerateSFPrefixFallsBackToSparkles() {
        let result = ShowcaseStage.mark(hero: "SF=")
        XCTAssertEqual(result.mark, "sparkles")
        XCTAssertNil(result.artwork)
    }

    /// A file hero draws no mark over itself.
    func testMarkWithFileHeroBecomesArtworkOnly() {
        let result = ShowcaseStage.mark(hero: "hero.png")
        XCTAssertNil(result.mark)
        XCTAssertEqual(result.artwork, "hero.png")
    }
}
