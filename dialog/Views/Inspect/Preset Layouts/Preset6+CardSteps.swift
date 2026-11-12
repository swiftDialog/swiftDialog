//
//  Preset6+CardSteps.swift
//  dialog
//
//  Preset 6 adapter onto the shared card chrome (CardStepComponents.swift), used with `"chrome": "card"`.
//  Maps each item and engine state to a CardStepModel; navigation reuses the Preset 6 handlers.
//

import SwiftUI

extension Preset6View {

    var isCardChrome: Bool { inspectState.config?.construction == .card }

    /// Card-mode replacement for both intro/outro and sidebar layouts: one card per item, crossfaded.
    @ViewBuilder
    var cardCurrentStepView: some View {
        if let item = inspectState.steps[safe: currentStep] {
            cardStepView(item: item, index: currentStep)
                .id("card-step-\(item.id)")
                .transition(.opacity)
        }
    }

    @ViewBuilder
    func cardStepView(item: InspectConfig.IntroStep, index: Int) -> some View {
        // Dispatch on renderer first (processing renders as processing in any role), then on role.
        if item.stepType == "processing" {
            cardProcessingStepView(item: item, index: index)
        } else if item.resolvedPhase == "outro" {
            cardOutroStepView(item: item, index: index)
        } else {
            cardIntroStepView(item: item, index: index)
        }
    }

    // MARK: - Shared mapping helpers

    private func cardTitle(_ item: InspectConfig.IntroStep) -> String {
        localizedHeadline(item, fallback: item.title ?? item.displayName) ?? (item.displayName ?? item.title ?? item.id)
    }

    private func cardSubtitle(_ item: InspectConfig.IntroStep) -> String? {
        localized("subtitle", forItem: item, fallback: item.subtitle)
    }

    /// Localized guidance blocks, mapped the same way as the standard content panel.
    private func cardBlocks(_ item: InspectConfig.IntroStep) -> [InspectConfig.GuidanceContent] {
        // Live state is merged here, as in Preset 5's `cardBlocks`, so `update_guidance` reaches the card.
        (item.content ?? []).enumerated().map { idx, block in
            applyDynamicUpdates(to: localizedContentBlock(block, itemId: item.id, blockIndex: idx),
                                index: idx, itemId: item.id)
        }
    }

    // Internal: the rail adapter (Preset6+RailSteps.swift) uses the same Back label.
    func cardBackText(_ item: InspectConfig.IntroStep) -> String {
        // The per-step `backButtonText` takes precedence over the branding default.
        BackDoor.label(localized: localized("backButtonText", forItem: item, fallback: nil),
                       step: item.backButtonText, branding: branding.button2Text)
    }

    /// The bottom brand logo for the card footer; corner logos are suppressed under card chrome.
    private var cardFooterLogoPath: String? {
        BrandArtwork.resolve(inspectState.config?.logoConfig, isDark: colorScheme == .dark, gate: .footer)
    }

    private func cardFooter(for item: InspectConfig.IntroStep, index: Int,
                            dots: Bool = true, footnote: String? = nil,
                            continueDisabled: Bool? = nil) -> CardFooterModel {
        let showBack = canGoBack
        // The slot picker's copy keys word the footer, as in Preset 5's `cardFooter`.
        let slot = SlotPickerCopy.resolve(step: item, userValues: inspectState.userValues, now: Date(),
                                          l10n: { localizedUI($0, fallback: $1) })
        let slotSecondary: (() -> Void)? = slot?.secondaryText.map { _ in
            { [self] in
                let nowISO = SlotPicker.isoString(Date())
                inspectState.userValues[slot!.selectionKey] = nowISO
                DialogNotifications.postSelection(key: slot!.selectionKey, values: [nowISO])
                openCardContinueActionURL(item.continueAction)
                handleContinue()
            }
        }
        return CardFooterModel(
            dots: dots && CardFooterDots.shown(authored: item.showProgressDots)
                ? (index, max(1, inspectState.steps.count)) : nil,
            footnote: footnote,
            backText: showBack ? cardBackText(item) : nil,
            onBack: showBack ? { goToPreviousStep() } : nil,
            secondaryText: slot?.secondaryText,
            onSecondary: slotSecondary,
            continueText: slot?.continueText ?? getContinueButtonText(),
            continueDisabled: continueDisabled ?? isContinueDisabled,
            onContinue: {
                openCardContinueActionURL(item.continueAction)
                handleContinue()
            },
            logoPath: cardFooterLogoPath,
                logoHeight: CGFloat(inspectState.config?.logoConfig?.maxHeight ?? 27),
                logoClearSpace: inspectState.config?.logoConfig?.clearSpace ?? 0,
            inspectConfig: chromeDeferralAvailable ? inspectState.config : nil,
            deferralText: chromeDeferralAvailable ? chromeDeferralText : nil
        )
    }

