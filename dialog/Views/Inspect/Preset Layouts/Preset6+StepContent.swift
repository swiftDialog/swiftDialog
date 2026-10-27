//
//  Preset6+StepContent.swift
//  dialog
//
//  Preset 6 extension: content panel, inline back button, step heading, status badge, fallback content.
//

import SwiftUI

extension Preset6View {
    // MARK: - Content Panel

    @ViewBuilder
    var contentPanel: some View {
        VStack(spacing: 0) {
            if let currentItem = inspectState.steps[safe: currentStep] {
                GeometryReader { contentGeo in
                    ZStack(alignment: .bottom) {
                        ScrollView(.vertical, showsIndicators: true) {
                            let sp = metrics
                            // No spacing: the header band's unused bottom is the gap to the payload.
                            VStack(alignment: .leading, spacing: 0) {
                                // `headerBandH` is a maximum, not a fixed height: payloads start at the same y on every
                                // step with room, and the band gives space back when the payload would overflow.
                                stepHeading(for: currentItem)
                                    .frame(maxHeight: sp.headerBandH, alignment: .topLeading)

                                // The payload band is leading- and top-aligned; long content scrolls.
                                VStack(alignment: .leading, spacing: sp.sectionGap) {
                                if let guidanceContent = currentItem.content, !guidanceContent.isEmpty {
                                    // Localization, then live plist monitor state, then IPC updates, as on Preset 5.
                                    let updatedContent = guidanceContent.enumerated().map { index, block in
                                        let locBlock = localizedContentBlock(block, itemId: currentItem.id, blockIndex: index)
                                        let monBlock = applyPlistMonitorState(to: locBlock, index: index)
                                        return applyDynamicUpdates(to: monBlock, index: index, itemId: currentItem.id)
                                    }

                                    // Migration bodies, after the merge above. `width: nil`: the body reads its
                                    // geometry. Gated by `usesMigrationBodies`: `resolve` alone would claim plain
                                    // steps.
                                    if inspectState.config?.usesMigrationBodies == true,
                                       let kind = MigrationBodyKind.resolve(blocks: updatedContent) {
                                        migration6Body(kind, blocks: updatedContent)
                                    } else {
                                    GuidanceContentView(
                                        contentBlocks: updatedContent,
                                        scaleFactor: scaleFactor,
                                        iconBasePath: dynamicState.iconBasePathOverride ?? inspectState.uiConfiguration.iconBasePath,
                                        inspectState: inspectState,
                                        itemId: currentItem.id,
                                        onOverlayTap: currentItem.stepOverlay != nil ? {
                                            selectedItemForDetail = currentItem
                                            showItemDetailOverlay = true
                                        } : nil,
                                        accentColor: highlightColor,
                                        // Without this every checklist line reads unsatisfied.
                                        checklistLineSatisfied: checklistLineSatisfied[currentItem.id]
                                    )
                                    }
                                } else {
                                    fallbackContentView(for: currentItem)
                                }

                                // A card-chrome config keeps its `cardPanel` media when rendered in this layout.
                                if let panel = currentItem.cardPanel,
                                   panel.video != nil || panel.image != nil {
                                    CardPanelView(panel: panel, accent: highlightColor)
                                        .frame(maxWidth: sp.contentMaxW)
                                }

                                if isProcessing && processingState.stepId == currentItem.id {
                                    processingStateView(for: currentItem)
                                }

                                resultBanner(for: currentItem)
                                }
                                // Top-aligned; a lone media object still centres (see PayloadAlignment).
                                .frame(maxWidth: .infinity, maxHeight: .infinity,
                                       alignment: PayloadAlignment.alignment(for: currentItem.content ?? []))
                            }
                            .frame(minHeight: contentGeo.size.height - sp.sectionGap * 2,
                                   alignment: .top)
                            // Reading measure: `proseMaxW` scales with measureScale, not scaleFactor.
                            .frame(maxWidth: sp.proseMaxW, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, sp.contentPadH)
                            .padding(.vertical, sp.sectionGap)
                            .trackScrollForHint(coordinateSpace: "preset6Content")
                        }
                        .coordinateSpace(name: "preset6Content")

                        ScrollHintOverlay(
                            containerHeight: contentGeo.size.height,
                            contentHeight: contentPanelContentHeight,
                            scrollOffset: contentPanelScrollOffset
                        )
                    }
                    .onPreferenceChange(ScrollContentHeightKey.self) { contentPanelContentHeight = $0 }
                    .onPreferenceChange(ScrollOffsetKey.self) { contentPanelScrollOffset = $0 }
                }
                // Keyed by id so inserting or removing steps before this one does not remount it.
                .id(currentItem.id)
                .transition(.asymmetric(
                    insertion: .move(edge: navigationDirection == .forward ? .trailing : .leading)
                               .combined(with: .opacity),
                    removal: .move(edge: navigationDirection == .forward ? .leading : .trailing)
                               .combined(with: .opacity)
                ))
            } else {
                completionView
            }
        }
        .sourceTag()
    }

    // MARK: - Inline Back Button

