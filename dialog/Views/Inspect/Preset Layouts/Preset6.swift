//
//  Preset6.swift
//  dialog
//
//  Preset 6: sidebar navigation with a content panel and footer; intro/outro use BookendScreenView.
//  Extensions in Preset6+*.swift add commands, processing, persistence and card/rail chromes.
//

import SwiftUI

// MARK: - Preset6 State Definition

struct Preset6State: InspectPersistableState {
    let completedSteps: Set<String>
    let currentStep: Int
    let guidanceFormInputs: [String: GuidanceFormInputState]
    let timestamp: Date
}

// MARK: - Preset6 View

struct Preset6View: View, InspectLayoutProtocol {
    /// Lets the footer logo pick its appearance variant (LogoConfig.footerPath).
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Navigation Direction

    enum NavigationDirection { case forward, backward }
    @ObservedObject var inspectState: InspectState
    @Environment(\.palette) var palette

    // MARK: - Module Services

    @State var dynamicState = InspectDynamicState()
    @StateObject var complianceService = ComplianceAggregatorService()
    @State var introStepMonitor = IntroStepMonitorService()

    // MARK: - State Variables

    @State var completedSteps: Set<String> = []
    @State var downloadingItems: Set<String> = []
    @State var currentStep: Int = 0
    @State var navigationDirection: NavigationDirection = .forward
    @State var processingState: InspectProcessingState = .idle
    @State var processingCountdown: Int = 0
    /// The running countdown or waiting clock; one slot, one `cancel()`.
    @State var processingClock: (any ClockJob)?
    @State var failedSteps: [String: String] = [:]
    @State var skippedSteps: Set<String> = []

    // Per-line checklist watch (see Preset6+GuideMonitoring.swift).
    @State var checklistMonitoringPoll: Poll?
    /// stepId to satisfied flags, aligned with the lines of that step's first checklist block.
    @State var checklistLineSatisfied: [String: [Bool]] = [:]

    @State var mdmOverrides: MDMBrandingOverrides?

    // Hosted on a @StateObject so the monitor survives view struct copies.
    @StateObject var commandRouter = CommandRouter()

    @State var autoNavigationTask: Task<Void, Never>?

    // Whether a step moved the window, so it is re-centred only then and never fights a user's drag.
    @State var didMoveWindow = false

    @State var showDetailOverlay: Bool = false
    /// True while the current screen seats the help control in a row (`CardHeaderHelpSeatedKey`);
    /// the corner fallback hides meanwhile.
    @State var helpSeatedInRow: Bool = false
    @State var showItemDetailOverlay: Bool = false
    @State var selectedItemForDetail: InspectConfig.IntroStep?

    @State var showOverrideDialog: Bool = false

    // Content height, for the scroll hint's bottom fade.
    @State var contentPanelContentHeight: CGFloat = 0
    @State var contentPanelScrollOffset: CGFloat = 0

    let persistenceService = InspectPersistence<Preset6State>(presetName: "preset6")

    @State var localizationService = LocalizationService()

    /// Root content size, republished to `\.inspectHostSize` for sheet sizing.
    @State private var hostSize: CGSize = .zero

    // MARK: - Type Aliases

    typealias ProcessingState = InspectProcessingState
    typealias CompletionResult = InspectCompletionResult
    typealias OverrideLevel = InspectOverrideLevel

    // MARK: - Computed Properties

    var branding: BrandingResolver {
        BrandingResolver(config: inspectState.config, mdmOverrides: mdmOverrides)
    }

    // MARK: - Localization

    /// The user's selected language code, else the default language.
    var selectedLanguageCode: String? {
        if let manual = manualLanguageSelection { return manual }
        if let locConfig = inspectState.config?.localization {
            return localizationService.resolveDefaultLanguage(from: locConfig)
        }
        return nil
    }

    /// The picked language (`StepLanguage`): a recorded value (option picker, IPC `select:`, MDM)
    /// or a dropdown/radio block, as on Preset 5.
    var manualLanguageSelection: String? {
        StepLanguage.manualSelection(key: StepLanguage.key(inspectState.config), steps: inspectState.steps,
                                     userValues: inspectState.userValues,
                                     formInputs: inspectState.guidanceFormInputs)
    }

