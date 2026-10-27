//
//  Preset5+Provisioning.swift
//  dialog
//
//  Preset 5 step views on the provisioning shell (cadence, carousel, options, review, dock,
//  brand picker, closer, media). Geometry lives in ProvisioningShell and the row components;
//  this file only builds the models they render.
//

import SwiftUI

extension Preset5View {

    /// The viewport the shell measures against: the resolved window size, not a GeometryReader,
    /// because the shell pins absolute bands against the window and not the content height.
    var provisioningMetrics: ProvisioningM {
        let resolved = InspectSizes.windowSize(
            width: config?.width, height: config?.height,
            preset: "preset5", mode: nil, itemCount: 0,
            chrome: config?.chrome)
        return ProvisioningM(size: resolved.size)
    }

    /// Tiles when the step asks for them and the column can carry them; a column too narrow logs
    /// once and draws rows instead.
    func wantsTiles(_ step: InspectConfig.IntroStep, metrics: ProvisioningM) -> Bool {
        guard step.optionLayout?.lowercased() == "cards" else { return false }
        let tileCount = (step.optionCards?.count ?? 0) + (step.dockFlavors?.count ?? 0)
            + (step.dockDecline != nil ? 1 : 0)
        guard tileCount <= ProvisioningM.maxTiles else { return false }
        guard metrics.fitsTileGrid else {
            Self.warnOnceAboutNarrowTileColumn(step, column: metrics.column)
            return false
        }
        return true
    }

    private static var warnedNarrowTileStepIds = Set<String>()

    static func warnOnceAboutNarrowTileColumn(_ step: InspectConfig.IntroStep, column: CGFloat) {
        guard !warnedNarrowTileStepIds.contains(step.id) else { return }
        warnedNarrowTileStepIds.insert(step.id)
        writeLog("provisioning: optionLayout 'cards' on '\(step.id)' needs a "
                 + "\(Int(ProvisioningM.tileGridWidth(3)))pt column and this construction gives "
                 + "\(Int(column)) — drawing the row list instead. Rows at 500, tiles at 740: the "
                 + "column decides, so a narrow shell renders rows rather than a cramped grid.",
                 logLevel: .info)
    }

    /// The customer + vendor lockup when `logoConfig.lockup` is "both"; nil draws the vendor mark
    /// alone. The customer is the selected brand, else the first, as the brand picker writes it.
    var provisioningLockup: (name: String, mark: ProvisioningIdentity)? {
        guard config?.logoConfig?.lockup?.lowercased() == "both" else { return nil }
        let brands = config?.brands ?? []
        guard let brand = brands.first(where: { $0.id == selectedBrandId }) ?? brands.first
        else { return nil }
        return (brand.displayName,
                ProvisioningRowBuilder.identity(for: brand, scheme: colorScheme,
                                                ceiling: ProvisioningM.lockupRatioCeiling))
    }