    /// Whether the back button sits inline above the heading or in the footer.
    /// Set by config `backButtonStyle`: "inline" (default) or "footer".
    var useInlineBackButton: Bool {
        let style = inspectState.config?.backButtonStyle ?? "inline"
        return style == "inline"
    }

    @ViewBuilder
    var inlineBackButton: some View {
        let backText: String = {
            guard let item = inspectState.steps[safe: currentStep] else {
                return BackDoor.label(localized: nil, step: nil, branding: branding.button2Text)
            }
            return BackDoor.label(localized: localized("backButtonText", forItem: item, fallback: nil),
                                  step: item.backButtonText, branding: branding.button2Text)
        }()

        HStack {
            Door.back(plate: .quaternary, ink: .secondary,
                      label: backText, action: { goToPreviousStep() })
                .help(backText)
                .accessibilityLabel(backText)

            Spacer()
        }
    }

    // MARK: - Step Heading

    @ViewBuilder
    func stepHeading(for item: InspectConfig.IntroStep) -> some View {
        VStack(alignment: .leading, spacing: metrics.titleSubtitle) {
            HStack(spacing: 8) {
                headerIconTile(for: item)

                if let guidanceTitle = localizedHeadline(item, fallback: item.title) {
                    Text(guidanceTitle)
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                } else {
                    Text(item.displayName ?? item.title ?? item.id)
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                }

                if item.stepOverlay != nil {
                    Button(action: {
                        selectedItemForDetail = item
                        showItemDetailOverlay = true
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(palette.info)
                    }
                    .buttonStyle(.plain)
                    .help("View details")
                }

                Spacer()
            }

            // Per-step subtitle under the title.
            if let description = localized("subtitle", forItem: item, fallback: item.subtitle),
               !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if completedSteps.contains(item.id) || inspectState.completedItems.contains(item.id) {
                let completedText = localized("completedStatus", forItem: item, fallback: item.completedStatus) ?? "Completed"
                let failedText = ChromeCopy.failed
                statusBadge(completed: true, failed: failedSteps[item.id] != nil, completedText: completedText, failedText: failedText)
            }
        }
        .padding(.bottom, metrics.titleSubtitle)
    }

    /// Optional header tile: `heroImage` drawn as a 56 pt rounded tile beside `guidanceTitle`
    /// when `headerIconTile == true`. Uses `IntroHeroImage` for icon resolution.
    @ViewBuilder
    private func headerIconTile(for item: InspectConfig.IntroStep) -> some View {
        if item.headerIconTile == true, let heroImage = dynamicState.heroImageOverrides[item.id] ?? item.heroImage, !heroImage.isEmpty {
            IntroHeroImage(
                path: heroImage,
                shape: "roundedSquare",
                size: 56,
                accentColor: highlightColor
            )
        }
    }

    @ViewBuilder
    func statusBadge(completed: Bool, failed: Bool, completedText: String = "Completed", failedText: String = "Failed") -> some View {
        let statusColor = failed ? palette.error : palette.success
        HStack(spacing: 6) {
            StatusIconView(failed ? .failure : .success, size: 12)

            Text(failed ? failedText : completedText)
                .font(.caption.weight(.medium))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(failed ? palette.errorBackground : palette.successBackground)
        )
    }

    // MARK: - Fallback Content View

    @ViewBuilder
    func fallbackContentView(for item: InspectConfig.IntroStep) -> some View {
        VStack(alignment: .leading, spacing: metrics.sectionGap) {
            if let icon = item.heroImage {
                IntroHeroImage(
                    path: icon,
                    shape: "roundedSquare",
                    size: 80 * scaleFactor,
                    accentColor: highlightColor
                )
                .frame(maxWidth: .infinity)
            }

            if let description = item.paths?.first, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// One of the four migration bodies in Preset 6's payload band. `width: nil`: the body fills its
    /// container and picks its layout from its own geometry, using the shared `MigrationPayload` builders.
    @ViewBuilder
    func migration6Body(_ kind: MigrationBodyKind,
                        blocks: [InspectConfig.GuidanceContent]) -> some View {
        let normalized = blocks.map(InspectConfig.GuidanceContent.normalized)
        switch kind {
        case .receipt:
            MigrationReceiptBody(
                rows: MigrationPayload.rows(from: normalized),
                facts: MigrationPayload.facts(from: normalized),
                caption: MigrationPayload.caption(from: normalized, role: .list),
                width: nil, accent: highlightColor)
        case .mediaSplit:
            MigrationMediaSplit(
                steps: MigrationPayload.actionSteps(from: normalized),
                mediaURL: MigrationPayload.mediaURL(from: normalized),
                caption: MigrationPayload.caption(from: normalized, role: .list),
                mediaCaption: MigrationPayload.caption(from: normalized, role: .media),
                width: nil, accent: highlightColor)
        case .taskList:
            MigrationTaskListBody(
                rows: MigrationPayload.rows(from: normalized),
                caption: MigrationPayload.caption(from: normalized, role: .list),
                width: nil, accent: highlightColor)
        }
    }
}
