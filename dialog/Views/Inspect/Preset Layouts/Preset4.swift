//
//  Preset4.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Preset4: Compact Toast Installer
//  Minimal ~550×180 window showing one item at a time.
//  Supports intro → items → summary flow, all in the same compact window.
//
//  Features:
//    - Back/forth chevron navigation to browse items manually
//    - Colored status indicators (StatusIconView) for real-time feedback
//    - Plist-based status monitoring (items with plistKey get polled)
//    - Auto-advance on item completion, auto-transition to summary
//
//  Progress modes:
//    "shared"  — Single progress bar showing "X of Y completed" (default)
//    "perItem" — Indeterminate progress per item, auto-advances on completion
//

import SwiftUI

struct Preset4View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @StateObject private var iconCache = PresetIconCache()
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentPhase: PresetPhase = .main
    @State private var currentItemIndex: Int = 0
    @State private var isUserNavigating: Bool = false
    @State private var progressCount: Int = 0  // High-water-mark: only goes up

    // MARK: - Derived properties

    private var primaryColor: Color {
        let color = Color(hex: inspectState.uiConfiguration.highlightColor)
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

    /// Whether any items use plist-based status monitoring
    private var hasPlistMonitoring: Bool {
        inspectState.items.contains(where: { $0.plistKey != nil })
    }

    /// Total items in terminal state (completed + failed)
    private var terminalCount: Int {
        inspectState.completedItems.count + inspectState.failedItems.count
    }

    /// Whether all items have reached a terminal state
    private var allItemsTerminal: Bool {
        !inspectState.items.isEmpty && terminalCount >= inspectState.items.count
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)

            switch currentPhase {
            case .intro:
                compactIntroView
            case .main:
                mainPhaseView
            case .summary:
                compactSummaryView
            }
        }
        .ignoresSafeArea()
        .onAppear {
            iconCache.cacheMainIcon(for: inspectState)
            iconCache.cacheItemIcons(for: inspectState)

            if inspectState.config?.introScreen != nil {
                currentPhase = .intro
            }
        }
        .onChange(of: inspectState.completedItems) { _, _ in
            // Advance progress (high-water-mark — never decreases)
            let newCount = terminalCount
            if newCount > progressCount { progressCount = newCount }
            // Delay so the user sees the green/red pill before sliding to next
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
        // Plist polling timer — only active when items have plistKey configured
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            if hasPlistMonitoring && currentPhase == .main {
                checkPlistStatuses()
            }
        }
    }

    // MARK: - Main Phase

    private var mainPhaseView: some View {
        VStack(spacing: 6) {
            // Item row — this content slides on item change
            HStack(spacing: 8) {
                // Left chevron — browse to previous item
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

                cachedIcon(
                    for: currentItem.flatMap { iconCache.getItemIconPath(for: $0, state: inspectState) } ?? "",
                    fallbackSymbol: "app.fill"
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentItem?.displayName ?? inspectState.config?.title ?? "Installing...")
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
                            Text("\(inspectState.completedItems.count) of \(inspectState.items.count) completed")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if inspectState.items.count > 1 {
                            Text("\(currentItemIndex + 1)/\(inspectState.items.count)")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer(minLength: 4)

                // Status pill badge
                if let item = currentItem {
                    statusPill(for: item)
                }

                // Right chevron — browse to next item
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

            // Progress bar — driven by high-water-mark counter that never decreases
            if progressMode == "shared" {
                ProgressView(value: Double(progressCount), total: Double(max(inspectState.items.count, 1)))
                    .tint(primaryColor)
                    .padding(.horizontal, 20)
                    .animation(.easeInOut(duration: 0.4), value: progressCount)
            }
        }
    }

    // MARK: - Compact Intro Phase

    private var compactIntroView: some View {
        HStack(spacing: 14) {
            let heroPath = inspectState.config?.introScreen?.heroImage
                ?? inspectState.uiConfiguration.iconPath ?? ""
            toastIcon(path: heroPath, fallbackSymbol: "info.circle.fill")

            VStack(alignment: .leading, spacing: 2) {
                Text(inspectState.config?.introScreen?.title ?? inspectState.config?.title ?? "Welcome")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                if let subtitle = inspectState.config?.introScreen?.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                // Defer menu — shared deferral pattern (exit code 10, result file, ignitecli env)
                if inspectState.buttonConfiguration.button2Visible || isDeferralEnabled(config: inspectState.config) {
                    DeferralMenuView(
                        config: inspectState.config,
                        accentColor: primaryColor,
                        buttonText: inspectState.buttonConfiguration.button2Text.isEmpty
                            ? nil : inspectState.buttonConfiguration.button2Text,
                        style: .compact
                    )
                }

                Button(inspectState.config?.introScreen?.buttonText ?? "Continue") {
                    withAnimation(InspectConstants.stepTransition) {
                        currentPhase = .main
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(primaryColor)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Compact Report View (Plist Monitoring Mode)

    /// Shows all items at once as a compact check report with live-updating colored status
    private var compactReportView: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                let heroPath = inspectState.config?.introScreen?.heroImage
                    ?? inspectState.uiConfiguration.iconPath ?? ""
                toastIcon(path: heroPath, fallbackSymbol: "shield.checkered")

                VStack(alignment: .leading, spacing: 2) {
                    Text(inspectState.config?.title ?? "System Check")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    Text(reportProgressText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if allItemsTerminal {
                    Button(inspectState.config?.summaryScreen?.buttonText ?? "Done") {
                        writeLog("Preset4View: Report closed", logLevel: .info)
                        exit(0)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(primaryColor)
                    .controlSize(.small)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()
                .padding(.horizontal, 12)

            // Item list — compact rows with colored status
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(inspectState.items, id: \.id) { item in
                        reportItemRow(item)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    /// Report progress text — adapts as checks complete
    private var reportProgressText: String {
        if allItemsTerminal {
            let failedCount = inspectState.failedItems.count
            if failedCount > 0 {
                return "\(inspectState.completedItems.count) passed, \(failedCount) failed"
            }
            return "All \(inspectState.items.count) checks passed"
        }
        return "\(terminalCount) of \(inspectState.items.count) checks complete"
    }

    /// Single row in the check report — icon + name + status badge
    @ViewBuilder
    private func reportItemRow(_ item: InspectConfig.ItemConfig) -> some View {
        HStack(spacing: 8) {
            // Colored status icon
            reportItemStatusIcon(for: item)

            // Item icon (small)
            cachedIcon(
                for: iconCache.getItemIconPath(for: item, state: inspectState) ?? "",
                fallbackSymbol: "app.fill",
                size: 20
            )

            Text(item.displayName)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer()

            // Status badge
            Text(reportItemStatusText(for: item))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(reportItemStatusColor(for: item))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(reportItemStatusColor(for: item).opacity(0.12))
                )
        }
        .padding(.vertical, 3)
    }

    /// Status icon for report row
    @ViewBuilder
    private func reportItemStatusIcon(for item: InspectConfig.ItemConfig) -> some View {
        if inspectState.failedItems.contains(item.id) {
            StatusIconView(.failure, size: 14)
        } else if inspectState.completedItems.contains(item.id) {
            StatusIconView(.success, size: 14)
        } else {
            StatusIconView(.pending, size: 14)
        }
    }

    /// Status text for report badge
    private func reportItemStatusText(for item: InspectConfig.ItemConfig) -> String {
        if inspectState.failedItems.contains(item.id) {
            return "Failed"
        } else if inspectState.completedItems.contains(item.id) {
            return "Passed"
        } else {
            return "Pending"
        }
    }

    /// Status color for report badge
    private func reportItemStatusColor(for item: InspectConfig.ItemConfig) -> Color {
        if inspectState.failedItems.contains(item.id) {
            return .red
        } else if inspectState.completedItems.contains(item.id) {
            return .green
        } else {
            return .orange
        }
    }

    // MARK: - Compact Summary Phase

    private var compactSummaryView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                // Summary hero — config heroImage, or intro heroImage, or status icon
                summaryHeroIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(inspectState.config?.summaryScreen?.title ?? "Installation Complete")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    if let subtitle = inspectState.config?.summaryScreen?.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        summarySubtitleText
                    }
                }

                Spacer()

                Button(inspectState.config?.summaryScreen?.buttonText ?? "Close") {
                    writeLog("Preset4View: Summary closed", logLevel: .info)
                    exit(0)
                }
                .buttonStyle(.borderedProminent)
                .tint(primaryColor)
                .controlSize(.small)
            }

            // Per-item status strip — colored dots showing each item's result
            if !inspectState.items.isEmpty {
                HStack(spacing: 6) {
                    ForEach(inspectState.items, id: \.id) { item in
                        HStack(spacing: 3) {
                            itemStatusDot(for: item)
                            Text(shortName(item.displayName))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }

    /// Summary hero icon — uses summaryScreen heroImage, intro heroImage, config icon, or status icon fallback
    @ViewBuilder
    private var summaryHeroIcon: some View {
        let heroPath = inspectState.config?.summaryScreen?.heroImage
            ?? inspectState.config?.introScreen?.heroImage
            ?? inspectState.uiConfiguration.iconPath ?? ""

        if !heroPath.isEmpty {
            toastIcon(path: heroPath, fallbackSymbol: summaryFallbackSymbol)
        } else {
            // No hero configured — fall back to colored status icon
            let failedCount = inspectState.failedItems.count
            if failedCount == 0 {
                StatusIconView(.success, size: 36)
                    .frame(width: 48, height: 48)
            } else if failedCount < inspectState.items.count {
                StatusIconView(.warning, size: 36)
                    .frame(width: 48, height: 48)
            } else {
                StatusIconView(.failure, size: 36)
                    .frame(width: 48, height: 48)
            }
        }
    }

    /// SF Symbol name for summary fallback based on results
    private var summaryFallbackSymbol: String {
        let failedCount = inspectState.failedItems.count
        if failedCount == 0 { return "checkmark.circle.fill" }
        if failedCount < inspectState.items.count { return "exclamationmark.triangle.fill" }
        return "xmark.circle.fill"
    }

    /// Summary subtitle text with counts — adapts wording based on context
    private var summarySubtitleText: some View {
        let failedCount = inspectState.failedItems.count
        let passedCount = inspectState.completedItems.count
        let verb = hasPlistMonitoring ? "passed" : "installed"
        return Group {
            if failedCount > 0 {
                Text("\(passedCount) \(verb), \(failedCount) failed")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Text("\(passedCount) items \(verb) successfully")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Status Indicators

    /// Colored pill badge — "Pending" (orange), "Passed"/"Installed" (green), "Failed" (red), "Installing" (blue spinner)
    @ViewBuilder
    private func statusPill(for item: InspectConfig.ItemConfig) -> some View {
        let (text, color, showSpinner) = pillState(for: item)

        HStack(spacing: 4) {
            if showSpinner {
                ProgressView()
                    .controlSize(.mini)
                    .tint(color)
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
        // Use .id so SwiftUI crossfades between states instead of
        // morphing color/text/layout (which caused wobble).
        .id("\(item.id)-\(text)")
        .transition(.opacity)
    }

    /// Resolve pill text, color, and spinner state for an item
    private func pillState(for item: InspectConfig.ItemConfig) -> (String, Color, Bool) {
        if inspectState.failedItems.contains(item.id) {
            return ("Failed", .red, false)
        } else if inspectState.completedItems.contains(item.id) {
            return (hasPlistMonitoring ? "Passed" : "Installed", .green, false)
        } else if inspectState.downloadingItems.contains(item.id) {
            return ("Installing", .blue, true)
        } else {
            return ("Pending", .orange, false)
        }
    }

    /// Small colored dot for summary status strip
    @ViewBuilder
    private func itemStatusDot(for item: InspectConfig.ItemConfig) -> some View {
        if inspectState.failedItems.contains(item.id) {
            Circle().fill(Color.red).frame(width: 6, height: 6)
        } else if inspectState.completedItems.contains(item.id) {
            Circle().fill(Color.green).frame(width: 6, height: 6)
        } else {
            Circle().fill(Color.secondary.opacity(0.3)).frame(width: 6, height: 6)
        }
    }

    /// Shorten display name for compact summary strip
    private func shortName(_ name: String) -> String {
        // Remove common prefixes for compact display
        let shortened = name
            .replacingOccurrences(of: "Microsoft ", with: "")
        return shortened
    }

    // MARK: - Chevron Navigation

    private func navigateItem(_ direction: Int) {
        let newIndex = currentItemIndex + direction
        guard newIndex >= 0, newIndex < inspectState.items.count else { return }

        isUserNavigating = true
        currentItemIndex = newIndex

        // Resume auto-advance after 5 seconds of no manual navigation
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            isUserNavigating = false
        }
    }

    // MARK: - Icon helpers

    /// Synchronous icon from already-cached path — no loading spinner
    @ViewBuilder
    private func cachedIcon(for path: String, fallbackSymbol: String, size: CGFloat = 48) -> some View {
        let cornerRadius = size > 30 ? 10.0 : 5.0
        let symbolSize = size > 30 ? 28.0 : size * 0.6

        // SF Symbol icons (e.g. "SF=lock.shield.fill")
        if path.hasPrefix("SF=") {
            let symbolName = String(path.dropFirst(3))
            return AnyView(
                Image(systemName: symbolName)
                    .font(.system(size: symbolSize))
                    .foregroundStyle(primaryColor)
                    .frame(width: size, height: size)
            )
        }

        let resolvedPath = resolvePath(path)
        if let resolvedPath, let nsImage = NSImage(contentsOfFile: resolvedPath) {
            return AnyView(
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
        }

        return AnyView(
            Image(systemName: fallbackSymbol)
                .font(.system(size: symbolSize))
                .foregroundStyle(primaryColor.opacity(0.6))
                .frame(width: size, height: size)
        )
    }

    /// Async icon for intro (loads once, spinner acceptable)
    @ViewBuilder
    private func toastIcon(path: String, fallbackSymbol: String) -> some View {
        if !path.isEmpty {
            AsyncImageView(
                iconPath: path,
                basePath: basePath,
                maxWidth: 48,
                maxHeight: 48,
                imageFit: .fit
            ) {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: 28))
                    .foregroundStyle(primaryColor.opacity(0.6))
                    .frame(width: 48, height: 48)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: fallbackSymbol)
                .font(.system(size: 28))
                .foregroundStyle(primaryColor.opacity(0.6))
                .frame(width: 48, height: 48)
        }
    }

    /// Resolve relative path against basePath
    private func resolvePath(_ path: String) -> String? {
        guard !path.isEmpty else { return nil }
        if path.hasPrefix("/") { return path }
        guard let base = basePath else { return path }
        return (base as NSString).appendingPathComponent(path)
    }

    // MARK: - Plist Status Monitoring

    /// Poll plist files for item statuses (when items have plistKey configured)
    private func checkPlistStatuses() {
        for item in inspectState.items {
            guard !inspectState.completedItems.contains(item.id),
                  !inspectState.failedItems.contains(item.id),
                  let plistKey = item.plistKey else { continue }

            for path in item.paths {
                let resolvedPath = resolvePath(path) ?? path
                if let dict = PlistHelper.readPlistAsDict(at: resolvedPath) {
                    if let value = readNestedKey(from: dict, keyPath: plistKey) {
                        let stringValue = "\(value)"
                        let evaluation = item.evaluation ?? "exists"

                        if evaluatePlistValue(stringValue, expected: item.expectedValue, evaluation: evaluation) {
                            inspectState.completedItems.insert(item.id)
                            writeLog("Preset4View: Plist check passed for \(item.id) — \(plistKey)=\(stringValue)", logLevel: .info)
                        } else if isFailureValue(stringValue) {
                            inspectState.failedItems.insert(item.id)
                            writeLog("Preset4View: Plist check failed for \(item.id) — \(plistKey)=\(stringValue)", logLevel: .info)
                        }
                    }
                }
            }
        }
    }

    /// Check if a plist value indicates explicit failure
    private func isFailureValue(_ value: String) -> Bool {
        let failureKeywords = ["failed", "error", "disabled", "fail", "false", "no", "blocked", "denied", "outdated", "missing"]
        return failureKeywords.contains(value.lowercased())
    }

    /// Read a dot-notation key path from a dictionary (e.g., "Settings.Network.enabled")
    private func readNestedKey(from dict: [String: Any], keyPath: String) -> Any? {
        let keys = keyPath.split(separator: ".").map(String.init)
        var current: Any = dict
        for key in keys {
            guard let currentDict = current as? [String: Any],
                  let next = currentDict[key] else { return nil }
            current = next
        }
        return current
    }

    /// Evaluate a plist value against expected using the given evaluation type
    private func evaluatePlistValue(_ actual: String, expected: String?, evaluation: String) -> Bool {
        switch evaluation {
        case "exists":
            return true
        case "boolean":
            return ["true", "1", "yes"].contains(actual.lowercased())
        case "equals":
            return actual == (expected ?? "")
        case "contains":
            return actual.localizedCaseInsensitiveContains(expected ?? "")
        default:
            return true
        }
    }

    // MARK: - Deferral (uses shared performDeferral() from PresetCommonHelpers)

    // MARK: - Auto-Advance Logic

    private func advanceToNextItem() {
        guard currentPhase == .main, !inspectState.items.isEmpty else { return }
        // Don't auto-advance while user is manually navigating
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
        // Transition when all items are terminal (completed + failed)
        guard allItemsTerminal else { return }

        if inspectState.config?.summaryScreen != nil {
            withAnimation(InspectConstants.stepTransition) {
                currentPhase = .summary
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                writeLog("Preset4View: All items complete, auto-exiting", logLevel: .info)
                exit(0)
            }
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
