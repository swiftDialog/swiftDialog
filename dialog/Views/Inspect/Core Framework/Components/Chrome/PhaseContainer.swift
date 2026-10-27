//
//  PhaseContainer.swift
//  dialog
//
//  The three-phase window chrome (intro, main, summary) shared by Presets 1, 2 and 3: phase
//  switching, the shared backdrop, the logo overlay, phase events and readiness signalling.
//

import SwiftUI

/// Styled backdrop layers composite over the base surface at this opacity, so no palette or
/// procedural gradient can break text contrast. Hero bands draw palettes at full strength.
let phaseAtmosphereOpacity: CGFloat = 0.16

/// The backdrop every phase renders on: "plain", "splash", "gradient" (palette-tinted when one
/// is supplied) or a `ProceduralGradientStyle` name seeded by the config title.
struct PhaseBackdrop: View {
    let spec: PhaseBackdropSpec
    let seed: String
    @Environment(\.colorScheme) private var scheme

    @MainActor
    init(config: InspectConfig?) {
        self.spec = resolvePhaseBackdrop(config: config)
        self.seed = config?.title ?? "swiftDialog"
    }

    init(spec: PhaseBackdropSpec, seed: String = "swiftDialog") {
        self.spec = spec
        self.seed = seed
    }

    private var base: Color {
        scheme == .dark ? Color(hex: "#1F2229") : Color(hex: "#F5F6F8")
    }
    /// Must match `ResolvedPalette.backdropTint(for:)`: the dark palette only when the appearance
    /// is dark and one was authored.
    private var activePalette: [Color] {
        let hexes = scheme == .dark && !spec.darkPalette.isEmpty ? spec.darkPalette : spec.palette
        return hexes.map { Color(hex: $0) }
    }

    /// The splash ground is dark in both appearances, so it prefers the dark palette.
    private var splashPools: [Color] {
        (spec.darkPalette.isEmpty ? spec.palette : spec.darkPalette).map { Color(hex: $0) }
    }

