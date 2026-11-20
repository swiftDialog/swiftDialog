//
//  ResolvedPalette.swift
//  dialog
//
//  The brand palette every inspect view reads from `@Environment(\.palette)`.
//  Installed once at a preset root with `.inspectPalette(config:primaryColor:)`.
//

import SwiftUI

/// Brand palette resolved to concrete colours for one appearance.
/// Built from `InspectConfig.BrandPalette` with system-colour fallbacks.
struct ResolvedPalette {
    let primary: Color
    let secondary: Color
    let accent: Color
    let success: Color
    let warning: Color
    let error: Color
    let info: Color
    /// Settled, past-tense state (the removed-item chip), distinct from `warning`'s live caution.
    /// Authored via `BrandPalette.notice`; `Self.noticeColor(for:)` is the fallback.
    let notice: Color

    // MARK: - Optional surface / text slots
    // nil ⇒ the accessors below fall back to the system value.
    let background: Color?
    let surface: Color?
    let textPrimary: Color?
    let textSecondary: Color?

    // MARK: - Backdrop slots (`phaseBackgroundPalette` / `phaseBackgroundPaletteDark`)
    // The phase backdrop palette, so a tinted surface can match the ground it floats on.
    // Empty ⇒ no backdrop palette authored; callers fall back to the accent.
    let backdrop: [Color]
    let backdropDark: [Color]

    /// The appearance this palette was resolved for; the derived ink rungs depend on it.
    let scheme: ColorScheme

    /// The colour to wash a selected surface with: first entry of the palette in force
    /// (dark when the appearance is dark and one was authored, else light). `nil` ⇒ fall back.
    func backdropTint(for scheme: ColorScheme) -> Color? {
        (scheme == .dark && !backdropDark.isEmpty ? backdropDark : backdrop).first
    }

    // MARK: - Background Variants (0.15 opacity)

    var successBackground: Color { success.opacity(0.15) }
    var warningBackground: Color { warning.opacity(0.15) }
    var errorBackground: Color { error.opacity(0.15) }
    var infoBackground: Color { info.opacity(0.15) }
    var noticeBackground: Color { notice.opacity(0.16) }

    // MARK: - Surface / text accessors
    // Each falls back to the system value when its slot is unset.
    var windowBackground: Color { background ?? Color(NSColor.windowBackgroundColor) }
    /// A card's surface, not the window behind it: white in light, near-black in dark.
    var cardSurface: Color { surface ?? Color(NSColor.textBackgroundColor) }
    var text: Color { textPrimary ?? .primary }
    var textMuted: Color { textSecondary ?? .secondary }
    /// Third text rung (footnotes, units, hints). Derived from `textMuted` rather than `.tertiary`
    /// so all three rungs follow an authored `textSecondary`.
    var textFaint: Color { textMuted.opacity(0.7) }

    // MARK: - Derived rungs
    // Each derives from an authored token, never a new authored key, so it moves with the brand.

    /// Separator rung: hairlines, 0.5–1pt rules, chip borders. Follows `text` in both appearances.
    var hairline: Color { text.opacity(0.07) }

    /// Raised-surface rung: a tile or chip that must read a hair off the card it sits on.
    /// Translucent so it belongs to whatever ground it lands on.
    var surfaceRaised: Color { text.opacity(0.05) }

    /// Ink rung of a semantic hue: the token pushed far enough from its own wash to carry text.
    /// Dark mixes toward white and light toward black so the ink stays legible on the wash.
    var warningInk: Color { Self.ink(warning, scheme) }
    var successInk: Color { Self.ink(success, scheme) }
    var errorInk: Color { Self.ink(error, scheme) }
    var noticeInk: Color { Self.ink(notice, scheme) }

    private static func ink(_ base: Color, _ scheme: ColorScheme) -> Color {
        scheme == .dark ? base.mix(with: .white, by: 0.30) : base.mix(with: .black, by: 0.45)
    }

