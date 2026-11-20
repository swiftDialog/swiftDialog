//
//  Preset5+CardSteps.swift
//  dialog
//
//  Preset 5's adapter onto the shared card chrome: each arm maps an IntroStep plus
//  engine state onto a CardStepModel; the visual contract lives in CardStepComponents.swift.
//

import SwiftUI

extension Preset5View {

    /// Step types the card chrome renders; other types keep their normal rendering under card
    /// chrome. `standard` is the type every untyped step resolves to, so it needs a card home.
    static let cardEligibleStepTypes: Set<String> = ["intro", "guide", "processing", "outro",
                                                    "assistant", "media",
                                                    "options", "wallpaper", "brandPicker",
                                                    "dock", "substeps", "export",
                                                    "carousel", "bento", "standard"]

    nonisolated static func cardArm(for step: InspectConfig.IntroStep) -> CardArm {
        CardArm.of(step)
    }

    static func cardEligible(_ step: InspectConfig.IntroStep,
                             construction: InspectSizes.Construction?) -> Bool {
        construction == .card && cardEligibleStepTypes.contains(step.resolvedStepType)
    }

    func isCardStep(_ step: InspectConfig.IntroStep) -> Bool {
        Self.cardEligible(step, construction: config?.construction)
    }

    /// Position in the whole flow, not among card-eligible steps only; mixed flows would lie.
    func cardDotIndex(for stepIndex: Int) -> (current: Int, total: Int) {
        Self.visiblePosition(steps: allSteps, values: inspectState.userValues, index: stepIndex)
    }

    /// Position among the steps whose `showWhen` matches the picks so far. A hidden current
    /// step (reached by goto) still counts from where it sits.
    static func visiblePosition(steps: [InspectConfig.IntroStep], values: [String: String],
                                index: Int) -> (current: Int, total: Int) {
        let shows = { (step: InspectConfig.IntroStep) in step.showWhen?.matches(values) ?? true }
        let clamped = min(max(index, 0), max(0, steps.count - 1))
        let visible = steps.indices.filter { shows(steps[$0]) || $0 == clamped }
        let current = visible.firstIndex(of: clamped) ?? 0
        return (current, max(1, visible.count))
    }

    /// Chrome strings: sidecar `_ui.<key>`, then config labels, then the fallback.
    private func cardChromeUI(_ key: String, fallback: String) -> String {
        if let lang = selectedLanguageCode, localizationService.hasLanguage(lang),
           let s = localizationService.string(forLanguage: lang, key: "_ui.\(key)") {
            return s
        }
        return resolveLabel(key, config: config,
                            language: selectedLanguageCode, fallback: nil) ?? fallback
    }

    /// The card eyebrow: sidecar `_ui.title`, else config.title.
    var cardChromeTitle: String? {
        guard let title = config?.title else { return nil }
        return cardChromeUI("title", fallback: title)
    }


    /// Countdown-to-quit for a step authoring `autoCloseAfter`. Expiry writes the result file,
    /// sweeps readiness and exits 4 (timer expired), distinct from user close (0) and `close` (5).
    func cardAutoClose(_ step: InspectConfig.IntroStep) -> CardAutoCloseModel? {
        guard let seconds = step.autoCloseAfter, seconds > 0 else { return nil }
        let format = localized("ui.closesIn", forStep: step, fallback: "Closes in {time}")
            ?? "Closes in {time}"
        return CardAutoCloseModel(seconds: seconds, labelFormat: format) { [self] in
            writeLog("Preset5: autoCloseAfter expired — closing with exit 4", logLevel: .info)
            let allCompleted = completedNavigatedSteps.union(completedProcessingSteps)
            let stepInfos = allSteps.map { ResultStepInfo(id: $0.id, stepType: $0.resolvedStepType) }
            writeResultFile(
                config: config, exitCode: Int(appDefaults.exit4.code), steps: stepInfos,
                completedSteps: allCompleted, failedSteps: failedSteps,
                skippedSteps: skippedSteps, currentStepIndex: currentStepIndex,
                formValues: exportedFormValues, selections: mergedResultSelections,
                selectedBrand: selectedBrandId
            )
            cleanupReadinessFile(config: config, triggerFilePath: triggerFilePath,
                                 exitCode: Int(appDefaults.exit4.code),
                                 completedCount: allCompleted.count,
                                 failedCount: failedSteps.count,
                                 totalSteps: allSteps.count)
            quitDialog(exitCode: appDefaults.exit4.code)
        }
    }

