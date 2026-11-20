//
//  Preset6+RailSteps.swift
//  dialog
//
//  Preset 6 adapter onto the rail chrome (`"chrome": "rail"`): the rail lists the work items and the
//  content column reuses the card vocabulary. Navigation, processing and deferral reuse the engine.
//

import SwiftUI

/// `RailFooterView`'s own top inset, subtracted from the bento band's bottom correction
/// (`railBentoStepView`). The card host's `CardFooterBar` has none, so it applies `bandBottom` in full.
private let railFooterOwnTopInset: CGFloat = 22

extension Preset6View {

    var isRailChrome: Bool { inspectState.config?.construction == .rail }

    /// Items shown in the rail: the `main` steps, not the intro/outro bookends.
    private var railItems: [InspectConfig.IntroStep] {
        inspectState.steps.filter { $0.resolvedPhase == "main" }
    }

    private var railModel: RailChromeModel {
        let items = railItems
        // Failed takes precedence: failed steps are also in completedSteps.
        let doneCount = items.filter { completedSteps.contains($0.id) && failedSteps[$0.id] == nil }.count
        let rows = items.enumerated().map { idx, item in
            let state: RailState = failedSteps[item.id] != nil ? .failed
                : (completedSteps.contains(item.id) ? .done
                : (inspectState.steps[safe: currentStep]?.id == item.id ? .active : .pending))
            return RailRowModel(id: item.id,
                                label: localized("displayName", forItem: item,
                                                 fallback: item.displayName) ?? (item.displayName ?? item.title ?? item.id),
                                state: state,
                                number: idx + 1)
        }
        return RailChromeModel(
            // Sidecar `_ui.title` localizes the org label; the config title is the fallback.
            orgLabel: inspectState.config?.title.map { localizedChromeUI("title", fallback: $0) },
            brandIcon: inspectState.config?.icon,
            stepIcon: inspectState.steps[safe: currentStep].flatMap { dynamicState.heroImageOverrides[$0.id] ?? $0.heroImage },
            progress: items.isEmpty ? 0 : Double(doneCount) / Double(items.count),
            doneLabel: chromeDoneCounter(done: doneCount, total: items.count),
            rows: rows,
            logoPath: railFooterLogoPath,
            logoHeight: CGFloat(inspectState.config?.logoConfig?.maxHeight ?? 24),
            logoClearSpace: inspectState.config?.logoConfig?.clearSpace ?? 0
        )
    }

    private var railFooterLogoPath: String? {
        // The rail foot is the chrome's only logo seat, so any configured logo shows here (`.any`).
        // Resolved per appearance: the light art alone is unreadable on the dark rail.
        BrandArtwork.resolve(inspectState.config?.logoConfig, isDark: colorScheme == .dark)
    }

    /// Card-mode replacement for both screen modes: one rail screen per item.
    @ViewBuilder
    var railCurrentStepView: some View {
        if let item = inspectState.steps[safe: currentStep] {
            railStepView(item: item, index: currentStep)
                .id("rail-step-\(item.id)")
                .transition(.opacity)
        }
    }

    // Not `@ViewBuilder`, and every arm returns its own `AnyView`. A heterogeneous `_ConditionalContent`
    // chain crashes the Swift runtime when SwiftUI copies it (see `Preset5View.cardBentoStepView`).
    // A new arm returns its own `AnyView`; never add `@ViewBuilder` here or an arm yielding two view types.
    func railStepView(item: InspectConfig.IntroStep, index: Int) -> AnyView {
        // Renderer first (processing and bento render as such in any role), then role. Only the "hero" and
        // "summary" bento layouts have a rail arm; other bento steps fall through to the prose arm.
        let bentoKind: BentoArrangementKind? = {
            switch item.bentoLayout {
            case "hero":    return .heroRow
            case "summary": return .heroColumn
            default:        return nil
            }
        }()
        if item.stepType == "bento", let bentoKind {
            return AnyView(railBentoStepView(item: item, index: index, kind: bentoKind))
        } else if item.stepType == "processing" {
            return AnyView(railProcessingStepView(item: item, index: index))
        } else if item.resolvedPhase == "outro" {
            return AnyView(railOutroStepView(item: item, index: index))
        } else {
            return AnyView(railIntroStepView(item: item, index: index))
        }
    }

    // MARK: - Chrome-string localization (rail and card)

    /// Global UI strings: sidecar `_ui.<key>`, then config labels (resolveLabel), then fallback.
    /// Used for chrome copy that is not item-scoped (step counter, done counter, deferral button).
    func localizedChromeUI(_ key: String, fallback: String) -> String {
        if let lang = selectedLanguageCode, localizationService.hasLanguage(lang),
           let s = localizationService.string(forLanguage: lang, key: "_ui.\(key)") {
            return s
        }
        return resolveLabel(key, config: inspectState.config,
                            language: selectedLanguageCode, fallback: nil) ?? fallback
    }

