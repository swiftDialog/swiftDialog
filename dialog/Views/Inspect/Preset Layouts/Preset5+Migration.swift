//
//  Preset5+Migration.swift
//  dialog
//
//  Preset 5's host for the bodies in `MigrationBodies.swift`, plus the setup-assistant shell.
//  The body is chosen from the step's blocks (`MigrationBodyKind.resolve`), not a new step type,
//  so existing configs keep validating. This file supplies window metrics and the payload readers.
//

import SwiftUI

/// Shell adapter for a migration body: the body at the column, pinned into the body band
/// (`listTop` 152, the body band's top).
struct MigrationBodySlot<Content: View>: View {
    let metrics: ProvisioningM
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(width: metrics.column, alignment: .topLeading)
            .offset(x: ProvisioningM.rail, y: ProvisioningM.listTop)
    }
}

extension Preset5View {

    /// The migration body for a step, or nil when its blocks resolve to none (the host draws as usual).
    func migrationBodyKind(for step: InspectConfig.IntroStep) -> MigrationBodyKind? {
        MigrationBodyKind.resolve(blocks: step.guidanceContent ?? step.content)
    }

    /// The migration arm: one shell, one of the bodies, chosen by the step's contents.
    @ViewBuilder
    func provisioningMigrationStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let metrics = provisioningMetrics
        let accent = branding.primaryColor
        let blocks = (step.guidanceContent ?? step.content ?? [])
            .map(InspectConfig.GuidanceContent.normalized)
        let kind = MigrationBodyKind.resolve(blocks: blocks)

        let title = localized("title", forStep: step, fallback: step.title) ?? ""
        let lede = localized("subtitle", forStep: step, fallback: step.subtitle)
        // Only the task list has a bar; its fraction is measured from the rows (done over total).
        let rows = MigrationPayload.rows(from: blocks)
        let footerProgress: Double? = {
            guard kind == .taskList, !rows.isEmpty else { return nil }
            return Double(rows.filter { $0.mark == .done }.count) / Double(rows.count)
        }()

        provisioningScreen(
            for: step, index: stepIndex,
            title: title,
            lede: lede,
            primaryTitle: localized("continueButtonText", forStep: step,
                                    fallback: step.continueButtonText) ?? ChromeCopy.continue,
            primaryDisabled: false,
            // The task list shows a bar instead of the "Step n of 4" counter; no screen shows both.
            showStepCounter: kind != .taskList,
            footerProgress: footerProgress,
            onPrimary: { goToNextStep() }
        ) {
            MigrationBodySlot(metrics: metrics) {
                switch kind {
                case .receipt:
                    MigrationReceiptBody(
                        rows: MigrationPayload.rows(from: blocks),
                        facts: MigrationPayload.facts(from: blocks),
                        caption: MigrationPayload.caption(from: blocks, role: .list),
                        width: metrics.column, accent: accent)
                case .mediaSplit:
                    MigrationMediaSplit(
                        steps: MigrationPayload.actionSteps(from: blocks),
                        mediaURL: MigrationPayload.mediaURL(from: blocks),
                        caption: MigrationPayload.caption(from: blocks, role: .list),
                        mediaCaption: MigrationPayload.caption(from: blocks, role: .media),
                        width: metrics.column, accent: accent)
                case .taskList, .none:
                    MigrationTaskListBody(
                        rows: rows,
                        caption: MigrationPayload.caption(from: blocks, role: .list),
                        width: metrics.column, accent: accent)
                }
            }
        }
    }
}

// MARK: - Setup-assistant shell

extension Preset5View {

    /// The footer state line: the step's `footerNote`, else the flow's `footerText`.
    func setupAssistantFooterLine(for step: InspectConfig.IntroStep) -> String? {
        let line = localized("footerNote", forStep: step, fallback: step.footerNote)
            ?? branding.footerText
        guard let line, !line.isEmpty else { return nil }
        return line
    }

