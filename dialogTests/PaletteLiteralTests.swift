//
//  PaletteLiteralTests.swift
//  dialogTests
//
//  Source scans over dialog/Views/Inspect: every colour comes from `@Environment(\.palette)` or
//  a named sanction. SURFACE literals (white/black/hex paint) and SEMANTIC literals (.red,
//  .semanticWarning, ...) are counted separately; on-accent white glyphs are excluded.
//  Also covers dark brand palette resolution, hex validation and the backtick comment convention.
//
//  Known gap: the walk never reaches dialog/Views/Shared, so a hue map defined there and read
//  from inspect sites is not counted.
//

import XCTest
import SwiftUI
@testable import Dialog

final class PaletteLiteralTests: XCTestCase {

    // MARK: - Source access

    /// Everything under the inspect tree, as (path, source).
    private func inspectSources() throws -> [(path: String, source: String)] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect")
        var out: [(String, String)] = []
        let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        if let walker {
            for case let file as URL in walker where file.pathExtension == "swift" {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                out.append((file.lastPathComponent, text))
            }
        }
        XCTAssertFalse(out.isEmpty, "found no inspect sources — the walk is broken, not the tree")
        return out
    }

    /// Lines carrying a SURFACE literal. A literal that paints (fill, stroke, background) counts;
    /// one that only tints a glyph or label (foregroundStyle, foregroundColor, tint, including via
    /// a ternary) is on-accent and excluded. A line that is already a literal through a
    /// `Color.`-spelled value keeps the narrower adjacency carve-out so a bare `.white` branch
    /// cannot un-count it.
    private func surfaceLiteralLines(_ source: String) throws -> [String] {
        try source.split(separator: "\n", omittingEmptySubsequences: false).compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("//") else { return nil }
            let hasOtherLiteral = line.contains("Color.white") || line.contains("Color.black")
                || line.contains("Color(white:") || line.contains("Color(red:")
                || line.contains("Color(hex: \"") || line.contains("Color(.textBackgroundColor)")
                || line.contains("Color(nsColor:")
            let hasBareWhite = try Self.bareWhitePattern.firstMatch(
                in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) != nil
            guard hasOtherLiteral || hasBareWhite else { return nil }

            let hasPaint = line.contains(".background(") || line.contains(".fill(")
                || line.contains(".stroke")
            let isAccentCall = line.contains(".foregroundStyle(") || line.contains(".foregroundColor(")
                || line.contains(".tint(")
            let onAccentOnly: Bool
            if hasOtherLiteral {
                onAccentOnly = (line.contains(".foregroundStyle(.white")
                                || line.contains(".foregroundColor(.white"))
                    && !hasPaint
            } else {
                onAccentOnly = isAccentCall && !hasPaint
            }
            return onAccentOnly ? nil : String(line)
        }
    }

    /// `surfaceLiteralLines` minus the content-keyed sanctions, as "path:line".
    private func surfaceLiteralSites(_ source: String, path: String) throws -> [String] {
        try source.split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { offset, raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard try !surfaceLiteralLines(String(raw)).isEmpty else { return nil }
            return Self.surfaceSanctionedSites["\(path)|\(line)"] != nil ? nil : "\(path):\(offset + 1)"
        }
    }

    /// Bare `.white` only; `Color.white` goes through the `hasOtherLiteral` path.
    private static var bareWhitePattern: NSRegularExpression { get throws { try NSRegularExpression(pattern: #"(?<!Color)\.white\b"#) } }

    /// Files whose literals are the subject, exempt wholesale.
    private static let sanctioned: Set<String> = [
        // the resolver's own defaults are the one place a hex may live outside a renderer
        "ResolvedPalette.swift",
        "SemanticColors.swift",      // defines the semantic tokens
        "AppearanceSwatch.swift",    // light/dark preview swatches; the literals are the content
        // debug-only (DIALOG_INSPECT_DEBUG); must hold against any brand ground and read as not the product
        "InspectDebugPanel.swift",
        // colour arithmetic: black/white are blend targets, Color(red:)/Color(nsColor:) are constructor parts
        "BentoSurface.swift",
        // every literal is white or black on a photograph, which has no light/dark variant
        "SetupAssistantShell.swift",
        "SetupAssistantFullBleedShell.swift",
        // dark in both appearances by design; the near-black ground is the artwork
        "SplashChooserShell.swift"
    ]

    /// SURFACE's site-level sanctions: "file|trimmed line" to the number of copies the file
    /// carries. Content-keyed so edits above a line do not break the match; count-pinned so a
    /// new copy fails instead of inheriting the sanction. A 0 pins that a line stays gone.
    private static let surfaceSanctionedSites: [String: Int] = [
        // S0: a mask; only the alpha channel is read
        "CardStepShell.swift|Rectangle().fill(Color.black)": 1,
        "CardStepShell.swift|LinearGradient(colors: [Color.black, Color.black.opacity(0)],": 1,
        // S1: on-accent ink written where the classifier cannot see it; the fill under it does not adapt
        "SettingsPaneMockup.swift|Circle().fill(.white)": 1,
        // paint on a desktop picture, which has no light/dark variant
        "DesktopNotificationMockup.swift|.fill(.white.opacity(0.16))": 1,
        "DesktopNotificationMockup.swift|Circle().fill(.white.opacity(0.5))": 1,
        "DesktopNotificationMockup.swift|.foregroundStyle(.white)": 1,
        "RailStepComponents.swift|Circle().fill(Color.white.opacity(0.26))": 1,
        "RailStepComponents.swift|case .active: return .white": 1,
        "BookendCeremonyComponents.swift|Circle().fill(Color.white.opacity(0.22))": 1,
        "BookendCeremonyComponents.swift|Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1)": 1,
        "StatusComponents.swift|.fill(.white)": 1,
        // toggle thumb and radio centre dot, white in both appearances like the native controls
        "BrandSwitches.swift|.fill(.white)": 2,
        "BrandTrackControls.swift|.fill(.white)": 1,
        "BentoCellView.swift|mixedTitleBlock(includeSubtitle: true, titleColor: .white,": 1,
        "BentoCellView.swift|mixedTitleBlock(includeSubtitle: false, titleColor: .white,": 1,
        "BentoCellView.swift|subtitleColor: .white.opacity(0.9), shadowed: true)": 2,
        "CardShowcaseView.swift|private var stageInk: Color { .white }": 1,
        "CardStepComponents.swift|disabled ? text.opacity(0.31) : .white": 1,

        // S2: scrims and shadows, black in both appearances by construction
        "MediaComponents.swift|.shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)": 1,
        "MediaComponents.swift|.shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)": 1,
        "Preset5+CardSubsteps.swift|.shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)": 3,
        "Preset5+CardProgress.swift|Color.black.opacity(0.4)": 1,
        // the Preset 1/2 help control has no disc, so no disc shadow
        "PresetOverlayComponents.swift|.shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)": 0,
        // the compliance card has no drop shadow, matching its header card
        "ComplianceComponents.swift|color: Color.black.opacity(0.06),": 0,
        "Preset5+Processing.swift|Color.black.opacity(0.4)": 1,
        "Preset6.swift|colors: [.clear, Color.black.opacity(0.5)],": 1,
        "PresetCommonViews.swift|backgroundColor: Color = Color.black.opacity(0.7),": 1,
        "DockPicker.swift|.fill(Color.black.opacity(0.25))": 1,

        // S3: artwork; the literals are the content
        "CardMediaViewer.swift|private static let stage = Color(red: 0.957, green: 0.961, blue: 0.969)": 1,
        // an email signature renders on white in every appearance
        "GuidancePickerBlocks.swift|private let panelFill = Color(red: 0.933, green: 0.945, blue: 0.965) // #eef1f6": 1,
        "GuidancePickerBlocks.swift|private let ink = Color(red: 0.114, green: 0.114, blue: 0.122)       // #1d1d1f": 1,
        "GuidancePickerBlocks.swift|Rectangle().fill(Color(red: 0.84, green: 0.86, blue: 0.89))": 1,
        "GuidancePickerBlocks.swift|.foregroundStyle(Color(red: 0.33, green: 0.38, blue: 0.44))": 1,
        "GuidancePickerBlocks.swift|.foregroundStyle(Color(red: 0.48, green: 0.53, blue: 0.60))": 1,
        // window traffic lights in a depicted Mac window; green means zoom, not success
        "BookendCeremonyComponents.swift|Circle().fill(Color(hex: \"#FF5F57\")).frame(width: 6, height: 6)": 1,
        "BookendCeremonyComponents.swift|Circle().fill(Color(hex: \"#FEBC2E\")).frame(width: 6, height: 6)": 1,
        "BookendCeremonyComponents.swift|Circle().fill(Color(hex: \"#28C840\")).frame(width: 6, height: 6)": 1,
        // a depicted system tooltip, which already inverts with appearance
        "BookendCeremonyComponents.swift|.foregroundStyle(scheme == .dark ? Color.black : .white)": 1,
        "BookendCeremonyComponents.swift|.background(RoundedRectangle(cornerRadius: 7).fill(scheme == .dark ? Color.white : Color(hex: \"#1D1D1F\")))": 1,

        // S4: debug-only overlay
        "BentoGridView.swift|.background(Color.black.opacity(0.65))": 1,

        // S1 on a scrim; the non-scrim branch reads the palette
        "PortalChrome.swift|return style.isOnScrim ? .white.opacity(0.7) : palette.textMuted": 1,
        "PortalChrome.swift|style.isOnScrim ? .white.opacity(0.92) : palette.text.opacity(0.8)": 1,

        // S5: defaults an authored backdrop palette replaces entirely
        "PhaseContainer.swift|scheme == .dark ? Color(hex: \"#1F2229\") : Color(hex: \"#F5F6F8\")": 1,
        "PhaseContainer.swift|? [Color(hex: \"#2A2D34\"), Color(hex: \"#1F2229\")]": 1,
        "PhaseContainer.swift|: [Color(hex: \"#EEF1F6\"), Color(hex: \"#DFE4EE\"), Color(hex: \"#CDD6E6\")],": 1,
        "BookendScreenView.swift|return palette.count >= 2 ? palette : [Color(hex: \"#2BD07A\"), Color(hex: \"#2FB6D9\"), Color(hex: \"#5B6EF5\")]": 1,

        // S6: an authored dark-style panel is dark in both appearances by instruction
        "StatusComponents.swift|isDarkStyle ? Color.black.opacity(0.85) : palette.cardSurface.opacity(0.5)": 1,
        "StatusComponents.swift|isDarkStyle ? .white : palette.text": 1,
        "StatusComponents.swift|isDarkStyle ? .white.opacity(0.7) : palette.textMuted": 1,
        "StatusComponents.swift|isDarkStyle ? Color.white.opacity(0.2) : palette.hairline": 1,

        // S7: colour arithmetic and a glossy highlight, per line because the file also draws a view
        "GradientIconTile.swift|return Color(nsColor: NSColor(hue: normalizedHue / 360, saturation: saturation, brightness: brightness, alpha: base.alpha))": 1,
        "GradientIconTile.swift|color.mix(with: .white, by: 0.16)": 1,
        "GradientIconTile.swift|.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1)": 1,

        // S8: the duration chip sits on a movie, not the window; one media box, so one copy
        "PlainSimplePageChrome.swift|.background(Capsule().fill(Color.black.opacity(0.55)))": 1

    ]


    /// SEMANTIC literals assert meaning (.red, Color.orange, .semanticWarning). Disjoint from
    /// SURFACE by design; bare `.white` belongs to SURFACE and must not be added here.
    private static var semanticPattern: NSRegularExpression { get throws { try NSRegularExpression(
        pattern: #"(?<!Color)\.(red|green|orange|blue|gray)\b"#
               + #"|Color\.(red|green|orange|blue|gray)\b"#
               + #"|\.semantic(Success|Warning|Failure|Info)\b"#
    ) } }

    private static func isSemanticLiteralLine(_ line: String) throws -> Bool {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return try semanticPattern.firstMatch(in: line, range: range) != nil
    }

    /// SEMANTIC's sanctions, keyed "file|trimmed line"; each must name exactly one line
    /// (`testSemanticSanctionsAreUnambiguous`).
    private static let semanticSanctionedSites: Set<String> = [
        // debug-only hint
        "GuidanceContentView.swift|.foregroundStyle(.red)",
        // preview bodies under #if DEBUG; the matcher skips comments, not preprocessor blocks
        "ProceduralGradientView.swift|ProceduralGradientView(seed: \"sofa\", palette: [.blue, .cyan], style: .vivid)",
        "SidebarNavigationModule.swift|accentColor: .blue,"
    ]

    /// A content key that matched two lines would exempt a literal nobody decided about.
    func testSemanticSanctionsAreUnambiguous() throws {
        let sources = try inspectSources()
        for site in Self.semanticSanctionedSites {
            let parts = site.split(separator: "|", maxSplits: 1).map(String.init)
            let (file, needle) = (parts[0], parts[1])
            guard let text = sources.first(where: { $0.path == file })?.source else {
                return XCTFail("sanctioned file is not in the walk root: \(file)")
            }
            let hits = text.split(separator: "\n").filter {
                $0.trimmingCharacters(in: .whitespaces) == needle
            }.count
            XCTAssertEqual(hits, 1,
                           "\(file) has \(hits) lines matching the sanctioned text — a content "
                           + "key must name exactly one line or it exempts more than was decided")
        }
    }

    /// Each SURFACE sanction matches exactly its pinned number of copies.
    func testSurfaceSanctionsMatchTheirPinnedCounts() throws {
        let sources = try inspectSources()
        for (site, pinned) in Self.surfaceSanctionedSites {
            let parts = site.split(separator: "|", maxSplits: 1).map(String.init)
            let (file, needle) = (parts[0], parts[1])
            guard let text = sources.first(where: { $0.path == file })?.source else {
                return XCTFail("sanctioned file is not in the walk root: \(file)")
            }
            let hits = text.split(separator: "\n", omittingEmptySubsequences: false).filter {
                $0.trimmingCharacters(in: .whitespaces) == needle
            }.count
            XCTAssertEqual(hits, pinned,
                           "\(file) has \(hits) copies of a line sanctioned for \(pinned) — a "
                           + "sanction covers the sites it was decided about, not however many "
                           + "copies appear later: \(needle)")
        }
    }

    /// SEMANTIC literal sites in `source` minus the sanctions, as "path:line".
    private func semanticLiteralSites(_ source: String, path: String) throws -> [String] {
        try source.split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { offset, raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("//") else { return nil }
            guard try Self.isSemanticLiteralLine(line) else { return nil }
            let site = "\(path):\(offset + 1)"
            return Self.semanticSanctionedSites.contains("\(path)|\(line)") ? nil : site
        }
    }

    // MARK: - The mechanism

    /// The palette environment seam exists and is widely read.
    func testThePaletteEnvironmentSeamExists() throws {
        let sources = try inspectSources()
        let palette = try XCTUnwrap(sources.first { $0.path == "ResolvedPalette.swift" }?.source,
                                    "ResolvedPalette.swift must exist — it is the seam")
        XCTAssertTrue(palette.contains("EnvironmentKey"),
                      "the palette must be an environment value, not a passed parameter")
        XCTAssertTrue(palette.contains("var palette"),
                      "the environment accessor must exist")

        let readers = sources.filter { $0.source.contains("@Environment(\\.palette)") }
        XCTAssertGreaterThan(readers.count, 5,
                             "the palette is read by \(readers.count) files — if this collapses "
                             + "toward zero the tree is drifting back to literals")
    }

    /// Adding a whole-file sanction is a deliberate decision, so the count is pinned.
    func testTheSanctionedSetStaysSmall() {
        XCTAssertEqual(Self.sanctioned.count, 8,
                       "adding a sanctioned file is a decision that belongs in a commit message: "
                       + "\(Self.sanctioned.sorted())")
    }

    // MARK: - The target

    /// Every file paints from the palette or a named sanction. On failure, convert the literal or
    /// add a reasoned entry to `surfaceSanctionedSites`; never raise a ceiling.
    func testEveryFilePaintsFromThePaletteOrANamedSanction() throws {
        let sources = try inspectSources()
        var offenders: [String: Int] = [:]
        for (path, source) in sources where !Self.sanctioned.contains(path) {
            let hits = try surfaceLiteralSites(source, path: path)
            if !hits.isEmpty { offenders[path] = hits.count }
        }
        XCTAssertEqual(offenders, [:],
                       "files still painting with literal colours: "
                       + "\(offenders.sorted { $0.key < $1.key })")
    }

    /// The SURFACE count never grows past zero.
    func testSurfaceLiteralsDoNotGrowBeyondTheMeasuredCeiling() throws {
        let ceiling = 0

        let total = try inspectSources()
            .filter { !Self.sanctioned.contains($0.path) }
            .reduce(0) { try $0 + surfaceLiteralSites($1.source, path: $1.path).count }

        XCTAssertLessThanOrEqual(total, ceiling,
                                 "surface literals grew to \(total) (ceiling \(ceiling)). A new "
                                 + "component hardcoded a colour instead of reading \\.palette.")
    }

    // MARK: - The SEMANTIC class

    /// The SEMANTIC matcher counts bare hues and semantic tokens, not hex.
    func testSemanticLiteralsAreCounted() throws {
        let sample = """
        Color.red
        .green
        .semanticWarning
        Color(hex: "#EEF4FD")
        """
        let hits = try semanticLiteralSites(sample, path: "Sample.swift")
        XCTAssertEqual(hits.count, 3,
                       "bare .red/.green/.semanticWarning count; Color(hex:) belongs to the other class")
    }

    /// The SEMANTIC count never grows past zero.
    func testSemanticCeilingHolds() throws {
        let ceiling = 0

        let total = try inspectSources()
            .filter { !Self.sanctioned.contains($0.path) }
            .reduce(0) { try $0 + semanticLiteralSites($1.source, path: $1.path).count }

        XCTAssertLessThanOrEqual(total, ceiling,
                                 "semantic literals grew to \(total) (ceiling \(ceiling)). A new "
                                 + "bare colour or semantic token bypassed \\.palette instead of "
                                 + "reading it.")
    }
}

// MARK: - Dark brand palette

/// What `ResolvedPalette` answers when a config supplies light and dark palettes.
final class DarkBrandPaletteTests: XCTestCase {

    private func palette(_ primary: String? = nil, success: String? = nil,
                         textPrimary: String? = nil, notice: String? = nil) -> InspectConfig.BrandPalette {
        InspectConfig.BrandPalette(
            primary: primary, secondary: nil, accent: nil,
            success: success, warning: nil, error: nil, info: nil,
            notice: notice,
            background: nil, surface: nil, surfaceLight: nil,
            textPrimary: textPrimary, textSecondary: nil,
            logos: nil, custom: nil
        )
    }

    /// No dark palette: dark resolves exactly as light.
    func testWithoutADarkPaletteBothAppearancesResolveIdentically() {
        let light = palette("#05164D", success: "#0A7B54")
        let inLight = ResolvedPalette(from: light, dark: nil, scheme: .light)
        let inDark  = ResolvedPalette(from: light, dark: nil, scheme: .dark)
        XCTAssertEqual(inLight.primary, inDark.primary)
        XCTAssertEqual(inLight.success, inDark.success)
    }

    func testTheDarkValueWinsInADarkAppearance() {
        let resolved = ResolvedPalette(from: palette("#05164D"), dark: palette("#8FA7E8"),
                                       scheme: .dark)
        XCTAssertEqual(resolved.primary, Color(hex: "#8FA7E8"))
    }

    /// The dark palette is inert in a light appearance.
    func testTheDarkPaletteIsNotConsultedInALightAppearance() {
        let resolved = ResolvedPalette(from: palette("#05164D"), dark: palette("#8FA7E8"),
                                       scheme: .light)
        XCTAssertEqual(resolved.primary, Color(hex: "#05164D"))
    }

    // MARK: - successColor alias

    /// `successColor` is an alias that fills the palette's success slot when it is unauthored.
    func testSuccessColorAliasFeedsThePalette() {
        let resolved = ResolvedPalette(from: nil, successColor: Color(hex: "#22AA55"))
        XCTAssertEqual(resolved.success, Color(hex: "#22AA55"),
                       "an authored successColor fills the unauthored palette slot")
    }

    /// An explicit palette value wins over the alias.
    func testBrandPaletteSuccessBeatsTheAlias() {
        let resolved = ResolvedPalette(from: palette(success: "#0A7B54"),
                                       successColor: Color(hex: "#22AA55"))
        XCTAssertEqual(resolved.success, Color(hex: "#0A7B54"),
                       "an explicit brandPalette.success wins over the successColor alias")
    }

    /// The alias touches only its own slot.
    func testTheAliasDoesNotDisturbTheOtherSlots() {
        let resolved = ResolvedPalette(from: nil, successColor: Color(hex: "#22AA55"))
        XCTAssertEqual(resolved.warning, .semanticWarning)
        XCTAssertEqual(resolved.error, .semanticFailure)
        XCTAssertEqual(resolved.info, .semanticInfo)
    }

    /// Fallback is per key: an unset dark key keeps the light brand value, not a system default.
    func testUnsetDarkKeysFallBackToTheLightValueNotTheSystemDefault() {
        let light = palette("#05164D", success: "#0A7B54")
        let dark  = palette("#8FA7E8")
        let resolved = ResolvedPalette(from: light, dark: dark, scheme: .dark)
        XCTAssertEqual(resolved.primary, Color(hex: "#8FA7E8"), "the authored dark key wins")
        XCTAssertEqual(resolved.success, Color(hex: "#0A7B54"), "the unset one keeps the brand")
        XCTAssertNotEqual(resolved.success, Color.semanticSuccess,
                          "falling through to the system green would silently discard the brand")
    }

    /// A slot authored in neither palette stays nil so accessors keep their system fallbacks.
    func testASlotAuthoredInNeitherPaletteStaysUnset() {
        let resolved = ResolvedPalette(from: palette("#05164D"), dark: palette("#8FA7E8"),
                                       scheme: .dark)
        XCTAssertNil(resolved.surface)
        XCTAssertNil(resolved.textPrimary)
        XCTAssertNil(resolved.textSecondary)
    }

    /// `textFaint` is derived from `textMuted`, so the text rungs move together.
    func testTheFaintTextRungFollowsTheDarkTextColour() {
        let resolved = ResolvedPalette(from: palette(textPrimary: "#111111"),
                                       dark: palette(), scheme: .dark)
        XCTAssertEqual(resolved.textFaint, resolved.textMuted.opacity(0.7))
    }
}

// MARK: - Brand palette hex validation

/// `Color(hex:)` is not failable and renders a malformed value black, so validation names the key.
final class BrandPaletteHexValidationTests: XCTestCase {

    private let service = Config()

    private func config(light: [String: String] = [:], dark: [String: String]? = nil) throws
        -> InspectConfig {
        var root: [String: Any] = ["preset": "preset5"]
        if !light.isEmpty { root["brandPalette"] = light }
        if let dark { root["brandPaletteDark"] = dark }
        let data = try JSONSerialization.data(withJSONObject: root)
        return try JSONDecoder().decode(InspectConfig.self, from: data)
    }

    func testAWellFormedPaletteWarnsAboutNothing() throws {
        let cfg = try config(light: ["primary": "#05164D", "success": "0A7B54", "accent": "#FFF"])
        XCTAssertTrue(service.validateBrandPalettes(cfg).isEmpty,
                      "6-digit, bare-without-hash and 3-digit forms are all accepted by Color(hex:)")
    }

    func testATooShortValueIsNamedWithItsKey() throws {
        let warnings = try service.validateBrandPalettes(config(light: ["primary": "#05164"]))
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].contains("brandPalette.primary"),
                      "the warning has to name the key, or it is no better than the black itself")
    }

    /// Right length, wrong alphabet scans as zero and renders black.
    func testACorrectLengthValueWithNonHexCharactersIsCaught() throws {
        let warnings = try service.validateBrandPalettes(config(light: ["primary": "#GG164D"]))
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].contains("#GG164D"))
    }

    func testTheDarkPaletteIsValidatedToo() throws {
        let warnings = try service.validateBrandPalettes(
            config(light: ["primary": "#05164D"], dark: ["primary": "not-a-colour"]))
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].contains("brandPaletteDark.primary"),
                      "a second palette doubles the exposure, so it cannot go unchecked")
    }

    /// `logos` and `custom` hold paths and free-form strings, not colours.
    func testNonColourSlotsAreNotTreatedAsHex() throws {
        var root: [String: Any] = ["preset": "preset5"]
        root["brandPalette"] = ["primary": "#05164D",
                                "logos": ["main": "SF=building.2.fill,colour1=#17C9A5"],
                                "custom": ["tagline": "Managed by IT"]]
        let data = try JSONSerialization.data(withJSONObject: root)
        let cfg = try JSONDecoder().decode(InspectConfig.self, from: data)
        XCTAssertTrue(service.validateBrandPalettes(cfg).isEmpty)
    }
}