    var body: some View {
        Group {
            switch spec.style {
            case "plain":
                Color(NSColor.windowBackgroundColor)
            case "splash":
                SplashGround(pools: splashPools)
            case "gradient" where activePalette.isEmpty:
                // Default wash for palette-less configs.
                LinearGradient(
                    colors: scheme == .dark
                        ? [Color(hex: "#2A2D34"), Color(hex: "#1F2229")]
                        : [Color(hex: "#EEF1F6"), Color(hex: "#DFE4EE"), Color(hex: "#CDD6E6")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case "gradient":
                ZStack {
                    base
                    LinearGradient(colors: activePalette.count > 1 ? activePalette : activePalette + activePalette,
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .opacity(phaseAtmosphereOpacity)
                }
            default:
                ZStack {
                    base
                    ProceduralGradientView(
                        seed: seed,
                        palette: activePalette,
                        style: ProceduralGradientStyle(rawValue: spec.style) ?? .ethereal
                    )
                    .opacity(phaseAtmosphereOpacity)
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// What the main-content closure may need from the phase machinery. File-scope so callers need
/// not specialize it.
struct PhaseProxy {
    let currentPhase: PresetPhase
    /// Button1 action when a summary screen is configured; nil means the caller's default exit.
    let summaryAction: (() -> Void)?
    /// Main to intro, nil when no `introScreen` is configured. Does not check whether an item is
    /// running; the surface offering the back action decides that.
    var backAction: (() -> Void)?
}

struct PhaseContainer<MainContent: View>: View {
    /// Resolved through the same `BrandPosition` the footer gates on, so seat and overlay agree.
    private var logoSeatedInFooter: Bool {
        state.config?.logoConfig?.resolvedPosition == .footer
    }

    /// Only `.header` draws the root overlay; `.footer` and `.none` do not.
    private var logoSeatedInOverlay: Bool {
        state.config?.logoConfig?.resolvedPosition == .header
    }

    /// Concrete `InspectState`: the phase helper chain is state-typed.
    @ObservedObject var state: InspectState
    let accent: Color
    let scaleFactor: CGFloat
    let windowSize: CGSize
    let triggerFilePath: String
    let presetLabel: String     // phase-event and summary log label
    let presetNumber: String    // readiness file payload
    /// Sidecar localization lookup; nil renders the config strings as authored.
    var localize: ((String) -> String?)?
    /// Intro/summary button-row insets, pre-scale; nil uses the chrome convention.
    var footerHorizontalPadding: CGFloat?
    /// Replace the shared intro/summary surface for that phase. The closure argument is the
    /// phase-advance action the override must call, so both paths advance the phase machine and
    /// run the summary cleanup identically. Type-erased so callers without an override need no
    /// extra type parameter.
    var introOverride: ((@escaping () -> Void) -> AnyView)?
    var summaryOverride: ((@escaping () -> Void) -> AnyView)?
    @ViewBuilder let main: (PhaseProxy) -> MainContent

    @State private var currentPhase: PresetPhase = .main
    /// Keeps an already-complete list on screen briefly before auto-advancing.
    @State private var mainAppearedAt: Date?

    var body: some View {
        Group {
            switch currentPhase {
            case .intro:
                if let introOverride {
                    introOverride({ currentPhase = .main })
                        .frame(width: windowSize.width, height: windowSize.height)
                        .background(PhaseBackdrop(config: state.config))
                } else if let introConfig = state.config?.introScreen {
                    PresetIntroScreenView(
                        config: introConfig,
                        highlightColor: accent,
                        scaleFactor: scaleFactor,
                        basePath: state.uiConfiguration.iconBasePath,
                        inspectState: state,
                        userName: resolveGreetingName(config: state.config),
                        localize: localize,
                        footerHorizontalPadding: footerHorizontalPadding,
                        onContinue: { currentPhase = .main }
                    )
                    .frame(width: windowSize.width, height: windowSize.height)
                    .background(PhaseBackdrop(config: state.config))
                }
            case .main:
                main(PhaseProxy(
                    currentPhase: currentPhase,
                    summaryAction: summaryTransitionAction(state: state, currentPhase: $currentPhase),
                    // Same gate as the `phaseStepRequest` "prev" arm below.
                    backAction: state.config?.introScreen != nil ? { currentPhase = .intro } : nil
                ))
                .onAppear {
                    if mainAppearedAt == nil { mainAppearedAt = Date() }
                    // Readiness is announced on main-appear, so wait-ready fires after the intro.
                    writeReadinessFile(config: state.config, triggerFilePath: triggerFilePath,
                                       preset: presetNumber, itemCount: state.items.count,
                                       itemIDs: state.items.map { $0.id })
                }
            case .summary:
                if let summaryOverride {
                    summaryOverride({
                        writeLog("\(presetLabel): Summary screen closed", logLevel: .info)
                        writeItemPresetResultFile(state: state, exitCode: 0)
                        cleanupReadinessFile(state: state, triggerFilePath: triggerFilePath, exitCode: 0)
                        exit(0)
                    })
                    .frame(width: windowSize.width, height: windowSize.height)
                    .background(PhaseBackdrop(config: state.config))
                } else if let summaryConfig = state.config?.summaryScreen {
                    PresetSummaryScreenView(
                        config: summaryConfig,
                        highlightColor: accent,
                        scaleFactor: scaleFactor,
                        basePath: state.uiConfiguration.iconBasePath,
                        inspectState: state,
                        userName: resolveGreetingName(config: state.config),
                        localize: localize,
                        footerHorizontalPadding: footerHorizontalPadding,
                        onClose: {
                            writeLog("\(presetLabel): Summary screen closed", logLevel: .info)
                            writeItemPresetResultFile(state: state, exitCode: 0)
                            cleanupReadinessFile(state: state, triggerFilePath: triggerFilePath, exitCode: 0)
                            exit(0)
                        }
                    )
                    .frame(width: windowSize.width, height: windowSize.height)
                    .background(PhaseBackdrop(config: state.config))
                }
            }
        }
        .overlay(alignment: .bottom) {
            // Brand logo across phases. A footer-seated mark must not also draw here or it
            // appears twice; the overlay is `accessibilityHidden`, so only a screenshot shows it.
            if logoSeatedInOverlay {
                PhaseLogoOverlay(
                    logoConfig: state.config?.logoConfig,
                    basePath: state.uiConfiguration.iconBasePath,
                    phase: currentPhase,
                    scaleFactor: scaleFactor
                )
            }
        }
        .onAppear {
            if state.config?.introScreen != nil { currentPhase = .intro }
        }
        .onChange(of: state.completedItems.count) { _, _ in
            phaseAutoTransitionToSummary(state: state, currentPhase: $currentPhase, mainAppearedAt: mainAppearedAt)
        }
        .onChange(of: state.phaseStepRequest) { oldValue, newValue in
            // IPC `next`/`prev`: one step per signal, no-op at either end or when the target
            // phase is not configured.
            let delta = newValue - oldValue
            for _ in 0..<abs(delta) {
                if delta > 0 {
                    switch currentPhase {
                    case .intro: currentPhase = .main
                    case .main: if state.config?.summaryScreen != nil { currentPhase = .summary }
                    case .summary: break
                    }
                } else {
                    switch currentPhase {
                    case .summary: currentPhase = .main
                    case .main: if state.config?.introScreen != nil { currentPhase = .intro }
                    case .intro: break
                    }
                }
            }
        }
        .onChange(of: currentPhase) { _, newPhase in
            writePhaseEvent(newPhase, config: state.config, presetLabel: presetLabel)

            // Items may have completed during the intro.
            if newPhase == .main {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    phaseAutoTransitionToSummary(state: state, currentPhase: $currentPhase, mainAppearedAt: mainAppearedAt)
                }
            }
        }
    }
}