    /// The rail's step counter: sidecar, then config labels, substituted by `StepCounterLabel.format`
    /// so `{n}` templates resolve as elsewhere.
    func chromeStepCounter(_ index: Int) -> String {
        StepCounterLabel.format(
            localizedChromeUI("stepCounterFormat", fallback: StepCounterLabel.fallback),
            current: index + 1, total: inspectState.steps.count)
    }

    func chromeDoneCounter(done: Int, total: Int) -> String {
        localizedChromeUI("completedCounterFormat", fallback: "{done} of {total} completed")
            .replacingOccurrences(of: "{done}", with: "\(done)")
            .replacingOccurrences(of: "{total}", with: "\(max(1, total))")
    }

    var chromeDeferralText: String? {
        guard isDeferralEnabled(config: inspectState.config) else { return nil }
        return localizedChromeUI("deferralButton",
                                 fallback: inspectState.config?.deferralConfig?.buttonText ?? "Not Now")
    }

    var chromeDeferralAvailable: Bool {
        DeferralMenu.isOffered(steps: inspectState.steps, currentIndex: currentStep)
    }

    /// Card-panel localization: `<itemId>.cardPanel.caption/stat/imageTitle`, `.pairs.<i>.label|value`,
    /// `.paragraphs.<i>`, with the same selection scope as other item-scoped lookups.
    func localizedCardPanel(_ item: InspectConfig.IntroStep) -> InspectConfig.CardPanel? {
        guard let panel = item.cardPanel else { return nil }
        guard let lang = selectedLanguageCode, localizationService.hasLanguage(lang) else { return panel }
        guard StepLanguage.applies(isManual: isManualLanguageSelection, pickerIndex: languagePickerStepIndex,
                                   stepIndex: inspectState.steps.firstIndex(where: { $0.id == item.id })) else { return panel }
        let prefix = "\(item.id).cardPanel"
        func loc(_ key: String, _ value: String?) -> String? {
            guard value != nil else { return nil }
            return localizationService.string(forLanguage: lang, key: "\(prefix).\(key)") ?? value
        }
        let pairs = panel.pairs.map { list in
            list.enumerated().map { i, pair in
                InspectConfig.CardPanelPair(
                    label: loc("pairs.\(i).label", pair.label) ?? pair.label,
                    value: loc("pairs.\(i).value", pair.value) ?? pair.value)
            }
        }
        let paragraphs = panel.paragraphs.map { list in
            list.enumerated().map { i, para in loc("paragraphs.\(i)", para) ?? para }
        }
        return InspectConfig.CardPanel(
            caption: loc("caption", panel.caption),
            stat: loc("stat", panel.stat),
            pairs: pairs,
            image: panel.image,
            video: panel.video,
            imageTitle: loc("imageTitle", panel.imageTitle),
            paragraphs: paragraphs,
            layout: panel.layout)
    }

    // MARK: - Shared mapping helpers

    private func railTitle(_ item: InspectConfig.IntroStep) -> String {
        localizedHeadline(item, fallback: item.title ?? item.displayName) ?? (item.displayName ?? item.title ?? item.id)
    }

    private func railSubtitle(_ item: InspectConfig.IntroStep) -> String? {
        localized("subtitle", forItem: item, fallback: item.subtitle)
    }

    private func railBlocks(_ item: InspectConfig.IntroStep) -> [InspectConfig.GuidanceContent] {
        (item.content ?? []).enumerated().map { idx, block in
            localizedContentBlock(block, itemId: item.id, blockIndex: idx)
        }
    }

    /// Fact rows for the panel from the localized cardPanel: caption and stat first, then pairs.
    private func railFacts(_ item: InspectConfig.IntroStep) -> [RailFactRow]? {
        guard let panel = localizedCardPanel(item) else { return nil }
        var rows: [RailFactRow] = []
        if let caption = panel.caption, let stat = panel.stat {
            rows.append(RailFactRow(label: caption.capitalized, value: stat))
        }
        for pair in panel.pairs ?? [] {
            rows.append(RailFactRow(label: pair.label, value: pair.value))
        }
        return rows.isEmpty ? nil : rows
    }