    // swiftlint:disable function_parameter_count
    /// One provisioning screen for every arm: the shell with the flow-wide chrome (eyebrow, back,
    /// wordmark, lockup) absorbed. `title` and `lede` are required because a nil lede means
    /// "no lede", not "use a default".
    func provisioningScreen<Content: View>(
        for step: InspectConfig.IntroStep,
        index: Int,
        title: String,
        lede: String?,
        primaryTitle: String,
        primaryDisabled: Bool = false,
        primaryHidden: Bool = false,
        showStepCounter: Bool = true,
        secondaryStyle: ProvisioningShell<Content>.SecondaryStyle = .text,
        accent: Color? = nil,
        /// A footer progress bar replaces the action run; no screen carries both it and the counter.
        footerProgress: Double? = nil,
        /// The footer's centre line, always authored: nil reads the step's `footerNote`, then the
        /// flow's `footerText`; this shell has no default claim.
        stateLine: String? = nil,
        onPrimary: (() -> Void)? = nil,
        primaryPopoverShown: Binding<Bool>? = nil,
        primaryPopover: AnyView? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        // swiftlint:enable function_parameter_count
        let tint = accent ?? branding.primaryColor
        let metrics = provisioningMetrics
        let canBack = canGoBack(fromStepIndex: index) && (step.showBackButton ?? true)
        return ProvisioningShell(
            metrics: metrics,
            eyebrow: provisioningEyebrow(stepTitle: title),
            stepCounter: showStepCounter && allSteps.count > 1 ? cardStepLabel(index) : nil,
            title: title,
            lede: lede,
            primaryTitle: primaryTitle,
            primaryDisabled: primaryDisabled,
            primaryHidden: primaryHidden,
            onPrimary: onPrimary ?? { goToNextStep() },
            primaryPopoverShown: primaryPopoverShown,
            primaryPopover: primaryPopover,
            secondaryTitle: canBack
                ? BackDoor.label(localized: localized("backButtonText", forStep: step, fallback: nil),
                                 step: step.backButtonText, branding: branding.button2Text)
                : nil,
            onSecondary: { goToPreviousStep() },
            secondaryStyle: ProvisioningShell<Content>.SecondaryStyle(authored: step.backButtonKind) ?? secondaryStyle,
            accent: tint,
            wordmarkPath: cardFooterLogoPath,
            customerName: provisioningLockup?.name,
            customerMark: provisioningLockup?.mark,
            attribution: provisioningLockup == nil ? nil
                : (localizedUI("ui.managedWith", fallback: "Managed with")),
            logoHeight: CGFloat(config?.logoConfig?.maxHeight ?? Double(ProvisioningM.wordmarkHeight)),
            logoClearSpace: config?.logoConfig?.clearSpace ?? 0,
            footerProgress: footerProgress,
            stateLine: stateLine ?? localized("footerNote", forStep: step, fallback: step.footerNote)
                ?? footerClaim,
            content: content
        )
    }

    /// The flow's name as the eyebrow; withheld when it merely repeats the step title.
    func provisioningEyebrow(stepTitle: String) -> String? {
        guard let flow = config?.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              flow.isEmpty == false,
              flow.compare(stepTitle, options: .caseInsensitive) != .orderedSame else { return nil }
        return flow.uppercased()
    }

    // MARK: - The cadence arm

    /// Whether this step still holds its door (items not yet terminal, or `holdPrimary` in
    /// division mode). The router defers a `quit:` while this is true.
    func journeyHoldsItsDoor(step: InspectConfig.IntroStep) -> Bool {
        let items: [any MonitoredItem] = step.items ?? []
        guard !items.isEmpty else { return false }
        let statuses = items.map { monitoringService.itemStatuses[$0.id] ?? .pending }
        let vocabulary = ProvisioningVocabulary.packages.merged(with: step.stateWords)
        let rows = ProvisioningRowBuilder.itemRows(items: items, statuses: statuses,
                                                   removedIds: Set(monitoringService.removedItems.keys),
                                                   vocabulary: vocabulary)
        if let division = JourneyDivision.resolve(step: step, rows: rows, vocabulary: vocabulary) {
            return division.primaryDisabled || division.primaryHidden
        }
        return !rows.allSatisfy(JourneyScroll.isTerminal)
    }

    @ViewBuilder
    func provisioningCadenceStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let metrics = provisioningMetrics
        let run = CadenceProgress(monitor: cadenceMonitor, step: step, entries: derivedCadenceEntries(for: step),
                                  include: { cadenceEntryIsShown($0, in: step) },
                                  adjust: { cadenceEntryArtwork($0, in: step) })
        let accent = cadenceBrandColor(step: step) ?? branding.primaryColor
        let halted = cadenceMonitor.haltedIndex

        let runningTitle = localized("title", forStep: step, fallback: step.title) ?? ""
        // Absent completed/failed copy keeps the running copy.
        let title: String = {
            if halted != nil {
                return localized("failedTitle", forStep: step, fallback: step.failedTitle) ?? runningTitle
            }
            return CadenceCopy.resolvedTitle(
                isComplete: run.isComplete, title: runningTitle,
                completedTitle: localized("completedTitle", forStep: step, fallback: step.completedTitle))
        }()
        let lede: String? = {
            if halted != nil {
                return localized("failureMessage", forStep: step, fallback: step.failureMessage)
                    ?? localizedCadenceMessage(step: step)
            }
            return CadenceCopy.resolvedClaim(
                isComplete: run.isComplete,
                runningClaim: localizedCadenceMessage(step: step) ?? "",
                completedMessage: localized("completedMessage", forStep: step, fallback: step.completedMessage))
        }()