    /// Whether the language was picked by the user rather than defaulted.
    var isManualLanguageSelection: Bool {
        manualLanguageSelection != nil
    }

    /// Index of the step holding the language picker (option step or content block).
    var languagePickerStepIndex: Int? {
        StepLanguage.pickerIndex(key: StepLanguage.key(inspectState.config), steps: inspectState.steps)
    }

    /// Localized string for an item property. A user pick applies from the picker step onward;
    /// the default language applies to every step.
    func localized(_ property: String, forItem item: InspectConfig.IntroStep, fallback: String?) -> String? {
        guard let lang = selectedLanguageCode,
              localizationService.hasLanguage(lang) else {
            return fallback
        }
        // A pick inside the flow translates its step and later ones; a pick from IPC or MDM translates all.
        guard StepLanguage.applies(isManual: isManualLanguageSelection, pickerIndex: languagePickerStepIndex,
                                   stepIndex: inspectState.steps.firstIndex(where: { $0.id == item.id })) else {
            return fallback
        }
        return localizationService.string(forLanguage: lang, key: "\(item.id).\(property)") ?? fallback
    }

    /// A step's headline from the language pack: `<step>.guidanceTitle`, else `<step>.title` (shared with Preset 5).
    func localizedHeadline(_ item: InspectConfig.IntroStep, fallback: String?) -> String? {
        localized("guidanceTitle", forItem: item, fallback: nil)
            ?? localized("title", forItem: item, fallback: fallback)
    }

    /// Delegates to LocalizationService.uiString, shared with Preset 5.
    func localizedUI(_ key: String, fallback: String) -> String {
        localizationService.uiString(key, language: selectedLanguageCode, fallback: fallback)
    }

    /// Localized UI string for the current processing step; sidecar key `{stepId}.ui.{key}`.
    func localizedProcessingText(_ key: String, fallback: String) -> String {
        guard let lang = selectedLanguageCode,
              localizationService.hasLanguage(lang),
              let stepId = processingState.stepId else { return fallback }
        return localizationService.string(forLanguage: lang, key: "\(stepId).ui.\(key)") ?? fallback
    }

    /// A guidance block with localized text applied, using the same scope rule as `localized`.
    func localizedContentBlock(_ block: InspectConfig.GuidanceContent, itemId: String, blockIndex: Int) -> InspectConfig.GuidanceContent {
        guard let lang = selectedLanguageCode,
              localizationService.hasLanguage(lang) else { return block }
        guard StepLanguage.applies(isManual: isManualLanguageSelection, pickerIndex: languagePickerStepIndex,
                                   stepIndex: inspectState.steps.firstIndex(where: { $0.id == itemId })) else { return block }
        return localizationService.localizedBlock(block, language: lang, prefix: "\(itemId).content.\(blockIndex)")
    }

    /// Highlight color: MDM, then JSON, then uiConfiguration.
    var highlightColor: Color {
        if let hex = branding.effectiveHighlightColor ?? inspectState.uiConfiguration.highlightColor.nilIfEmpty {
            return Color(hex: hex)
        }
        return .accentColor
    }

    /// Fixed sidebar width; added to the Preset 5 content width to size the window (see InspectSizes).
    static let sidebarWidthConstant: CGFloat = 250

    var sidebarWidth: CGFloat { Self.sidebarWidthConstant }

    /// Show step numbers in the sidebar.
    var showStepNumbers: Bool {
        true
    }

    /// Show completion marks in the sidebar.
    var showCompletionMarks: Bool {
        true
    }

    /// Override level from the elapsed wait time.
    var currentOverrideLevel: OverrideLevel {
        ProcessingFlow.overrideLevel(for: inspectState.steps[safe: currentStep], waited: processingState.waitElapsed)
    }

    var isProcessing: Bool {
        processingState.isActive
    }

    var shouldBlockNavigation: Bool {
        guard isProcessing, let currentItem = inspectState.steps[safe: currentStep] else {
            return false
        }
        let allowNav = currentItem.allowNavigationDuringProcessing ?? true
        return !allowNav
    }


    var isIntroStep: Bool {
        guard let firstItem = inspectState.steps.first else { return false }
        return currentStep == 0 && firstItem.resolvedPhase == "intro"
    }

