//
//  InspectDensityTests.swift
//  dialogTests
//
//  The authored density knob: at `comfortable` every font token is its base x1.1 and every measure
//  token matches `standard`. The tier is a closed enum; an unknown tier renders at `standard` with an advisory.
//

import XCTest
import SwiftUI
@testable import Dialog

/// `@MainActor`: `InspectLayoutProtocol` is main-actor isolated, so its scales are too.
@MainActor
final class InspectDensityTests: XCTestCase {

    // MARK: - Decode matrix

    private func config(_ json: String) throws -> InspectConfig {
        try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
    }

    func testAnAbsentDensityDecodesAsNil() throws {
        let config = try config(#"{"preset": "preset5"}"#)
        XCTAssertNil(config.density)
    }

    func testAnAbsentDensityResolvesToStandard() {
        let resolved = InspectDensity.resolve(authored: nil, preset: "preset5")
        XCTAssertEqual(resolved.tier, .standard)
        XCTAssertNil(resolved.advisory, "an unauthored key is the normal case and owes no log line")
    }

    func testAnAuthoredStandardDecodesAndResolves() throws {
        let config = try config(#"{"preset": "preset5", "density": "standard"}"#)
        XCTAssertEqual(config.density, "standard")
        XCTAssertEqual(InspectDensity.resolve(authored: config.density, preset: "preset5").tier, .standard)
    }

    func testAnAuthoredComfortableDecodesAndResolves() throws {
        let config = try config(#"{"preset": "preset5", "density": "comfortable"}"#)
        XCTAssertEqual(config.density, "comfortable")
        XCTAssertEqual(InspectDensity.resolve(authored: config.density, preset: "preset5").tier, .comfortable)
    }

    /// An unknown tier resolves to `standard` with an advisory.
    func testAnUnknownTierResolvesToStandardAndSaysSo() {
        let resolved = InspectDensity.resolve(authored: "cozy", preset: "preset5")
        XCTAssertEqual(resolved.tier, .standard)
        let advisory = try? XCTUnwrap(resolved.advisory)
        XCTAssertTrue(advisory?.contains("cozy") ?? false,
                      "the advisory must name the value that was rejected: \(resolved.advisory ?? "nil")")
        XCTAssertTrue(advisory?.contains("standard") ?? false,
                      "the advisory must name the tier applied instead: \(resolved.advisory ?? "nil")")
    }

    /// Tier matching ignores case, like the operator switches.
    func testTierMatchingIsCaseInsensitive() {
        XCTAssertEqual(InspectDensity.resolve(authored: "Comfortable", preset: "preset5").tier, .comfortable)
        XCTAssertNil(InspectDensity.resolve(authored: "Comfortable", preset: "preset5").advisory)
    }

    func testDensityIsARegisteredRootKey() throws {
        XCTAssertTrue(InspectConfig.knownRootKeys.contains("density"),
                      "an unregistered root key logs a false 'Unknown key' warning on every load")
        InspectConfig.unknownKeyWarnings = []
        _ = try config(#"{"preset": "preset5", "density": "comfortable"}"#)
        XCTAssertEqual(InspectConfig.unknownKeyWarnings.filter { $0.contains("density") }, [])
    }

    /// The schema declares the closed enum.
    func testTheSchemaDeclaresTheClosedEnum() throws {
        let schemaURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: schemaURL))
        let properties = try XCTUnwrap((schema as? [String: Any])?["properties"] as? [String: Any])
        let density = try XCTUnwrap(properties["density"] as? [String: Any],
                                    "root property 'density' is missing from the schema")
        XCTAssertEqual(density["type"] as? String, "string")
        XCTAssertEqual(density["enum"] as? [String], ["standard", "comfortable"])
    }

    // MARK: - Type moves, measure does not

    private let standard = InspectMetrics(typeScale: 1.0, measureScale: 1.0)
    private let comfortable = InspectMetrics(typeScale: InspectDensity.comfortable.typeScale,
                                             measureScale: 1.0)

    func testComfortableIsExactlyOnePointOne() {
        XCTAssertEqual(InspectDensity.comfortable.typeScale, 1.1, accuracy: 0.0001)
        XCTAssertEqual(InspectDensity.standard.typeScale, 1.0, accuracy: 0.0001)
    }

    /// One assertion per font token, pinning both the base constant and the multiplier.
    func testEveryFontTokenTakesTheDensityMultiplier() {
        XCTAssertEqual(comfortable.stepTitle, .system(size: 26 * 1.1, weight: .bold))
        XCTAssertEqual(comfortable.stepSubtitle, .system(size: 13 * 1.1))
        XCTAssertEqual(comfortable.phaseTitle, .system(size: 28 * 1.1, weight: .bold))
        XCTAssertEqual(comfortable.phaseSubtitle, .system(size: 15 * 1.1))
        XCTAssertEqual(comfortable.displayTitle, .system(size: 34 * 1.1, weight: .bold))
        XCTAssertEqual(comfortable.body, .system(size: 14 * 1.1))
        XCTAssertEqual(comfortable.caption, .system(size: 12 * 1.1))
        XCTAssertEqual(comfortable.railTitleSize, 27 * 1.1)
        XCTAssertEqual(comfortable.railBodySize, 14 * 1.1)
        XCTAssertEqual(comfortable.cardHeroGlyph, 20 * 1.1)
    }

    /// Every measure token is identical across tiers: a fixed window gains no room for larger text.
    func testEveryMeasureTokenIsFrozenAcrossTiers() {
        XCTAssertEqual(comfortable.contentPadH, standard.contentPadH)
        XCTAssertEqual(comfortable.contentMaxW, standard.contentMaxW)
        XCTAssertEqual(comfortable.proseMaxW, standard.proseMaxW)
        XCTAssertEqual(comfortable.wideContentMaxW, standard.wideContentMaxW)
        XCTAssertEqual(comfortable.headerBandH, standard.headerBandH)
        XCTAssertEqual(comfortable.titleSubtitle, standard.titleSubtitle)
        XCTAssertEqual(comfortable.blockGap, standard.blockGap)
        XCTAssertEqual(comfortable.sectionGap, standard.sectionGap)
        XCTAssertEqual(comfortable.topInset, standard.topInset)
        XCTAssertEqual(comfortable.anchorTopInset, standard.anchorTopInset)
        XCTAssertEqual(comfortable.phaseFooterHorizontal, standard.phaseFooterHorizontal)
        XCTAssertEqual(comfortable.phaseFooterBottom, standard.phaseFooterBottom)
        XCTAssertEqual(comfortable.railWidth, standard.railWidth)
        XCTAssertEqual(comfortable.railPad, standard.railPad)
        XCTAssertEqual(comfortable.railChildPad, standard.railChildPad)
        XCTAssertEqual(comfortable.railContentTop, standard.railContentTop)
        XCTAssertEqual(comfortable.railContentLeading, standard.railContentLeading)
        XCTAssertEqual(comfortable.railContentBottom, standard.railContentBottom)
        XCTAssertEqual(comfortable.railContentTrailing, standard.railContentTrailing)
        XCTAssertEqual(comfortable.railContentGap, standard.railContentGap)
        XCTAssertEqual(comfortable.railSubtitleMax, standard.railSubtitleMax)
        XCTAssertEqual(comfortable.cardHeroBox, standard.cardHeroBox)
        XCTAssertEqual(comfortable.cardEdge, standard.cardEdge)
        XCTAssertEqual(comfortable.cardHeaderTop, standard.cardHeaderTop)
        XCTAssertEqual(comfortable.cardHeaderGap, standard.cardHeaderGap)
        XCTAssertEqual(comfortable.cardBodyTop, standard.cardBodyTop)
        XCTAssertEqual(comfortable.cardColGap, standard.cardColGap)
        XCTAssertEqual(comfortable.cardListWidth, standard.cardListWidth)
        XCTAssertEqual(comfortable.cardCopyMax, standard.cardCopyMax)
        XCTAssertEqual(comfortable.cardFooterBottom, standard.cardFooterBottom)
        XCTAssertEqual(comfortable.cardGlyphBox, standard.cardGlyphBox)
        XCTAssertEqual(comfortable.cardGlyphNudge, standard.cardGlyphNudge)
    }

    // MARK: - Measure tokens are read, not shadowed
    // `scaleFactor` is a type scale; using it for a measure would re-merge the two axes.

    func testTheMeasureTokensHaveTheValuesThePresetsDependOn() {
        XCTAssertEqual(standard.proseMaxW, 520, "the body-copy cap Preset 6's payload column reads")
        XCTAssertEqual(standard.contentMaxW, 480, "the centred content cap")
        XCTAssertEqual(standard.headerBandH, 96,
                       "the header band CEILING — chosen from rendered comparisons at "
                       + "168/120/96/72. It was 168 (picked between the guide's 168 and the design's "
                       + "184, before the options had been compared as images), which left a 142pt "
                       + "void under a one-line heading against the earlier build's 58pt")
    }

    /// Preset 6's step content takes `maxWidth` from tokens, never from a literal.
    func testPreset6StepContentReadsMeasuresFromTokensNotLiterals() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Preset Layouts/Preset6+StepContent.swift")
        let text = try String(contentsOf: file, encoding: .utf8)

        var offenders: [String] = []
        for (index, line) in text.components(separatedBy: .newlines).enumerated()
        where line.range(of: #"maxWidth:\s*[0-9]"#, options: .regularExpression) != nil {
            offenders.append("\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
        }
        XCTAssertEqual(offenders, [],
                       "measures belong in InspectMetrics so density and the type ramp reach them")
    }

    /// Density does not flip the button control size.
    func testDensityDoesNotFlipTheButtonControlSize() {
        XCTAssertEqual(comfortable.buttonControlSize, standard.buttonControlSize)
    }

    // MARK: - P4 exemption

    /// Preset 4 (a 550x110 toast) pins `standard` and says so: larger type there would clip.
    func testPreset4PinsStandardAndSaysSo() {
        let resolved = InspectDensity.resolve(authored: "comfortable", preset: "preset4")
        XCTAssertEqual(resolved.tier, .standard)
        XCTAssertTrue(resolved.advisory?.contains("preset4") ?? false,
                      "the advisory must name the exemption: \(resolved.advisory ?? "nil")")
    }

    func testThePreset4ExemptionFollowsTheAliasesNotJustTheCanonicalName() {
        for alias in ["4", "toast", "compact-installer"] {
            XCTAssertEqual(InspectDensity.resolve(authored: "comfortable", preset: alias).tier, .standard,
                           "preset alias '\(alias)' is preset 4 and must be exempt too")
        }
    }

    /// A P4 config that authors no density gets no advisory.
    func testPreset4EarnsNoAdvisoryWhenItAuthorsNoDensity() {
        let resolved = InspectDensity.resolve(authored: nil, preset: "preset4")
        XCTAssertEqual(resolved.tier, .standard)
        XCTAssertNil(resolved.advisory)
    }

    func testEveryOtherPresetHonoursComfortable() {
        for preset in ["preset1", "preset2", "preset3", "preset5", "preset6", "preset7"] {
            XCTAssertEqual(InspectDensity.resolve(authored: "comfortable", preset: preset).tier, .comfortable,
                           "\(preset) should honour an authored density")
        }
    }

    // MARK: - Partial seam coverage

    /// Only P5 step bodies read the metrics font tokens (bookends do in every preset), so a P6 config
    /// authoring `comfortable` gets an advisory naming that boundary.
    func testAPresetWhoseStepBodiesAreNotOnTheSeamSaysSo() {
        let resolved = InspectDensity.resolve(authored: "comfortable", preset: "preset6")
        XCTAssertEqual(resolved.tier, .comfortable,
                       "density still reaches this preset's bookend screens — do not pin it to standard")
        let advisory = try? XCTUnwrap(resolved.advisory)
        XCTAssertTrue(advisory?.contains("preset6") ?? false, "\(resolved.advisory ?? "nil")")
        XCTAssertTrue(advisory?.contains("step") ?? false,
                      "the advisory must name WHICH screens are unaffected: \(resolved.advisory ?? "nil")")
    }

    func testTheFullyCoveredPresetsEarnNoCoverageAdvisory() {
        for preset in ["preset5", "preset7", "5", "7", "guided-setup"] {
            let resolved = InspectDensity.resolve(authored: "comfortable", preset: preset)
            XCTAssertEqual(resolved.tier, .comfortable)
            XCTAssertNil(resolved.advisory, "\(preset) is fully on the seam: \(resolved.advisory ?? "")")
        }
    }

    /// No density authored, no coverage advisory.
    func testAnUncoveredPresetEarnsNoAdvisoryAtStandard() {
        XCTAssertNil(InspectDensity.resolve(authored: nil, preset: "preset6").advisory)
        XCTAssertNil(InspectDensity.resolve(authored: "standard", preset: "preset6").advisory)
    }

    /// `stepBodySeamPresets` matches the presets whose sources read the font tokens.
    func testTheCoverageSetStillMatchesTheSource() throws {
        let layouts = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Preset Layouts")
        let files = try FileManager.default.contentsOfDirectory(at: layouts, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty, "no preset layout sources found at \(layouts.path)")

        let fontToken = try NSRegularExpression(
            pattern: #"metrics\.(stepTitle|stepSubtitle|phaseTitle|phaseSubtitle|displayTitle|body|caption)\b"#)

        var presetsReadingFontTokens: Set<String> = []
        for file in files {
            let name = file.lastPathComponent
            guard name.hasPrefix("Preset"), let digit = name.dropFirst("Preset".count).first,
                  digit.isNumber else { continue }
            let source = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            if fontToken.firstMatch(in: source, range: range) != nil {
                presetsReadingFontTokens.insert("preset\(digit)")
            }
        }

        XCTAssertEqual(presetsReadingFontTokens, ["preset5"],
                       "preset step bodies on the metrics font seam moved — update "
                       + "InspectDensity.stepBodySeamPresets and this expectation together")
        XCTAssertEqual(InspectDensity.stepBodySeamPresets, ["preset5"],
                       "preset7 is gone from this set because it is gone as a preset: it now "
                       + "NORMALIZES onto preset5 (InspectSizes.normalizePreset), so it cannot be a "
                       + "distinct member of a set keyed on normalized names")
    }

    /// Every Preset 7 spelling (`"7"`, `"guided-setup"`) still normalizes onto preset 5.
    func testEveryPreset7SpellingNormalizesOntoPreset5() {
        for spelling in ["7", "preset7", "guided-setup", "guided"] {
            XCTAssertEqual(InspectSizes.normalizePreset(spelling), "preset5",
                           "'\(spelling)' must still resolve — retiring the preset must not break "
                           + "configs that author it")
        }
    }

    /// Retired Preset 7 takes the plain 820x600 footprint.
    func testRetiredPreset7TakesThePlainFootprint() {
        for mode in ["standard", "compact", "large", "setup"] {
            let size = InspectSizes.getSize(preset: "preset7", mode: mode)
            XCTAssertEqual(size.0, 820, "guided setup width moved on '\(mode)'")
            XCTAssertEqual(size.1, 600, "guided setup height moved on '\(mode)'")
        }
    }

    // MARK: - Layout seam

    /// The smallest conformer; the scales come from the protocol extension, the production path.
    private struct DensityProbe: InspectLayoutProtocol {
        let inspectState: InspectState
        var body: some View { EmptyView() }
    }

    private func probe(preset: String, density: String?) -> DensityProbe {
        let state = InspectState()
        state.uiConfiguration.preset = preset
        state.uiConfiguration.density = density
        return DensityProbe(inspectState: state)
    }

    func testTheSeamFeedsDensityToTypeScaleOnly() {
        let comfortable = probe(preset: "preset5", density: "comfortable")
        let standard = probe(preset: "preset5", density: nil)

        XCTAssertEqual(comfortable.typeScale, standard.typeScale * 1.1, accuracy: 0.0001)
        XCTAssertEqual(comfortable.measureScale, standard.measureScale, accuracy: 0.0001,
                       "measureScale is pinned to the window and must not follow density")
    }

    /// The legacy `scaleFactor:` feed never sees density, so measures cannot move through it.
    func testTheLegacyOneKnobFeedNeverSeesDensity() {
        XCTAssertEqual(probe(preset: "preset5", density: "comfortable").scaleFactor,
                       probe(preset: "preset5", density: nil).scaleFactor,
                       accuracy: 0.0001)
    }

    func testTheSeamHonoursThePreset4Exemption() {
        XCTAssertEqual(probe(preset: "preset4", density: "comfortable").typeScale,
                       probe(preset: "preset4", density: nil).typeScale,
                       accuracy: 0.0001)
    }

    func testTheSeamFallsBackToStandardOnAnUnknownTier() {
        XCTAssertEqual(probe(preset: "preset5", density: "cozy").typeScale,
                       probe(preset: "preset5", density: nil).typeScale,
                       accuracy: 0.0001)
    }

    /// Metrics built from the seam grow type and freeze measure.
    func testMetricsBuiltFromTheSeamGrowTypeAndFreezeMeasure() {
        let comfortable = probe(preset: "preset5", density: "comfortable").metrics
        let standard = probe(preset: "preset5", density: nil).metrics

        XCTAssertEqual(comfortable.stepTitle, .system(size: 26 * 1.1, weight: .bold))
        XCTAssertEqual(standard.stepTitle, .system(size: 26, weight: .bold))
        XCTAssertEqual(comfortable.contentMaxW, standard.contentMaxW)
        XCTAssertEqual(comfortable.blockGap, standard.blockGap)
        XCTAssertEqual(comfortable.anchorTopInset, standard.anchorTopInset)
    }

    /// Density does not move the window.
    func testDensityDoesNotMoveTheWindow() {
        XCTAssertEqual(probe(preset: "preset5", density: "comfortable").windowSize,
                       probe(preset: "preset5", density: nil).windowSize)
    }

    // MARK: - Corpus

    /// No in-repo example authors density.
    func testNoCorpusConfigAuthorsDensityYet() throws {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialogTests/Fixtures/inspect")
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertFalse(files.isEmpty, "no example configs found at \(dir.path)")

        var authored: [String] = []
        for file in files {
            let config = try JSONDecoder().decode(InspectConfig.self, from: Data(contentsOf: file))
            if let density = config.density {
                authored.append("\(file.lastPathComponent): \(density)")
            }
        }
        XCTAssertEqual(authored, [])
    }
}