    private func cardScreen(model: CardStepModel, stepId: String) -> CardStepScreen {
        CardStepScreen(model: model,
                       accent: branding.primaryColor,
                       inspectState: inspectState,
                       scaleFactor: scaleFactor,
                       iconBasePath: dynamicState.iconBasePathOverride ?? inspectState.uiConfiguration.iconBasePath,
                       stepId: stepId)
    }

    // MARK: - Card bodies

    @ViewBuilder
    func cardIntroStepView(item: InspectConfig.IntroStep, index: Int) -> some View {
        cardScreen(model: CardStepModel(
            eyebrow: inspectState.config?.title,
            eyebrowIcon: inspectState.config?.icon,
            stepLabel: chromeStepCounter(index),
            title: cardTitle(item),
            subtitle: cardSubtitle(item),
            blocks: cardBlocks(item),
            panel: localizedCardPanel(item),
            footer: cardFooter(for: item, index: index)
        ), stepId: item.id)
        .sourceTag()
    }

    // Preset 6 processing is per step, so the card shows one substep row for the whole step.
    @ViewBuilder
    func cardProcessingStepView(item: InspectConfig.IntroStep, index: Int) -> some View {
        // Failed takes precedence: failed steps are also in completedSteps.
        let stepFailed = failedSteps[item.id] != nil
        let stepDone = completedSteps.contains(item.id) && !stepFailed
        let rowState: CardSubstepState = stepFailed ? .failed
            : (stepDone ? .done : (isProcessing ? .active : .pending))
        let duration = item.processingDuration ?? 0
        let progress: Double? = stepDone ? 1.0
            : (isProcessing && duration > 0
                ? max(0, 1.0 - Double(processingCountdown) / Double(duration))
                : nil)
        // A processing step's text block becomes the card subtitle; an explicit subtitle wins.
        let textBlock = cardBlocks(item).first { $0.type == "text" }?.content
        cardScreen(model: CardStepModel(
            eyebrow: inspectState.config?.title,
            eyebrowIcon: inspectState.config?.icon,
            stepLabel: chromeStepCounter(index),
            title: cardTitle(item),
            subtitle: cardSubtitle(item) ?? textBlock,
            progress: progress,
            substeps: [(rowState,
                        localized("processingMessage", forItem: item,
                                  fallback: item.processingMessage) ?? cardTitle(item))],
            panel: localizedCardPanel(item),
            footer: cardFooter(for: item, index: index)
        ), stepId: item.id)
        .sourceTag()
    }

    // Outro: badge, receipt panel and footnote. Failed steps are listed and make the badge red.
    @ViewBuilder
    func cardOutroStepView(item: InspectConfig.IntroStep, index: Int) -> some View {
        let failures: [(label: String, detail: String?)] = inspectState.steps.compactMap { other in
            guard let reason = failedSteps[other.id] else { return nil }
            return (localized("displayName", forItem: other,
                              fallback: other.displayName) ?? (other.displayName ?? other.title ?? other.id),
                    reason)
        }
        cardScreen(model: CardStepModel(
            eyebrow: inspectState.config?.title,
            eyebrowIcon: inspectState.config?.icon,
            stepLabel: chromeStepCounter(index),
            title: cardTitle(item),
            titleBadge: true,
            titleBadgeFailed: !failures.isEmpty,
            subtitle: cardSubtitle(item),
            blocks: cardBlocks(item),
            failures: failures,
            panel: localizedCardPanel(item),
            footer: cardFooter(for: item, index: index,
                               dots: false,
                               footnote: localized("footerNote", forItem: item,
                                                   fallback: item.footerNote))
        ), stepId: item.id)
        .sourceTag()
    }
}