    var isOutroStep: Bool {
        guard let lastItem = inspectState.steps.last else { return false }
        return currentStep == inspectState.steps.count - 1 && lastItem.resolvedPhase == "outro"
    }

    var hasBanner: Bool {
        inspectState.uiConfiguration.bannerImage != nil ||
        (inspectState.uiConfiguration.bannerTitle?.isEmpty == false)
    }

    // MARK: - Interaction Log Paths

    var interactionLogPath: String {
        "/tmp/preset6_interaction.log"
    }

    var interactionPlistPath: String {
        "/tmp/preset6_interaction.plist"
    }

    var acknowledgmentLogPath: String {
        "/var/tmp/dialog-ack.log"
    }

    // MARK: - Trigger File Configuration

    var triggerFilePath: String {
        presetTriggerFilePath(config: inspectState.config)
    }

    var finalTriggerFilePath: String {
        presetFinalTriggerFilePath(config: inspectState.config)
    }

    var triggerMode: String {
        if inspectState.config?.triggerFile != nil {
            return "custom"
        }
        return appArguments.inspectMode.present ? "dev" : "prod"
    }

    // MARK: - Initializer

    init(inspectState: InspectState) {
        self.inspectState = inspectState
    }

    // MARK: - Body

    var body: some View {
        innerBody
            // Lets `compliance-summary` and `findings-list` work as on Preset 5.
            .environment(\.complianceAggregator, complianceService)
            // Localized `ui.*` strings for shared renderers.
            .environment(\.inspectLocalization) { key, fallback in
                localizedUI(key, fallback: fallback)
            }
            // Date formatters follow the config's UI language, not `Locale.current`.
            .onChange(of: selectedLanguageCode, initial: true) { _, lang in
                DateDisplayService.shared.configure(languageCode: lang)
            }
            // Publishes the root size so DetailSheetShell can cap sheets against the real window.
            .onGeometryChange(for: CGSize.self) { $0.size } action: { hostSize = $0 }
            .environment(\.inspectHostSize, hostSize)
    }

