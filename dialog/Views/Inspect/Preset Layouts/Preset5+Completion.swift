//
//  Preset5+Completion.swift
//  dialog
//
//  Preset 5 extension: override levels, processing completion and completion triggers (as on Preset 6).
//

import SwiftUI

extension Preset5View {

    // MARK: - Completion Handling

    /// Override level from the elapsed wait time.
    var currentOverrideLevel: OverrideLevel {
        ProcessingFlow.overrideLevel(for: allSteps[safe: currentStepIndex], waited: processingWaitElapsed)
    }

    /// Handles step completion triggers (success/failure/warning). `confirmed`: the result is the
    /// user's own choice, so a `requireManualConfirm` step completes at once.
    func handleCompletionTrigger(stepId: String, result: CompletionResult, confirmed: Bool = false) {
        // Looks up every step, not only intro/outro: a trigger can target any renderer.
        let effect = StepCompletion.record(result, stepId: stepId, steps: allSteps, confirmed: confirmed,
                                           completed: &completedProcessingSteps, failed: &failedSteps,
                                           skipped: &skippedSteps, values: &inspectState.userValues)
        switch effect {
        case .unknownStep:
            writeLog("Preset5: Cannot handle completion for unknown step: \(stepId)", logLevel: .error)

        case .awaitingConfirm:
            // requireManualConfirm: the result is recorded; no timer stop, no auto-advance.
            writeLog("Preset5: Completion trigger for '\(stepId)' received but requireManualConfirm=true — waiting for user click", logLevel: .info)
            switch result {
            case .success(let message):
                writeLog("Preset5: Step '\(stepId)' success recorded (manual confirm required): \(message ?? "")", logLevel: .info)
            case .warning(let message):
                writeLog("Preset5: Step '\(stepId)' warning recorded (manual confirm required): \(message ?? "")", logLevel: .info)
            case .failure(let message):
                writeLog("Preset5: Step '\(stepId)' failure recorded (manual confirm required): \(message ?? "")", logLevel: .info)
            case .cancelled:
                break
            }

        case .completed:
            stopProcessingCountdown()
            switch result {
            case .success(let message):
                writeLog("Preset5: Processing completed with success for '\(stepId)': \(message ?? "No message")", logLevel: .info)
                print("[PRESET11_PROCESSING] processing_result: \(stepId) = success")
            case .warning(let message):
                writeLog("Preset5: Processing completed with warning for '\(stepId)': \(message ?? "No message")", logLevel: .info)
                print("[PRESET11_PROCESSING] processing_result: \(stepId) = warning")
            case .failure(let message):
                writeLog("Preset5: Processing completed with failure for '\(stepId)': \(message ?? "No reason")", logLevel: .info)
                print("[PRESET11_PROCESSING] processing_result: \(stepId) = failed")
            case .cancelled:
                writeLog("Preset5: Processing cancelled/skipped for '\(stepId)'", logLevel: .info)
                print("[PRESET11_PROCESSING] processing_result: \(stepId) = skipped")
            }
        }
    }

    /// Maps `LegacyProcessingResult` calls onto `handleCompletionTrigger`.
    func markProcessingCompleted(step: InspectConfig.IntroStep, result: LegacyProcessingResult,
                                 confirmed: Bool = false) {
        switch result {
        case .success:
            handleCompletionTrigger(stepId: step.id, result: .success(message: step.successMessage), confirmed: confirmed)
        case .failure(let reason):
            handleCompletionTrigger(stepId: step.id, result: .failure(message: reason), confirmed: confirmed)
        case .skipped:
            handleCompletionTrigger(stepId: step.id, result: .cancelled, confirmed: confirmed)
        }
    }

    /// Processing result used by older call sites.
    enum LegacyProcessingResult {
        case success
        case failure(reason: String)
        case skipped
    }

    /// Starts the waiting timer after a countdown completes.
    func startWaitingTimer(for step: InspectConfig.IntroStep, stepIndex: Int) {
        let clock = Poll(every: 1)
        processingClock = clock
        clock.start { [self] in
            processingWaitElapsed += 1
            if case .waiting(let stepId, let waitElapsed) = processingState {
                processingState = .waiting(stepId: stepId, waitElapsed: waitElapsed + 1)
            }
        }
    }