    /// Default `notice` pair when neither `BrandPalette.notice` nor `brandPaletteDark.notice` is authored.
    private static func noticeColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#e0b378") : Color(hex: "#724913")
    }

    // MARK: - Defaults (system colors)

    static let `default` = ResolvedPalette(
        primary: .accentColor,
        secondary: .secondary,
        accent: .accentColor,
        success: .semanticSuccess,
        warning: .semanticWarning,
        error: .semanticFailure,
        info: .semanticInfo
    )

    // MARK: - Init from BrandPalette config

    /// Resolve for an appearance from a light palette and an optional dark one. The appearance is
    /// chosen here, once, so every surface agrees on which palette is in force.
    /// Falls back per key: a dark palette naming only `primary` keeps the light values for the rest.
    /// `backdrop` is the already-resolved `PhaseBackdropSpec`; resolving it twice would let the
    /// backdrop and the surfaces on it drift apart.
    init(from palette: InspectConfig.BrandPalette?,
         dark darkPalette: InspectConfig.BrandPalette?,
         scheme: ColorScheme,
         primaryColor: Color = .accentColor,
         successColor: Color? = nil,
         backdrop: PhaseBackdropSpec = PhaseBackdropSpec()) {
        // The dark palette is never consulted in a light appearance.
        let dark = scheme == .dark ? darkPalette : nil
        func pick(_ d: String?, _ l: String?) -> String? { d ?? l }
        self.primary   = pick(dark?.primary,   palette?.primary).map { Color(hex: $0) } ?? primaryColor
        self.secondary = pick(dark?.secondary, palette?.secondary).map { Color(hex: $0) } ?? .secondary
        self.accent    = pick(dark?.accent,    palette?.accent).map { Color(hex: $0) } ?? primaryColor
        // `successColor` is an alias: `brandPalette.success` wins, then `successColor`, then default.
        self.success   = pick(dark?.success,   palette?.success).map { Color(hex: $0) }
                         ?? successColor ?? .semanticSuccess
        self.warning   = pick(dark?.warning,   palette?.warning).map { Color(hex: $0) } ?? .semanticWarning
        self.error     = pick(dark?.error,     palette?.error).map { Color(hex: $0) } ?? .semanticFailure
        self.info      = pick(dark?.info,      palette?.info).map { Color(hex: $0) } ?? .semanticInfo
        self.notice    = pick(dark?.notice,    palette?.notice).map { Color(hex: $0) } ?? Self.noticeColor(for: scheme)
        // Neutrals do not fall back to the light palette: a brand's hue is the same in both
        // appearances, but its light grey is not its dark grey. In dark, an unnamed neutral
        // resolves to the system default. `pickNeutral` is named so the asymmetry with `pick` is visible.
        func pickNeutral(_ d: String?) -> String? { d }
        self.background    = pickNeutral(dark?.background).map { Color(hex: $0) }
                             ?? (scheme == .dark ? nil : palette?.background.map { Color(hex: $0) })
        self.surface       = pickNeutral(dark?.surface).map { Color(hex: $0) }
                             ?? (scheme == .dark ? nil : palette?.surface.map { Color(hex: $0) })
        self.textPrimary   = pickNeutral(dark?.textPrimary).map { Color(hex: $0) }
                             ?? (scheme == .dark ? nil : palette?.textPrimary.map { Color(hex: $0) })
        self.textSecondary = pickNeutral(dark?.textSecondary).map { Color(hex: $0) }
                             ?? (scheme == .dark ? nil : palette?.textSecondary.map { Color(hex: $0) })
        self.backdrop     = backdrop.palette.map { Color(hex: $0) }
        self.backdropDark = backdrop.darkPalette.map { Color(hex: $0) }
        self.scheme = scheme
    }

    /// Light-only overload; resolves as `.light` with no dark palette.
    init(from palette: InspectConfig.BrandPalette?, primaryColor: Color = .accentColor,
         successColor: Color? = nil,
         backdrop: PhaseBackdropSpec = PhaseBackdropSpec()) {
        self.primary = palette?.primary.map { Color(hex: $0) } ?? primaryColor
        self.secondary = palette?.secondary.map { Color(hex: $0) } ?? .secondary
        self.accent = palette?.accent.map { Color(hex: $0) } ?? primaryColor
        self.success = palette?.success.map { Color(hex: $0) } ?? successColor ?? .semanticSuccess
        self.warning = palette?.warning.map { Color(hex: $0) } ?? .semanticWarning
        self.error = palette?.error.map { Color(hex: $0) } ?? .semanticFailure
        self.info = palette?.info.map { Color(hex: $0) } ?? .semanticInfo
        self.notice = palette?.notice.map { Color(hex: $0) } ?? Self.noticeColor(for: .light)
        // Left nil when unset so the accessors fall back to system values; not run through
        // `.resolved()`, which would inject its own neutral defaults into the chrome.
        self.background = palette?.background.map { Color(hex: $0) }
        self.surface = palette?.surface.map { Color(hex: $0) }
        self.textPrimary = palette?.textPrimary.map { Color(hex: $0) }
        self.textSecondary = palette?.textSecondary.map { Color(hex: $0) }
        self.backdrop = backdrop.palette.map { Color(hex: $0) }
        self.backdropDark = backdrop.darkPalette.map { Color(hex: $0) }
        self.scheme = .light
    }

    /// Memberwise init. Optional slots default to nil; `notice` defaults to the pair for `scheme`.
    init(primary: Color, secondary: Color, accent: Color,
         success: Color, warning: Color, error: Color, info: Color,
         notice: Color? = nil,
         background: Color? = nil, surface: Color? = nil,
         textPrimary: Color? = nil, textSecondary: Color? = nil,
         backdrop: [Color] = [], backdropDark: [Color] = [],
         scheme: ColorScheme = .light) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.success = success
        self.warning = warning
        self.error = error
        self.info = info
        self.notice = notice ?? Self.noticeColor(for: scheme)
        self.background = background
        self.surface = surface
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.backdrop = backdrop
        self.backdropDark = backdropDark
        self.scheme = scheme
    }

}