    @ViewBuilder
    var innerBody: some View {
        ZStack {
            // The window's single surface (PhaseBackdrop; plain when nothing is configured).
            // Steps must not paint their own background; floating surfaces (sheets, override card) keep fills.
            PhaseBackdrop(config: inspectState.config)
                .ignoresSafeArea()

            // Card and rail chromes replace sidebar and footer entirely, as on Preset 5.
            if isCardChrome {
                // Injected so an authored `footerText` reaches card and rail footers.
                cardCurrentStepView
                    .environment(\.cardFooterClaim, inspectState.config?.footerText)
                    .environment(\.cardBrandSlot,
                                 BrandSlot(position: inspectState.config?.logoConfig?.position))
                    .environment(\.cardStepCounterPlacement,
                                 CardStepCounterPlacement(inspectState.config?.stepCounterPlacement))
            } else if isRailChrome {
                railCurrentStepView
                    .environment(\.cardFooterClaim, inspectState.config?.footerText)
                    .environment(\.cardBrandSlot,
                                 BrandSlot(position: inspectState.config?.logoConfig?.position))
                    .environment(\.cardStepCounterPlacement,
                                 CardStepCounterPlacement(inspectState.config?.stepCounterPlacement))
            } else if isIntroStep || isOutroStep {
                introOutroView(isOutro: isOutroStep)
            } else {
                mainLayout
            }

            // Corner logo for `.header` only; `.footer` logos are drawn by the footer, `.none` draws nothing.
            if let logoConfig = inspectState.config?.logoConfig,
               logoConfig.resolvedPosition == .header,
               !isCardChrome, !isRailChrome {  // card/rail own their full chrome
                BrandedLogoView(
                    logoConfig: logoConfig,
                    basePath: inspectState.uiConfiguration.iconBasePath
                )
                .transaction { $0.animation = nil }
            }
        }
        // Help appears only when the config sets `helpButton`; screens without a row seat show it in the corner.
        .environment(\.cardHeaderHelp, inspectState.config?.helpButton.flatMap { help in
            help.isShown
                ? CardHeaderHelp(icon: help.icon ?? "questionmark.circle",
                                 tooltip: help.tooltip ?? ChromeCopy.getHelp,
                                 action: { handleHelpButtonAction(config: help, showOverlay: $showDetailOverlay) })
                : nil
        })
        .onPreferenceChange(CardHeaderHelpSeatedKey.self) { helpSeatedInRow = $0 }
        // Log every overlay state change so an unexpected open can be traced.
        .onChange(of: showDetailOverlay) { _, shown in
            writeLog("Preset 6 help overlay: \(shown ? "presented" : "dismissed")", logLevel: .info)
        }
        .overlay {
            if let helpButtonConfig = inspectState.config?.helpButton,
               helpButtonConfig.isShown, !helpSeatedInRow {
                PositionedHelpButton(
                    config: helpButtonConfig,
                    action: { handleHelpButtonAction(config: helpButtonConfig, showOverlay: $showDetailOverlay) },
                    padding: 16
                )
            }
        }
        // The backdrop palette follows the brand palette so surfaces can tint from the same source.
        .inspectPalette(config: inspectState.config, primaryColor: branding.primaryColor)
        // Footer primary button size comes from InspectMetrics.buttonControlSize, as on Preset 5.
        .environment(\.footerControlSize, metrics.buttonControlSize)
        // One rail for every footer in the flow (`flowFooterRail`), as on Preset 5.
        .environment(\.flowFooterRail, FooterBandM.flowRail(card: isCardChrome))
        .onAppear {
            mdmOverrides = AppConfigService.shared.loadMDMOverrides(source: inspectState.config?.appConfigSource)
            if let locConfig = inspectState.config?.localization {
                localizationService.loadLanguages(from: locConfig, iconBasePath: inspectState.uiConfiguration.iconBasePath,
                                                   configPath: inspectState.configPath)
            }
            writeLog("Preset6: View appearing, loading state...", logLevel: .info)
            loadPersistedState()
            setupCommandRouter()
            startComplianceMonitoring()
            startIntroStepMonitoring()
            writeReadinessFile(config: inspectState.config, triggerFilePath: triggerFilePath,
                               preset: "6", itemCount: inspectState.steps.count,
                               itemIDs: inspectState.steps.map { $0.id })
            writeInteractionLog("launched", step: "preset6")
            logPreset6Event("view_appeared", details: [
                "totalSteps": inspectState.steps.count,
                "triggerFile": triggerFilePath
            ])
            // Only when some step has a watched checklist line (`ChecklistLineMonitor.hasWatchedLines`).
            if hasWatchedChecklistLines {
                startChecklistMonitoring()
            }
        }
        .onChange(of: inspectState.completedItems) { _, newCompletedItems in
            handleExternalCompletions(newCompletedItems)
        }
        .onChange(of: inspectState.downloadingItems) { _, newDownloadingItems in
            withAnimation(.spring()) {
                downloadingItems = newDownloadingItems
            }
        }
        .onChange(of: currentStep) { oldStep, newStep in
            if oldStep != newStep {
                autoNavigationTask?.cancel()
                autoNavigationTask = nil
            }
            applyWindowPosition(for: inspectState.steps[safe: newStep])
        }
        .sheet(isPresented: $showOverrideDialog) {
            if let stepId = processingState.stepId {
                let cancelText = localizedProcessingText("cancelButton", fallback: branding.button2Text ?? "Cancel")
                OverrideDialogView(
                    isPresented: $showOverrideDialog,
                    stepId: stepId,
                    cancelButtonText: cancelText,
                    titleText: localizedProcessingText("overrideTitle", fallback: "Override Step"),
                    descriptionText: localizedProcessingText("overrideDescription", fallback: "This step has been waiting for an extended period. How would you like to proceed?"),
                    successText: localizedProcessingText("markSuccess", fallback: "Mark as Success"),
                    failureText: localizedProcessingText("markFailed", fallback: "Mark as Failed"),
                    skipText: localizedProcessingText("skipStep", fallback: "Skip This Step"),
                    onAction: { action in
                        handleOverrideAction(action: action, stepId: stepId)
                    }
                )
            }
        }
        .detailOverlay(
            inspectState: inspectState,
            isPresented: $showDetailOverlay,
            config: inspectState.config?.detailOverlay
        )
        .itemDetailOverlay(
            inspectState: inspectState,
            isPresented: $showItemDetailOverlay,
            item: selectedItemForDetail
        )
        .onDisappear {
            savePersistedState()
            stopFileMonitoring()  // also stops DialogNotifications observation
            processingClock?.cancel()
            processingClock = nil
            stopChecklistMonitoring()
        }
    }

