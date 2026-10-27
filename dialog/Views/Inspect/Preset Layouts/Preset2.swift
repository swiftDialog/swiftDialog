//
//  Preset2.swift
//  dialog
//
//
//  Preset 2: banner header over a paged card grid with a progress block and the shared
//  action footer.
//

import SwiftUI

struct Preset2View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @State private var showDetailOverlay = false
    /// True while the action footer seats the help control; the corner fallback stands down then.
    @State private var helpSeatedInFooter = false
    @State private var showItemDetailOverlay = false
    @State private var selectedItemForDetail: InspectConfig.ItemConfig?
    @StateObject private var iconCache = PresetIconCache()
    @StateObject private var commandRouter = CommandRouter()
    @State private var localizationService = LocalizationService()

    /// Unauthored falls through to the system accent, never to a grey.
    private var primaryColor: Color {
        inspectState.uiConfiguration.highlightColor.nilIfEmpty
            .map { Color(hex: $0) } ?? .accentColor
    }

    /// Readiness trigger file; lets `wait-ready` succeed alongside the FSEvents command path.
    private var triggerFilePath: String {
        presetTriggerFilePath(config: inspectState.config)
    }

    private var loc: PresetLocalization {
        PresetLocalization(state: inspectState, service: localizationService)
    }

    init(inspectState: InspectState) {
        self.inspectState = inspectState
    }

    var body: some View {
        PhaseContainer(
            state: inspectState,
            accent: primaryColor,
            scaleFactor: scaleFactor,
            windowSize: windowSize,
            triggerFilePath: triggerFilePath,
            presetLabel: "Preset2View",
            presetNumber: "2",
            localize: { loc.string($0, fallback: nil) }
        ) { proxy in
            mainPhaseView(summaryAction: proxy.summaryAction)
                .sourceTag()
        }
        .onAppear {
            if let locConfig = inspectState.config?.localization {
                localizationService.loadLanguages(from: locConfig, iconBasePath: inspectState.uiConfiguration.iconBasePath,
                                                   configPath: inspectState.configPath)
            }
            commandRouter.wireItemBase(
                state: inspectState,
                presetLabel: "Preset2",
                triggerFilePath: triggerFilePath
            )
            writeLog("Preset2View: Using refined deployment layout (assembly composition)", logLevel: .info)
        }
        .onDisappear {
            commandRouter.stopMonitoring()
        }
        // Help lives at phase level so the intro footer can seat the control and open the overlay.
        .environment(\.cardHeaderHelp, inspectState.config?.helpButton.flatMap { help in
            help.isShown
                ? CardHeaderHelp(icon: help.icon ?? "questionmark.circle",
                                 tooltip: help.tooltip ?? ChromeCopy.getHelp,
                                 action: { handleHelpButtonAction(config: help, showOverlay: $showDetailOverlay) })
                : nil
        })
        .detailOverlay(
            inspectState: inspectState,
            isPresented: $showDetailOverlay,
            config: inspectState.config?.detailOverlay
        )
        // Without `inspectPalette` every child reads the default palette.
        .inspectPalette(config: inspectState.config, primaryColor: primaryColor)
    }

    // MARK: - Main Phase (assembled)

    private func mainPhaseView(summaryAction: (() -> Void)?) -> some View {
        ZStack(alignment: .top) {
            PhaseBackdrop(config: inspectState.config)

            VStack(spacing: 0) {
                // The hero stays out of the page/side-message animations: animated relayout
                // re-composites the window's top edge and blinks.
                BannerHeader(
                    state: inspectState,
                    iconCache: iconCache,
                    scaleFactor: scaleFactor,
                    windowWidth: windowSize.width,
                    title: loc.string("title", fallback: inspectState.uiConfiguration.windowTitle) ?? "",
                    bannerTitle: loc.string("bannerTitle", fallback: inspectState.uiConfiguration.bannerTitle)
                )
                .transaction { $0.animation = nil }

                // Fixed `message` line (#670), distinct from the rotating side messages below.
                if let subtitle = loc.string("subtitle", fallback: inspectState.uiConfiguration.subtitleMessage),
                   !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13))    // Setup Assistant body: 13pt secondary
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        // Two lines at most, or the column below shifts.
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 56 * scaleFactor)
                        .padding(.top, 8 * scaleFactor)
                }

                // Fixed-height slot so a rotating message never shifts the layout.
                Group {
                    if let currentMessage = loc.sideMessage() {
                        Text(currentMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: InspectConstants.standardAnimationDuration), value: inspectState.uiConfiguration.currentSideMessageIndex)
                    }
                }
                .frame(height: 32 * scaleFactor)
                .padding(.horizontal, 56 * scaleFactor)

                // With the trailing spacer, this splits the spare height evenly, so the cards and
                // progress sit as one group centred between the header and the footer band.
                Spacer(minLength: 8 * scaleFactor)

                Preset2CardPager(
                    inspectState: inspectState,
                    iconCache: iconCache,
                    accent: primaryColor,
                    loc: loc,
                    onItemInfo: { item in
                        selectedItemForDetail = item
                        showItemDetailOverlay = true
                    }
                )

                Preset2ProgressBlock(
                    completed: inspectState.trackedCompletedCount,
                    total: inspectState.trackedItems.count,
                    accent: primaryColor,
                    // Sidecar format, else the authored `uiLabels.progressFormat`.
                    localizedFormat: loc.string("progressFormat", fallback: nil)
                        ?? inspectState.config?.uiLabels?.progressFormat
                )
                // Setup Assistant's large content width (600pt), centred, so the bar reads as part
                // of the card group rather than a rule across the window.
                .frame(maxWidth: 600 * scaleFactor)
                .padding(.horizontal, 40 * scaleFactor)
                .padding(.top, 24 * scaleFactor)

                Spacer(minLength: 0)
            }
            // minHeight too: with only a max an over-tall child grows the phase and pushes the band
            // below the window.
            .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
            // An inset, not a column row: the band stays pinned to the window's bottom edge.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ActionFooterRow(
                    state: inspectState,
                    tint: primaryColor,
                    scaleFactor: scaleFactor,
                    onShowDetailOverlay: { showDetailOverlay = true },
                    onButton1Action: summaryAction,
                    infoOpensDetailOverlay: false,
                    popoverArrowEdge: nil,
                    config: inspectState.config,
                    triggerFilePath: triggerFilePath,
                    // Authored only: no stock claim when `footerText` is unset or resolves empty.
                    centerText: inspectState.config?.footerText.map(resolveManagedLine).flatMap { $0.isEmpty ? nil : $0 }
                )
            }
        }
        .onPreferenceChange(CardHeaderHelpSeatedKey.self) { helpSeatedInFooter = $0 }
        .overlay {
            // Corner help button, only when no footer seated it.
            if let helpButtonConfig = inspectState.config?.helpButton,
               helpButtonConfig.isShown, !helpSeatedInFooter {
                PositionedHelpButton(
                    config: helpButtonConfig,
                    action: {
                        handleHelpButtonAction(
                            config: helpButtonConfig,
                            showOverlay: $showDetailOverlay
                        )
                    },
                    padding: 16
                )
            }
        }
        .itemDetailOverlay(
            inspectState: inspectState,
            isPresented: $showItemDetailOverlay,
            item: selectedItemForDetail,
            showsDetail: true   // the card has no room for the claim
        )
    }
}