    /// The secondary action ("What changes?"). With both `secondaryButtonText` and `stepOverlay` it opens
    /// the overlay; with a label alone it keeps `secondaryAction`'s back/next meaning.
    func setupAssistantQuietDoor(for step: InspectConfig.IntroStep)
    -> (title: String, action: () -> Void)? {
        guard let title = localized("secondaryButtonText", forStep: step,
                                    fallback: step.secondaryButtonText),
              !title.isEmpty else { return nil }
        if let overlay = step.stepOverlay, overlay.isShown {
            // Both values are needed: `.detailOverlay` presents on `showStepOverlay` with `currentStepOverlayConfig`.
            return (title, { currentStepOverlayConfig = overlay; showStepOverlay = true })
        }
        if step.secondaryAction?.lowercased() == "next" {
            return (title, { goToNextStep() })
        }
        return (title, { goToPreviousStep() })
    }

    /// The footer logo (18 pt tall), chosen by surface: alpha sits on a dark scrimmed photograph and takes
    /// the dark-mode art; beta follows the window, like `cardFooterLogoPath`.
    func setupAssistantLogoPath(surface: SetupAssistantSurface,
                                ground: SetupAssistantGround = .dark) -> String? {
        guard let logo = config?.logoConfig else { return nil }
        // `.photograph` forces the light art, but only while alpha's ground is actually dark; on a light
        // ground the mark takes the window's artwork.
        let effective: BrandArtwork.Surface =
            (surface == .alpha && ground.isDark) ? .photograph : .window
        return BrandArtwork.resolve(logo, isDark: colorScheme == .dark,
                                    surface: effective, gate: .footer)
    }

    /// Alpha (full bleed) or beta (framed), from `mediaLayout`: "fill" fills the payload, anything else
    /// sits in a card.
    func setupAssistantIsFullBleed(_ blocks: [InspectConfig.GuidanceContent]) -> Bool {
        guard let media = blocks.first(where: {
            GuidanceBlockRole(blockType: $0.type) == .media
        }) else { return true }  // no picture is alpha with an empty ground
        return media.mediaLayout?.lowercased() == "fill"
    }

