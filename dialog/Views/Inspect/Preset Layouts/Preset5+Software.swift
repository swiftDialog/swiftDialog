//
//  Preset5+Software.swift
//  dialog
//
//  `stepType: "software"`: one card arm with three layouts: bundles (catalogue), detail (one bundle's
//  apps) and handoff (where self-service takes over). Status comes from UnifiedMonitoringService; counts
//  are computed, not authored. swiftDialog installs nothing: actions emit a `request` for the orchestrator.
//

import SwiftUI

extension Preset5View {

    /// Starts detection in catalogue mode. `reflectsCurrentState: true` lets a tile go back to missing
    /// when the user removes an app; install runs keep the one-way latch.
    func startSoftwareMonitoring(step: InspectConfig.IntroStep) {
        guard let items = step.items, !items.isEmpty else {
            writeLog("Preset5 software: step '\(step.id)' has no items to detect", logLevel: .error)
            return
        }
        monitoringService.startMonitoring(items: items,
                                          cachePaths: config?.cachePaths ?? [],
                                          cacheExtensions: config?.resolvedCacheExtensions,
                                          receiptsBasePath: config?.receiptsBasePath,
                                          reflectsCurrentState: true,
                                          receiptCensus: config?.receiptCensus ?? false,
                                          scanInterval: config?.scanInterval,
                                          owner: step.id)
        // Bundle install progress arrives through LogMonitor's itemIds routing.
        if let config {
            LogMonitorService.shared.setItems(items)
            LogMonitorService.shared.configure(with: config)
        }
        writeLog("Preset5 software: detecting \(items.count) items for step '\(step.id)'", logLevel: .info)
    }

    // MARK: - Members

    func softwareMember(for item: InspectConfig.ListItem) -> SoftwareMember {
        let status = monitoringService.itemStatuses[item.id] ?? .pending
        // Version is read from the installed bundle, so it exists only when the app is present.
        let detail: String? = status == .completed ? inspectState.getBundleInfoForItem(item) : nil
        let appRequirement = item.requirements?.first { $0.type.lowercased() == "app" }

        var member = SoftwareMember(
            id: item.id,
            name: item.displayName,
            icon: item.icon,
            bundleId: appRequirement?.bundleId,
            paths: item.paths,
            status: status,
            detail: detail
        )
        // The row's action follows its state (`SoftwareRowRule`).
        let action = SoftwareRowRule.action(for: status,
                                            openURL: item.openURL,
                                            appBundleId: appRequirement?.bundleId,
                                            firstPath: item.paths.first)
        member.actionLabel = action.label
        member.action = action.action
        member.actionURL = action.url
        member.requestId = action.requestId
        return member
    }

    // MARK: - Card software arm

