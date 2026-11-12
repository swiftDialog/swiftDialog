//
//  Preset5.swift
//  dialog
//
//
//  Preset 5: a linear sequence of steps (native screens, processing, portal web view, outro),
//  each rendered by its stepType. Root view, state and the step dispatch; the step bodies live
//  in the Preset5+*.swift extensions.
//

import SwiftUI
import WebKit

// MARK: - Type Aliases for Shared Enums

typealias CompletionResult = InspectCompletionResult

typealias OverrideLevel = InspectOverrideLevel


struct Preset5View: View, InspectLayoutProtocol {

    @ObservedObject var inspectState: InspectState
    @Environment(\.colorScheme) var colorScheme
    /// Built from config, not the environment: this view sets the palette for its children and
    /// cannot read it back.
    var palette: ResolvedPalette {
        ResolvedPalette(from: config?.brandPalette, dark: config?.brandPaletteDark,
                        scheme: colorScheme, primaryColor: branding.primaryColor,
                        successColor: config?.successColor.map { Color(hex: $0) })
    }

    // MARK: - Module Services
    @StateObject var monitoringService = UnifiedMonitoringService()
    @State var introStepMonitor = IntroStepMonitorService()
    /// The one cadence run, owned by `InspectState` so blocks can read it too.
    var cadenceMonitor: CadenceMonitorService { inspectState.cadenceMonitor }
    /// Step id whose continue-or-confirm sheet is showing.
    @State var confirmIncompleteStepId: String?
    @StateObject var complianceService = ComplianceAggregatorService()
    @State var dynamicState = InspectDynamicState()
    @State var preferencesService: PreferencesService?
    @State var localizationService = LocalizationService()

    /// Root content size, republished to `\.inspectHostSize` for sheet sizing.
    @State private var hostSize: CGSize = .zero

    @State var currentStepIndex: Int = 0
    /// The one pending delayed auto-advance; every scheduling site goes through
    /// `scheduleAutoAdvance`, so at most one advance is ever in flight.
    @State var autoAdvanceTask: Task<Void, Never>?
    @State var gridSelections: [String: Set<String>] = [:]  // gridSelectionKey -> selected IDs
    @State var guideSelections: Set<String> = []  // guide picker mode: selected step ids

    @State var installationItems: [InstallationItemData] = []
    @State var processingState: InspectProcessingState = .idle
    @State var carouselScrollOffset: Int = 0
    @State var carouselMeasuredWidth: CGFloat = 0  // content width feeding the adaptive card count

    @State var processingCountdown: Int = 0
    /// The running countdown or waiting clock, whichever kind; one seat, one `cancel()`.
    @State var processingClock: (any ClockJob)?
    @State var processingWaitElapsed: Int = 0  // seconds waited, drives override escalation
    @State var showOverridePicker: Bool = false
    @State var pendingOverrideStepIndex: Int = 0
    @State var lastOverrideResult: String?  // "success", "failed", or "skipped"
    @State var lastOverrideStepId: String?
    @State var failedSteps: [String: String] = [:]  // stepId -> failure reason
    @State var skippedSteps: Set<String> = []
    @State var completedProcessingSteps: Set<String> = []
    @State var completedNavigatedSteps: Set<String> = []  // every step navigated past, for the result file
    @State var didMoveWindow = false  // restore the window only when a step moved it

    @StateObject var commandRouter = CommandRouter()

    // Guide step state
    @State var guideMonitoringPoll: Poll?
    @State var guideValidationCache: [String: Bool] = [:]       // stepId -> isValid
    @State var guideLastValidationTime: [String: Date] = [:]
    @State var guideCompletedSteps: Set<String> = []
    /// stepId -> per-line satisfied flags of that step's first checklist block, so lines tick off
    /// independently of the whole-step `guideValidationCache`.
    @State var checklistLineSatisfied: [String: [Bool]] = [:]
    @State var guideFullscreenImagePresented: Bool = false
    @State var guideFullscreenImagePath: String = ""

    @State var selectedBrandId: String?

    @State var showGlobalHelpOverlay: Bool = false
    /// True while a card header seats the help control; the corner glyph stands down meanwhile.
    @State var helpSeatedInCardHeader: Bool = false
    /// True while the current card draws its own brand mark.
    @State var brandSeatedInCard: Bool = false

