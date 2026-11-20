//
//  Preset6+FooterAndIntroOutro.swift
//  dialog
//
//  Preset 6 extension: footer bar, button logic and the full-screen intro/outro view.
//

import SwiftUI

extension Preset6View {
    // MARK: - Footer Bar

    @ViewBuilder
    var footerBar: some View {
        let backText: String = {
            guard let item = inspectState.steps[safe: currentStep] else {
                return BackDoor.label(localized: nil, step: nil, branding: branding.button2Text)
            }
            return BackDoor.label(localized: localized("backButtonText", forItem: item, fallback: nil),
                                  step: item.backButtonText, branding: branding.button2Text)
        }()

        // In the `fill` arrangement the media caption is shown in the footer instead of under the picture.
        let mediaCaption: String? = {
            guard let blocks = inspectState.steps[safe: currentStep]?.content else { return nil }
            guard case .fill(let index) = MediaArrangement.resolve(blocks.filter { $0.visible != false }) else { return nil }
            let block = blocks.filter { $0.visible != false }[index]
            guard MediaLayout.resolve(block.mediaLayout).captionBelongsOnTheBar else { return nil }
            return block.caption
        }()

        IntroFooterView(
            // The claim shows only when authored, as on card footers (`CardFooterClaim`).
            // A media caption takes precedence.
            footerText: mediaCaption ?? CardFooterClaim.resolve(authored: branding.footerText),
            backButtonText: backText,
            continueButtonText: getContinueButtonText(),
            accentColor: highlightColor,
            showBackButton: canGoBack,
            onBack: goToPreviousStep,
            onContinue: handleContinue,
            continueDisabled: isContinueDisabled,
            inspectConfig: inspectState.config,
            buttonControlSize: .large,
            // Step counter, dots and the Option-click reset sit beside the logo. The template is resolved here
            // with the selected language rather than through the module's environment lookup.
            stepCounter: StepCounter(
                current: currentStep + 1,
                total: inspectState.steps.count,
                template: StepCounterLabel.template { key in
                    localizationService.string(forLanguage: selectedLanguageCode ?? "", key: key)
                },
                onTap: {
                    if NSEvent.modifierFlags.contains(.option) {
                        resetSteps()
                    }
                })
        )
        .transaction { $0.animation = nil }  // keep the footer still during step transitions
    }

    // MARK: - Button Logic

    var canGoBack: Bool {
        let hasIntro = inspectState.steps.first?.resolvedPhase == "intro"
        let minimumStep = hasIntro ? 1 : 0
        return currentStep > minimumStep && !shouldBlockNavigation
    }

    var isContinueDisabled: Bool {
        if isProcessing {
            return true
        }
        // Required guidance fields gate Continue/Finish.
        if let item = inspectState.steps[safe: currentStep],
           !inspectState.validateGuidanceInputs(for: item) {
            return true
        }
        // The last step uses the global observe-only flag; other steps use their own.
        if currentStep >= inspectState.steps.count - 1 {
            return isGlobalObserveOnly(config: inspectState.config)
        }
        return isItemObserveOnly(inspectState.steps[safe: currentStep], config: inspectState.config)
    }

    func getContinueButtonText() -> String {
        if currentStep >= inspectState.steps.count - 1 {
            if let item = inspectState.steps.last,
               let locText = localized("continueButtonText", forItem: item, fallback: nil) {
                return locText
            }
            return branding.button1Text ?? "Finish"
        }

        // Item button text: localization, then config.
        if let currentItem = inspectState.steps[safe: currentStep] {
            if let locText = localized("continueButtonText", forItem: currentItem, fallback: nil) {
                return locText
            }
            if let customText = currentItem.continueButtonText {
                return customText
            }

            if failedSteps[currentItem.id] != nil {
                return localized("continueAnywayText", forItem: currentItem, fallback: nil) ?? ChromeCopy.continueAnyway
            }
        }

        return branding.button1Text ?? ChromeCopy.continue
    }

    // MARK: - Intro/Outro View

    @ViewBuilder
    func introOutroView(isOutro: Bool) -> some View {
        // Pick the bookend by phase, falling back to the first or last step.
        let wanted = isOutro ? "outro" : "intro"
        let item = inspectState.steps.first { $0.resolvedPhase == wanted }
            ?? (isOutro ? inspectState.steps.last : inspectState.steps.first)

        // Shares BookendScreenView with Presets 1–3. No `onAction` is passed: this footer carries Back
        // and the deferral menu, which the shared bookend footer does not.
        VStack(spacing: 0) {
            let itemId = item?.id ?? "intro"
            let content = item?.content ?? []
            // Localization, then live plist monitor state, then IPC updates, so bookends receive update_guidance too.
            let mergedBlocks = content.enumerated().map { (index, block) -> InspectConfig.GuidanceContent in
                let locBlock = localizedContentBlock(block, itemId: itemId, blockIndex: index)
                let monBlock = applyPlistMonitorState(to: locBlock, index: index)
                return applyDynamicUpdates(to: monBlock, index: index, itemId: itemId)
            }

            BookendScreenView(
                role: isOutro ? .outro : .intro,
                heroPath: item.flatMap { dynamicState.heroImageOverrides[$0.id] } ?? item?.heroImage,
                heroSize: item?.heroImageSize,
                heroPadding: item?.heroImagePadding,
                title: item.flatMap { localizedHeadline($0, fallback: $0.title) }
                    ?? item?.title,
                contentBlocks: mergedBlocks,
                accentColor: highlightColor,
                scaleFactor: scaleFactor,
                iconBasePath: dynamicState.iconBasePathOverride ?? inspectState.uiConfiguration.iconBasePath,
                itemId: itemId,
                inspectState: inspectState
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            IntroFooterView(
                footerText: branding.footerText,
                backButtonText: BackDoor.label(
                    localized: item.flatMap { localized("backButtonText", forItem: $0, fallback: nil) },
                    step: item?.backButtonText, branding: branding.button2Text),
                continueButtonText: {
                    if let item = item, let locText = localized("continueButtonText", forItem: item, fallback: nil) {
                        return locText
                    }
                    return item?.continueButtonText ?? (isOutro ? "Finish" : ChromeCopy.continue)
                }(),
                accentColor: highlightColor,
                showBackButton: isOutro && currentStep > 0,
                onBack: isOutro ? { goToPreviousStep() } : nil,
                onContinue: {
                    if isOutro {
                        handleFinish()
                    } else {
                        if let item = item {
                            handleStepCompletion(item: item)
                        }
                        navigateToNextStep()
                    }
                }
            )
        }
        .sourceTag()
    }
}