// MARK: - SwiftUI Environment Key

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = ResolvedPalette.default
}

extension EnvironmentValues {
    var palette: ResolvedPalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

// MARK: - Palette installation at a preset root

/// Palette resolution shared by the window install and the dark-surface install.
extension ResolvedPalette {
    /// Lay a managed-preference role map over an inline palette, role by role. A partial map is
    /// the normal case: roles the profile does not name keep their inline value.
    /// Merged through JSON so a role `BrandPalette` does not carry is ignored, not fatal.
    static func overlay(_ inline: InspectConfig.BrandPalette?,
                        with managed: [String: String]?) -> InspectConfig.BrandPalette? {
        guard let managed, !managed.isEmpty else { return inline }
        var dict: [String: Any] = [:]
        if let inline,
           let data = try? JSONEncoder().encode(inline),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            dict = object
        }
        for (role, hex) in managed { dict[role] = hex }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let merged = try? JSONDecoder().decode(InspectConfig.BrandPalette.self, from: data) else {
            // The inline palette is still a valid design; never blank the screen over a bad merge.
            return inline
        }
        return merged
    }

    /// The light and dark palettes a window installs, managed profile laid over the inline ones.
    /// Main-actor because `CadenceMonitorService` owns the managed plist read.
    @MainActor
    static func palettes(for config: InspectConfig?)
        -> (light: InspectConfig.BrandPalette?, dark: InspectConfig.BrandPalette?) {
        guard let ref = config?.brandPaletteRef else {
            return (config?.brandPalette, config?.brandPaletteDark)
        }
        return (overlay(config?.brandPalette,
                        with: CadenceMonitorService.resolvePalette(from: ref, dark: false)),
                overlay(config?.brandPaletteDark,
                        with: CadenceMonitorService.resolvePalette(from: ref, dark: true)))
    }
}

/// Installs the palette for the window's appearance and re-resolves when the managed profile
/// changes on disk. A `ViewModifier` so it can read `\.colorScheme` itself.
private struct InspectPaletteModifier: ViewModifier {
    let config: InspectConfig?
    let primaryColor: Color
    @Environment(\.colorScheme) private var colorScheme

    /// Bumped when the managed profile changes so `body` re-reads it through `palettes(for:)`.
    @State private var profileRevision = 0
    @State private var lastSeen: Date?
    /// Lives in `@State`: the modifier is rebuilt on every re-apply, and a timer stored on it
    /// would restart each time and never fire.
    @State private var watch: Poll?