    /// Whether the window-corner brand mark is drawn on this screen. Shared by the mark overlay
    /// and the corner help glyph that stacks below it, so the glyph never clears a mark that is
    /// not drawn.
    var drawsCornerLogo: Bool {
        config?.logoConfig != nil && resolvedLogoPosition == .header
            && config?.construction != .card && !isPortalStep && !brandSeatedInCard
    }
    @State var showStepOverlay: Bool = false
    @State var currentStepOverlayConfig: InspectConfig.DetailOverlayConfig?

    // Portal state
    @State var loadState: PortalLoadState = .initializing
    @State var showContent: Bool = false
    @State var isRefetching: Bool = false
    /// Where the web view actually is after redirects. The address readout must follow this, never
    /// the authored URL.
    @State var portalLiveURL: URL?
    /// Rebuilds the web view on "Try again", clearing the coordinator's failed-URL latch.
    @State var portalViewId = UUID()
    @State var mdmOverrides: MDMBrandingOverrides?

    // Computed config references
    var config: InspectConfig? { inspectState.config }
    var portalConfig: InspectConfig.PortalConfig? { config?.portalConfig }
    var appConfigService: AppConfigService { AppConfigService.shared }

    var selectedBrand: InspectConfig.BrandConfig? {
        guard let id = selectedBrandId else { return nil }
        return config?.brands?.first { $0.id == id }
    }

    /// How many brands the managed allow-list hid; nil when there is no allow-list at all.
    var hiddenBrandCount: Int? {
        guard let all = config?.brands, !all.isEmpty,
              let allowed = appConfigService.loadAllowedBrandIds(source: config?.appConfigSource),
              !allowed.isEmpty else { return nil }
        return max(0, all.count - all.filter { allowed.contains($0.id) }.count)
    }

    var resolvedAvailableBrands: [InspectConfig.BrandConfig] {
        guard let allBrands = config?.brands, !allBrands.isEmpty else { return [] }
        if let allowed = appConfigService.loadAllowedBrandIds(source: config?.appConfigSource),
           !allowed.isEmpty {
            return allBrands.filter { allowed.contains($0.id) }
        }
        return allBrands
    }

    var branding: BrandingResolver {
        BrandingResolver(config: config, mdmOverrides: mdmOverrides, selectedBrand: selectedBrand, colorScheme: colorScheme)
    }

    // MARK: - Localization

    /// The manually picked language code, else the config's default language.
    var selectedLanguageCode: String? {
        if let manual = manualLanguageSelection { return manual }
        if let locConfig = config?.localization {
            return localizationService.resolveDefaultLanguage(from: locConfig)
        }
        return nil
    }

    /// The picked language: grid picker, recorded value (option picker, IPC, MDM) or a form block.
    var manualLanguageSelection: String? {
        StepLanguage.manualSelection(key: StepLanguage.key(config), steps: allSteps,
                                     userValues: inspectState.userValues,
                                     formInputs: inspectState.guidanceFormInputs,
                                     gridSelections: gridSelections)
    }

    var isManualLanguageSelection: Bool { manualLanguageSelection != nil }

    /// Index of the step that contains the language picker, whatever form it takes.
    var languagePickerStepIndex: Int? {
        StepLanguage.pickerIndex(key: StepLanguage.key(config), steps: allSteps)
    }

    /// Whether the step is translated: a pick from a picker in the flow translates its own step and
    /// the ones after it; a pick from outside (IPC, MDM) translates every step.
    func languageApplies(toStep stepId: String) -> Bool {
        StepLanguage.applies(isManual: isManualLanguageSelection, pickerIndex: languagePickerStepIndex,
                             stepIndex: allSteps.firstIndex(where: { $0.id == stepId }))
    }

    /// Localized string for a step property, keyed `<stepId>.<property>`.
    func localized(_ property: String, forStep step: InspectConfig.IntroStep, fallback: String?) -> String? {
        guard let lang = selectedLanguageCode,
              localizationService.hasLanguage(lang) else {
            return fallback
        }
        guard languageApplies(toStep: step.id) else { return fallback }
        return localizationService.string(forLanguage: lang, key: "\(step.id).\(property)") ?? fallback
    }