    func cardStepLabel(_ stepIndex: Int) -> String? {
        let dots = cardDotIndex(for: stepIndex)
        // Only the substitution is shared, so `{n}` and `{current}` mean the same on every surface.
        return StepCounterLabel.format(
            cardChromeUI("stepCounterFormat", fallback: "Step {current} of {total}"),
            current: dots.current + 1, total: dots.total)
    }

    var cardDeferralText: String? {
        guard isDeferralEnabled(config: config) else { return nil }
        return cardChromeUI("deferralButton",
                            fallback: config?.deferralConfig?.buttonText ?? "Not Now")
    }

    /// Localized guidance blocks with live state merged in, plus the step-level stats, media
    /// and grid folds. Internal so the showcase caption band can draw the same blocks.
    func cardBlocks(_ step: InspectConfig.IntroStep) -> [InspectConfig.GuidanceContent] {
        // Live state (plist monitor, then IPC) merges before the folds so block indices still
        // match `step.content`, which is what the command router resolves against. The plist
        // monitor belongs to the current step only; showcase draws other steps' blocks here too.
        let isCurrent = step.id == currentStep?.id
        let localizedBlocks = (step.content ?? []).enumerated().map { idx, block in
            let localized = localizedContentBlock(block, stepId: step.id, blockIndex: idx)
            let withPlist = isCurrent
                ? applyDynamicState(to: localized, dynamicState: introStepMonitor.stateForBlock(idx))
                : localized
            return applyIPCState(to: withPlist, blockIndex: idx, stepId: step.id)
        }
        // Same treatment as the legacy renderer: sidecar `<stepId>.stats.<i>.value|label`, then
        // `{itemCount}` from live state.
        let withStats = CardStepBlocks.fold(content: localizedBlocks, stats: step.stats) { index, field, text in
            let key = "stats.\(index).\(field == .value ? "value" : "label")"
            let sidecar = localized(key, forStep: step, fallback: text) ?? text
            return sidecar.replacingOccurrences(of: "{itemCount}", with: "\(inspectState.items.count)")
        }
        // Folded here, not at decode: the standard renderer still reads these keys directly.
        // Order matches it: content, then media, then grid.
        let withMedia = CardStepBlocks.foldMedia(content: withStats, items: step.mediaItems,
                                                 height: step.mediaHeight,
                                                 autoplay: step.mediaAutoplay,
                                                 showArrows: step.mediaShowArrows,
                                                 showDots: step.mediaShowDots,
                                                 fit: step.mediaFit)
        return CardStepBlocks.foldGrid(content: withMedia, items: step.gridItems,
                                       columns: step.gridColumns,
                                       selectionMode: step.gridSelectionMode,
                                       // Same default key as the standard renderer.
                                       selectionKey: step.gridSelectionKey ?? step.id)
    }

