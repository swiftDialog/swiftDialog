//
//  Preset5+CoreSteps.swift
//  dialog
//
//  Preset 5 extension: the step router, installation step and deployment step.
//

import SwiftUI

extension Preset5View {

    // MARK: - Intro/Outro Step View

    /// Renders one step: stepType picks the renderer, the phase picks intro vs outro.
    @ViewBuilder
    func introStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        // `canonicalizeStep` sets stepType at decode (InspectConfig.stepRendererPriority), for file and IPC
        // steps alike; the presence checks below are the fallback for a step that skipped it.
        switch step.stepType {
        case "installation":
            installationStepView(step: step, stepIndex: stepIndex)
        case "wallpaper":
            cardStepView(step: step, stepIndex: stepIndex)  // wallpaper card arm
        case "options", "dock":
            cardStepView(step: step, stepIndex: stepIndex)
        case "processing" where step.processingDuration != nil:
            processingStepView(step: step, stepIndex: stepIndex)
        default:
            uncanonicalizedStepView(step: step, stepIndex: stepIndex)
        }
    }

    /// Presence-based dispatch, a fallback for steps that were not canonicalized.
    @ViewBuilder
    private func uncanonicalizedStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        if let installationMode = step.installationMode, !installationMode.isEmpty {
            installationStepView(step: step, stepIndex: stepIndex)
        } else if step.wallpaperCategories?.isEmpty == false {
            cardStepView(step: step, stepIndex: stepIndex)  // cardArm routes wallpaper payloads first
        } else if step.optionCards?.isEmpty == false
                    || (step.dockFlavors?.isEmpty == false) || (step.dockItems?.isEmpty == false) {
            cardStepView(step: step, stepIndex: stepIndex)  // cardArm routes by the same presence order
        } else {
            standardIntroStepView(step: step, stepIndex: stepIndex)
        }
    }

    /// Whether a step is an outro, by phase; an outro that renders a grid is still an outro.
    func isOutroStep(_ step: InspectConfig.IntroStep) -> Bool {
        step.resolvedPhase == "outro"
    }

    /// Whether Back is possible from a step.
    func canGoBack(fromStepIndex stepIndex: Int) -> Bool {
        stepIndex > 0
    }

    // MARK: - Installation Step View

    /// Renders an installation progress step.
    @ViewBuilder
    func installationStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let continueText = localized("continueButtonText", forStep: step, fallback: nil) ?? step.continueButtonText ?? ChromeCopy.continue

        let installationData: [InstallationItemData] = (step.items ?? []).map { item in
            let status = monitoringService.itemStatuses[item.id] ?? .pending
            let progress = monitoringService.progressValues[item.id]
            var message = monitoringService.statusMessages[item.id]

            // Add bundle info for completed items when configured.
            if status == .completed, let bundleInfo = inspectState.getBundleInfoForItem(item) {
                message = bundleInfo
            }

            return InstallationItemData(from: item, status: status, progress: progress, statusMessage: message,
                                        iconOverride: inspectState.itemIconOverrides[item.id])
        }

        // `cards` is an alias for the list layout, which is also the default.
        let layout: InstallationLayout =
            step.installationLayout?.lowercased() == "grid" ? .grid : .list

        // Rows added at runtime (`listitem: add`) are shown but not counted.
        let counted = installationData.filter { !inspectState.addedItemIDs.contains($0.id) }
        let allCompleted = !counted.isEmpty && counted.allSatisfy { $0.status == .completed }
        let anyFailed = counted.contains { if case .failed = $0.status { return true } else { return false } }

        // Card layout: header, rows stating `version · size`, and the sidecar.
        cardInstallationStepView(step: step, stepIndex: stepIndex,
                                 installationData: installationData, layout: layout,
                                 continueText: allCompleted && anyFailed ? ChromeCopy.continueAnyway : continueText)
            .onAppear { startInstallationMonitoring(for: step) }
            .onDisappear { stopInstallationMonitoring(for: step) }
            .onChange(of: allCompleted) {
                if allCompleted && (step.autoAdvanceOnComplete ?? false) {
                    writeLog("Preset5: All installation items completed, auto-advancing", logLevel: .info)
                    scheduleAutoAdvance(after: 1.0, from: step.id)
                }
            }
            .sourceTag()
    }

    /// Starts monitoring the installation step's items.
    func startInstallationMonitoring(for step: InspectConfig.IntroStep) {
        guard let items = step.items, !items.isEmpty else {
            writeLog("Preset5: No items to monitor for installation step", logLevel: .debug)
            DetectionLog.trace("monitoring NOT started: step '\(step.id)' has no items — every "
                               + "command addressed at a row on this screen will be unmatched")
            return
        }

        writeLog("Preset5: Starting installation monitoring for \(items.count) items", logLevel: .info)
        // Log the inventory once per run so later unmatched lines can be read against it.
        DetectionLog.trace("monitoring started: step '\(step.id)' chrome='\(config?.chrome ?? "-")' "
                           + "rows=\(items.count)")
        // Debug panel facts: pid and trigger file tell concurrent dialogs apart.
        InspectDebugMeter.shared.note(fact: "pid", "\(ProcessInfo.processInfo.processIdentifier)")
        // Which config file loaded; the debug panel shows it where `--debug` is not available.
        InspectDebugMeter.shared.note(fact: "config", inspectState.configPath ?? "(no file — inline or sample)")
        InspectDebugMeter.shared.note(fact: "trigger", triggerFilePath)
        InspectDebugMeter.shared.note(fact: "appearance",
                                      colorScheme == .dark ? "dark" : "light")
        InspectDebugMeter.shared.note(fact: "chrome", config?.chrome ?? "(default)")
        InspectDebugMeter.shared.note(fact: "preset", config?.preset ?? "-")
        InspectDebugMeter.shared.note(fact: "step", step.id)
        InspectDebugMeter.shared.note(fact: "rows", "\(items.count)")
        InspectDebugMeter.shared.note(fact: "rows with a path",
                                      "\(items.filter { !$0.paths.isEmpty }.count)")
        InspectDebugMeter.shared.note(fact: "row names",
                                      items.map(\.displayName).joined(separator: ", "))
        for item in items {
            DetectionLog.trace("  row \(item.id) | \(item.displayName) | "
                               + "paths=\(item.paths.count) "
                               + "requirements=\(item.requirements?.count ?? 0) "
                               + "aliases=\((item.logAliases ?? []).joined(separator: "/"))")
        }
        // The step id is the owner token: SwiftUI runs the next screen's `onAppear` before this one's
        // `onDisappear` (see `UnifiedMonitoringService.monitoringOwner`).
        monitoringService.startMonitoring(items: items, cachePaths: config?.cachePaths ?? [], cacheExtensions: config?.resolvedCacheExtensions,
                                          receiptsBasePath: config?.receiptsBasePath,
                                          receiptCensus: config?.receiptCensus ?? false,
                                          scanInterval: config?.scanInterval,
                                          owner: step.id)

        // Start log monitoring when configured at the top level.
        if let config = config {
            LogMonitorService.shared.setItems(items)
            LogMonitorService.shared.configure(with: config)
            writeLog("Preset5: Configured log monitoring", logLevel: .info)
        }
    }

    /// Stops only the monitoring this step started. The next screen's `onAppear` runs before this
    /// `onDisappear`, so the service checks ownership and the log monitor is gated on the same answer.
    func stopInstallationMonitoring(for step: InspectConfig.IntroStep) {
        guard monitoringService.stopMonitoring(owner: step.id) else {
            writeLog("Preset5: Step '\(step.id)' left, but a later screen owns the monitoring — leaving it running",
                     logLevel: .debug)
            return
        }
        LogMonitorService.shared.stop()
        writeLog("Preset5: Stopped installation monitoring for step '\(step.id)'", logLevel: .debug)
    }

    // MARK: - Deployment Step

    /// The deployment step on the card layout: overall bar, one status-ordered list (completed, active,
    /// pending), and the stats sidecar. Rows are the shared InstallRowsList; live probes own every state.
    /// Continue is disabled until every item has an outcome (autoEnableButton, default true);
    /// also supports autoAdvanceOnComplete and sideMessages.
    @ViewBuilder
    func deploymentStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let installationData: [InstallationItemData] = (step.items ?? []).map { item in
            let status = monitoringService.itemStatuses[item.id] ?? .pending
            let progress = monitoringService.progressValues[item.id]
            var message = monitoringService.statusMessages[item.id]

            if status == .completed, let bundleInfo = inspectState.getBundleInfoForItem(item) {
                message = bundleInfo
            }

            return InstallationItemData(from: item, status: status, progress: progress, statusMessage: message,
                                        iconOverride: inspectState.itemIconOverrides[item.id])
        }

        // Rows added at runtime (`listitem: add`) are shown but not counted.
        let counted = installationData.filter { !inspectState.addedItemIDs.contains($0.id) }
        let allCompleted = !counted.isEmpty && counted.allSatisfy { $0.status == .completed }
        // Continue needs an outcome per row, not success ("Continue Anyway"); auto-advance needs all completed.
        let allFinished = !counted.isEmpty && counted.allSatisfy { $0.status.isFinished }
        let anyFailed = counted.contains { if case .failed = $0.status { return true } else { return false } }
        let autoEnable = step.autoEnableButton ?? true
        let sortedItems = deploymentSortedItems(installationData)
        // Count what completion counts; extra rows are drawn but not summed.
        let summary = InstallMath.summarize(counted)
        let activeName = installationData.first { $0.status == .active }?.displayName
        let sidecar = installSidecarPanel(step: step, summary: summary,
                                          nowInstalling: activeName)

        let continueText: String = {
            if allFinished {
                return anyFailed ? ChromeCopy.continueAnyway : (step.autoEnableButtonText ?? ChromeCopy.done)
            }
            return localized("continueButtonText", forStep: step, fallback: nil) ?? step.continueButtonText ?? ChromeCopy.continue
        }()

        CardStepShell(
            eyebrow: cardChromeTitle,
            eyebrowIcon: config?.icon,
            stepLabel: cardStepLabel(stepIndex),
            title: localized("title", forStep: step, fallback: step.title) ?? "",
            subtitle: localized("subtitle", forStep: step, fallback: step.subtitle),
            accent: branding.primaryColor,
            // The default back gate (`canGoBack && showBackButton`); `onBack` is withheld when it is shut.
            footer: cardFooter(for: step, index: stepIndex,
                               continueText: continueText,
                               continueDisabled: autoEnable && !allFinished) {
                // If the button is enabled early, confirmIncomplete guards rows still waiting.
                continueOrConfirm(step: step,
                                  remaining: counted.filter { !$0.status.isFinished }.count)
            }
        ) {
            HStack(alignment: .top, spacing: 26) {
                VStack(alignment: .leading, spacing: 16) {
                    InstallOverallBar(summary: summary, accent: branding.primaryColor)
                    ScrollView(.vertical) {
                        InstallRowsList(items: sortedItems, accent: branding.primaryColor)
                    }
                    if let messages = step.sideMessages, !messages.isEmpty {
                        DeploymentSideMessageView(
                            messages: messages,
                            interval: step.sideMessageInterval ?? 8
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let sidecar {
                    CardPanelView(panel: sidecar, accent: branding.primaryColor)
                        .frame(width: 222)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { confirmIncompleteStepId == step.id },
            set: { if !$0 { confirmIncompleteStepId = nil } }
        )) {
            confirmIncompleteSheet(step: step,
                                   remaining: summary.total - summary.completed,
                                   total: summary.total)
        }
        .onAppear {
            startInstallationMonitoring(for: step)
        }
        .onDisappear {
            stopInstallationMonitoring(for: step)
        }
        .onChange(of: allCompleted) {
            if allCompleted && (step.autoAdvanceOnComplete ?? false) {
                writeLog("Preset5: All deployment items completed, auto-advancing", logLevel: .info)
                scheduleAutoAdvance(after: 1.0, from: step.id)
            }
        }
        // Do not use `.id()` here: recreating the view fires onDisappear and stops this step's monitoring.
        // The owner token does not prevent that, since the same step still owns the session.
        .sourceTag()
    }
}

extension Preset5View {
    /// The installation step on the card layout, as a list or 2-up grid of rows stating `version · size`.
    /// The sidecar combines Time left / Downloaded estimates (InstallMath) with the step's `cardPanel` pairs;
    /// live probes own the real state.
    @ViewBuilder
    func cardInstallationStepView(step: InspectConfig.IntroStep, stepIndex: Int,
                                  installationData: [InstallationItemData],
                                  layout: InstallationLayout,
                                  continueText: String) -> some View {
        let counted = installationData.filter { !inspectState.addedItemIDs.contains($0.id) }
        let summary = InstallMath.summarize(counted)
        let sidecar = installSidecarPanel(step: step, summary: summary)
        // `continueWhileRunning`, as on the cadence step. Running = a counted row still installing or waiting
        // (the rows "n of m installed" counts), so a failed install still releases Continue.
        let running = counted.contains { $0.status == .active || $0.status == .pending }
        let continueVisibility = CadenceContinueVisibility.resolve(step.continueWhileRunning, running: running)
        CardStepShell(
            eyebrow: cardChromeTitle,
            eyebrowIcon: config?.icon,
            stepLabel: cardStepLabel(stepIndex),
            title: localized("title", forStep: step, fallback: step.title) ?? "",
            subtitle: localized("subtitle", forStep: step,
                                fallback: step.subtitle ?? step.processingMessage),
            accent: branding.primaryColor,
            footer: {
                var footer = cardFooter(for: step, index: stepIndex, continueText: continueText,
                                        continueDisabled: continueVisibility == .disabled) {
                    continueOrConfirm(step: step,
                                      remaining: summary.total - summary.completed)
                }
                footer.primaryHidden = continueVisibility == .hidden
                return footer
            }()
        ) {
            HStack(alignment: .top, spacing: 26) {
                VStack(alignment: .leading, spacing: 16) {
                    InstallOverallBar(summary: summary, accent: branding.primaryColor)
                    // The list scrolls to the installing row (else the next waiting one) each time it changes.
                    let focus = InstallMath.focusRow(installationData)
                    ScrollViewReader { proxy in
                        ScrollView(.vertical) {
                            if layout == .grid {
                                InstallTilesGrid(items: installationData,
                                                 accent: branding.primaryColor)
                            } else {
                                InstallRowsList(items: installationData,
                                                accent: branding.primaryColor)
                            }
                        }
                        .onAppear { if let focus { proxy.scrollTo(focus, anchor: .center) } }
                        .onChange(of: focus) {
                            guard let focus else { return }
                            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                                proxy.scrollTo(focus, anchor: .center)
                            } else {
                                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(focus, anchor: .center) }
                            }
                        }
                    }
                    // As on the classic installation step: the step's rotating lines under the rows.
                    if let messages = step.sideMessages, !messages.isEmpty {
                        DeploymentSideMessageView(
                            messages: messages,
                            interval: step.sideMessageInterval ?? 8
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let sidecar {
                    CardPanelView(panel: sidecar, accent: branding.primaryColor)
                        .frame(width: 222)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { confirmIncompleteStepId == step.id },
            set: { if !$0 { confirmIncompleteStepId = nil } })) {
            confirmIncompleteSheet(step: step,
                                   remaining: summary.total - summary.completed,
                                   total: summary.total)
        }
    }

    /// The sidecar as a CardPanel: computed rows (Time left when any row has a `timeEstimate`,
    /// Downloaded when sizes parse), then the authored `cardPanel`. nil when both are empty.
    func installSidecarPanel(step: InspectConfig.IntroStep,
                             summary: InstallMath.Summary,
                             nowInstalling: String? = nil) -> InspectConfig.CardPanel? {
        let authored = step.cardPanel
        var pairs: [InspectConfig.CardPanelPair] = []
        if summary.totalMB > 0 {
            pairs.append(InspectConfig.CardPanelPair(
                label: "Downloaded",
                value: "\(Int(summary.downloadedMB.rounded())) of \(Int(summary.totalMB.rounded())) MB"))
        }
        if let nowInstalling {
            pairs.append(InspectConfig.CardPanelPair(
                label: localized("ui.nowInstalling", forStep: step,
                                 fallback: "Now installing") ?? "Now installing",
                value: nowInstalling))
        }
        pairs.append(contentsOf: authored?.pairs ?? [])
        let caption = summary.secondsLeft != nil ? "Time left" : authored?.caption
        let stat = summary.secondsLeft.map(InstallMath.friendlyTime) ?? authored?.stat
        if caption == nil && stat == nil && pairs.isEmpty { return nil }
        return InspectConfig.CardPanel(
            caption: caption, stat: stat, pairs: pairs.isEmpty ? nil : pairs,
            image: nil, video: nil, imageTitle: nil, paragraphs: nil, layout: nil)
    }
}
