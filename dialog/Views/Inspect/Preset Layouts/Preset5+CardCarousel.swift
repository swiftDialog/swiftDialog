//
//  Preset5+CardCarousel.swift
//  dialog
//
//  The carousel arm and its scroll helpers.
//

import SwiftUI

extension Preset5View {
    // MARK: - Carousel arm

    /// The carousel arm: cards row (or manifest rows), a content pager below the cards, and the
    /// progress bar. Banner mode and the footer info popover are not drawn.
    @ViewBuilder
    func cardCarouselStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
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
        // Rows added while running (`listitem: add`) are shown, never counted.
        let counted = installationData.filter { !inspectState.addedItemIDs.contains($0.id) }
        let allCompleted = !counted.isEmpty && counted.allSatisfy { $0.status == .completed }
        // Continue waits for every row to finish; auto-advance waits for every row to complete.
        let allFinished = !counted.isEmpty && counted.allSatisfy { $0.status.isFinished }
        let anyFailed = counted.contains { if case .failed = $0.status { return true } else { return false } }
        let autoEnable = step.autoEnableButton ?? true
        let visibleCount = carouselVisibleCardCount()
        let allItemsFit = installationData.count <= visibleCount
        let baseContinue = localized("continueButtonText", forStep: step, fallback: nil)
            ?? step.continueButtonText ?? ChromeCopy.continue
        let continueText = allFinished
            ? (anyFailed ? ChromeCopy.continueAnyway : (step.autoEnableButtonText ?? ChromeCopy.done))
            : baseContinue
        CardStepShell(
            eyebrow: config?.title,
            eyebrowIcon: config?.icon,
            stepLabel: cardStepLabel(stepIndex),
            hero: cardHero(step),
            title: localized("title", forStep: step, fallback: step.title) ?? "",
            subtitle: localized("subtitle", forStep: step, fallback: step.subtitle),
            accent: branding.primaryColor,
            footer: cardFooter(for: step, index: stepIndex,
                               continueText: continueText,
                               continueDisabled: autoEnable && !allFinished) { goToNextStep() }
        ) {
            ScrollView(.vertical) {
                VStack(spacing: cardMetricsSectionGap) {
                    if let messages = step.sideMessages, !messages.isEmpty {
                        DeploymentSideMessageView(
                            messages: messages,
                            interval: step.sideMessageInterval ?? 8
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(spacing: 12) {
                        if CarouselM.form(step.carouselStyle) == .manifest {
                            VStack(spacing: 0) {
                                ForEach(Array(installationData.enumerated()), id: \.element.id) { index, data in
                                    CarouselManifestRow(item: data,
                                                        accentColor: branding.primaryColor,
                                                        compact: false)
                                    if index < installationData.count - 1 {
                                        Rectangle()
                                            .fill(Color.primary.opacity(0.08))
                                            .frame(height: 0.5)
                                    }
                                }
                            }
                        } else {
                            HStack(spacing: 12) {
                                let visibleItems = carouselVisibleItems(from: installationData)
                                ForEach(visibleItems) { item in
                                    CarouselCardView(
                                        item: item,
                                        accentColor: branding.primaryColor,
                                        compact: false,
                                        iconLed: !IconRef.isSymbolReference(item.icon ?? item.iconPath ?? "")
                                    )
                                }
                                if !allItemsFit {
                                    ForEach(0..<max(0, visibleCount - carouselVisibleItems(from: installationData).count), id: \.self) { _ in
                                        CarouselPlaceholderCardView(compact: false)
                                    }
                                }
                            }
                            .animation(.easeInOut(duration: 0.3), value: carouselScrollOffset)
                            if !allItemsFit {
                                HStack(spacing: 14) {
                                    Button(action: { carouselScrollLeft(itemCount: installationData.count) }) {
                                        Image(systemName: "chevron.left.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(carouselScrollOffset > 0 ? branding.primaryColor : palette.text.opacity(0.3))
                                    }
                                    .disabled(carouselScrollOffset <= 0)
                                    .buttonStyle(.plain)
                                    Text("\(min(carouselScrollOffset + visibleCount, installationData.count)) of \(installationData.count)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                    Button(action: { carouselScrollRight(itemCount: installationData.count) }) {
                                        Image(systemName: "chevron.right.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(carouselScrollOffset + visibleCount < installationData.count ? branding.primaryColor : palette.text.opacity(0.3))
                                    }
                                    .disabled(carouselScrollOffset + visibleCount >= installationData.count)
                                    .buttonStyle(.plain)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        CarouselProgressBarView(
                            completed: counted.filter { $0.status == .completed }.count,
                            total: counted.count,
                            accentColor: branding.primaryColor,
                            progressFormat: step.progressFormat,
                            compact: false,
                            rowWidth: CarouselM.wideRowWidth(
                                cards: min(installationData.count, visibleCount),
                                scale: 1.0
                            )
                        )
                    }
                }
            }
            .background(
                GeometryReader { probe in
                    Color.clear
                        .onAppear { carouselMeasuredWidth = probe.size.width }
                        .onChange(of: probe.size.width) { _, newWidth in
                            carouselMeasuredWidth = newWidth
                        }
                }
            )
        }
        .onAppear { startInstallationMonitoring(for: step) }
        .onDisappear { stopInstallationMonitoring(for: step) }
        .onChange(of: allCompleted) {
            if allCompleted && (step.autoAdvanceOnComplete ?? false) {
                writeLog("Preset5: All carousel items completed, auto-advancing", logLevel: .info)
                scheduleAutoAdvance(after: 1.0, from: step.id)
            }
        }
        .onChange(of: monitoringService.itemStatuses) { _, _ in
            carouselAutoCenter(items: step.items ?? [])
        }
        .sourceTag()
    }

    // MARK: - Carousel Scroll Helpers

    /// Cards that fit the measured content width, clamped to 1...5; 5 until geometry lands.
    func carouselVisibleCardCount() -> Int {
        guard carouselMeasuredWidth > 0 else { return 5 }
        // The measured width is already inside the shell's inset; subtracting padding again drops a card.
        return CarouselM.wideCardsThatFit(contentWidth: carouselMeasuredWidth, scale: metrics.measureScale)
    }

    func carouselScrollLeft(itemCount: Int) {
        if carouselScrollOffset > 0 {
            carouselScrollOffset = max(0, carouselScrollOffset - 1)
        }
    }

    func carouselScrollRight(itemCount: Int) {
        let visibleCount = carouselVisibleCardCount()
        if carouselScrollOffset + visibleCount < itemCount {
            carouselScrollOffset = min(itemCount - visibleCount, carouselScrollOffset + 1)
        }
    }

    func carouselVisibleItems(from items: [InstallationItemData]) -> [InstallationItemData] {
        let visibleCount = carouselVisibleCardCount()
        let start = carouselScrollOffset
        let end = min(start + visibleCount, items.count)
        guard start < items.count else { return [] }
        return Array(items[start..<end])
    }

    /// Scrolls so the active item sits in the second slot.
    func carouselAutoCenter(items: [InspectConfig.ListItem]) {
        guard let activeId = items.first(where: {
            (monitoringService.itemStatuses[$0.id] ?? .pending).isActive
        })?.id,
        let activeIndex = items.firstIndex(where: { $0.id == activeId }) else {
            return
        }

        let visibleCount = carouselVisibleCardCount()
        var targetOffset = activeIndex - 1
        targetOffset = max(0, targetOffset)
        targetOffset = min(targetOffset, max(0, items.count - visibleCount))

        if targetOffset != carouselScrollOffset {
            withAnimation(.easeInOut(duration: 0.6)) {
                carouselScrollOffset = targetOffset
            }
        }
    }
}