    /// Card-panel localization: `<stepId>.cardPanel.caption/stat/imageTitle`,
    /// `.pairs.<i>.label|value`, `.paragraphs.<i>`.
    func localizedCardPanel(_ step: InspectConfig.IntroStep) -> InspectConfig.CardPanel? {
        guard let panel = step.cardPanel else { return nil }
        guard let lang = selectedLanguageCode, localizationService.hasLanguage(lang) else { return panel }
        guard languageApplies(toStep: step.id) else { return panel }
        let prefix = "\(step.id).cardPanel"
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

    private var cardDeferralAvailable: Bool {
        DeferralMenu.isOffered(steps: allSteps, currentIndex: currentStepIndex)
    }

    var cardDeferralConfig: InspectConfig? {
        cardDeferralAvailable ? config : nil
    }

    /// The top band is all-steps-or-nothing: one step whose arm cannot carry it suppresses the
    /// band for the whole flow, with one advisory naming the step. Card chrome only.
    func cardTopBandFor(_ step: InspectConfig.IntroStep) -> InspectConfig.TopBandConfig? {
        guard let band = config?.topBand else { return nil }
        guard config?.construction == .card else {
            return suppressBand(why: "topBand renders in the card chrome only")
        }
        let claim = band.flavor.lowercased() == "claim"
        let blocking = topBandBlockingStep(in: allSteps, claim: claim)
        if let blocking {
            return suppressBand(why: "step '\(blocking.id)' (\(blocking.resolvedStepType)) is on the band's conflict list, and the band is all-steps-or-nothing")
        }
        // Resolve the ground palette at injection so the shell needs no config access.
        return InspectConfig.TopBandConfig(
            flavor: band.flavor, height: band.height, image: band.image,
            ground: band.ground,
            groundPalette: band.groundPalette ?? config?.gradientPalette,
            groundImage: band.groundImage)
    }

    /// Process-lifetime latch, not @State: a @State insert loses the race against the double
    /// body evaluation at launch.
    static var topBandAdvisoryLogged = false
    private func suppressBand(why: String) -> InspectConfig.TopBandConfig? {
        if !Self.topBandAdvisoryLogged {
            Self.topBandAdvisoryLogged = true
            writeLog("Preset5: topBand not rendered — \(why)", logLevel: .info)
        }
        return nil
    }

    /// Brand mark for the card chrome. Only the `.actionLeading` slot keeps the footer gate;
    /// every other slot seats the mark itself and must not be starved by that gate.
    var cardFooterLogoPath: String? {
        guard let lc = config?.logoConfig else { return nil }
        return BrandArtwork.resolve(lc, isDark: colorScheme == .dark,
                                    gate: BrandSlot(position: lc.position) == .actionLeading ? .footer : .any)
    }

    /// The card footer for every arm. Logo, deferral and config are absorbed here; the back
    /// pair defaults on (progress arms pass `showBack: false`); sub-pager arms pass `onBack` to
    /// step back within their sub-flow first. `onContinue` differs per arm and stays a parameter.
    func cardFooter(for step: InspectConfig.IntroStep,
                    index: Int,
                    dots: Bool = true,
                    showBack: Bool? = nil,
                    continueText: String? = nil,
                    continueDisabled: Bool = false,
                    footnote: String? = nil,
                    secondaryText: String? = nil,
                    onSecondary: (() -> Void)? = nil,
                    subStepper: CardSubStepperModel? = nil,
                    onBack: (() -> Void)? = nil,
                    autoClose: CardAutoCloseModel? = nil,
                    onContinue: @escaping () -> Void) -> CardFooterModel {
        let canBack = showBack ?? (canGoBack(fromStepIndex: index) && (step.showBackButton ?? true))
        // A `slot-picker` step words its buttons from the chosen slot; an arm's explicit text
        // still wins. The secondary moves the slot to now and continues.
        let slot = SlotPickerCopy.resolve(step: step, userValues: inspectState.userValues, now: Date(),
                                          l10n: { localizedUI($0, fallback: $1) })
        let slotSecondary: (() -> Void)? = slot?.secondaryText.map { _ in
            { [self] in
                let nowISO = SlotPicker.isoString(Date())
                inspectState.userValues[slot!.selectionKey] = nowISO
                DialogNotifications.postSelection(key: slot!.selectionKey, values: [nowISO])
                onContinue()
            }
        }
        return CardFooterModel(
            dots: dots && CardFooterDots.shown(authored: step.showProgressDots) ? cardDotIndex(for: index) : nil,
            subStepper: subStepper,
            footnote: footnote,
            backText: canBack ? BackDoor.label(localized: localized("backButtonText", forStep: step, fallback: nil),
                                               step: step.backButtonText,
                                               branding: branding.button2Text) : nil,
            onBack: canBack ? (onBack ?? { goToPreviousStep() }) : nil,
            secondaryText: secondaryText ?? slot?.secondaryText,
            onSecondary: onSecondary ?? slotSecondary,
            continueText: continueText ?? slot?.continueText
                ?? localized("continueButtonText", forStep: step, fallback: step.continueButtonText) ?? ChromeCopy.continue,
            continueDisabled: continueDisabled,
            onContinue: onContinue,
            logoPath: cardFooterLogoPath,
            logoHeight: CGFloat(config?.logoConfig?.maxHeight ?? 27),
            logoClearSpace: config?.logoConfig?.clearSpace ?? 0,
            inspectConfig: cardDeferralConfig,
            deferralText: cardDeferralText,
            autoClose: autoClose
        )
    }

    // Internal: read from the sibling card arm files.
    func cardScreen(model: CardStepModel, stepId: String) -> CardStepScreen {
        CardStepScreen(model: model,
                       accent: branding.primaryColor,
                       inspectState: inspectState,
                       scaleFactor: scaleFactor,
                       iconBasePath: effectiveIconBasePath,
                       stepId: stepId,
                       checklistLineSatisfied: checklistLineSatisfied)
    }

    func cardStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        cardStepBody(step: step, stepIndex: stepIndex)
    }

