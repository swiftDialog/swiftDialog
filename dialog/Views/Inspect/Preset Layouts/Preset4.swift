//
//  Preset4.swift
//  dialog
//
//  Preset 4: a compact (~550×180) toast showing one item at a time. `progressMode`: "shared" (default),
//  "perItem" or "report" (a check list until Done). Phase views are in Preset4Components.swift.
//  It does not use the shared PhaseContainer/footer chrome by design; keep the toast's size and look.
//

import SwiftUI

struct Preset4View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @StateObject private var iconCache = PresetIconCache()
    @StateObject private var commandRouter = CommandRouter()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.palette) private var palette

    @State private var currentPhase: PresetPhase = .main
    @State private var currentItemIndex: Int = 0
    @State private var isUserNavigating: Bool = false
    /// The plist status poll (a `Poll`, as in Preset 3's `startStatusPoll()`).
    @State private var statusPoll: Poll?
    @State private var progressCount: Int = 0  // only increases
    @State private var externalProgressPct: Int?  // live `progress:` value (0-100); nil derives it from the item count

    // MARK: - Derived properties

    private var primaryColor: Color {
        // Unset falls back to the system accent (see `InspectState.highlightColor`).
        let color = inspectState.uiConfiguration.highlightColor.nilIfEmpty
            .map { Color(hex: $0) } ?? Color.accentColor
        return colorScheme == .dark ? color.darkModeAdapted : color
    }

    private var progressMode: String {
        inspectState.config?.progressMode ?? "shared"
    }

    private var basePath: String? {
        inspectState.uiConfiguration.iconBasePath
    }

    private var currentItem: InspectConfig.ItemConfig? {
        guard !inspectState.items.isEmpty,
              currentItemIndex >= 0,
              currentItemIndex < inspectState.items.count else { return nil }
        return inspectState.items[currentItemIndex]
    }

    /// Whether any item uses plist status monitoring.
    private var hasPlistMonitoring: Bool {
        inspectState.items.contains(where: { $0.plistKey != nil })
    }

    /// Items in a terminal state (completed or failed).
    private var terminalCount: Int {
        inspectState.trackedCompletedCount + inspectState.trackedFailedCount
    }

    /// Whether every item is in a terminal state.
    private var allItemsTerminal: Bool {
        !inspectState.trackedItems.isEmpty && terminalCount >= inspectState.trackedItems.count
    }

    /// Trigger file path for IPC commands.
    private var triggerFilePath: String {
        presetTriggerFilePath(config: inspectState.config)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)

            if inspectState.config?.messageStyle == "info" {
                // Info cards: one card per item (or the intro screen when there are none); the last one exits like
                // Done.
                ToastInfoSequence(state: inspectState, accent: primaryColor, basePath: basePath) {
                    if ButtonExit.minimizeInsteadOfExiting(inspectState.config?.button1Action, label: "Preset4View") { return }
                    presetCleanExit(state: inspectState, triggerFilePath: triggerFilePath,
                                    label: "Preset4View", message: "Answer closed")
                }
            } else {
            switch currentPhase {
            case .intro:
                ToastIntroBar(state: inspectState, accent: primaryColor, basePath: basePath) {
                    withAnimation(InspectConstants.stepTransition) {
                        currentPhase = .main
                    }
                }
            case .main:
                // "report" shows all items as a check list until Done; otherwise one item at a time.
                if progressMode == "report" {
                    ToastReportList(state: inspectState, iconCache: iconCache,
                                    accent: primaryColor, basePath: basePath) {
                        if ButtonExit.minimizeInsteadOfExiting(inspectState.config?.button1Action, label: "Preset4View") { return }
                        presetCleanExit(state: inspectState, triggerFilePath: triggerFilePath,
                                        label: "Preset4View", message: "Report closed")
                    }
                } else {
                    mainPhaseView
                }
            case .summary:
                ToastSummaryBar(state: inspectState, accent: primaryColor, basePath: basePath) {
                    if ButtonExit.minimizeInsteadOfExiting(inspectState.config?.button1Action, label: "Preset4View") { return }
                    presetCleanExit(state: inspectState, triggerFilePath: triggerFilePath,
                                    label: "Preset4View", message: "Summary closed")
                }
            }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            iconCache.cacheMainIcon(for: inspectState)
            iconCache.cacheItemIcons(for: inspectState)

            if inspectState.config?.introScreen != nil {
                currentPhase = .intro
            }

            applyToastAnchor()
            setupCommandRouter()
            writeReadinessFile(config: inspectState.config, triggerFilePath: triggerFilePath,
                               preset: "4", itemCount: inspectState.items.count,
                               itemIDs: inspectState.items.map { $0.id })
        }
        .onDisappear {
            commandRouter.stopMonitoring()
            statusPoll?.cancel()
            statusPoll = nil
        }
        .onChange(of: inspectState.completedItems) { _, _ in
            // Only increases.
            let newCount = terminalCount
            if newCount > progressCount { progressCount = newCount }
            // Let the user see the result pill before moving on.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                advanceToNextItem()
                checkAutoTransitionToSummary()
            }
        }
        .onChange(of: inspectState.failedItems) { _, _ in
            let newCount = terminalCount
            if newCount > progressCount { progressCount = newCount }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                advanceToNextItem()
                checkAutoTransitionToSummary()
            }
        }
        .onChange(of: currentPhase) { _, newPhase in
            if newPhase == .main {
                checkAutoTransitionToSummary()
            }
        }
        .onChange(of: inspectState.downloadingItems) { _, newDownloading in
            guard !isUserNavigating else { return }
            if let nextDownloadingIndex = inspectState.items.firstIndex(where: { newDownloading.contains($0.id) && !inspectState.completedItems.contains($0.id) }) {
                currentItemIndex = nextDownloadingIndex
            }
        }
        // When rows move under the index (`listitem: order`, added rows), keep showing the same item.
        .onChange(of: inspectState.items.map(\.id)) { oldIDs, newIDs in
            if let moved = ListItemCommand.index(following: currentItemIndex, from: oldIDs, to: newIDs) {
                currentItemIndex = moved
            }
        }
        // Plist polling only runs in the main phase when items set plistKey. A `Poll` reads at once on entry,
        // and unlike `onReceive(Timer.publish…)` a body pass does not restart it.
        .onAppear { startStatusPoll() }
        .onChange(of: currentPhase) { _, newPhase in
            if newPhase == .main, hasPlistMonitoring { checkPlistStatuses() }
        }
        // Without this, brandPalette/brandPaletteDark/successColor have no effect on this preset (see
        // `inspectPalette`).
        .inspectPalette(config: inspectState.config, primaryColor: primaryColor)
    }

    // MARK: - Main Phase

    private var mainPhaseView: some View {
        VStack(spacing: 6) {
            // The item row slides on item change.
            HStack(spacing: 8) {
                if inspectState.items.count > 1 {
                    Button { navigateItem(-1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 48)
                    }
                    .buttonStyle(.plain)
                    .opacity(currentItemIndex > 0 ? 0.6 : 0.15)
                    .disabled(currentItemIndex <= 0)
                }

                ToastCachedIcon(
                    path: currentItem.flatMap { iconCache.getItemIconPath(for: $0, state: inspectState) } ?? "",
                    // `app.dashed`: `app.fill` reads as a broken image. Keep in step with the report row's fallback.
                    fallbackSymbol: "app.dashed",
                    accent: primaryColor,
                    basePath: basePath
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentItem?.displayName ?? inspectState.config?.title ?? ChromeCopy.installing)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    if progressMode == "perItem" {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .tint(primaryColor)
                    }

                    HStack {
                        if let item = currentItem {
                            Text(getItemStatus(for: item))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else if progressMode == "shared" {
                            Text("\(inspectState.trackedCompletedCount) of \(inspectState.trackedItems.count) completed")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if inspectState.items.count > 1 {
                            Text("\(currentItemIndex + 1)/\(inspectState.items.count)")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(palette.textFaint)
                        }
                    }
                }

                Spacer(minLength: 4)

                if let item = currentItem {
                    statusPill(for: item)
                }

                if inspectState.items.count > 1 {
                    Button { navigateItem(1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 48)
                    }
                    .buttonStyle(.plain)
                    .opacity(currentItemIndex < inspectState.items.count - 1 ? 0.6 : 0.15)
                    .disabled(currentItemIndex >= inspectState.items.count - 1)
                }
            }
            .padding(.horizontal, 16)

            // Live `progress:` value when driven, else the item counter; neither decreases. `ProgressBar` applies
            // `progressBarConfig` colours when set.
            if progressMode == "shared" {
                let fraction = externalProgressPct.map { Double($0) / 100.0 }
                    ?? Double(progressCount) / Double(max(inspectState.trackedItems.count, 1))
                ProgressBar(
                    state: inspectState,
                    width: nil,
                    height: nil,
                    showLabel: false,
                    tint: primaryColor,
                    progressOverride: fraction
                )
                .padding(.horizontal, 20)
                .animation(.easeInOut(duration: 0.4), value: fraction)
            }
        }
    }

    // MARK: - Status pill

    /// Coloured status pill from the shared row model; a spinner while installing.
    @ViewBuilder
    private func statusPill(for item: InspectConfig.ItemConfig) -> some View {
        let (text, color, showSpinner) = pillState(for: item)

        HStack(spacing: 4) {
            if showSpinner {
                IndeterminateRing(size: 10, color: color, lineWidth: 1.5)
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
        // Keyed so state changes crossfade instead of morphing.
        .id("\(item.id)-\(text)")
        .transition(.opacity)
    }

    /// Pill text, colour and spinner from the shared row (`ItemSetModel.row` / `itemStatusColor`).
    private func pillState(for item: InspectConfig.ItemConfig) -> (String, Color, Bool) {
        let row = ItemSetModel.row(for: item, state: inspectState)
        return (row.statusText,
                ItemSetModel.itemStatusColor(row.status, hasWarning: row.hasWarning, palette: palette),
                row.status == .active)
    }

    // MARK: - Chevron Navigation

    private func navigateItem(_ direction: Int) {
        let newIndex = currentItemIndex + direction
        guard newIndex >= 0, newIndex < inspectState.items.count else { return }

        isUserNavigating = true
        currentItemIndex = newIndex

        // Resume auto-advance after 5 s without manual navigation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            isUserNavigating = false
        }
    }

    // MARK: - Launch window anchor

    /// Anchors the toast window at launch when the config sets `windowPosition` (e.g. "topright"),
    /// using WindowAnchoring. Without the key the default placement applies.
    private func applyToastAnchor() {
        guard let pos = inspectState.config?.windowPosition, !pos.isEmpty else { return }
        let offset = inspectState.config?.windowPositionOffset
        DispatchQueue.main.async {
            applyWindowAnchor(position: pos, offset: offset, didMoveWindow: false,
                              label: "Preset4View", animated: false)
        }
    }

    // MARK: - Plist Status Monitoring

    /// Polls plist files for item status via PlistStatusPoller (PlistHelper.swift); the view owns only the timer.
    private func startStatusPoll() {
        guard hasPlistMonitoring, statusPoll == nil else { return }
        if currentPhase == .main { checkPlistStatuses() }
        let poll = Poll(every: InspectConstants.plistPollInterval)
        statusPoll = poll
        poll.start { if self.currentPhase == .main { self.checkPlistStatuses() } }
    }

    private func checkPlistStatuses() {
        PlistStatusPoller.pollItemStatuses(state: inspectState, basePath: basePath)
    }

    // MARK: - Auto-Advance Logic

    private func advanceToNextItem() {
        guard currentPhase == .main, !inspectState.items.isEmpty else { return }
        guard !isUserNavigating else { return }

        if let item = currentItem,
           !inspectState.completedItems.contains(item.id),
           !inspectState.failedItems.contains(item.id) {
            return
        }

        if let nextIdx = inspectState.items.firstIndex(where: {
            inspectState.downloadingItems.contains($0.id) && !inspectState.completedItems.contains($0.id)
        }) {
            currentItemIndex = nextIdx
            return
        }

        if let nextIdx = inspectState.items.firstIndex(where: {
            !inspectState.completedItems.contains($0.id) &&
            !inspectState.downloadingItems.contains($0.id) &&
            !inspectState.failedItems.contains($0.id)
        }) {
            currentItemIndex = nextIdx
            return
        }
    }

    private func checkAutoTransitionToSummary() {
        guard currentPhase == .main, !inspectState.items.isEmpty else { return }
        // Report mode stays until its Done button.
        guard progressMode != "report" else { return }
        guard allItemsTerminal else { return }

        DialogNotifications.postStepChange(stepId: "all", action: "all_complete")

        if inspectState.config?.summaryScreen != nil {
            withAnimation(InspectConstants.stepTransition) {
                currentPhase = .summary
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                presetCleanExit(state: inspectState, triggerFilePath: triggerFilePath,
                                label: "Preset4View", message: "All items complete, auto-exiting")
            }
        }
    }

    // MARK: - Command Router Setup

    /// Wires the shared CommandRouter to Preset 4: trigger-file monitoring, acks and the command protocol.
    private func setupCommandRouter() {
        commandRouter.wireItemBase(state: inspectState, presetLabel: "Preset4",
                                   triggerFilePath: triggerFilePath) { [self] router in
            // `progress:<id>:<0-100|0-1>` drives the single overall bar (never decreasing); the step id is ignored.
            router.onProgress = { _, pct in
                externalProgressPct = max(externalProgressPct ?? 0, pct)
            }

            // Navigation moves between items, not phases.
            router.onNavigateByID = { stepId in
                if let index = inspectState.items.firstIndex(where: { $0.id == stepId }) {
                    isUserNavigating = true
                    currentItemIndex = index
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { isUserNavigating = false }
                }
            }
            router.onNavigateByIndex = { index in
                guard index >= 0, index < inspectState.items.count else { return }
                isUserNavigating = true
                currentItemIndex = index
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { isUserNavigating = false }
            }
            router.onNext = { navigateItem(1) }
            router.onPrev = { navigateItem(-1) }

            // The base reset plus this preset's counters.
            let baseReset = router.onReset
            router.onReset = {
                baseReset?()
                withAnimation(.spring()) {
                    progressCount = 0
                    externalProgressPct = nil
                    currentItemIndex = 0
                }
            }

            // The toast has no warning state, so warnings count as completed.
            router.onWarning = { stepId, _ in inspectState.applyItemStatus(stepId, .completed) }
        }
    }
}

// MARK: - Preset4 Wrapper

struct Preset4Wrapper: View {
    @ObservedObject var coordinator: InspectState

    var body: some View {
        Preset4View(inspectState: coordinator)
    }
}