        let running = !run.isComplete && halted == nil
        let stayMaxHoldExceeded = run.heldByStay
            && (run.current?.stayMaxHold).map { run.heldElapsedSeconds >= $0 } ?? false
        let continueVisibility: CadenceContinueVisibility = stayMaxHoldExceeded
            ? .live
            : CadenceContinueVisibility.resolve(step.continueWhileRunning, running: running)

        provisioningScreen(
            for: step, index: stepIndex,
            title: title,
            lede: lede,
            primaryTitle: halted != nil
                ? (localized("retryButtonText", forStep: step, fallback: nil) ?? "Retry")
                : (localized("continueButtonText", forStep: step, fallback: step.continueButtonText) ?? ChromeCopy.continue),
            primaryDisabled: continueVisibility == .disabled,
            // The one arm tinted from the cadence brand rather than the global accent.
            accent: accent,
            onPrimary: { continueOrConfirm(step: step, remaining: run.pending) },
            primaryPopoverShown: Binding(
                get: { confirmIncompleteStepId == step.id },
                set: { if !$0 { confirmIncompleteStepId = nil } }),
            primaryPopover: AnyView(confirmIncompleteSheet(step: step, remaining: run.pending,
                                                           total: run.total))
        ) {
            if step.cadenceStyle?.lowercased() == "bento" {
                CadenceBentoBoard(run: run, haltedIndex: halted, accent: accent,
                                  size: CGSize(width: metrics.column,
                                               height: metrics.bodyBottom - ProvisioningM.listTop))
                    .offset(x: ProvisioningM.rail, y: ProvisioningM.listTop)
            } else {
                // Manifest (the default for an absent or unknown word) or spotlight card on the
                // minimal sheet; how many rows it names comes from the height it is handed.
                let minimalCard = CadenceMinimalKind.forStep(authored: step.cadenceStyle)
                let sheetHeight = metrics.bodyBottom - ProvisioningM.listTop
                let fit = CadenceMinimalFit.resolve(height: sheetHeight, kind: minimalCard)
                CadenceMinimalSheet(run: run, accent: accent,
                                    size: CGSize(width: metrics.column, height: sheetHeight),
                                    machineImage: fit.machineImage) {
                    switch minimalCard {
                    case .manifest:
                        CadenceManifestCard(run: run, haltedIndex: halted, accent: accent, queued: fit.rows)
                    case .spotlight:
                        CadenceSpotlightCard(run: run, haltedIndex: halted, accent: accent, named: fit.rows)
                    }
                }
                .offset(x: ProvisioningM.rail, y: ProvisioningM.listTop)
            }
        }
        // The cadence monitor's only entry point; without it the screen never advances.
        .onAppear { startCadenceStep(step: step) }
    }
}

extension Preset5View {

    // MARK: - The carousel arm

    /// Package items as provisioning rows, with the status band beneath.
    @ViewBuilder
    func provisioningCarouselStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let metrics = provisioningMetrics
        let accent = branding.primaryColor
        let items: [any MonitoredItem] = step.items ?? []
        // Statuses and removals come from the monitoring service: the config-level item detection
        // never sees a step-authored manifest.
        let statuses = items.map { monitoringService.itemStatuses[$0.id] ?? .pending }
        let vocabulary = ProvisioningVocabulary.packages.merged(with: step.stateWords)
        let rows = ProvisioningRowBuilder.itemRows(items: items, statuses: statuses,
                                                   removedIds: Set(monitoringService.removedItems.keys),
                                                   vocabulary: vocabulary)
        let band = ProvisioningRowBuilder.itemBand(items: items, statuses: statuses,
                                                    vocabulary: vocabulary)
        let division = JourneyDivision.resolve(step: step, rows: rows, vocabulary: vocabulary)
        let title = localized("title", forStep: step, fallback: step.title) ?? ""