    @ViewBuilder
    private func cardStepBody(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        switch Self.cardArm(for: step) {
        case .processing:  cardProcessingStepView(step: step, stepIndex: stepIndex)
        case .outro:       cardOutroStepView(step: step, stepIndex: stepIndex)
        case .media:       cardMediaStepView(step: step, stepIndex: stepIndex)
        case .chooserOptions, .chooserWallpaper, .chooserBrands, .chooserDock:
            cardChooserStepView(step: step, stepIndex: stepIndex, arm: Self.cardArm(for: step))
        case .substepsWizard:
            cardSubstepsWizardView(step: step, stepIndex: stepIndex)
        case .export:
            cardExportStepView(step: step, stepIndex: stepIndex)
        case .carousel:
            cardCarouselStepView(step: step, stepIndex: stepIndex)
        case .bento:
            cardBentoStepView(step: step, stepIndex: stepIndex)
        case .prose:       cardIntroStepView(step: step, stepIndex: stepIndex)
        }
    }

    /// The hero band from the step's `heroImage*` keys; no `heroImage`, no band. The card hero
    /// is a fixed mark, so `assistant.imageHeight` is ignored and the author is told.
    func cardHero(_ step: InspectConfig.IntroStep) -> CardHeroModel? {
        // Before the guard: `heroBadge` is authorable on a step with no hero at all.
        cardIgnoredKeyAdvisory(step)
        guard let icon = dynamicState.heroImageOverrides[step.id] ?? step.heroImage else { return nil }
        if step.assistantImageHeight != nil {
            writeLog("card chrome: assistant.imageHeight ignored on '\(step.id)' — the card hero "
                     + "is a fixed 44pt mark; remove the key or drop heroImage to remove the band",
                     logLevel: .info)
        }

        return CardHeroModel(icon: icon,
                             sfColor: step.heroImageSFSymbolColor.map { Color(hex: $0) },
                             sfWeight: CardHeroAdvice.weight(from: step.heroImageSFSymbolWeight))
    }