    /// The language row, from the item's dropdown block keyed by the localization selectionKey.
    /// Selecting writes the same form state as the dropdown, so localization reacts the same way.
    private func railLanguageRow(_ item: InspectConfig.IntroStep) -> RailLanguageRow? {
        let key = inspectState.config?.localization?.selectionKey ?? "preferredLanguage"
        guard let block = railBlocks(item).first(where: { $0.id == key && $0.type == "dropdown" }),
              let options = block.options, !options.isEmpty else { return nil }
        let current = manualLanguageSelection ?? block.value ?? options[0]
        return RailLanguageRow(
            label: block.content ?? "Language",
            options: options,
            current: current,
            onSelect: { [self] value in
                inspectState.guidanceFormInputs[item.id, default: GuidanceFormInputState()]
                    .dropdowns[key] = value
            }
        )
    }

    private func railFooter(for item: InspectConfig.IntroStep,
                            footnote: String? = nil,
                            continueDisabled: Bool? = nil,
                            showLaterAndBack: Bool = true) -> RailFooterModel {
        RailFooterModel(
            footnote: footnote,
            backText: (showLaterAndBack && canGoBack) ? cardBackText(item) : nil,
            onBack: { goToPreviousStep() },
            continueText: getContinueButtonText(),
            continueDisabled: continueDisabled ?? isContinueDisabled,
            onContinue: {
                openCardContinueActionURL(item.continueAction)
                handleContinue()
            },
            inspectConfig: (showLaterAndBack && chromeDeferralAvailable) ? inspectState.config : nil,
            deferralText: (showLaterAndBack && chromeDeferralAvailable) ? chromeDeferralText : nil
        )
    }

    private func railScreen(model: RailStepModel, stepId: String) -> RailStepScreen {
        RailStepScreen(rail: railModel,
                       model: model,
                       accent: branding.primaryColor,
                       inspectState: inspectState,
                       scaleFactor: scaleFactor,
                       iconBasePath: dynamicState.iconBasePathOverride ?? inspectState.uiConfiguration.iconBasePath,
                       stepId: stepId)
    }

    // MARK: - Screens

    // Intro and guide/generic steps: the language dropdown and facts move from the block list into the panel.
    @ViewBuilder
    func railIntroStepView(item: InspectConfig.IntroStep, index: Int) -> some View {
        let langKey = inspectState.config?.localization?.selectionKey ?? "preferredLanguage"
        let facts = railFacts(item)
        let language = railLanguageRow(item)
        let panel = localizedCardPanel(item)
        let media = (panel?.video != nil || panel?.image != nil) ? panel : nil
        let mediaMax = media != nil && panel?.layout == "max"
        let allBlocks = railBlocks(item).filter { block in
            !(block.type == "dropdown" && block.id == langKey && language != nil)
        }
        // Media-max: the player leads and the warning box collapses to one line under it.
        let mediaCaption = mediaMax
            ? allBlocks.first(where: { $0.type == "warning" })?.content
            : nil
        let blocks = mediaMax ? allBlocks.filter { $0.type != "warning" } : allBlocks
        railScreen(model: RailStepModel(
            stepLabel: chromeStepCounter(index),
            title: railTitle(item),
            subtitle: railSubtitle(item),
            blocks: blocks,
            facts: facts,
            media: media,
            mediaMax: mediaMax,
            mediaCaption: mediaCaption,
            languageRow: language,
            footer: railFooter(for: item,
                               // The intro step offers only Begin.
                               showLaterAndBack: item.resolvedPhase != "intro")
        ), stepId: item.id)
        .sourceTag()
    }

    // Processing: running, stalled and confirmed states of one screen.
    @ViewBuilder
    func railProcessingStepView(item: InspectConfig.IntroStep, index: Int) -> some View {
        let stepFailed = failedSteps[item.id] != nil
        let stepDone = completedSteps.contains(item.id) && !stepFailed
        let rowState: CardSubstepState = stepFailed ? .failed
            : (stepDone ? .done : (isProcessing ? .active : .pending))
        let duration = item.processingDuration ?? 0
        let progress: Double? = stepDone ? 1.0
            : (isProcessing && duration > 0
                ? max(0, 1.0 - Double(processingCountdown) / Double(duration))
                : nil)
        let textBlock = railBlocks(item).first { $0.type == "text" }?.content
        // The skip option appears once override escalation offers one (15 s, as in the standard chrome), never on
        // entry.
        let isStalled: Bool = {
            if case .waiting = processingState {
                return (currentOverrideLevel == .small || currentOverrideLevel == .large) && !stepDone
            }
            return false
        }()
        railScreen(model: RailStepModel(
            stepLabel: chromeStepCounter(index),
            title: railTitle(item),
            statusPill: stepFailed
                ? (failedSteps[item.id]
                   ?? localized("failureMessage", forItem: item,
                                fallback: item.failureMessage) ?? "Marked as failed")
                : (stepDone
                    ? (localized("completedStatus", forItem: item,
                                 fallback: item.completedStatus ?? item.successMessage) ?? "Completed")
                    : nil),
            statusPillFailed: stepFailed,
            subtitle: railSubtitle(item) ?? textBlock,
            progress: progress,
            substeps: [(rowState,
                        localized("processingMessage", forItem: item,
                                  fallback: item.processingMessage) ?? railTitle(item))],
            paragraphs: localizedCardPanel(item)?.paragraphs,
            escape: isStalled ? RailEscapeModel(
                headline: localizedProcessingText("overrideTitle",
                                                  fallback: "Waiting longer than expected"),
                consequence: localizedProcessingText("overrideDescription",
                    fallback: "You can decide whether this step passed, failed, or should be skipped."),
                skipText: localizedProcessingText("overrideButton",
                    fallback: item.overrideButtonText ?? "Override This Step"),
                // Opens the override decision sheet (pass / fail / skip).
                onSkip: { showOverrideDialog = true }
            ) : nil,
            footer: railFooter(for: item)
        ), stepId: item.id)
        .sourceTag()
    }