    /// Copy of a content block with localized text, keyed `<stepId>.content.<blockIndex>`.
    func localizedContentBlock(_ block: InspectConfig.GuidanceContent, stepId: String, blockIndex: Int) -> InspectConfig.GuidanceContent {
        guard let lang = selectedLanguageCode,
              localizationService.hasLanguage(lang) else { return block }
        guard languageApplies(toStep: stepId) else { return block }
        return localizationService.localizedBlock(block, language: lang, prefix: "\(stepId).content.\(blockIndex)")
    }

    /// Localized copies of a step's option cards, keyed `<stepId>.options.<cardId>.label` and
    /// `.subtitle`. Every other field must be carried through; a dropped field silently changes
    /// every localized flow.
    func localizedOptionCards(for step: InspectConfig.IntroStep) -> [InspectConfig.OptionCard] {
        guard let cards = step.optionCards else { return [] }
        return cards.map { card in
            InspectConfig.OptionCard(
                cardId: card.cardId,
                label: localized("options.\(card.cardId).label", forStep: step, fallback: card.label) ?? card.label,
                subtitle: localized("options.\(card.cardId).subtitle", forStep: step, fallback: card.subtitle),
                sfSymbol: card.sfSymbol,
                iconPath: card.iconPath,
                value: card.value,
                dockPreview: card.dockPreview,
                state: card.state,
                preview: card.preview,
                effort: card.effort,
                exposure: card.exposure,
                recommended: card.recommended,
                recommendReason: card.recommendReason,
                action: card.action,
                url: card.url,
                differentiator: card.differentiator,
                category: card.category,
                includes: card.includes,
                cancels: card.cancels,
                runOrder: card.runOrder,
                runMessage: card.runMessage
            )
        }
    }

    // MARK: - Step Navigation

    /// Where the cursor lands when the step list changes under it: the same step id; else the
    /// nearest earlier step that survived; else the first. Pure.
    static func reloadedStepIndex(oldIds: [String], newIds: [String], current: Int) -> Int {
        guard !newIds.isEmpty else { return 0 }
        guard oldIds.indices.contains(current) else { return min(max(current, 0), newIds.count - 1) }
        for index in stride(from: current, through: 0, by: -1) {
            if let found = newIds.firstIndex(of: oldIds[index]) { return found }
        }
        return 0
    }

    /// The step sequence: the runtime overlay once step_add/step_remove has edited it, else the
    /// decoded steps with the introScreen/summaryScreen bookends projected in.
    var allSteps: [InspectConfig.IntroStep] {
        inspectState.runtimeSteps ?? config?.stepsWithBookends ?? []
    }

    var totalSteps: Int { allSteps.count }

    var hasSteps: Bool { !allSteps.isEmpty }

    /// Nil when the index is out of bounds.
    var currentStep: InspectConfig.IntroStep? {
        guard currentStepIndex >= 0 && currentStepIndex < allSteps.count else { return nil }
        return allSteps[currentStepIndex]
    }

    /// Where this step's content sits (`ContentStance`). Preset default is top-leading; a step or
    /// the whole config may override it.
    func stance(for step: InspectConfig.IntroStep?) -> ContentStance {
        // Split step types lay text in a column beside media and read flush left by construction;
        // a config-wide alignment must not re-centre them. The step's own alignment still applies.
        let isSplit = ["assistant", "media"].contains(step?.resolvedStepType ?? "standard")
        // Picker step types take their own band default; both config rungs still outrank it.
        let presetStance = ContentStanceResolver.presetDefault(
            forStepType: step?.resolvedStepType, preset: .topLeading)
        return ContentStanceResolver.resolve(stepAnchor: step?.contentAnchor,
                                             stepAlign: step?.contentAlign,
                                             configAnchor: config?.contentAnchor,
                                             configAlign: isSplit ? nil : config?.contentAlign,
                                             preset: presetStance)
    }

    var stance: ContentStance { stance(for: currentStep) }

    /// `logoConfig.position` resolved to footer, header or none.
    var resolvedLogoPosition: BrandPosition {
        BrandPosition(authored: config?.logoConfig?.position)
    }

    /// The authored footer claim (MDM > brand > JSON); unset or `""` draws no claim.
    var footerClaim: String? {
        branding.footerText
    }

    /// Phase of the persistent logo, read from the step's phase axis rather than its renderer.
    var logoPhase: LogoPhase {
        switch currentStep?.resolvedPhase {
        case "intro": return .intro
        case "outro": return .summary
        default: return .main
        }
    }