    /// Full-bleed screens on the setup-assistant shell: the same blocks as the other bodies, mapped to
    /// one image and two sentences. The facts panel has no place here. Beta is `setupAssistantBeta`;
    /// it clips rather than scrolls if its card is taller than the frame.
    @ViewBuilder
    func setupAssistantStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        // IPC state merges here too (config indices, before normalization), so `update_guidance` reaches this shell.
        let blocks = (step.guidanceContent ?? step.content ?? []).enumerated()
            .map { idx, block in applyIPCState(to: block, blockIndex: idx, stepId: step.id) }
            .map(InspectConfig.GuidanceContent.normalized)
        // A `carousel` step under this construction is the delivery journey. Routed here, inside the
        // construction gate, so that gate alone decides which shell a flow gets.
        if step.resolvedStepType == "carousel" {
            setupAssistantJourney(step: step, stepIndex: stepIndex, blocks: blocks)
        } else if setupAssistantIsFullBleed(blocks) {
            setupAssistantAlpha(step: step, stepIndex: stepIndex, blocks: blocks)
        } else {
            setupAssistantBeta(step: step, stepIndex: stepIndex, blocks: blocks)
        }
    }

    /// Alpha with the delivery journey: `provisioningCarouselStepView` on this shell. It reads the
    /// step's items and the live monitor, not guidance blocks.
    @ViewBuilder
    func setupAssistantJourney(step: InspectConfig.IntroStep, stepIndex: Int,
                               blocks: [InspectConfig.GuidanceContent]) -> some View {
        let items: [any MonitoredItem] = step.items ?? []
        // Read the monitoring service, not `InspectState`: completedItems/removedItems track the config-level
        // `items[]`, which a Preset 5 flow cannot author.
        let statuses = items.map { monitoringService.itemStatuses[$0.id] ?? .pending }
        let vocabulary = ProvisioningVocabulary.packages.merged(with: step.stateWords)
        let rows = ProvisioningRowBuilder.itemRows(
            items: items, statuses: statuses,
            removedIds: Set(monitoringService.removedItems.keys),
            vocabulary: vocabulary)
        let division = JourneyDivision.resolve(step: step, rows: rows, vocabulary: vocabulary)
        let quiet = setupAssistantQuietDoor(for: step)
        // The capsule shows at most five rows, so the footer line carries the total ("7 of 23 installed")
        // while work remains, then falls back to the authored line.
        let footerLine = JourneyScroll.progressLine(rows: rows,
                                                    noun: vocabulary.done.lowercased(),
                                                    enabled: step.showProgressLine ?? true)
            ?? setupAssistantFooterLine(for: step)

        SetupAssistantFullBleedShell(
            title: localized("title", forStep: step, fallback: step.title) ?? "",
            lede: localized("subtitle", forStep: step, fallback: step.subtitle),
            // No capsule for an empty manifest. `layout: "grid"` shows cards instead of the list; division mode,
            // when authored, paces the step's cadence entries by the real rows' completion.
            capsule: rows.isEmpty ? .none
                   : (division.map { .cardGrid(rows: $0.cardRows, total: $0.total,
                                                columns: step.gridColumns ?? JourneyGridM.columns,
                                                progress: step.gridProgress == true && $0.total > 0
                                                    ? Double($0.completed) / Double($0.total) : nil,
                                                style: JourneyGridStyle.resolve(step.gridStyle),
                                                completed: $0.completed) }
                      ?? (JourneyLayout.isGrid(step.layout)
                          ? .cardGrid(rows: rows, total: nil,
                                      columns: step.gridColumns ?? JourneyGridM.columns,
                                      progress: step.gridProgress == true && !rows.isEmpty
                                          ? Double(rows.filter(JourneyScroll.isTerminal).count) / Double(rows.count) : nil,
                                      style: JourneyGridStyle.resolve(step.gridStyle))
                                                             : .checklist(rows: rows))),
            // The ground and ink follow the window's appearance.
            ground: colorScheme == .dark ? .dark : .light,
            // `phaseBackground: "banded"` uses the accent band; anything else the ramp. This seat only.
            groundStyle: SetupAssistantGroundStyle.resolve(config?.phaseBackground),
            logoPath: setupAssistantLogoPath(surface: .alpha,
                                             ground: colorScheme == .dark ? .dark : .light),
            footerLine: footerLine,
            primaryTitle: localized("continueButtonText", forStep: step,
                                    fallback: step.continueButtonText) ?? ChromeCopy.continue,
            // Same rule as the carousel arm: the button is held only in division mode.
            primaryDisabled: division?.primaryDisabled ?? false,
            primaryHidden: division?.primaryHidden ?? false,
            onPrimary: { goToNextStep() },
            logoHeight: BrandMarkBox.fit(authored: config?.logoConfig?.maxHeight,
                                         default: SetupAssistantM.footerLogoHeight,
                                         cap: SetupAssistantM.footerLogoCap).height,
            // The footer support line, from root `supportText`.
            supportLine: config?.supportText,
            showCounter: step.showGridCounter ?? true,
            secondaryTitle: quiet?.title,
            onSecondary: quiet?.action,
            backLabel: canGoBack(fromStepIndex: stepIndex) && (step.showBackButton ?? true)
                ? BackDoor.label(localized: localized("backButtonText", forStep: step, fallback: nil),
                                 step: step.backButtonText, branding: branding.button2Text)
                : nil,
            onBack: { goToPreviousStep() },
            accent: branding.primaryColor
        ) {
            if let url = MigrationPayload.mediaURL(from: blocks) {
                // One brand still across every step, sized to `hostHeight` (see `setupAssistantAlpha`).
                IntroMediaPlayer(url: url, autoplay: true,
                                 height: SetupAssistantM.hostHeight,
                                 cornerRadius: 0, fit: .fill)
            } else {
                // Without media, a ramp from the brand accent to near-black instead of a black frame.
                BrandGroundFallback(accent: branding.primaryColor,
                                    ground: colorScheme == .dark ? .dark : .light)
            }
        }
        // Without monitoring every row stays "Queued". Ownership-scoped by step id: SwiftUI runs the next
        // screen's `onAppear` before this one's `onDisappear`.
        .onAppear { startInstallationMonitoring(for: step) }
        .onDisappear { stopInstallationMonitoring(for: step) }
        // Dark palette only when the ground is dark (dark window); a light window keeps the root palette.
        .modifier(DarkSurfaceIfNeeded(active: colorScheme == .dark,
                                      config: config, primaryColor: branding.primaryColor))
    }

    /// Beta: the walkthrough framed as a specimen, with instructions in the strip beneath it.
    @ViewBuilder
    func setupAssistantBeta(step: InspectConfig.IntroStep, stepIndex: Int,
                            blocks: [InspectConfig.GuidanceContent]) -> some View {
        let metrics = provisioningMetrics
        let isWait = step.resolvedStepType == "processing" || step.processingDuration != nil
        let quiet = setupAssistantQuietDoor(for: step)
        let wait = MigrationPayload.waitProgress(from: blocks)
        SetupAssistantFramedShell(
            title: localized("title", forStep: step, fallback: step.title) ?? "",
            lede: localized("subtitle", forStep: step, fallback: step.subtitle),
            steps: MigrationPayload.actionSteps(from: blocks),
            specimenNote: MigrationPayload.caption(from: blocks, role: .list)
                ?? MigrationPayload.caption(from: blocks, role: .media),
            // Phase, count and bar in the strip under the specimen, at the card's width.
            progress: isWait
                ? .progress(text: MigrationPayload.phase(from: blocks)
                            ?? localized("subtitle", forStep: step, fallback: step.subtitle) ?? "",
                            count: wait.count, fraction: wait.fraction)
                : .none,
            logoPath: setupAssistantLogoPath(surface: .beta),
            footerLine: setupAssistantFooterLine(for: step),
            primaryTitle: localized("continueButtonText", forStep: step,
                                    fallback: step.continueButtonText) ?? ChromeCopy.continue,
            // Continue is disabled while the wait runs.
            primaryDisabled: isWait,
            onPrimary: { goToNextStep() },
            secondaryTitle: quiet?.title,
            onSecondary: quiet?.action,
            // No Back on a wait screen.
            backLabel: !isWait && canGoBack(fromStepIndex: stepIndex)
                && (step.showBackButton ?? true)
                ? BackDoor.label(localized: localized("backButtonText", forStep: step, fallback: nil),
                                 step: step.backButtonText, branding: branding.button2Text)
                : nil,
            onBack: { goToPreviousStep() },
            accent: branding.primaryColor,
            frameHeight: metrics.height
        ) {
            if let url = MigrationPayload.mediaURL(from: blocks) {
                IntroMediaPlayer(url: url, autoplay: true,
                                 height: SetupAssistantM.betaMediaHeight,
                                 cornerRadius: 0, fit: .fill)
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    func setupAssistantAlpha(step: InspectConfig.IntroStep, stepIndex: Int,
                             blocks: [InspectConfig.GuidanceContent]) -> some View {
        let lines = MigrationPayload.rows(from: blocks)
        // The title has no tick of its own; the row marks carry the state.
        let allMet = !lines.isEmpty && lines.allSatisfy { $0.mark == .done }
        let isWait = step.resolvedStepType == "processing" || step.processingDuration != nil
        let quiet = setupAssistantQuietDoor(for: step)

        let capsule: SetupAssistantCapsule = {
            if isWait {
                // The capsule carries the progress: phase name and phases left, from the progress block.
                let wait = MigrationPayload.waitProgress(from: blocks)
                return .progress(text: MigrationPayload.phase(from: blocks)
                                 ?? localized("subtitle", forStep: step,
                                              fallback: step.subtitle) ?? "",
                                 count: wait.count, fraction: wait.fraction)
            }
            guard !lines.isEmpty else { return .none }
            return .marks(lines: lines.map(\.name), met: allMet)
        }()
        let banded = SetupAssistantGroundStyle.resolve(config?.phaseBackground) == .banded
        // `contentAlign` centre: a standard step becomes `.centered`, a processing step `.status`;
        // anything else keeps the bottom-anchored `.stack`.
        let centred = (step.contentAlign ?? config?.contentAlign)?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "center"
        // `layout: "features"` or `"permissions"` takes precedence over `contentAlign`.
        let onbContent = SetupAssistantContent.resolve(step.layout, rows: lines)
        let arrangement: SetupAssistantArrangement = onbContent != nil ? .content
            : (centred ? (isWait ? .status : .centered) : .stack)
        let onbWait = MigrationPayload.waitProgress(from: blocks)
        let dots: (index: Int, count: Int)? = {
            guard config?.stepCounterPlacement?.lowercased() == "dots" else { return nil }
            let count = allSteps.count
            return count > 1 ? (min(max(stepIndex, 0), count - 1), count) : nil
        }()

        SetupAssistantFullBleedShell(
            title: localized("title", forStep: step, fallback: step.title) ?? "",
            // The wait screen keeps its lede; the phase name comes from the progress block.
            lede: localized("subtitle", forStep: step, fallback: step.subtitle),
            capsule: arrangement == .status ? .none : capsule,
            // On the banded ground this seat follows the window, so a light flow does not end on a dark screen;
            // on the ramp it stays dark.
            ground: banded ? (colorScheme == .dark ? .dark : .light) : .dark,
            groundStyle: banded ? .banded : .ramp,
            arrangement: arrangement,
            heroImage: step.heroImage,
            content: onbContent,
            tag: step.eyebrow,
            statusTitle: arrangement == .status
                ? (MigrationPayload.phase(from: blocks)
                   ?? localized("subtitle", forStep: step, fallback: step.subtitle)) : nil,
            statusDetail: arrangement == .status ? onbWait.count : nil,
            statusProgress: arrangement == .status ? onbWait.fraction : nil,
            dots: dots,
            logoPath: setupAssistantLogoPath(surface: .alpha,
                                             ground: banded ? (colorScheme == .dark ? .dark : .light) : .dark),
            footerLine: setupAssistantFooterLine(for: step),
            // The primary is present even while waiting, disabled until the migration ends.
            primaryTitle: localized("continueButtonText", forStep: step,
                                    fallback: step.continueButtonText) ?? ChromeCopy.continue,
            primaryDisabled: isWait,
            onPrimary: { goToNextStep() },
            logoHeight: BrandMarkBox.fit(authored: config?.logoConfig?.maxHeight,
                                         default: SetupAssistantM.footerLogoHeight,
                                         cap: SetupAssistantM.footerLogoCap).height,
            secondaryTitle: quiet?.title,
            onSecondary: quiet?.action,
            // No Back mid-migration.
            backLabel: !isWait && canGoBack(fromStepIndex: stepIndex)
                && (step.showBackButton ?? true)
                ? BackDoor.label(localized: localized("backButtonText", forStep: step, fallback: nil),
                                 step: step.backButtonText, branding: branding.button2Text)
                : nil,
            onBack: { goToPreviousStep() },
            accent: branding.primaryColor
        ) {
            if let url = MigrationPayload.mediaURL(from: blocks) {
                // `hostHeight`, not `recommended.height`: `IntroMediaPlayer` pins its own frame height.
                IntroMediaPlayer(url: url, autoplay: true,
                                 height: SetupAssistantM.hostHeight,
                                 cornerRadius: 0, fit: .fill)
            } else {
                // No still authored: use the brand ground, dark as on this seat.
                BrandGroundFallback(accent: branding.primaryColor, ground: .dark)
            }
        }
        // Alpha's ground is a still under a dark scrim, so its content resolves against the dark palette, as the
        // footer mark does. Beta and the banded ground in a light window follow the window.
        .modifier(DarkSurfaceIfNeeded(active: !banded || colorScheme == .dark,
                                      config: config, primaryColor: branding.primaryColor))
    }
}

