//
//  Preset3.swift
//  dialog
//
//
//  Preset 3: onboarding card with a greeting header, overall progress, category rows of item
//  tiles, an admin-details layer and the shared intro/outro phases.
//

import SwiftUI

struct Preset3View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @StateObject private var iconCache = PresetIconCache()
    @StateObject private var commandRouter = CommandRouter()
    @State private var localizationService = LocalizationService()
    @State private var showDetails = false
    @State private var showHelpOverlay = false
    /// The plist / managed-pref status poll.
    @State private var statusPoll: Poll?

    /// Unauthored falls through to the system accent, never to a grey.
    private var primaryColor: Color {
        inspectState.uiConfiguration.highlightColor.nilIfEmpty
            .map { Color(hex: $0) } ?? .accentColor
    }

    /// Readiness trigger file, also the command IPC path.
    private var triggerFilePath: String {
        presetTriggerFilePath(config: inspectState.config)
    }

    private var loc: PresetLocalization {
        PresetLocalization(state: inspectState, service: localizationService)
    }

    private var basePath: String? {
        inspectState.uiConfiguration.iconBasePath
    }

    private var hasPolledSources: Bool {
        inspectState.items.contains { $0.plistKey != nil || $0.managedPrefDomain != nil }
    }

    private var allComplete: Bool {
        !inspectState.trackedItems.isEmpty &&
        inspectState.trackedCompletedCount == inspectState.trackedItems.count
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
            presetLabel: "Preset3View",
            presetNumber: "3",
            localize: { loc.string($0, fallback: nil) },
            footerHorizontalPadding: FooterBandM.rail  // same rail as OnboardingFooter
        ) { proxy in
            mainPhaseView(summaryAction: proxy.summaryAction)
                .sourceTag()
        }
        .onAppear {
            if let locConfig = inspectState.config?.localization {
                localizationService.loadLanguages(from: locConfig, iconBasePath: inspectState.uiConfiguration.iconBasePath,
                                                   configPath: inspectState.configPath)
            }
            setupCommandRouter()
            startStatusPoll()
            writeLog("Preset3View: Using onboarding assembly (redesign)", logLevel: .info)
        }
        .onDisappear {
            commandRouter.stopMonitoring()
            statusPoll?.cancel()
            statusPoll = nil
        }
        // Help lives at phase level so the intro footer can seat the control and open the overlay.
        .environment(\.cardHeaderHelp, inspectState.config?.helpButton.flatMap { help in
            help.isShown
                ? CardHeaderHelp(icon: help.icon ?? "questionmark.circle",
                                 tooltip: help.tooltip ?? ChromeCopy.getHelp,
                                 action: { handleHelpButtonAction(config: help, showOverlay: $showHelpOverlay) })
                : nil
        })
        .detailOverlay(
            inspectState: inspectState,
            isPresented: $showHelpOverlay,
            config: inspectState.config?.detailOverlay
        )
        // Without `inspectPalette` every child reads the default palette.
        .inspectPalette(config: inspectState.config, primaryColor: primaryColor)
    }

    // MARK: - Main phase (assembled)

    private func mainPhaseView(summaryAction: (() -> Void)?) -> some View {
        let userName = OnboardingGreeting.resolveUserName(config: inspectState.config)
        // Once every tile is complete the greeting swaps to `completedTitle`, when authored.
        let completedOverride = allComplete
            ? loc.string("completedTitle", fallback: inspectState.config?.completedTitle)
            : nil
        let title = OnboardingGreeting.substitute(
            completedOverride ?? loc.string("title", fallback: inspectState.uiConfiguration.windowTitle) ?? "",
            userName: userName
        )
        let message = (loc.string("subtitle", fallback: inspectState.uiConfiguration.subtitleMessage))
            .map { OnboardingGreeting.substitute($0, userName: userName) }

        return VStack(spacing: 0) {
            OnboardingHeader(
                inspectState: inspectState,
                iconCache: iconCache,
                title: title,
                message: message,
                sideMessage: loc.sideMessage(),
                sideMessages: loc.sideMessages(),
                showDetails: $showDetails
            )

            // Progress and items align with the header text column (Preset3M.textColumn).
            progressZone
                .padding(.leading, Preset3M.textColumn * scaleFactor)
                .padding(.trailing, FooterBandM.rail * scaleFactor)
                .padding(.top, 10 * scaleFactor)

            ScrollView {
                // `chrome: "grid"` opts in to the tiles; the list is the default (the 3.1.1 look).
                Group {
                    if InspectSizes.preset3UsesGrid(chrome: inspectState.config?.chrome) {
                        AppTileGrid(inspectState: inspectState, iconCache: iconCache,
                                    accent: primaryColor, showDetails: showDetails)
                    } else {
                        AppRowList(inspectState: inspectState, iconCache: iconCache,
                                   accent: primaryColor, showDetails: showDetails)
                    }
                }
                .padding(.vertical, 18 * scaleFactor)
            }

            OnboardingFooter(
                inspectState: inspectState,
                accent: primaryColor,
                showDetails: showDetails,
                onButton1Action: summaryAction,
                triggerFilePath: triggerFilePath
            )
        }
        .animation(.easeInOut(duration: 0.2), value: showDetails)
        .frame(width: windowSize.width, height: windowSize.height)
        // Without it a gradient config flashes plain during the main phase.
        .background(PhaseBackdrop(config: inspectState.config))
    }

    // MARK: - Overall progress zone

    private var progressZone: some View {
        let total = inspectState.trackedItems.count
        let done = inspectState.trackedCompletedCount
        let fraction = total == 0 ? 0 : Double(done) / Double(total)

        return VStack(spacing: 7 * scaleFactor) {
            FractionBar(
                fraction: fraction,
                height: 6 * scaleFactor,
                cornerRadius: 3,
                fill: allComplete ? StatusGlyph.success.color : primaryColor,
                animateChanges: true
            )

            HStack {
                Text(progressLeftText)
                Spacer()
                Text("\(Int(fraction * 100))%")
            }
            .font(.system(size: 12 * scaleFactor))
            .foregroundStyle(.secondary)
        }
    }

    private var progressLeftText: String {
        if allComplete {
            // The authored completion text, as in 3.1.1 (`completionMessage`), before v6's own key.
            return loc.string("completionMessage", fallback: inspectState.config?.uiLabels?.completionMessage)
                ?? loc.string("setupComplete", fallback: nil) ?? "Setup complete"
        }
        return PresetCommonViews.getProgressText(
            state: inspectState,
            localizedFormat: loc.string("progressFormat", fallback: nil)
        )
    }

    // MARK: - Managed-pref (mobileconfig) item polling

    /// Polls plist and managed-pref items at `InspectConstants.plistPollInterval`, reading once
    /// immediately. A `Poll` in `@State`, because a timer publisher rebuilt per body pass never
    /// completes an interval on this view.
    private func startStatusPoll() {
        guard hasPolledSources, statusPoll == nil else { return }
        pollStatusSources()
        let poll = Poll(every: InspectConstants.plistPollInterval)
        statusPoll = poll
        poll.start { self.pollStatusSources() }
    }

    private func pollStatusSources() {
        PlistStatusPoller.pollItemStatuses(state: inspectState, basePath: basePath)
        pollManagedPrefItems()
    }

    /// Marks items complete once their managed preference has landed in /Library/Managed
    /// Preferences. Monotonic: a satisfied item stays completed.
    private func pollManagedPrefItems() {
        for item in inspectState.items {
            guard let domain = item.managedPrefDomain,
                  !inspectState.completedItems.contains(item.id) else { continue }
            let prefPath = "\(CadenceMonitorService.managedPreferencesBase)/\(domain).plist"
            let satisfied: Bool
            if let key = item.managedPrefKey {
                if let value = Validation.shared.getPlistValue(at: prefPath, key: key) {
                    satisfied = Validation.shared.performSmartEvaluation(
                        value: value,
                        evaluationType: EvaluationOperator
                            .resolve(evaluation: item.evaluation,
                                     expectedValue: item.expectedValue)?.rawValue
                            ?? (item.evaluation ?? ""),
                        expectedValue: item.expectedValue,
                        key: key
                    )
                } else {
                    satisfied = false
                }
            } else {
                // No key: the domain plist existing is the check.
                satisfied = FileManager.default.fileExists(atPath: prefPath)
            }
            if satisfied {
                inspectState.applyItemStatus(item.id, .completed)
                writeLog("Preset3View: managed pref '\(domain)' satisfied for item '\(item.id)'", logLevel: .info)
            }
        }
    }

    // MARK: - Command router

    /// Shared item-set command wiring; `progress:<id>:<pct>` drives the per-tile bars.
    private func setupCommandRouter() {
        commandRouter.wireItemBase(
            state: inspectState,
            presetLabel: "Preset3",
            triggerFilePath: triggerFilePath
        )
    }
}