    var isPortalStep: Bool {
        currentStep?.stepType == "portal"
    }

    /// Per-step portal config overrides the global one.
    var effectivePortalConfig: InspectConfig.PortalConfig? {
        currentStep?.portalConfig ?? config?.portalConfig
    }

    var body: some View {
        innerBody
            // Debug panel: off unless DIALOG_INSPECT_DEBUG is set.
            .overlay(alignment: .topTrailing) {
                if InspectDebugMeter.panelEnabled() {
                    InspectDebugPanel().padding(10)
                }
            }
            // Shared renderers (content blocks) read these from the environment.
            .environment(\.complianceAggregator, complianceService)
            .environment(\.inspectLocalization) { key, fallback in
                localizedUI(key, fallback: fallback)
            }
            // Date formatters follow the config's language, not Locale.current.
            .onChange(of: selectedLanguageCode, initial: true) { _, lang in
                DateDisplayService.shared.configure(languageCode: lang)
            }
            // Sheets cap their height against the real window size.
            .onGeometryChange(for: CGSize.self) { $0.size } action: { hostSize = $0 }
            .environment(\.inspectHostSize, hostSize)
    }

    /// Constructions whose shell draws its own footer band; the accent ribbon stays off for them.
    static func constructionOwnsItsFooter(_ construction: InspectSizes.Construction?) -> Bool {
        switch construction {
        case .card, .provisioning, .migration, .setupAssistant: return true
        default: return false
        }
    }