        provisioningScreen(
            for: step, index: stepIndex,
            title: title,
            lede: localized("subtitle", forStep: step, fallback: step.subtitle),
            primaryTitle: localized("continueButtonText", forStep: step,
                                    fallback: step.continueButtonText) ?? ChromeCopy.continue,
            primaryDisabled: division?.primaryDisabled ?? false,
            primaryHidden: division?.primaryHidden ?? false,
            onPrimary: { goToNextStep() }
        ) {
            if division != nil || JourneyLayout.isGrid(step.layout) {
                // A bare grid carries no offset of its own, so the body slot pins it below the
                // title; the capsule must end above the status band.
                MigrationBodySlot(metrics: metrics) {
                    JourneyCardGrid(rows: division?.cardRows ?? rows, accent: accent,
                                    width: metrics.column - JourneyGridM.capsulePadH * 2,
                                    maxHeight: metrics.listRegionHeight - JourneyGridM.capsulePadV * 2,
                                    total: division?.total,
                                    columns: step.gridColumns ?? JourneyGridM.columns,
                                    progress: step.gridProgress == true && !rows.isEmpty
                                        ? Double((division?.completed ?? rows.filter(JourneyScroll.isTerminal).count))
                                          / Double(division?.total ?? rows.count) : nil)
                        .padding(.vertical, JourneyGridM.capsulePadV)
                        .padding(.horizontal, JourneyGridM.capsulePadH)
                        .background(
                            RoundedRectangle(cornerRadius: JourneyGridM.capsuleRadius, style: .continuous)
                                .fill(palette.text.opacity(JourneyGridM.capsuleFillOpacity))
                        )
                }
            } else {
                ProvisioningRowList(rows: rows, metrics: metrics, accent: accent)
            }
            ProvisioningStatusBand(content: band, metrics: metrics, accent: accent)
        }
        // The monitoring service does not start itself.
        .onAppear { startInstallationMonitoring(for: step) }
        .onDisappear { stopInstallationMonitoring(for: step) }
    }

    // MARK: - The options arm

    /// A single-select choice screen; a preview is drawn only where a card authors one.
    @ViewBuilder
    func provisioningOptionsStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let metrics = provisioningMetrics
        let accent = branding.primaryColor
        // Canonicalization folds the nested option payload into `optionCards`; read only that.
        let cards = step.optionCards ?? []
        let key = step.optionKey ?? step.id
        // The selection store is `userValues`, the one everything downstream reads. A restored
        // answer wins, then the recommended card, then nothing.
        let selected = ProvisioningRowBuilder.selectedOption(
            cards: cards, restored: inspectState.userValues[key])
        let rows = ProvisioningRowBuilder.optionRows(cards: cards, selectedId: selected)
        let title = localized("title", forStep: step, fallback: step.title) ?? ""
        let preview = cards.first(where: { $0.cardId == selected })?.preview

        provisioningScreen(
            for: step, index: stepIndex,
            title: title,
            lede: localized("subtitle", forStep: step, fallback: step.subtitle),
            primaryTitle: localized("continueButtonText", forStep: step,
                                    fallback: step.continueButtonText) ?? ChromeCopy.continue,
            primaryDisabled: selected == nil,
            onPrimary: { goToNextStep() }
        ) {
            if wantsTiles(step, metrics: metrics) {
                ProvisioningTileGrid(
                    tiles: ProvisioningRowBuilder.optionTiles(cards: cards, selectedId: selected),
                    metrics: metrics, accent: accent,
                    onSelect: { commitOptionSelection(key: key, value: $0) })
            } else if let preview, preview.hasPrefix(GradientSwatch.prefix) {
                ProvisioningPreviewList(
                    rows: rows, previewPath: nil,
                    caption: localizedUI("ui.previewUpdates", fallback: "Preview updates as you choose."),
                    metrics: metrics, accent: accent,
                    onSelect: { commitOptionSelection(key: key, value: $0) })
                    .overlay(alignment: .topLeading) {
                        GradientSwatch(reference: preview)
                            .frame(width: ProvisioningM.previewWidth, height: ProvisioningM.previewHeight)
                            .clipShape(RoundedRectangle(cornerRadius: ProvisioningM.previewRadius))
                            .offset(x: ProvisioningM.rail, y: ProvisioningM.listTop)
                    }
            } else if let preview, AppearanceSwatch.known.contains(preview) {
                ProvisioningPreviewList(
                    rows: rows, previewPath: nil,
                    caption: localizedUI("ui.previewUpdates", fallback: "Preview updates as you choose."),
                    metrics: metrics, accent: accent,
                    onSelect: { commitOptionSelection(key: key, value: $0) })
                    .overlay(alignment: .topLeading) {
                        AppearanceSwatch(kind: preview)
                            .frame(width: ProvisioningM.previewWidth, height: ProvisioningM.previewHeight)
                            .clipShape(RoundedRectangle(cornerRadius: ProvisioningM.previewRadius))
                            .offset(x: ProvisioningM.rail, y: ProvisioningM.listTop)
                    }
            } else {
                ProvisioningRowList(rows: rows, metrics: metrics, accent: accent,
                                    onSelect: { commitOptionSelection(key: key, value: $0) })
            }
            ProvisioningStatusBand(
                content: ProvisioningRowBuilder.optionBand(cards: cards, selectedId: selected),
                metrics: metrics, accent: accent)
        }
        // A pre-selected recommendation is recorded on appear: accepting it never taps a row, and
        // an unrecorded answer never reaches the receipt or the orchestrator.
        .onAppear {
            guard (inspectState.userValues[key] ?? "").isEmpty, let selected else { return }
            commitOptionSelection(key: key, value: selected)
        }
    }

    /// Multi-select choice. Stored in `userValues[key]` as the picked values in card order,
    /// comma-joined, with the resolved plan beside it under `OptionPlan.runKey`, so every reader
    /// of a single pick reads a multi-pick the same way. Continue waits for at least one pick.
    @ViewBuilder
    func provisioningMultiOptionsStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let metrics = provisioningMetrics
        let accent = branding.primaryColor
        let cards = step.optionCards ?? []
        let key = step.optionKey ?? step.id
        let restored = inspectState.userValues[key]
        let selected: Set<String> = restored.map {
            Set($0.split(separator: ",").map(String.init))
        } ?? Set(cards.filter { $0.recommended == true && $0.state?.lowercased() != "unavailable" }
                    .map { $0.value ?? $0.cardId })
        let plan = OptionPlan.resolve(cards: cards, picked: selected)
        let title = localized("title", forStep: step, fallback: step.title) ?? ""

        provisioningScreen(
            for: step, index: stepIndex,
            title: title,
            lede: localized("subtitle", forStep: step, fallback: step.subtitle),
            primaryTitle: localized("continueButtonText", forStep: step,
                                    fallback: step.continueButtonText) ?? ChromeCopy.continue,
            primaryDisabled: plan.run.isEmpty,
            onPrimary: { goToNextStep() }
        ) {
            ProvisioningSectionedList(
                sections: ProvisioningRowBuilder.multiOptionSections(
                    cards: cards, picked: selected, switches: step.optionControl?.lowercased() == "switch"),
                metrics: metrics, accent: accent,
                onSelect: { value in
                    var next = selected
                    if next.contains(value) { next.remove(value) } else { next.insert(value) }
                    commitMultiOptionSelection(key: key, cards: cards, selected: next)
                })
            ProvisioningStatusBand(
                content: ProvisioningRowBuilder.multiOptionBand(count: selected.count, total: cards.count,
                                                                runs: plan.run.count),
                metrics: metrics, accent: accent)
        }
        // Recommended picks are an answer, recorded on appear as on the single-select arm.
        .onAppear {
            guard restored == nil, !selected.isEmpty else { return }
            commitMultiOptionSelection(key: key, cards: cards, selected: selected)
        }
    }

    func commitMultiOptionSelection(key: String, cards: [InspectConfig.OptionCard], selected: Set<String>) {
        let value = ProvisioningRowBuilder.multiOptionValue(cards: cards, selected: selected)
        inspectState.userValues[key] = value
        storeOptionPlan(key: key, cards: cards, picked: selected)
        inspectState.writeToInteractionLog("select:\(key):\(value)")
        DialogNotifications.postSelection(key: key, values: value.split(separator: ",").map(String.init))
    }

    /// The resolved plan, stored beside the picks; the progress and review steps read it.
    func storeOptionPlan(key: String, cards: [InspectConfig.OptionCard], picked: Set<String>) {
        inspectState.userValues[OptionPlan.runKey(key)] =
            OptionPlan.resolve(cards: cards, picked: picked).run.joined(separator: ",")
    }

    /// The cards of the multi-select step that owns `key`, if one does.
    func multiOptionCards(forKey key: String) -> [InspectConfig.OptionCard]? {
        allSteps.first { $0.stepType == "options" && $0.optionMultiSelect == true
            && ($0.optionKey ?? $0.id) == key }?.optionCards
    }

    // MARK: - The review

    /// The multi-select plan as rows before it runs: what runs, then what was picked but will not.
    /// When the plan holds an option with `exposure`, an acknowledgement row closes the list and
    /// Continue waits for it.
    @ViewBuilder
    func provisioningReviewStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let metrics = provisioningMetrics
        let accent = branding.primaryColor
        let key = OptionPlan.followedKey(explicit: step.reviewSelectionKey, in: allSteps) ?? ""
        let cards = multiOptionCards(forKey: key) ?? []
        let picked = Set((inspectState.userValues[key] ?? "").split(separator: ",").map(String.init))
        let plan = OptionPlan.resolve(cards: cards, picked: picked)
        let ackKey = OptionPlan.acknowledgedKey(key)
        let needsAck = step.reviewAcknowledge != nil && cards.contains {
            plan.run.contains($0.value ?? $0.cardId) && $0.exposure?.isEmpty == false
        }
        let acknowledged = inspectState.userValues[ackKey] == "yes"
        let rows = ProvisioningRowBuilder.reviewRows(cards: cards, picked: picked, plan: plan)
            + (needsAck ? [ProvisioningRowModel(
                id: ackKey, name: step.reviewAcknowledge?.label ?? "",
                detail: step.reviewAcknowledge?.subtitle, detailIsMachine: false,
                mark: .check(selected: acknowledged), trailing: .state("Required", failed: true))] : [])
        let skipped = picked.subtracting(plan.run).count

        provisioningScreen(
            for: step, index: stepIndex,
            title: localized("title", forStep: step, fallback: step.title) ?? "",
            lede: localized("subtitle", forStep: step, fallback: step.subtitle),
            primaryTitle: localized("continueButtonText", forStep: step,
                                    fallback: step.continueButtonText) ?? "Run",
            primaryDisabled: plan.run.isEmpty || (needsAck && !acknowledged),
            onPrimary: { goToNextStep() }
        ) {
            ProvisioningRowList(rows: rows, metrics: metrics, accent: accent, onSelect: { id in
                guard id == ackKey else { return }
                inspectState.userValues[ackKey] = acknowledged ? nil : "yes"
            })
            ProvisioningStatusBand(
                content: .consequence(
                    text: skipped == 0 ? "\(plan.run.count) will run"
                                       : "\(plan.run.count) will run · \(skipped) skipped",
                    detail: nil, swatch: nil),
                metrics: metrics, accent: accent)
        }
    }

    /// A Dock answer goes to `dockSelection`, not `userValues`, in the shape the Dock picker
    /// writes: a flavour's item paths filtered by existence and comma-joined, or the decline value.
    func commitDockSelection(key: String, flavorId: String,
                             flavors: [InspectConfig.DockFlavor],
                             decline: InspectConfig.DeclineOption?) {
        if let decline, (decline.value ?? "decline") == flavorId {
            let value = decline.value ?? "none"
            inspectState.dockSelection[key] = value
            inspectState.writeToInteractionLog("select:\(key):\(value)")
            DialogNotifications.postSelection(key: key, values: [value], flavorId: value)
            return
        }
        guard let flavor = flavors.first(where: { $0.flavorId == flavorId }) else { return }
        let paths = flavor.items.map(\.path)
            .filter { FileManager.default.fileExists(atPath: ($0 as NSString).expandingTildeInPath) }
        let joined = paths.joined(separator: ",")
        inspectState.dockSelection[key] = joined
        inspectState.writeToInteractionLog("select:\(key):\(joined)")
        DialogNotifications.postSelection(key: key, values: paths, flavorId: flavor.flavorId)
    }

    /// The same three writes the card option picker makes, so downstream cannot tell the shells apart.
    func commitOptionSelection(key: String, value: String) {
        guard SelectionEmission.shouldEmit(newValue: value,
                                           recorded: inspectState.userValues[key],
                                           trigger: .committed) else { return }
        inspectState.userValues[key] = value
        inspectState.writeToInteractionLog("select:\(key):\(value)")
        DialogNotifications.postSelection(key: key, values: [value])
    }

    // MARK: - The closer

    /// The ending on the shell, with the `ChoiceReceipt` (one row per decision, each with Change).
    @ViewBuilder
    func provisioningOutroStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let metrics = provisioningMetrics
        let accent = branding.primaryColor
        let title = localized("title", forStep: step, fallback: step.title) ?? ""
        let rows: [ChoiceReceiptRow] = (step.receipt ?? []).compactMap { row in
            // A choice with no answer is omitted; a blank row would imply a decision never made.
            guard let value = receiptValue(for: row) else { return nil }
            return ChoiceReceiptRow(
                stepId: row.stepId,
                label: localized("receipt.\(row.stepId).label", forStep: step, fallback: row.label) ?? row.label,
                value: value)
        }

        provisioningScreen(
            for: step, index: stepIndex,
            title: title,
            lede: localized("subtitle", forStep: step, fallback: step.subtitle),
            primaryTitle: localized("continueButtonText", forStep: step,
                                    fallback: step.continueButtonText)
                ?? localizedUI("finish", fallback: "Finish"),
            primaryDisabled: false,
            secondaryStyle: .chevron,
            onPrimary: { goToNextStep() }
        ) {
            if !rows.isEmpty {
                ChoiceReceipt(
                    rows: rows, accent: accent, scaleFactor: 1.0,
                    changeLabel: localizedUI("receiptChange", fallback: "Change"),
                    onChange: { navigateToStep(stepId: $0) })
                    .frame(width: metrics.column, alignment: .leading)
                    .offset(x: ProvisioningM.rail, y: ProvisioningM.listTop)
            }
        }
    }

    // MARK: - The dock arm

    /// A Dock choice; each row's detail is the flavour's app names.
    @ViewBuilder
    func provisioningDockStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let metrics = provisioningMetrics
        let accent = branding.primaryColor
        // The Dock's own key, never `optionKey`.
        let key = step.dockSelectionKey ?? step.id
        let flavors = step.dockFlavors ?? []
        let selectedDock = ProvisioningRowBuilder.selectedDock(
            flavors: flavors, decline: step.dockDecline,
            restored: inspectState.dockSelection[key])
        let rows = ProvisioningRowBuilder.dockRows(
            flavors: flavors, decline: step.dockDecline, selectedId: selectedDock)
        let title = localized("title", forStep: step, fallback: step.title) ?? ""
        let chosen = rows.first(where: { if case .choice(let sel) = $0.mark { return sel } else { return false } })

        provisioningScreen(
            for: step, index: stepIndex,
            title: title,
            lede: localized("subtitle", forStep: step, fallback: step.subtitle),
            primaryTitle: localized("continueButtonText", forStep: step,
                                    fallback: step.continueButtonText) ?? ChromeCopy.continue,
            primaryDisabled: chosen == nil,
            onPrimary: { goToNextStep() }
        ) {
            if wantsTiles(step, metrics: metrics) {
                ProvisioningTileGrid(
                    tiles: ProvisioningRowBuilder.dockTiles(
                        flavors: flavors, decline: step.dockDecline, selectedId: selectedDock),
                    metrics: metrics, accent: accent,
                    onSelect: { commitDockSelection(key: key, flavorId: $0, flavors: flavors,
                                                    decline: step.dockDecline) })
            } else {
                ProvisioningRowList(rows: rows, metrics: metrics, accent: accent,
                                    onSelect: { commitDockSelection(key: key, flavorId: $0, flavors: flavors,
                                                                    decline: step.dockDecline) })
            }
            ProvisioningStatusBand(
                content: .consequence(text: chosen?.detail ?? "Nothing selected",
                                      detail: nil, swatch: nil),
                metrics: metrics, accent: accent)
        }
        // A pre-selection is recorded on appear, as on the options arm.
        .onAppear {
            guard (inspectState.dockSelection[key] ?? "").isEmpty, let selectedDock else { return }
            commitDockSelection(key: key, flavorId: selectedDock, flavors: flavors,
                                decline: step.dockDecline)
        }
    }

    // MARK: - The brandPicker arm

    /// Brand choice as rows; the first brand is pre-selected so Continue is never dead.
    @ViewBuilder
    func provisioningBrandPickerStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let metrics = provisioningMetrics
        let brands = config?.brands ?? []
        let selected = selectedBrandId ?? brands.first?.id
        let accent = branding.primaryColor
        let rows = ProvisioningRowBuilder.brandRows(brands: brands, selectedId: selected,
                                                    scheme: colorScheme)
        let band = ProvisioningRowBuilder.brandBand(brands: brands, selectedId: selected,
                                                    scheme: colorScheme)
        let title = localized("title", forStep: step, fallback: step.title) ?? ""

        provisioningScreen(
            for: step, index: stepIndex,
            title: title,
            lede: localized("subtitle", forStep: step, fallback: step.subtitle),
            primaryTitle: localized("continueButtonText", forStep: step,
                                    fallback: step.continueButtonText) ?? ChromeCopy.continue,
            primaryDisabled: brands.isEmpty,
            onPrimary: { goToNextStep() }
        ) {
            ProvisioningRowList(rows: rows, metrics: metrics, accent: accent,
                                onSelect: { selectedBrandId = $0 })
            ProvisioningStatusBand(content: band, metrics: metrics, accent: accent)
        }
        // Only when nothing is chosen yet, so a restored selection wins.
        .onAppear { if selectedBrandId == nil { selectedBrandId = brands.first?.id } }
    }
}