    // Outro: badge, checks, receipt facts, footnote and Done. Failed steps are listed with their reason
    // and make the badge red.
    @ViewBuilder
    func railOutroStepView(item: InspectConfig.IntroStep, index: Int) -> some View {
        let failures: [(label: String, detail: String?)] = railItems.compactMap { railItem in
            guard let reason = failedSteps[railItem.id] else { return nil }
            return (localized("displayName", forItem: railItem,
                              fallback: railItem.displayName) ?? (railItem.displayName ?? railItem.title ?? railItem.id),
                    reason)
        }
        railScreen(model: RailStepModel(
            stepLabel: chromeStepCounter(index),
            title: railTitle(item),
            titleBadge: true,
            titleBadgeFailed: !failures.isEmpty,
            subtitle: railSubtitle(item),
            blocks: railBlocks(item),
            facts: railFacts(item),
            failures: failures,
            footer: railFooter(for: item,
                               footnote: localized("footerNote", forItem: item,
                                                   fallback: item.footerNote),
                               showLaterAndBack: false)
        ), stepId: item.id)
        .sourceTag()
    }

    // Bento hero/summary, the rail's counterpart of `cardBentoHeroArm`. A separate function keeps
    // `railStepView` a flat list of returns.

    /// Bento arm header: step counter, title and subtitle, as `RailStepScreen.header` draws them.
    private func railBentoHeader(item: InspectConfig.IntroStep, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(chromeStepCounter(index))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.text.opacity(0.44))
            VStack(alignment: .leading, spacing: 7) {
                Text(railTitle(item))
                    .font(.system(size: InspectMetrics.unit.railTitleSize, weight: .bold))
                    .tracking(-0.594)
                    .foregroundStyle(palette.text.opacity(0.9))
                if let subtitle = railSubtitle(item) {
                    Text(subtitle)
                        .font(.system(size: 14.5))
                        .foregroundStyle(palette.text.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: InspectMetrics.unit.railSubtitleMax, alignment: .leading)
                }
            }
        }
    }

    private func railBentoStepView(item: InspectConfig.IntroStep, index: Int,
                                   kind: BentoArrangementKind) -> some View {
        RailStepShell(rail: railModel, accent: branding.primaryColor) {
            VStack(alignment: .leading, spacing: 0) {
                railBentoHeader(item: item, index: index)
                // No ScrollView: BentoModule sizes cells from the container height, which a scroll leaves unbounded.
                // Top inset is `bandTop` (nothing spent above); bottom adds only what `railFooterOwnTopInset` leaves.
                AnyView(BentoModule(
                    cells: item.bentoCells ?? [],
                    kind: kind,
                    accent: branding.primaryColor,
                    iconBasePath: dynamicState.iconBasePathOverride ?? inspectState.uiConfiguration.iconBasePath,
                    inspectState: inspectState,
                    onAction: { cell in
                        // Label and itemId are used for logging and result-file rows.
                        handleRowAction(action: cell.action, url: cell.url,
                                        requestId: cell.requestId,
                                        label: cell.actionLabel ?? "",
                                        itemId: cell.id, inspectState: inspectState)
                    }
                )
                .padding(.top, BentoHeroArrangement.bandTopAdjustment(shellInset: 0))
                .padding(.bottom, max(0, BentoHeroArrangement.bandBottom - railFooterOwnTopInset)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                RailFooterView(footer: railFooter(for: item), accent: branding.primaryColor)
            }
            .padding(.init(top: InspectMetrics.unit.railContentTop, leading: InspectMetrics.unit.railContentLeading,
                           bottom: InspectMetrics.unit.railContentBottom, trailing: InspectMetrics.unit.railContentTrailing))
        }
        .sourceTag()
    }
}