    @ViewBuilder
    var innerBody: some View {
        ZStack {
            mainContent
                // A card header seats the help control and reports it; every other screen draws
                // the same glyph in the corner instead.
                .environment(\.cardHeaderHelp, config?.helpButton.flatMap { help in
                    help.isShown
                        ? CardHeaderHelp(icon: help.icon ?? "questionmark.circle",
                                         tooltip: help.tooltip ?? ChromeCopy.getHelp,
                                         action: {
                                             writeLog("HelpButton: opening the help overlay (Preset 5)", logLevel: .info)
                                             showGlobalHelpOverlay = true
                                         })
                        : nil
                })
                .onPreferenceChange(CardHeaderHelpSeatedKey.self) { helpSeatedInCardHeader = $0 }
                .onChange(of: showGlobalHelpOverlay) { _, shown in
                    writeLog("Preset 5 help overlay: \(shown ? "presented" : "dismissed")", logLevel: .info)
                }
                .onPreferenceChange(CardBrandSeatedKey.self) { brandSeatedInCard = $0 }

            // Accent ribbon on the window's bottom edge, opt-in via `showAccentBorder`; never under
            // a construction that draws its own footer band.
            if config?.showAccentBorder ?? false, !Self.constructionOwnsItsFooter(config?.construction) {
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(branding.primaryColor.opacity(0.25))
                        .frame(height: 1)
                }
            }

            if let helpButton = config?.helpButton, helpButton.isShown, !helpSeatedInCardHeader {
                cornerHelpButton(config: helpButton)
            }

            // Persistent corner logo for the `.header` seat; footer logos are drawn by the footer
            // row, and a screen whose chrome draws the brand itself stands this down.
            if let logoConfig = config?.logoConfig, drawsCornerLogo {
                BrandedLogoView(
                    logoConfig: logoConfig,
                    basePath: effectiveIconBasePath,
                    phase: logoPhase,
                )
            }

            if let bannerConfig = config?.instructionBanner,
               let bannerText = bannerConfig.text {
                VStack {
                    InstructionBanner(
                        text: bannerText,
                        autoDismiss: bannerConfig.autoDismiss ?? true,
                        dismissDelay: bannerConfig.dismissDelay ?? 5.0,
                        icon: bannerConfig.icon
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer()
                }
            }
        }
        // The window's one surface. A step must not paint its own full-area fill; floating
        // surfaces (sheets, the override picker) keep theirs.
        .background(PhaseBackdrop(config: inspectState.config))
        .inspectPalette(config: config, primaryColor: branding.primaryColor)
        .environment(\.footerControlSize, metrics.buttonControlSize)
        // One footer rail for the whole flow, so the primary button never moves between screens.
        .environment(\.flowFooterRail, FooterBandM.flowRail(card: config?.construction == .card))
        .environment(\.cardBrandSlot, BrandSlot(position: config?.logoConfig?.position))
        .environment(\.cardStepCounterPlacement,
                     CardStepCounterPlacement(config?.stepCounterPlacement))
        .environment(\.cardGreetingName, resolveGreetingName(config: config))
        .onAppear {
            loadMDMOverrides()
            initializePhase()
            applyWindowPosition(for: currentStep)
            // The guide / checklist-line watch is owned here for the whole flow, not per step.
            if Self.needsGuideWatch(allSteps) {
                startGuideMonitoring()
            }
        }
        .onDisappear {
            stopGuideMonitoring()
        }
        // A reloaded config or step_add/step_remove changes the list under the cursor.
        .onChange(of: allSteps.map(\.id)) { oldIds, newIds in
            let index = Self.reloadedStepIndex(oldIds: oldIds, newIds: newIds, current: currentStepIndex)
            if index != currentStepIndex { currentStepIndex = index }
        }
        .overlay(alignment: .top) {
            if let issue = inspectState.reloadIssue {
                Label("Changes not applied: \(issue)", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.error)
                    .lineLimit(2)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(palette.cardSurface))
                    .overlay(Capsule().strokeBorder(palette.error.opacity(0.4), lineWidth: 1))
                    .padding(.top, 36).padding(.horizontal, 40)
                    .accessibilityIdentifier("inspect-reload-issue")
            }
        }
        .onChange(of: currentStepIndex) { _, newIndex in
            // Hooked on the index so every navigation path, IPC jumps included, retires a
            // pending auto-advance.
            cancelAutoAdvance()
            // Move the window after the step crossfade, not during it; a stale apply no-ops.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard currentStepIndex == newIndex else { return }
                applyWindowPosition(for: currentStep)
            }
        }
        .detailOverlay(
            inspectState: inspectState,
            isPresented: $showGlobalHelpOverlay,
            config: config?.detailOverlay
        )
        .detailOverlay(
            inspectState: inspectState,
            isPresented: $showStepOverlay,
            config: currentStepOverlayConfig
        )
    }

    @ViewBuilder
    var mainContent: some View {
        if config == nil {
            ProgressView(ChromeCopy.loading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let step = currentStep {
            VStack(spacing: 0) {
                currentStepView(step: step)
                    // The top band's conflict map is applied per arm before injection.
                    .environment(\.cardTopBand, cardTopBandFor(step))
            // A step still holding its door hands the shell no model, so the auto-close clock
            // starts when the last card is processed, not when the step appears.
            .environment(\.cardAutoClose,
                         CardAutoCloseGate.model(cardAutoClose(step), doorHeld: journeyHoldsItsDoor(step: step)))
            .environment(\.cardFooterClaim, footerClaim)
                    // The flow knows where the step sits; chrome reads it from here.
                    .environment(\.stepPosition,
                                 StepPosition(index: currentStepIndex, count: allSteps.count))
            }
                // Id-keyed so runtime step insertion before the current step does not remount it.
                .id("step-\(step.id)")
                // Opacity only: a move transform rasterizes text at fractional offsets.
                .transition(.opacity)
        } else if currentStepIndex >= allSteps.count {
            Color.clear.onAppear { handleCompletion() }
        } else {
            noStepsConfigured
        }
    }

    /// Renders the current step by its resolved stepType.
    @ViewBuilder
    func currentStepView(step: InspectConfig.IntroStep) -> some View {
        let stepType = step.resolvedStepType

        // A reserved-id bookend step whose root screen names a layout renders through the bookend
        // surface, which reads the root introScreen/summaryScreen keys: the projected step cannot
        // carry everything the ceremony needs.
        if step.id == InspectConfig.reservedIntroStepId,
           let intro = config?.introScreen, let layout = intro.layout,
           layout != "centered", InspectConfig.stepRenderableBookendLayouts.contains(layout) {
            BookendScreenView(
                role: .intro,
                layout: layout,
                accentColor: branding.primaryColor,
                scaleFactor: scaleFactor,
                iconBasePath: effectiveIconBasePath,
                itemId: step.id,
                inspectState: inspectState,
                intro: intro,
                userName: resolveGreetingName(config: config),
                onAction: { goToNextStep() }
            )
        } else if step.id == InspectConfig.reservedOutroStepId,
                  let summary = config?.summaryScreen, let layout = summary.layout,
                  layout != "centered", InspectConfig.stepRenderableBookendLayouts.contains(layout) {
            BookendScreenView(
                role: .outro,
                layout: layout,
                accentColor: branding.primaryColor,
                scaleFactor: scaleFactor,
                iconBasePath: effectiveIconBasePath,
                itemId: step.id,
                inspectState: inspectState,
                summary: summary,
                userName: resolveGreetingName(config: config),
                onAction: { goToNextStep() }
            )
        } else if isCardStep(step) {
            cardStepView(step: step, stepIndex: currentStepIndex)
        } else {
        switch stepType {
        // Construction-gated arms come first: the type-only cases below would shadow them.
        case _ where config?.construction == .splash || stepType == "splash":
            splashChooserStepView(step: step)
        case _ where config?.construction == .setupAssistant:
            setupAssistantStepView(step: step, stepIndex: currentStepIndex)
        case "portal":
            cardPortalStepView(step: step, stepIndex: currentStepIndex)
        case "processing":
            if step.processingDuration != nil {
                processingStepView(step: step, stepIndex: currentStepIndex)
            } else {
                standardIntroStepView(step: step, stepIndex: currentStepIndex)
            }
        case "cadence":
            provisioningCadenceStepView(step: step, stepIndex: currentStepIndex)
        case "showcase":
            cardShowcaseStepView(step: step, stepIndex: currentStepIndex)
        case "guide":
            // Guide monitoring starts and stops at the preset root, not on this step: a step-scoped
            // stop would kill the shared poll during a transition.
            cardStepView(step: step, stepIndex: currentStepIndex)
        // Migration bodies: opt-in by construction, and only when the step's blocks resolve to a
        // body. One `case let` because a `where` clause binds only to the last pattern of a list.
        case let migrationType where ["intro", "standard", "assistant", "media"].contains(migrationType)
            && config?.construction == .migration
            && migrationBodyKind(for: step) != nil:
            provisioningMigrationStepView(step: step, stepIndex: currentStepIndex)
        case "review" where config?.construction == .provisioning:
            provisioningReviewStepView(step: step, stepIndex: currentStepIndex)
        case "options" where config?.construction == .provisioning && step.optionMultiSelect == true:
            provisioningMultiOptionsStepView(step: step, stepIndex: currentStepIndex)
        case "options" where config?.construction == .provisioning:
            provisioningOptionsStepView(step: step, stepIndex: currentStepIndex)
        case "dock" where config?.construction == .provisioning:
            provisioningDockStepView(step: step, stepIndex: currentStepIndex)
        // A closer with no receipt keeps the bookend renderer; the shell would show an empty body.
        case "outro" where config?.construction == .provisioning
            && !((step.receipt ?? []).isEmpty):
            provisioningOutroStepView(step: step, stepIndex: currentStepIndex)
        case "brandPicker":
            provisioningBrandPickerStepView(step: step, stepIndex: currentStepIndex)
        case "deployment":
            deploymentStepView(step: step, stepIndex: currentStepIndex)
        case "carousel":
            provisioningCarouselStepView(step: step, stepIndex: currentStepIndex)
        case "assistant":
            cardStepView(step: step, stepIndex: currentStepIndex)
        case "bento":
            cardStepView(step: step, stepIndex: currentStepIndex)
        case "media" where config?.construction == .provisioning:
            provisioningMediaStepView(step: step, stepIndex: currentStepIndex)
        case "media":
            cardStepView(step: step, stepIndex: currentStepIndex)
        case "software":
            // Not gated on chrome: the configs this serves author no `chrome` key.
            cardSoftwareStepView(step: step, stepIndex: currentStepIndex)

        case "options", "dock":
            cardStepView(step: step, stepIndex: currentStepIndex)
        case "substeps":
            cardStepView(step: step, stepIndex: currentStepIndex)
        case "export":
            cardExportStepView(step: step, stepIndex: currentStepIndex)
        case "outro":
            introStepView(step: step, stepIndex: currentStepIndex)
        default:
            introStepView(step: step, stepIndex: currentStepIndex)
        }
        }
    }

    @ViewBuilder
    var noStepsConfigured: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("No Steps Configured")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add steps to the introSteps array in your configuration")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
    struct Preset5View_Previews: PreviewProvider {
        static var previews: some View {
            let state = InspectState()
            Preset5View(inspectState: state)
                .frame(width: 1000, height: 750)
        }
    }
#endif