// MARK: - Media step on the shell

extension Preset5View {
    /// A media step on the provisioning shell: the step's blocks rendered as they are, beside the
    /// media on the side the step names, under the same header, rail and footer as its neighbours.
    @ViewBuilder
    func provisioningMediaStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let metrics = provisioningMetrics
        let accent = branding.primaryColor
        let mediaPath = dynamicState.heroImageOverrides[step.id] ?? step.heroImage ?? step.mediaItems?.first?.url
        let isClip = mediaPath.map { p in
            ["gif", "mp4", "mov", "m4v"].contains((p as NSString).pathExtension.lowercased())
        } ?? false
        let panel = localizedCardPanel(step) ?? mediaPath.map { path in
            InspectConfig.CardPanel(caption: nil, stat: nil, pairs: nil,
                                    image: isClip ? nil : path, video: isClip ? path : nil,
                                    imageTitle: nil, paragraphs: nil, layout: nil)
        }
        let mediaLeading = (step.mediaSide ?? "right").lowercased() == "left"
        let copyWidth = InspectMetrics.unit.cardListWidth

        provisioningScreen(
            for: step, index: stepIndex,
            title: localized("title", forStep: step, fallback: step.title) ?? "",
            lede: localized("subtitle", forStep: step, fallback: step.subtitle),
            primaryTitle: localized("continueButtonText", forStep: step,
                                    fallback: step.continueButtonText) ?? ChromeCopy.continue,
            primaryDisabled: false,
            onPrimary: {
                openCardContinueActionURL(step.continueAction)
                goToNextStep()
            }
        ) {
            MigrationBodySlot(metrics: metrics) {
                HStack(alignment: .top, spacing: InspectMetrics.unit.cardColGap) {
                    if mediaLeading, let panel {
                        CardPanelView(panel: panel, accent: accent)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    GuidanceContentView(contentBlocks: cardBlocks(step), scaleFactor: scaleFactor,
                                        iconBasePath: effectiveIconBasePath, inspectState: inspectState,
                                        itemId: step.id, accentColor: accent,
                                        checklistLineSatisfied: checklistLineSatisfied[step.id])
                        .frame(width: panel == nil ? metrics.column : copyWidth, alignment: .topLeading)
                    if !mediaLeading, let panel {
                        CardPanelView(panel: panel, accent: accent)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .frame(height: metrics.bodyBottom - ProvisioningM.listTop, alignment: .top)
                .clipped()
            }
        }
        .sourceTag()
    }
}