    /// The profile can arrive after launch, so the palette is re-resolved from an mtime check,
    /// only when a ref is authored. The check is a stat, not a parse.
    private static let watchInterval: TimeInterval = 30

    private var refPath: String? {
        guard let domain = config?.brandPaletteRef?.domain else { return nil }
        return "\(CadenceMonitorService.managedPreferencesBase)/\(domain).plist"
    }

    func body(content: Content) -> some View {
        // Read so SwiftUI knows body depends on it.
        _ = profileRevision
        let resolved = ResolvedPalette.palettes(for: config)
        return content.environment(\.palette, ResolvedPalette(
            from: resolved.light,
            dark: resolved.dark,
            scheme: colorScheme,
            primaryColor: primaryColor,
            successColor: config?.successColor.map { Color(hex: $0) },
            // The same resolved backdrop the root paints with, so surfaces tint from it.
            backdrop: resolvePhaseBackdrop(config: config)))
            .onAppear { startWatch() }
            .onDisappear {
                watch?.cancel()
                watch = nil
            }
    }

    private func startWatch() {
        guard refPath != nil, watch == nil else { return }
        checkProfile()
        let poll = Poll(every: Self.watchInterval)
        watch = poll
        poll.start { self.checkProfile() }
    }

    private func checkProfile() {
        guard let path = refPath else { return }
        let stamp = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate]) as? Date
        // nil -> a date is the profile appearing, and counts as a change.
        if stamp != lastSeen {
            lastSeen = stamp
            profileRevision += 1
            writeLog("Palette: managed profile changed at \(path) — re-resolved",
                     logLevel: .info)
            InspectDebugMeter.shared.note(fact: "brand profile",
                                          stamp == nil ? "absent" : "present, re-resolved")
        }
    }
}

/// Installs the palette resolved for a dark surface regardless of the window's appearance,
/// e.g. content on a photograph under a dark scrim. Stored hues are resolved once, so overriding
/// `\.colorScheme` downstream cannot fix them; the resolver has to be asked for the right surface.
/// Pins `scheme: .dark` so an authored `brandPaletteDark` is reachable and light neutrals stay off.
private struct DarkSurfacePaletteModifier: ViewModifier {
    let config: InspectConfig?
    let primaryColor: Color

    func body(content: Content) -> some View {
        content.environment(\.palette,
                            ResolvedPalette.onDarkSurface(config: config, primaryColor: primaryColor))
    }
}

extension ResolvedPalette {
    /// The palette a dark surface's subtree is handed. The appearance is not consulted; the surface is.
    @MainActor
    static func onDarkSurface(config: InspectConfig?, primaryColor: Color) -> ResolvedPalette {
        let resolved = ResolvedPalette.palettes(for: config)
        return ResolvedPalette(
            from: resolved.light,
            dark: resolved.dark,
            scheme: .dark,
            primaryColor: primaryColor,
            successColor: config?.successColor.map { Color(hex: $0) },
            backdrop: resolvePhaseBackdrop(config: config))
    }
}

extension View {
    /// Install the palette at a preset root. Every preset calls this exactly once.
    func inspectPalette(config: InspectConfig?, primaryColor: Color) -> some View {
        modifier(InspectPaletteModifier(config: config, primaryColor: primaryColor))
    }

    /// Re-install the palette for a subtree whose ground is dark whatever the window is.
    func inspectPaletteOnDarkSurface(config: InspectConfig?, primaryColor: Color) -> some View {
        modifier(DarkSurfacePaletteModifier(config: config, primaryColor: primaryColor))
    }
}

/// Re-install the dark-surface palette only when `active`. A modifier with a Bool keeps one view
/// type and identity where a ternary over two view types would not.
struct DarkSurfaceIfNeeded: ViewModifier {
    let active: Bool
    let config: InspectConfig?
    let primaryColor: Color

    func body(content: Content) -> some View {
        if active {
            content.inspectPaletteOnDarkSurface(config: config, primaryColor: primaryColor)
        } else {
            content
        }
    }
}