    /// The software step on the card layout, the single renderer for every chrome (not gated on `chrome`).
    /// Uses `CardStepShell` rather than `CardStepScreen` because it draws the tally, agent label and
    /// trailing `softwareNote`, which `CardStepModel` has no place for.
    @ViewBuilder
    func cardSoftwareStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let layout = (step.layout ?? "bundles").lowercased()
        let bundles = step.bundles ?? []
        // The bundle a `detail` step describes, resolved once and shared with `CardStepBlocks.detailBundle`.
        let bundle: InspectConfig.SoftwareBundle? = layout == "detail"
            ? CardStepBlocks.detailBundle(in: bundles, named: step.bundleId)
            : nil
        let title = localized("title", forStep: step, fallback: step.title) ?? bundle?.title ?? ""
        CardStepShell(
            // The detail breadcrumb ("‹ All bundles") uses the eyebrow; see `softwareEyebrow`.
            eyebrow: softwareEyebrow(step: step),
            eyebrowIcon: config?.icon,
            stepLabel: cardStepLabel(stepIndex),
            title: title,
            subtitle: localized("subtitle", forStep: step, fallback: step.subtitle) ?? bundle?.summary,
            titleAccessory: layout == "bundles" ? AnyView(softwareTallyCluster(step: step)) : nil,
            accent: branding.primaryColor,
            footer: softwareFooter(for: step, index: stepIndex, layout: layout)
        ) {
            // Measure the band here; inside the ScrollView a GeometryReader sees unbounded height.
            GeometryReader { band in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 12) {
                        if layout == "detail" && bundle == nil {
                            Text("No bundle configured for this step")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        GuidanceContentView(
                            contentBlocks: softwareCardBlocks(step, bundle: bundle),
                            scaleFactor: scaleFactor,
                            iconBasePath: effectiveIconBasePath,
                            inspectState: inspectState,
                            itemId: step.id,
                            // Opening a detail is step navigation, which the arm owns rather than the block.
                            onOpenSoftwareDetail: { bundleId in openSoftwareDetail(bundleId: bundleId) },
                            accentColor: branding.primaryColor)
                        // On the catalogue the note is the footer's state line (`softwareFooter`).
                        if let note = step.softwareNote, layout != "bundles" {
                            Text(note)
                                .font(.system(size: layout == "handoff" ? 11 : 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                // Minus the overflow fade, so the last row is not dimmed.
                .environment(\.softwareBandHeight, band.size.height - CardStepShellM.bodyFadeHeight)
            }
        }
        // Catalogue-mode detection with the latch released; see `startSoftwareMonitoring`.
        .onAppear { startSoftwareMonitoring(step: step) }
        .sourceTag()
    }

    /// The standard card footer; on the catalogue the `softwareNote` takes the claim's place.
    private func softwareFooter(for step: InspectConfig.IntroStep, index: Int,
                                layout: String) -> CardFooterModel {
        var footer = cardFooter(for: step, index: index,
                                autoClose: cardAutoClose(step)) { goToNextStep() }
        if layout == "bundles" { footer.stateLine = step.softwareNote }
        return footer
    }

    /// The eyebrow on a software step: the detail breadcrumb or nothing. The flow name is already in the
    /// window title and the step counter, and the space is needed on the handoff layout.
    private func softwareEyebrow(step: InspectConfig.IntroStep) -> String? {
        guard let breadcrumb = step.backLabel, !breadcrumb.isEmpty else { return nil }
        return breadcrumb
    }

    /// The catalogue tally beside the title (`CardStepShell.titleAccessory`): counted from live detection
    /// over all items, plus the orchestrator name only when the config states it.
    private func softwareTallyCluster(step: InspectConfig.IntroStep) -> some View {
        let tally = BundleTally(statuses: (step.items ?? []).map {
            monitoringService.itemStatuses[$0.id] ?? .pending
        })
        // One line on the title's baseline: count, then agent.
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(tally.installed) of \(tally.total) installed")
                .font(.system(size: 15, weight: .semibold))
            if let agent = step.agentLabel {
                Text(agent)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: true, vertical: false)  // never wrap the count
    }

    /// The step's blocks: `cardBlocks` (authored content, stats, media, grid items), then the
    /// `bundle-list` / `bundle-detail` / `handoff-list` block for the layout.
    private func softwareCardBlocks(_ step: InspectConfig.IntroStep,
                                    bundle: InspectConfig.SoftwareBundle?)
    -> [InspectConfig.GuidanceContent] {
        CardStepBlocks.foldCatalogue(
            content: cardBlocks(step),
            layout: step.layout,
            sources: .init(bundles: step.bundles ?? [], detailBundle: bundle,
                           items: step.items ?? [], handoffs: step.handoffs ?? []),
            member: { softwareMember(for: $0) },
            hasDetail: { hasSoftwareDetail(bundleId: $0) })
    }

    /// Whether a detail step exists for this bundle, so no button points to a missing screen.
    func hasSoftwareDetail(bundleId: String) -> Bool {
        allSteps.contains { $0.stepType == "software" && ($0.layout ?? "") == "detail" && $0.bundleId == bundleId }
    }

    /// Opens a bundle's detail step. Navigates only to existing step ids, so index-based resume stays valid.
    func openSoftwareDetail(bundleId: String) {
        guard let index = allSteps.firstIndex(where: {
            $0.stepType == "software" && ($0.layout ?? "") == "detail" && $0.bundleId == bundleId
        }) else { return }
        currentStepIndex = index
    }
}
