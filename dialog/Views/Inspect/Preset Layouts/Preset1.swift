//
//  Preset1.swift
//  dialog
//
//
//  Preset 1: sidebar item list with FSEvents progress tracking, plus the three `plain-*`
//  constructions (plain-simple, plain-centered, plain-branded) that branch its main phase.
//

import SwiftUI

struct Preset1View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @State private var showDetailOverlay = false
    /// True while the action footer seats the help control; the corner fallback stands down then.
    @State private var helpSeatedInFooter = false
    @State private var showItemDetailOverlay = false
    @State private var selectedItemForDetail: InspectConfig.ItemConfig?
    @StateObject private var iconCache = PresetIconCache()
    @StateObject private var commandRouter = CommandRouter()
    /// Held and injected as `\.complianceAggregator`; compliance blocks render empty without it.
    @StateObject private var complianceService = ComplianceAggregatorService()
    @State private var localizationService = LocalizationService()
    /// Selects the dark wordmark variant for the plain footers.
    @Environment(\.colorScheme) private var colorScheme

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

    /// Opt-in via `chrome`. This construction ignores `sideMessages`, `helpButton`, `detailOverlay`,
    /// per-item info, the button2 keys, `button1symbol` and `popupButtonText` by design.
    var isPlainSimple: Bool { inspectState.config?.construction == .plainSimple }

    /// Opt-in via `chrome`. Main phase switches list → progress; intro/summary are hero overrides.
    var isPlainCentered: Bool { inspectState.config?.construction == .plainCentered }

    /// Opt-in via `chrome`. Only the main phase is branched; no hero screens, no back chevron.
    var isPlainBranded: Bool { inspectState.config?.construction == .plainBranded }

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
            presetLabel: "Preset1View",
            presetNumber: "1",
            localize: { loc.string($0, fallback: nil) },
            // Closures, not method references: a main-actor method reference through a ternary
            // into an optional closure defeats the strict-concurrency type-checker.
            introOverride: isPlainCentered ? { plainCenteredIntroOverride(onContinue: $0) } : nil,
            summaryOverride: isPlainCentered ? { plainCenteredSummaryOverride(onClose: $0) }
                : (isPlainSimple ? { plainSimpleSummaryOverride(onClose: $0) } : nil)
        ) { proxy in
            // Only the main phase branches, so phases and the onAppear/palette wiring stay shared.
            if isPlainSimple {
                plainSimpleMainPhaseView(summaryAction: proxy.summaryAction)
                    .sourceTag()
            } else if isPlainCentered {
                plainCenteredMainPhaseView(summaryAction: proxy.summaryAction, backAction: proxy.backAction)
                    .sourceTag()
            } else if isPlainBranded {
                plainBrandedMainPhaseView(summaryAction: proxy.summaryAction)
                    .sourceTag()
            } else {
                mainPhaseView(summaryAction: proxy.summaryAction)
                    .sourceTag()
            }
        }
        .onAppear {
            if let locConfig = inspectState.config?.localization {
                localizationService.loadLanguages(from: locConfig, iconBasePath: inspectState.uiConfiguration.iconBasePath,
                                                   configPath: inspectState.configPath)
            }
            commandRouter.wireItemBase(
                state: inspectState,
                presetLabel: "Preset1",
                triggerFilePath: triggerFilePath
            )
            // The aggregator stays empty until monitoring starts; no `plistSources` is ordinary.
            if let plistSources = inspectState.config?.plistSources, !plistSources.isEmpty {
                writeLog("Preset1: Starting ComplianceAggregatorService with \(plistSources.count) sources",
                         logLevel: .info)
                complianceService.startMonitoring(sources: plistSources, refreshInterval: 5.0)
            } else {
                writeLog("Preset1: No plistSources configured, compliance service not started",
                         logLevel: .info)
            }
            writeLog("Preset1View: Using assembly composition", logLevel: .info)
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
        .environment(\.complianceAggregator, complianceService)
        .inspectPalette(config: inspectState.config, primaryColor: primaryColor)
    }

    // MARK: - Main Phase (plain-simple)

    /// Same label chain as `PresetCommonViews.buttonArea`: autoEnable → finalButtonText →
    /// button1Text → resolved button1Text → "Continue".
    private var plainSimpleButtonText: String {
        let allItemsCompleted = inspectState.allRequiredItemsFinished
        let shouldUseAutoEnableText = allItemsCompleted
            && inspectState.buttonConfiguration.autoEnableButton
            && inspectState.config?.autoEnableButtonText != nil
        if shouldUseAutoEnableText {
            return inspectState.config?.autoEnableButtonText ?? "OK"
        }
        return inspectState.config?.finalButtonText
            ?? inspectState.config?.button1Text
            ?? (inspectState.buttonConfiguration.button1Text.isEmpty
                ? ChromeCopy.continue : inspectState.buttonConfiguration.button1Text)
    }

    /// Primary action as `PresetCommonViews.buttonArea` does it. A nil `summaryAction` means no
    /// summary screen: write the result file, clean up readiness and exit (or minimise).
    private func plainSimplePrimaryAction(summaryAction: (() -> Void)?) {
        if let summaryAction {
            writeLog("Preset: User clicked button1 (\(plainSimpleButtonText)) - custom action", logLevel: .info)
            summaryAction()
        } else if ButtonExit.minimizeInsteadOfExiting(inspectState.config?.button1Action, label: "Preset1") {
            return
        } else {
            writeLog("Preset: User clicked button1 (\(plainSimpleButtonText)) - exiting with code 0", logLevel: .info)
            writeItemPresetResultFile(state: inspectState, exitCode: 0)
            cleanupReadinessFile(state: inspectState, triggerFilePath: triggerFilePath, exitCode: 0)
            exit(0)
        }
    }

    /// The plain-simple confirmation screen on the summary phase. Summary keys map as: title →
    /// screen title; caption → card headline; subtitle → card headline when caption is absent,
    /// else the instruction line; footnote → card detail.
    private func plainSimpleSummaryOverride(onClose: @escaping () -> Void) -> AnyView {
        guard let summaryConfig = inspectState.config?.summaryScreen else { return AnyView(EmptyView()) }
        let title = loc.string("summaryScreen.title", fallback: summaryConfig.title) ?? ""
        let subtitle = loc.string("summaryScreen.subtitle", fallback: summaryConfig.subtitle) ?? ""
        let caption = loc.string("summaryScreen.caption", fallback: summaryConfig.caption)
        let footnote = loc.string("summaryScreen.footnote", fallback: summaryConfig.footnote) ?? ""

        let cardTitle = (caption?.isEmpty == false) ? caption! : subtitle
        let instruction = (caption?.isEmpty == false) ? subtitle : ""

        return AnyView(
            PlainSimpleShell(
                showsBack: false,
                buttonTitle: summaryConfig.buttonText ?? "Close",
                onPrimaryAction: onClose,
                accent: primaryColor,
                wordmarkPath: BrandArtwork.resolve(inspectState.config?.logoConfig, isDark: colorScheme == .dark, gate: .footer),
                logoHeight: resolvedLogoHeight(fallback: PlainSimpleM.wordmarkHeight),
                logoMaxWidth: resolvedLogoMaxWidth,
                logoClearSpace: resolvedLogoClearSpace
                // No footer stepper: the outer step sits in the eyebrow on this screen.
            ) {
                PlainSimpleConfirmScreen(
                    eyebrow: plainSummaryStepText,
                    title: title,
                    instruction: instruction,
                    confirmationTitle: cardTitle,
                    confirmationDetail: footnote,
                    accent: primaryColor
                )
            }
            .frame(width: windowSize.width, height: windowSize.height)
            .background(PhaseBackdrop(config: inspectState.config))
        )
    }

    /// The plain-simple main phase: the install list, then the tour (if authored) while install
    /// keeps running underneath.
    private func plainSimpleMainPhaseView(summaryAction: (() -> Void)?) -> some View {
        let onTour = plainSimpleShowsTour && plainSimpleHasTour
        let position = plainStepPosition(phase: onTour ? .tour : .main)
        // One indicator per screen: with a pager the outer step is the eyebrow, not the footer.
        let pagerOwnsTheIndicator = onTour && plainSimpleTourIsPaged

        return PlainSimpleShell(
            showsBack: false,
            buttonTitle: onTour ? plainSimpleTourContinueText : plainSimpleButtonText,
            // On a paged walkthrough the primary stays inert until the last page.
            buttonDisabled: onTour
                ? (plainSimpleTourIsPaged && plainSimpleTourPage < plainSimpleTourPages.count)
                : inspectState.buttonConfiguration.button1Disabled,
            // On the list the primary opens the tour instead of leaving.
            onPrimaryAction: {
                if plainSimpleHasTour && !plainSimpleShowsTour {
                    plainSimpleShowsTour = true
                } else {
                    plainSimplePrimaryAction(summaryAction: summaryAction)
                }
            },
            accent: primaryColor,
            // `gate: .footer` gates on a bottom position and resolves the dark variant, so this
            // footer and `PhaseContainer`'s own logo overlay never both draw the mark.
            wordmarkPath: BrandArtwork.resolve(inspectState.config?.logoConfig, isDark: colorScheme == .dark, gate: .footer),
            logoHeight: resolvedLogoHeight(fallback: PlainSimpleM.wordmarkHeight),
            logoMaxWidth: resolvedLogoMaxWidth,
            logoClearSpace: resolvedLogoClearSpace,
            // Skip is text, only on the single-movie tour; a paged walkthrough is gated by its pager.
            secondaryTitle: (onTour && !plainSimpleTourIsPaged) ? plainSimpleSkipTourText : nil,
            onSecondaryAction: (onTour && !plainSimpleTourIsPaged) ? { plainSimplePrimaryAction(summaryAction: summaryAction) } : nil,
            stepIndicatorText: pagerOwnsTheIndicator ? nil : position.map {
                StepCounterLabel.format(
                    StepCounterLabel.template { key in loc.string(key, fallback: nil) },
                    current: $0.current, total: $0.total)
            },
            stepDots: pagerOwnsTheIndicator ? nil : position
        ) {
            if onTour {
                plainSimpleTourScreen
            } else {
                // Migration bodies are passed as a kind, not a screen swap; nil draws the plain list.
                PlainSimpleListScreen(
                    inspectState: inspectState,
                    iconCache: iconCache,
                    model: ItemSetModel.build(from: inspectState),
                    title: loc.string("title", fallback: inspectState.uiConfiguration.windowTitle) ?? "",
                    subtitle: loc.string("subtitle", fallback: inspectState.uiConfiguration.subtitleMessage) ?? "",
                    accent: primaryColor,
                    loc: loc,
                    // Gated on `usesMigrationBodies` like every other host; reads the flow's blocks.
                    migrationKind: inspectState.config?.usesMigrationBodies == true
                        ? MigrationBodyKind.resolve(blocks: inspectState.config?.guidanceContent)
                        : nil
                )
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .background(PhaseBackdrop(config: inspectState.config))
    }

    /// The tour: a single step when there is one movie, a paged walkthrough when there are pages.
    @ViewBuilder
    private var plainSimpleTourScreen: some View {
        if plainSimpleTourIsPaged {
            plainSimpleWalkthroughScreen
        } else {
            plainSimpleMediaStepScreen
        }
    }

    /// A walkthrough page; the pager gates Continue until the last page.
    private var plainSimpleWalkthroughScreen: some View {
        let pages = plainSimpleTourPages
        let index = min(max(plainSimpleTourPage, 1), pages.count)
        let page = pages[index - 1]

        return PlainSimpleWalkthroughScreen(
            eyebrow: plainStepPosition(phase: .tour).map {
                StepCounterLabel.format(
                    StepCounterLabel.template { key in loc.string(key, fallback: nil) },
                    current: $0.current, total: $0.total)
            },
            title: loc.string("tour.title", fallback: page.title) ?? plainSimpleTourFallbackTitle,
            instruction: loc.string("tour.instruction", fallback: page.text) ?? "",
            mediaPath: page.content,
            durationLabel: page.caption,
            current: index,
            total: pages.count,
            gateText: "Finish all \(pages.count) pages to continue",
            centred: plainSimpleIsCentred,
            accent: primaryColor,
            onBack: { plainSimpleTourPage = max(index - 1, 1) },
            onForward: { plainSimpleTourPage = min(index + 1, pages.count) }
        )
    }

    /// The single-movie tour; its strip reads the same `ItemSetModel` the list renders.
    private var plainSimpleMediaStepScreen: some View {
        let block = plainSimpleTourBlock
        let model = ItemSetModel.build(from: inspectState)
        let running = model.rows.first { $0.status == .active }
        let done = model.rows.filter { $0.status == .completed }.count

        return PlainSimpleMediaScreen(
            title: loc.string("tour.title", fallback: block?.title) ?? plainSimpleTourFallbackTitle,
            subtitle: loc.string("tour.subtitle", fallback: block?.text) ?? "",
            mediaPath: block?.content,
            // Absent caption, no chip; the screen never invents a duration.
            durationLabel: block?.caption,
            runningItemText: running.map { row in
                let name = loc.string("\(row.item.id).displayName", fallback: row.item.displayName) ?? row.item.displayName
                return "\(loc.itemStatus(for: row.item, baseStatus: row.statusText)) \(name)"
            },
            progressText: model.rows.isEmpty ? nil : "\(done) of \(model.rows.count)",
            centred: plainSimpleIsCentred,
            accent: primaryColor
        )
    }

    /// Tour copy fallbacks; authored labels win.
    private var plainSimpleTourFallbackTitle: String { "While you wait" }
    private var plainSimpleTourContinueText: String {
        loc.string("tour.continue", fallback: nil) ?? ChromeCopy.continue
    }
    private var plainSimpleSkipTourText: String {
        loc.string("tour.skip", fallback: nil) ?? "Skip tour"
    }

    /// Main-phase step numbers; nil for a single-phase flow.
    private var plainStepDots: (current: Int, total: Int)? { plainStepPosition(phase: .main) }

    /// Centred is the default; root `contentAlign` "leading" opts into the leading rail.
    /// Resolved once per flow, never per step, so the axis cannot shift between screens.
    private var plainSimpleIsCentred: Bool {
        PlainSimpleM.isCentred(authored: inspectState.config?.contentAlign)
    }

    /// The tour is a view of the running main phase, not a fourth `PresetPhase`.
    @State private var plainSimpleShowsTour = false

    /// Tour media: root `guidanceContent` video/image blocks that carry a `content` path.
    private var plainSimpleTourPages: [InspectConfig.GuidanceContent] {
        inspectState.config?.guidanceContent?.filter {
            ($0.type == "video" || $0.type == "image") && !($0.content ?? "").isEmpty
        } ?? []
    }

    private var plainSimpleTourBlock: InspectConfig.GuidanceContent? { plainSimpleTourPages.first }
    private var plainSimpleHasTour: Bool { !plainSimpleTourPages.isEmpty }

    /// One media block is a step; several are the pages of one task and take a pager.
    private var plainSimpleTourIsPaged: Bool { plainSimpleTourPages.count > 1 }

    /// Current walkthrough page, 1-based.
    @State private var plainSimpleTourPage: Int = 1

    /// The outer step a phase is; arithmetic lives in `PlainStepPosition`.
    private func plainStepPosition(phase: PlainStepPosition.Phase) -> (current: Int, total: Int)? {
        PlainStepPosition.position(phase: phase,
                                   hasIntro: inspectState.config?.introScreen != nil,
                                   hasTour: plainSimpleHasTour,
                                   hasSummary: inspectState.config?.summaryScreen != nil)
    }

    /// The summary phase's own label, for the confirmation screen's eyebrow.
    private var plainSummaryStepText: String? {
        plainStepPosition(phase: .summary).map {
            StepCounterLabel.format(
                StepCounterLabel.template { key in loc.string(key, fallback: nil) },
                current: $0.current, total: $0.total
            )
        }
    }

    /// The words beside the dots; `StepCounterLabel` owns the key list and the English fallback.
    private var plainStepIndicatorText: String? {
        plainStepDots.map {
            StepCounterLabel.format(
                StepCounterLabel.template { key in loc.string(key, fallback: nil) },
                current: $0.current, total: $0.total
            )
        }
    }

    /// `logoConfig.maxWidth`; nil keeps height-only sizing.
    private var resolvedLogoMaxWidth: CGFloat? {
        inspectState.config?.logoConfig?.maxWidth.map { CGFloat($0) }
    }

    /// `logoConfig.maxHeight`, else the calling construction's own constant.
    private func resolvedLogoHeight(fallback: CGFloat) -> CGFloat {
        CGFloat(inspectState.config?.logoConfig?.maxHeight ?? fallback)
    }

    /// `logoConfig.clearSpace`, shared by all three plain shells; `BrandMark` clamps it.
    private var resolvedLogoClearSpace: CGFloat {
        inspectState.config?.logoConfig?.clearSpace ?? 0
    }

    // MARK: - Main Phase (plain-branded)

    /// The plain-branded main phase: `PlainBrandedShell` wrapping `PlainBrandedScreen`.
    /// The logo is not footer-gated: this shell has one seat, which `footer` and `header` both
    /// resolve to; only `none` suppresses. Step dots count configured phases (intro/main/summary),
    /// not item progress, and hide when fewer than two.
    private func plainBrandedMainPhaseView(summaryAction: (() -> Void)?) -> some View {
        let logoConfig = inspectState.config?.logoConfig
        let resolvedPosition = logoConfig?.resolvedPosition ?? .footer
        let logoPath = resolvedPosition == .none
            ? nil
            : BrandArtwork.resolve(logoConfig, isDark: colorScheme == .dark)
        let logoHeight = CGFloat(logoConfig?.maxHeight ?? PlainBrandedM.logoHeight)
        let logoMaxWidth = logoConfig?.maxWidth.map { CGFloat($0) }
        // `footerText` is opt-in; an authored empty string is an explicit opt-out.
        let footerText = inspectState.config?.footerText
        let claimText = (footerText?.isEmpty ?? true) ? nil : footerText

        let introConfigured = inspectState.config?.introScreen != nil
        let summaryConfigured = inspectState.config?.summaryScreen != nil
        let totalPhases = 1 + (introConfigured ? 1 : 0) + (summaryConfigured ? 1 : 0)
        let currentPhaseNumber = introConfigured ? 2 : 1
        let stepDots: (current: Int, total: Int)? = totalPhases >= 2
            ? (current: currentPhaseNumber, total: totalPhases)
            : nil
        let stepIndicatorText = stepDots.map {
            StepCounterLabel.format(
                StepCounterLabel.template { key in loc.string(key, fallback: nil) },
                current: $0.current, total: $0.total
            )
        }

        return PlainBrandedShell(
            buttonTitle: plainSimpleButtonText,
            buttonDisabled: inspectState.buttonConfiguration.button1Disabled,
            onPrimaryAction: { plainSimplePrimaryAction(summaryAction: summaryAction) },
            accent: primaryColor,
            logoPath: logoPath,
            logoHeight: logoHeight,
            logoMaxWidth: logoMaxWidth,
            logoClearSpace: resolvedLogoClearSpace,
            stepIndicatorText: stepIndicatorText,
            stepDots: stepDots,
            claimText: claimText
        ) {
            PlainBrandedScreen(
                inspectState: inspectState,
                iconCache: iconCache,
                model: ItemSetModel.build(from: inspectState),
                title: loc.string("title", fallback: inspectState.uiConfiguration.windowTitle) ?? "",
                subtitle: loc.string("subtitle", fallback: inspectState.uiConfiguration.subtitleMessage) ?? "",
                accent: primaryColor,
                loc: loc
            )
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .background(PhaseBackdrop(config: inspectState.config))
    }

    // MARK: - Intro/Summary hero screens (plain-centered)

    /// The plain-centered intro hero in `PlainCenteredShell`. The button must call `onContinue`,
    /// never touch phase state, so the phase machine advances identically to the default arm.
    private func plainCenteredIntroOverride(onContinue: @escaping () -> Void) -> AnyView {
        guard let introConfig = inspectState.config?.introScreen else { return AnyView(EmptyView()) }
        let systemImage = PlainCenteredIcon.heroGlyph(
            mainIconPath: introConfig.heroImage ?? iconCache.getMainIconPath(for: inspectState)
        )
        let title = loc.string("introScreen.title", fallback: introConfig.title) ?? ""
        let bodyText = loc.string("introScreen.subtitle", fallback: introConfig.subtitle) ?? ""
        let buttonTitle = introConfig.buttonText ?? "Get Started"

        return AnyView(
            PlainCenteredShell(
                showsBack: false,
                buttonTitle: buttonTitle,
                onPrimaryAction: onContinue,
                accent: primaryColor,
                logoPath: BrandArtwork.resolve(inspectState.config?.logoConfig, isDark: colorScheme == .dark, gate: .footer),
                logoHeight: resolvedLogoHeight(fallback: PlainCenteredM.footerWordmarkHeight),
                logoMaxWidth: resolvedLogoMaxWidth,
                logoClearSpace: resolvedLogoClearSpace
            ) {
                PlainCenteredHeroScreen(
                    systemImage: systemImage,
                    title: title,
                    bodyText: bodyText,
                    accent: primaryColor
                )
            }
        )
    }

    /// The summary hero with its success badge lit. `onClose` carries the readiness cleanup and
    /// exit; this must call it rather than perform that itself.
    private func plainCenteredSummaryOverride(onClose: @escaping () -> Void) -> AnyView {
        guard let summaryConfig = inspectState.config?.summaryScreen else { return AnyView(EmptyView()) }
        let systemImage = PlainCenteredIcon.heroGlyph(
            mainIconPath: summaryConfig.heroImage ?? iconCache.getMainIconPath(for: inspectState)
        )
        let title = loc.string("summaryScreen.title", fallback: summaryConfig.title) ?? ""
        let bodyText = loc.string("summaryScreen.subtitle", fallback: summaryConfig.subtitle) ?? ""
        let buttonTitle = summaryConfig.buttonText ?? "Close"

        return AnyView(
            PlainCenteredShell(
                showsBack: false,
                buttonTitle: buttonTitle,
                onPrimaryAction: onClose,
                accent: primaryColor,
                logoPath: BrandArtwork.resolve(inspectState.config?.logoConfig, isDark: colorScheme == .dark, gate: .footer),
                logoHeight: resolvedLogoHeight(fallback: PlainCenteredM.footerWordmarkHeight),
                logoMaxWidth: resolvedLogoMaxWidth,
                logoClearSpace: resolvedLogoClearSpace
            ) {
                PlainCenteredHeroScreen(
                    systemImage: systemImage,
                    title: title,
                    bodyText: bodyText,
                    accent: primaryColor,
                    showsSuccessBadge: true
                )
            }
        )
    }

    // MARK: - Main Phase (plain-centered)

    /// The plain-centered main phase: the list while every item is pending, the progress screen
    /// once one runs. The back chevron needs an authored `introScreen` (`backAction` non-nil)
    /// and nothing running: a running item cannot be abandoned cleanly.
    private func plainCenteredMainPhaseView(summaryAction: (() -> Void)?, backAction: (() -> Void)?) -> some View {
        let model = ItemSetModel.build(from: inspectState)
        let isRunning = model.rows.contains { $0.status == .active }
        let canGoBack = backAction != nil && !isRunning
        let systemImage = PlainCenteredIcon.heroGlyph(mainIconPath: iconCache.getMainIconPath(for: inspectState))
        let title = loc.string("title", fallback: inspectState.uiConfiguration.windowTitle) ?? ""
        let bodyText = loc.string("subtitle", fallback: inspectState.uiConfiguration.subtitleMessage) ?? ""

        return PlainCenteredShell(
            showsBack: canGoBack,
            // Phase-level view, no step in scope: the label chain has localized and branding rungs only.
            backLabel: BackDoor.label(localized: loc.string("backButtonText", fallback: nil),
                                      step: nil,
                                      branding: inspectState.buttonConfiguration.button2Text),
            onBack: canGoBack ? backAction : nil,
            buttonTitle: plainSimpleButtonText,
            buttonDisabled: inspectState.buttonConfiguration.button1Disabled,
            onPrimaryAction: { plainSimplePrimaryAction(summaryAction: summaryAction) },
            accent: primaryColor,
            logoPath: BrandArtwork.resolve(inspectState.config?.logoConfig, isDark: colorScheme == .dark, gate: .footer),
            logoHeight: resolvedLogoHeight(fallback: PlainCenteredM.footerWordmarkHeight),
            logoMaxWidth: resolvedLogoMaxWidth,
            logoClearSpace: resolvedLogoClearSpace,
            bodyPadding: isRunning ? PlainCenteredM.bodyPadding : PlainCenteredM.bodyPaddingList
        ) {
            if isRunning {
                PlainCenteredProgressScreen(
                    systemImage: systemImage,
                    title: title,
                    bodyText: bodyText,
                    accent: primaryColor,
                    completed: inspectState.trackedCompletedCount,
                    total: inspectState.trackedItems.count,
                    activeItemName: plainCenteredActiveItemName(model: model)
                )
            } else {
                PlainCenteredListScreen(
                    systemImage: systemImage,
                    model: model,
                    title: title,
                    bodyText: bodyText,
                    accent: primaryColor,
                    loc: loc
                )
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .background(PhaseBackdrop(config: inspectState.config))
    }

    /// The running item's localized display name for the progress caption; nil if none is running.
    private func plainCenteredActiveItemName(model: ItemSetModel) -> String? {
        guard let row = model.rows.first(where: { $0.status == .active }) else { return nil }
        return loc.string("\(row.item.id).displayName", fallback: row.item.displayName) ?? row.item.displayName
    }

    // MARK: - Main Phase (assembled)

    private func mainPhaseView(summaryAction: (() -> Void)?) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                DeploymentSidebarPanel(
                    inspectState: inspectState,
                    iconCache: iconCache,
                    accent: primaryColor
                )

                rightColumn
            }

            ActionFooterRow(
                state: inspectState,
                tint: primaryColor,
                scaleFactor: scaleFactor,
                onShowDetailOverlay: { showDetailOverlay = true },
                onButton1Action: summaryAction,
                config: inspectState.config,
                triggerFilePath: triggerFilePath
            )
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .background(PhaseBackdrop(config: inspectState.config))
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
            item: selectedItemForDetail
        )
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.string("title", fallback: inspectState.uiConfiguration.windowTitle) ?? "")
                    .font(.system(size: 26, weight: .bold))

                // Fixed `message` line, distinct from the rotating side message below.
                if let subtitle = loc.string("subtitle", fallback: inspectState.uiConfiguration.subtitleMessage),
                   !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                if let currentMessage = loc.sideMessage() {
                    // The same size as `message` above, so the two read as one block.
                    RotatingMessageLine(messages: loc.sideMessages(), current: currentMessage,
                                        index: inspectState.uiConfiguration.currentSideMessageIndex,
                                        font: .system(size: 15))
                }
            }
            // 60 is the header without a `message`; with one it grows by that line.
            .frame(minHeight: 60, alignment: .topLeading)
            .padding(.horizontal)
            .padding(.top, InspectConstants.spacingInner)
            // The list scrolls under this edge as it follows the install; 12 keeps a scrolled row clear of the text.
            .padding(.bottom, 12)

            DeploymentItemList(
                inspectState: inspectState,
                iconCache: iconCache,
                accent: primaryColor,
                loc: loc,
                onItemInfo: { item in
                    selectedItemForDetail = item
                    showItemDetailOverlay = true
                }
            )
        }
    }
}