    /// Stops the processing countdown.
    func stopProcessingCountdown() {
        processingClock?.cancel()
        processingClock = nil
        processingCountdown = 0
        processingWaitElapsed = 0
        processingState = .idle
    }

    /// Standard intro step: hero image, title, content.
    @ViewBuilder
    func standardIntroStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let isOutro = isOutroStep(step)
        let canGoBackFromStep = canGoBack(fromStepIndex: stepIndex)
        let isLastStep = stepIndex == totalSteps - 1

        // Button text: MDM, then localization, then step config, then default.
        let continueText: String = {
            if isOutro {
                return branding.outroButtonText
                    ?? localized("continueButtonText", forStep: step, fallback: nil)
                    ?? step.continueButtonText ?? (isLastStep ? "Finish" : ChromeCopy.continue)
            } else {
                return branding.introButtonText
                    ?? localized("continueButtonText", forStep: step, fallback: nil)
                    ?? step.continueButtonText ?? ChromeCopy.continue
            }
        }()

        // Back button: localization, step config, MDM, default (order owned by BackDoor).
        let backText = BackDoor.label(localized: localized("backButtonText", forStep: step, fallback: nil),
                                    step: step.backButtonText, branding: branding.button2Text)

        // button2 acts as skip/defer when Back is unavailable (e.g. the first step).
        let button2AsSkip = !canGoBackFromStep ? branding.button2Text : nil

