//
//  BrandMarkTests.swift
//  dialogTests
//
//  `BrandArtwork.resolve` owns which brand artwork file a seat draws (appearance, surface,
//  position gate, `-dark` sibling); `BrandMarkBox.fit` owns the box it draws in.
//

import XCTest
@testable import Dialog

final class BrandMarkTests: XCTestCase {
    private func logo(_ light: String, dark: String? = nil, position: String? = "bottomleft")
    throws -> InspectConfig.LogoConfig {
        let json = """
        {"imagePath":"\(light)"\(dark.map { ",\"imagePathDark\":\"\($0)\"" } ?? "")\
        \(position.map { ",\"position\":\"\($0)\"" } ?? "")}
        """
        return try JSONDecoder().decode(InspectConfig.LogoConfig.self, from: Data(json.utf8))
    }

    func testLightWindowTakesImagePath() {
        XCTAssertEqual(BrandArtwork.resolve(try logo("/a/l.png", dark: "/a/d.png"), isDark: false), "/a/l.png")
    }
    func testDarkWindowTakesAuthoredDark() {
        XCTAssertEqual(BrandArtwork.resolve(try logo("/a/l.png", dark: "/a/d.png"), isDark: true), "/a/d.png")
    }
    func testDarkWindowWithoutAuthoredDarkFallsBackToLight() {
        XCTAssertEqual(BrandArtwork.resolve(try logo("/nonexistent/l.png"), isDark: true), "/nonexistent/l.png")
    }
    func testPhotographSurfaceTakesDarkArtInLightWindow() {
        XCTAssertEqual(BrandArtwork.resolve(try logo("/a/l.png", dark: "/a/d.png"), isDark: false,
                                            surface: .photograph), "/a/d.png")
    }
    func testFooterGateRefusesHeaderPosition() {
        XCTAssertNil(BrandArtwork.resolve(try logo("/a/l.png", position: "header"), isDark: false, gate: .footer))
    }
    func testAnyGateAcceptsHeaderPosition() {
        XCTAssertEqual(BrandArtwork.resolve(try logo("/a/l.png", position: "header"), isDark: false), "/a/l.png")
    }
    func testNilLogoResolvesNil() {
        XCTAssertNil(BrandArtwork.resolve(nil, isDark: true))
    }
    /// Byte-identity with the two `LogoConfig` resolvers, across every position and appearance.
    func testIdentityWithFooterPathAndResolvedPath() throws {
        for dark in [false, true] {
            for pos in ["bottomleft", "footer", "header", "none"] {
                let l = try logo("/a/l.png", dark: "/a/d.png", position: pos)
                XCTAssertEqual(BrandArtwork.resolve(l, isDark: dark, gate: .footer), l.footerPath(isDark: dark), "\(pos) \(dark)")
                XCTAssertEqual(BrandArtwork.resolve(l, isDark: dark), l.resolvedPath(isDark: dark), "\(pos) \(dark)")
            }
        }
    }

    // MARK: - BrandMarkBox

    func testAuthoredHeightWinsOverDefault() {
        XCTAssertEqual(BrandMarkBox.fit(authored: 30, default: 22).height, 30)
    }
    func testDefaultWhenUnauthored() {
        XCTAssertEqual(BrandMarkBox.fit(authored: nil, default: 22).height, 22)
    }
    func testCapShrinksNeverGrows() {
        XCTAssertEqual(BrandMarkBox.fit(authored: 60, default: 22, cap: 28).height, 28)
        XCTAssertEqual(BrandMarkBox.fit(authored: 12, default: 22, cap: 28).height, 12)
    }
    func testMaxWidthPassesThrough() {
        XCTAssertEqual(BrandMarkBox.fit(authored: nil, default: 24, maxWidth: 120).maxWidth, 120)
        XCTAssertNil(BrandMarkBox.fit(authored: nil, default: 24).maxWidth)
    }
    /// A wide mark is shrunk so its width fits the box: 220 / 12.7 = 17.3 tall, under the 22 cap.
    func testAspectRatioShrinksHeightToFitWidthBox() {
        let box = BrandMarkBox.fit(authored: 27, default: 27, cap: 22, maxWidth: 220,
                                   clearSpace: 0, aspectRatio: 12.7)
        XCTAssertEqual(box.height, 220 / 12.7, accuracy: 0.01)
        XCTAssertEqual(box.maxWidth, 220)
    }
    /// Reference implementation of the height clamp `BrandMarkBox.fit` must equal.
    private func legacyClampedMarkHeight(requestedHeight: CGFloat, clearSpace: CGFloat,
                                         box: CGSize, aspectRatio: CGFloat?) -> CGFloat {
        let heightCap = min(requestedHeight, box.height)
        guard let aspectRatio, aspectRatio > 0 else { return heightCap }
        let cs = min(max(clearSpace, 0), 0.6)
        let markHeightAtCap = heightCap * (1 - 2 * cs)
        let markWidthAtCap = markHeightAtCap * aspectRatio
        guard markWidthAtCap > box.width, markWidthAtCap > 0 else { return heightCap }
        return heightCap * (box.width / markWidthAtCap)
    }

    /// `fit` matches the reference clamp across the values the card seat feeds it.
    func testIdentityWithClampedMarkHeight() {
        let boxSize = BrandSlotMetrics.actionSlot
        for requested: CGFloat in [12, 22, 27, 28] {
            for clear: CGFloat in [0, 0.1, 0.3] {
                for aspect: CGFloat? in [nil, 1, 4, 12.7] {
                    let expected = legacyClampedMarkHeight(requestedHeight: requested,
                                                           clearSpace: clear, box: boxSize,
                                                           aspectRatio: aspect)
                    let got = BrandMarkBox.fit(authored: Double(requested), default: requested,
                                               cap: boxSize.height, maxWidth: boxSize.width,
                                               clearSpace: clear, aspectRatio: aspect).height
                    XCTAssertEqual(got, expected, accuracy: 0.001, "\(requested) \(clear) \(String(describing: aspect))")
                }
            }
        }
    }

    /// `PhaseLogoOverlay`'s height through `fit` equals the plain maxHeight-times-scale product
    /// (defaults 40 and 1).
    func testPhaseLogoOverlayHeightSurvivesTheFitCall() {
        for maxHeight: Double? in [nil, 18, 30, 40, 88] {
            for scale: Double? in [nil, 0.5, 1.0, 1.5, 2.0] {
                let before = CGFloat(maxHeight ?? 40) * CGFloat(scale ?? 1.0)
                let after = BrandMarkBox.fit(authored: maxHeight.map { $0 * (scale ?? 1.0) },
                                             default: 40 * CGFloat(scale ?? 1.0)).height
                XCTAssertEqual(after, before, accuracy: 0.0001,
                               "maxHeight \(String(describing: maxHeight)) scale \(String(describing: scale))")
            }
        }
    }
}
