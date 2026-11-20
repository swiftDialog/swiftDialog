//
//  BrandSlotMetricsTests.swift
//  dialogTests
//
//  A brand mark's height is clamped so the mark fits its box on both axes, aspect ratio kept,
//  shrinking only. Covers `BrandMarkBox.fit` (via the clamp shim) and the dark-mode accent lift.
//

import XCTest
import SwiftUI
@testable import Dialog

/// The height clamp in the call shape `CardBrandMark` uses.
private func clampedMarkHeight(requestedHeight: CGFloat, clearSpace: CGFloat,
                               box: CGSize, aspectRatio: CGFloat?) -> CGFloat {
    BrandMarkBox.fit(authored: Double(requestedHeight), default: requestedHeight,
                     cap: box.height, maxWidth: box.width,
                     clearSpace: clearSpace, aspectRatio: aspectRatio).height
}

final class BrandSlotMetricsTests: XCTestCase {

    // MARK: - Width cap

    /// A 12.7:1 wordmark at the card's 28pt height cap is pulled down until its width lands on
    /// the action slot's 220pt.
    func testWideWordmarkAtDefaultHeightShrinksToTheActionSlotWidth() {
        let aspectRatio: CGFloat = 280.0 / 22.0
        let box = BrandSlotMetrics.actionSlot   // 220 x 22
        let height = clampedMarkHeight(requestedHeight: 28, clearSpace: 0,
                                                         box: box, aspectRatio: aspectRatio)
        let resultingWidth = height * aspectRatio
        XCTAssertEqual(resultingWidth, box.width, accuracy: 0.01,
                       "the mark's natural width at the clamped height must land exactly on the box's width")
        XCTAssertLessThan(height, 28, "the height must have been pulled down to make that width fit")
    }

    // MARK: - Never scales up

    /// A mark smaller than the box on both axes is untouched.
    func testMarkAlreadySmallerThanTheBoxIsUnchanged() {
        let box = BrandSlotMetrics.actionSlot   // 220 x 22
        let height = clampedMarkHeight(requestedHeight: 18, clearSpace: 0,
                                                         box: box, aspectRatio: 1.2)
        XCTAssertEqual(height, 18, "an author asking for 18pt must still get 18pt")
    }

    /// Fixture numbers (18pt, clearSpace 0.1, 12.7:1) already fit the 220pt cap; the clamp is a no-op.
    func testAirlineFixtureConfigAlreadyFitsAndIsUnaffected() {
        let aspectRatio: CGFloat = 280.0 / 22.0
        let box = BrandSlotMetrics.actionSlot
        let height = clampedMarkHeight(requestedHeight: 18, clearSpace: 0.1,
                                                         box: box, aspectRatio: aspectRatio)
        XCTAssertEqual(height, 18, "18pt at this aspect ratio already fits the 220pt box")
    }

    // MARK: - Height cap

    func testBoxHeightCapsEvenWhenWidthWouldFit() {
        let box = CGSize(width: 400, height: 20)
        let height = clampedMarkHeight(requestedHeight: 28, clearSpace: 0,
                                                         box: box, aspectRatio: 1.0)
        XCTAssertEqual(height, 20, "the box's own height cap applies even when width has headroom")
    }

    // MARK: - Aspect ratio unavailable

    /// A nil aspect ratio means nothing to measure; only the height cap applies.
    func testNilAspectRatioFallsBackToTheHeightCapAlone() {
        let box = BrandSlotMetrics.actionSlot
        let height = clampedMarkHeight(requestedHeight: 28, clearSpace: 0,
                                                         box: box, aspectRatio: nil)
        XCTAssertEqual(height, box.height)   // min(28, 22)
    }

    // MARK: - Clear space

    /// Width is measured on the clear-space-trimmed ink, so more clear space means less shrink.
    func testClearSpaceRelaxesTheWidthShrink() {
        let aspectRatio: CGFloat = 12.0
        let box = BrandSlotMetrics.actionSlot   // 220 x 22
        let tight = clampedMarkHeight(requestedHeight: 28, clearSpace: 0,
                                                        box: box, aspectRatio: aspectRatio)
        let padded = clampedMarkHeight(requestedHeight: 28, clearSpace: 0.3,
                                                         box: box, aspectRatio: aspectRatio)
        XCTAssertGreaterThan(padded, tight,
                             "more clear space means the ink is smaller at the same nominal height, so less shrink is needed to fit the width")
    }
}

/// `Color.darkModeAdapted`: dark brand colours are lifted in HSB so the hue survives.
final class DarkModeAccentTests: XCTestCase {

    private func rgb(_ c: Color) -> (CGFloat, CGFloat, CGFloat) {
        let ns = NSColor(c).usingColorSpace(.sRGB) ?? NSColor(c)
        return (ns.redComponent, ns.greenComponent, ns.blueComponent)
    }

    private func hsb(_ c: Color) -> (h: CGFloat, s: CGFloat, b: CGFloat) {
        let ns = NSColor(c).usingColorSpace(.sRGB) ?? NSColor(c)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b)
    }

    /// A very dark saturated navy gets lighter without moving its hue or losing saturation.
    func testAVeryDarkBrandNavyKeepsItsHue() {
        let brand = Color(hex: "#05164D")
        let adapted = brand.darkModeAdapted
        XCTAssertEqual(hsb(adapted).h, hsb(brand).h, accuracy: 0.01,
                       "the hue is the brand — lifting brightness must not move it")
        XCTAssertGreaterThan(hsb(adapted).b, hsb(brand).b, "it must actually get lighter")
        XCTAssertGreaterThan(hsb(adapted).s, 0.5,
                             "saturation is what the old channel-blend destroyed; it must survive")
    }

    /// The adapted channels stay spread apart; a brand colour must not converge to grey.
    func testTheAdaptedAccentDoesNotCollapseTowardGrey() {
        let (r, g, b) = rgb(Color(hex: "#05164D").darkModeAdapted)
        let spread = max(r, max(g, b)) - min(r, min(g, b))
        XCTAssertGreaterThan(spread, 0.30,
                             "channels this close together are a grey, not a brand: "
                             + "r \(r) g \(g) b \(b)")
    }

    /// Colours with luminance at or above 0.15 pass through unchanged.
    func testABrightBrandColourPassesThroughUnchanged() {
        for hex in ["#0A6BD6", "#4C9BF0", "#E0902A", "#43C46B"] {
            let brand = Color(hex: hex)
            guard brand.luminance >= 0.15 else { continue }
            let (r1, g1, b1) = rgb(brand)
            let (r2, g2, b2) = rgb(brand.darkModeAdapted)
            XCTAssertEqual(r1, r2, accuracy: 0.001, "\(hex) must pass through")
            XCTAssertEqual(g1, g2, accuracy: 0.001, "\(hex) must pass through")
            XCTAssertEqual(b1, b2, accuracy: 0.001, "\(hex) must pass through")
        }
    }

    /// A dark grey has no hue and must not acquire one.
    func testADarkGreyStaysGrey() {
        let adapted = Color(hex: "#141414").darkModeAdapted
        XCTAssertEqual(hsb(adapted).s, 0, accuracy: 0.02,
                       "saturation 0 in means saturation 0 out — no invented hue")
    }
}