    // MARK: - Main Layout

    var mainLayout: some View {
        VStack(spacing: 0) {
            if let bannerPath = inspectState.uiConfiguration.bannerImage {
                let bannerH = CGFloat(inspectState.uiConfiguration.bannerHeight) * scaleFactor
                ZStack(alignment: .bottomLeading) {
                    AsyncImageView(
                        iconPath: bannerPath,
                        basePath: inspectState.uiConfiguration.iconBasePath,
                        maxWidth: .infinity,
                        maxHeight: bannerH,
                        imageFit: .fill
                    ) {
                        Rectangle()
                            .fill(highlightColor.opacity(0.15))
                            .frame(height: bannerH)
                    }

                    // Bottom fade into the content.
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: bannerH * 0.5)

                    VStack(alignment: .leading, spacing: 2) {
                        if let bannerTitle = inspectState.uiConfiguration.bannerTitle {
                            Text(bannerTitle)
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        }
                        if let message = inspectState.uiConfiguration.subtitleMessage {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity)
                .frame(height: bannerH)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 10, style: .continuous))
                .ignoresSafeArea(edges: .top)
            }

            HStack(spacing: 0) {
                SidebarNavigationModule(
                    items: inspectState.steps,
                    currentStep: currentStep,
                    completedSteps: completedSteps.union(inspectState.completedItems),
                    downloadingSteps: downloadingItems,
                    accentColor: highlightColor,
                    logoPath: nil,  // logo is in the footer
                    title: inspectState.uiConfiguration.windowTitle,
                    subtitle: inspectState.uiConfiguration.subtitleMessage,
                    iconPath: inspectState.uiConfiguration.iconPath,
                    iconBasePath: dynamicState.iconBasePathOverride ?? inspectState.uiConfiguration.iconBasePath,
                    // swiftDialog's `--overlayicon`.
                    overlayIconPath: inspectState.config?.overlayicon,
                    showStepNumbers: showStepNumbers,
                    showCompletionMarks: showCompletionMarks,
                    width: sidebarWidth,
                    scaleFactor: scaleFactor,
                    onStepSelected: handleStepSelection,
                    isNavigationBlocked: shouldBlockNavigation
                )
                .zIndex(1)

                // 1 pt layout gap between columns; the visible rule is drawn by `sidebarColumnGround`.
                Color.clear
                    .frame(width: 1)

                // Clipped so slide transitions don't bleed under the sidebar.
                contentPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }

            footerBar
        }
        .background(alignment: .topLeading) { sidebarColumnGround }
    }

    /// The sidebar ground and rule, drawn once behind the whole window. Only the host knows the column's
    /// full extent, so the fill reaches the top edge and runs behind the footer without affecting layout.
    private var sidebarColumnGround: some View {
        HStack(spacing: 0) {
            Color(NSColor.controlBackgroundColor)
                .opacity(0.5)
                .frame(width: sidebarWidth * scaleFactor)
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1)
                // The rule fades in below the top edge and out before the footer, in points so it holds at any window
                // height.
                .mask(
                    VStack(spacing: 0) {
                        // Starts 10 pt below the window edge, then ramps over 26 pt.
                        Color.clear
                            .frame(height: 10)
                        LinearGradient(colors: [.clear, .black],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 26)
                        // `Rectangle()`: a mask needs only opacity, and a colour here would count in the palette-
                        // literal census.
                        Rectangle()
                        LinearGradient(colors: [.black, .clear],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 26)
                        // Footer band (~76 pt) plus a hold-off, so the rule ends about 10 pt above the bar.
                        Color.clear
                            .frame(height: 70)
                    }
                )
            Color.clear
        }
        .ignoresSafeArea()
    }

}

// MARK: - Preset6 Wrapper

struct Preset6Wrapper: View {
    @ObservedObject var coordinator: InspectState

    var body: some View {
        Preset6View(inspectState: coordinator)
    }
}