    /// Logs the hero keys the card chrome ignores, once per step.
    func cardIgnoredKeyAdvisory(_ step: InspectConfig.IntroStep) {
        let ignored = CardHeroAdvice.ignoredKeys(shape: step.heroImageShape,
                                                 size: step.heroImageSize,
                                                 padding: step.heroImagePadding,
                                                 badge: step.heroBadge)
        guard !ignored.isEmpty, !Self.warnedHeroGeometryStepIds.contains(step.id) else { return }
        Self.warnedHeroGeometryStepIds.insert(step.id)
        writeLog("card chrome: \(ignored.joined(separator: ", ")) ignored on '\(step.id)' — the card "
                 + "hero is a fixed 44pt band in the card language rather than the legacy centred "
                 + "mark those keys size, shape and badge, and the card footer always states the "
                 + "step position. Remove them, or drop `chrome: \"card\"` for this flow.",
                 logLevel: .info)
    }

    /// Once per step id per process; Back-navigation revisits steps.
    private static var warnedHeroGeometryStepIds = Set<String>()


}


extension Preset5View {
    /// For steps with select blocks, the info card shows "Selected n of m" plus totals summed
    /// from option details (MB to "Total size", dollars to "Order total"). Authored content wins.
    func selectAwareCardPanel(_ step: InspectConfig.IntroStep) -> InspectConfig.CardPanel? {
        let authored = localizedCardPanel(step)
        let blocks = (step.guidanceContent?.map { $0 } ?? []) + (step.content?.map { $0 } ?? [])
        let selects = blocks.filter { $0.type == "select-list" || $0.type == "select-grid" }
        guard !selects.isEmpty else { return authored }

        var selectedCount = 0, totalCount = 0
        var totalMB = 0.0, totalDollars = 0.0
        for block in selects {
            let options = block.options ?? []
            totalCount += options.count
            let required = Set(block.requiredOptions ?? [])
            let stored = inspectState.guidanceFormInputs[step.id]?.textfields[block.id ?? ""]
            let raw: [String] = stored.map { $0.split(separator: "\u{001F}").map(String.init) }
                ?? (block.value ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let selected = Set(raw.filter { !$0.isEmpty }).union(required)
            selectedCount += options.filter { selected.contains($0) }.count
            if let details = block.optionDetails {
                for (i, option) in options.enumerated() where selected.contains(option) {
                    guard details.indices.contains(i) else { continue }
                    // The detail line carries prose around the size ("Recommended · 210 MB").
                    if let mbRange = details[i].range(of: #"[0-9]+(?:[.,][0-9]+)?\s*[MG]B"#,
                                                      options: .regularExpression),
                       let mb = InstallMath.megabytes(String(details[i][mbRange])) { totalMB += mb }
                    if let range = details[i].range(of: #"\$([0-9]+(?:\.[0-9]{1,2})?)"#,
                                                    options: .regularExpression),
                       let dollars = Double(details[i][range].dropFirst()) {
                        totalDollars += dollars
                    }
                }
            }
        }

        var pairs: [InspectConfig.CardPanelPair] = []
        if totalMB > 0 {
            pairs.append(InspectConfig.CardPanelPair(
                label: localized("ui.totalSize", forStep: step, fallback: "Total size") ?? "Total size",
                value: "\(Int(totalMB.rounded())) MB"))
        }
        if totalDollars > 0 {
            pairs.append(InspectConfig.CardPanelPair(
                label: localized("ui.orderTotal", forStep: step, fallback: "Order total") ?? "Order total",
                value: String(format: "$%.2f", totalDollars)))
        }
        pairs.append(contentsOf: authored?.pairs ?? [])

        return InspectConfig.CardPanel(
            caption: authored?.caption
                ?? (localized("ui.selected", forStep: step, fallback: "Selected") ?? "Selected"),
            stat: authored?.stat ?? "\(selectedCount) of \(totalCount)",
            pairs: pairs.isEmpty ? nil : pairs,
            image: authored?.image, video: authored?.video,
            imageTitle: authored?.imageTitle, paragraphs: authored?.paragraphs,
            layout: authored?.layout)
    }
}