        VStack(spacing: 0) {
            GeometryReader { geometry in
                // The shell owns contentAnchor positioning; content blocks pad themselves horizontally.
                AnchoredStepContent(
                    anchor: stance(for: step).anchor,
                    alignment: stance(for: step).align,
                    metrics: metrics,
                    horizontalPadding: stance(for: step).isLeading ? metrics.contentPadH : 0
                ) {

                        if let heroImage = dynamicState.heroImageOverrides[step.id] ?? step.heroImage {
                            let heroRatio: CGFloat = 0.28 * metrics.measureScale
                            let heroMax: CGFloat = 220 * metrics.measureScale
                            let proportionalSize = min(max(geometry.size.height * heroRatio, 100), heroMax)
                            IntroHeroImage(
                                path: heroImage,
                                shape: step.heroImageShape ?? "none",
                                size: step.heroImageSize ?? proportionalSize,
                                accentColor: heroImageColor(step: step),
                                sfSymbolColor: step.heroImageSFSymbolColor.map { Color(hex: $0) },
                                sfSymbolWeight: sfSymbolWeight(from: step.heroImageSFSymbolWeight),
                                basePath: effectiveIconBasePath,
                                padding: step.heroImagePadding
                            )
                            .overlay(alignment: .topTrailing) {
                                if step.heroBadge == "check" {
                                    ZStack {
                                        Circle().fill(Color(NSColor.windowBackgroundColor)).frame(width: 34, height: 34)
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 30))
                                            .foregroundStyle(.white, palette.success)
                                    }
                                    .offset(x: 8, y: -4)
                                }
                            }
                        }

                    // Title: MDM, then localization, then config.
                    let displayTitle: String? = {
                        if isOutro, let mdmTitle = branding.outroTitle {
                            return mdmTitle
                        } else if !isOutro, let mdmTitle = branding.introTitle {
                            return mdmTitle
                        }
                        return localized("title", forStep: step, fallback: step.title)
                    }()

                    // {userName} resolves through the greeting chain; strings without it pass through.
                    let s = stance(for: step)
                    VStack(alignment: s.align, spacing: metrics.titleSubtitle) {
                        if let title = displayTitle {
                            HStack(spacing: metrics.titleSubtitle) {
                                Text(title.contains("{userName}")
                                     ? substituteGreeting(title, userName: resolveGreetingName(config: config))
                                     : title)
                                    .font(metrics.stepTitle)
                                    .multilineTextAlignment(s.textAlignment)

                                stepInfoButton(for: step)
                            }
                            .frame(maxWidth: s.proseMaxWidth(metrics), alignment: s.frameAlignment)
                        }

                        if let subtitle = localized("subtitle", forStep: step, fallback: step.subtitle) {
                            Text(subtitle.contains("{userName}")
                                 ? substituteGreeting(subtitle, userName: resolveGreetingName(config: config))
                                 : subtitle)
                                .font(metrics.stepSubtitle)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(s.textAlignment)
                                .frame(maxWidth: s.proseMaxWidth(metrics), alignment: s.frameAlignment)
                        }
                    }
                    // Span the column so the flush edge is the column's edge.
                    .frame(maxWidth: .infinity, alignment: s.frameAlignment)

                    // Config-authored stat cells; `{itemCount}` resolves from live state.
                    if let stats = step.stats, !stats.isEmpty {
                        StatCellsRow(
                            cells: stats.enumerated().map { index, stat in
                                StatCell(
                                    value: localized("stats.\(index).value", forStep: step, fallback: stat.value)?
                                        .replacingOccurrences(of: "{itemCount}", with: "\(inspectState.items.count)")
                                        ?? stat.value,
                                    label: localized("stats.\(index).label", forStep: step, fallback: stat.label) ?? stat.label
                                )
                            },
                            scaleFactor: 1.0,
                            alignment: s.align,
                            // Leading layout wraps four facts to 2×2; centred keeps one row in the column.
                            columns: s.isLeading ? 2 : nil
                        )
                        .frame(maxWidth: s.maxWidth(metrics), alignment: s.frameAlignment)
                    }

                    // A receipt of the user's choices, each changeable before Finish.
                    if let rows = step.receipt, !rows.isEmpty {
                        let resolved = rows.compactMap { row -> ChoiceReceiptRow? in
                            // Unanswered choices are omitted rather than shown blank.
                            guard let value = receiptValue(for: row) else { return nil }
                            return ChoiceReceiptRow(
                                stepId: row.stepId,
                                label: localized("receipt.\(row.stepId).label", forStep: step, fallback: row.label) ?? row.label,
                                value: value
                            )
                        }
                        if !resolved.isEmpty {
                            ChoiceReceipt(
                                rows: resolved,
                                accent: branding.primaryColor,
                                scaleFactor: 1.0,
                                changeLabel: localizedUI("receiptChange", fallback: "Change"),
                                // Navigates only to existing step ids, so index-based resume stays valid.
                                onChange: { stepId in navigateToStep(stepId: stepId) }
                            )
                            .frame(maxWidth: metrics.contentMaxW)
                        }
                    }

                    // Recap of a cadence run completed in this launch.
                    if step.showCadenceRecap == true {
                        cadenceRecapView()
                            .padding(.top, 4)
                    }

                    // Localization first, then cadence tokens ({cadenceCount}/{cadenceDuration}/{cadenceTimeouts}).
                    if let content = step.content {
                        VStack(spacing: metrics.blockGap) {
                            ForEach(content.indices, id: \.self) { index in
                                let block = resolvedCadenceTokens(
                                    localizedContentBlock(content[index], stepId: step.id, blockIndex: index))
                                introContentBlock(block, blockIndex: index)
                            }
                        }
                        .padding(.top, metrics.topInset)
                        // Re-render when dynamic state or language changes.
                        .id("content-\(step.id)-\(selectedLanguageCode ?? "")")
                    }

                    if let mediaItems = step.mediaItems, !mediaItems.isEmpty {
                        IntroMediaCarousel(
                            items: mediaItems,
                            height: step.mediaHeight ?? 400,
                            autoplay: step.mediaAutoplay ?? true,
                            showArrows: step.mediaShowArrows ?? true,
                            showDots: step.mediaShowDots ?? true,
                            accentColor: branding.accentColor,
                            fit: MediaFit(step.mediaFit)
                        )
                        .padding(.horizontal, metrics.contentPadH)
                        .padding(.top, metrics.topInset)
                    }

                    if let gridItems = step.gridItems, !gridItems.isEmpty {
                        let key = step.gridSelectionKey ?? step.id
                        let binding = Binding<Set<String>>(
                            get: { gridSelections[key] ?? [] },
                            set: { gridSelections[key] = $0 }
                        )

                        IntroGridPicker(
                            items: gridItems.map { IntroGridItem(
                                id: $0.id,
                                imagePath: $0.imagePath,
                                sfSymbol: $0.sfSymbol,
                                title: $0.title,
                                subtitle: $0.description ?? $0.subtitle,  // description takes precedence
                                value: $0.value ?? $0.id  // defaults to id for preference writes
                            ) },
                            columns: step.gridColumns ?? 3,
                            selectionMode: step.gridSelectionMode ?? "single",
                            selectedIds: binding,
                            accentColor: branding.accentColor
                        )
                        .padding(.horizontal, metrics.contentPadH)
                    }

                    // The wallpaper picker is the `wallpaper-picker` content block.

                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if (step.showProgressDots ?? false) && totalSteps > 1 {
                StepDotIndicator(current: stepIndex + 1, total: totalSteps,
                                 accentColor: branding.primaryColor)
                .padding(.bottom, 16)
            }

            IntroFooterView(
                footerText: footerClaim,
                backButtonText: backText,
                continueButtonText: continueText,
                accentColor: branding.primaryColor,
                // Back must be both possible and wanted; `showBackButton` defaults to true.
                showBackButton: canGoBack(fromStepIndex: stepIndex) && (step.showBackButton ?? true),
                onBack: { goToPreviousStep() },
                onContinue: { goToNextStep() },
                continueDisabled: standardContinueDisabled(step: step),
                skipButtonText: button2AsSkip,
                onSkip: button2AsSkip != nil ? { handleButton2() } : nil,
                inspectConfig: config,
                buttonControlSize: metrics.buttonControlSize,
                showDeferral: !canGoBackFromStep
            )
        }
        .onAppear {
            initializeFormDefaults(for: step)
            // Start plist monitoring; the callback supports auto-advance.
            introStepMonitor.startMonitoring(step: step) { [self] triggerStepId, result in
                guard step.requireManualConfirm != true else {
                    writeLog("Preset5: Completion trigger fired for step '\(triggerStepId)' but requireManualConfirm=true", logLevel: .debug)
                    return
                }
                // Auto-advance only when configured and the result is success.
                guard step.autoAdvanceOnComplete == true else {
                    writeLog("Preset5: Completion trigger fired for step '\(triggerStepId)' but autoAdvanceOnComplete is not enabled", logLevel: .debug)
                    return
                }

                if case .success = result {
                    writeLog("Preset5: Auto-advancing from step '\(triggerStepId)' due to completion trigger", logLevel: .info)
                    goToNextStep()
                }
            }
        }
        .sourceTag()
    }

    /// The user's answer for a receipt row, in the words they saw, or nil when unanswered.
    /// Reads live selections, not config.
    func receiptValue(for row: InspectConfig.IntroStep.ReceiptRow) -> String? {
        let key = row.selectionKey ?? row.stepId
        let source = allSteps.first { $0.id == row.stepId }

        if let raw = inspectState.userValues[key], !raw.isEmpty {
            if let card = source?.optionCards?.first(where: { ($0.value ?? $0.cardId) == raw }) {
                return card.label
            }
            return raw
        }

        if let raw = inspectState.dockSelection[key], !raw.isEmpty {
            if let decline = source?.dockDecline, (decline.value ?? "none") == raw {
                return decline.label
            }
            let paths = raw.split(separator: ",").filter { !$0.isEmpty }
            if !paths.isEmpty {
                let flavour = source?.dockFlavors?.first {
                    Set($0.items.map(\.path)) == Set(paths.map(String.init))
                }
                let count = "\(paths.count) app\(paths.count == 1 ? "" : "s")"
                return flavour.map { "\($0.name) — \(count)" } ?? count
            }
            return raw
        }

        return row.fallbackValue
    }
}
