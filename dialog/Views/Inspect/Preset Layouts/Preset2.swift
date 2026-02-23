//
//  Preset2.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//
//  Card-based display with carousel navigation, option for banner image
//

import SwiftUI

struct Preset2View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @State private var showingAboutPopover = false
    @State private var showDetailOverlay = false
    @State private var showItemDetailOverlay = false
    @State private var selectedItemForDetail: InspectConfig.ItemConfig?
    @StateObject private var iconCache = PresetIconCache()
    @State private var localizationService = LocalizationService()
    @State private var scrollOffset: Int = 0
    @State private var lastDownloadingItem: String?
    @State private var currentPhase: PresetPhase = .main

    /// Highlight color derived from config
    private var primaryColor: Color {
        Color(hex: inspectState.uiConfiguration.highlightColor)
    }

    init(inspectState: InspectState) {
        self.inspectState = inspectState
    }

    var body: some View {
        Group {
            switch currentPhase {
            case .intro:
                if let introConfig = inspectState.config?.introScreen {
                    PresetIntroScreenView(
                        config: introConfig,
                        highlightColor: primaryColor,
                        scaleFactor: scaleFactor,
                        basePath: inspectState.uiConfiguration.iconBasePath,
                        inspectState: inspectState,
                        onContinue: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPhase = .main
                            }
                        }
                    )
                    .background(Color(NSColor.windowBackgroundColor))
                }
            case .main:
                mainPhaseView
            case .summary:
                if let summaryConfig = inspectState.config?.summaryScreen {
                    PresetSummaryScreenView(
                        config: summaryConfig,
                        highlightColor: primaryColor,
                        scaleFactor: scaleFactor,
                        basePath: inspectState.uiConfiguration.iconBasePath,
                        inspectState: inspectState,
                        onClose: {
                            writeLog("Preset2View: Summary screen closed", logLevel: .info)
                            exit(0)
                        }
                    )
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }
        }
        .onAppear {
            if inspectState.config?.introScreen != nil {
                currentPhase = .intro
            }
        }
        .onChange(of: inspectState.completedItems.count) { _, _ in
            checkAutoTransitionToSummary()
        }
        .onChange(of: currentPhase) { _, newPhase in
            if newPhase == .main {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    checkAutoTransitionToSummary()
                }
            }
        }
    }

    /// Check if all items are complete and auto-transition to summary
    private func checkAutoTransitionToSummary() {
        guard currentPhase == .main,
              let summaryConfig = inspectState.config?.summaryScreen,
              summaryConfig.autoTransition != false,
              !inspectState.items.isEmpty,
              inspectState.completedItems.count == inspectState.items.count else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPhase = .summary
        }
    }

    /// When summaryScreen is configured, button1 transitions to summary instead of exit(0).
    /// Returns nil when no summary → default exit(0) behavior.
    private var summaryScreenButtonAction: (() -> Void)? {
        guard inspectState.config?.summaryScreen != nil else { return nil }
        return {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPhase = .summary
            }
        }
    }

    // MARK: - Main Phase (Original Preset2 Layout)

    private var mainPhaseView: some View {
        VStack(spacing: 0) {
            // Top section - either banner or icon
            if inspectState.uiConfiguration.bannerImage != nil {
                // Banner display
                ZStack {
                    if let bannerNSImage = iconCache.bannerImage {
                        Image(nsImage: bannerNSImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: windowSize.width, height: CGFloat(inspectState.uiConfiguration.bannerHeight))
                            .clipped()

                        // Optional title overlay on banner
                        if let bannerTitle = localized("bannerTitle", fallback: inspectState.uiConfiguration.bannerTitle) {
                            Text(bannerTitle)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.5), radius: 3, x: 2, y: 2)
                        }
                    }
                }
                .frame(width: windowSize.width, height: CGFloat(inspectState.uiConfiguration.bannerHeight))
                .onAppear { iconCache.cacheBannerImage(for: inspectState) }

                // Title below banner
                Text(localized("title", fallback: inspectState.uiConfiguration.windowTitle) ?? "")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 20 * scaleFactor)
                    .padding(.bottom, 20 * scaleFactor)
            } else {
                // Original icon display (when no banner is set)
                VStack(spacing: 20 * scaleFactor) {
                    // Main icon - DOMINANT visual element with FIXED height
                    IconView(
                        image: getMainIconPath(),
                        overlay: iconCache.getOverlayIconPath(for: inspectState),
                        defaultImage: "briefcase.fill",
                        defaultColour: "accent"
                    )
                    .frame(height: 120 * scaleFactor)
                    .onAppear { iconCache.cacheMainIcon(for: inspectState) }

                    // Title - positioned below icon, centered
                    Text(localized("title", fallback: inspectState.uiConfiguration.windowTitle) ?? "")
                        .font(.system(size: 26, weight: .bold))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40 * scaleFactor)
            }

            // Rotating side messages - always visible
            if let currentMessage = localizedSideMessage() {
                Text(currentMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 50 * scaleFactor)
                    .frame(minHeight: 45 * scaleFactor)
                    .animation(.easeInOut(duration: InspectConstants.standardAnimationDuration), value: inspectState.uiConfiguration.currentSideMessageIndex)
            }

            // App cards with navigation arrows
            VStack(spacing: 6 * scaleFactor) {
                let visibleCount = sizeMode == "compact" ? 4 : (sizeMode == "large" ? 6 : 5)
                let allItemsFit = inspectState.items.count <= visibleCount

                HStack(spacing: 16 * scaleFactor) {
                    // Left arrow (hidden when all items fit)
                    if !allItemsFit {
                        Button(action: {
                            scrollLeft()
                        }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 28 * scaleFactor))
                                .foregroundStyle(canScrollLeft() ? Color(hex: inspectState.uiConfiguration.highlightColor) : .gray.opacity(0.3))
                        }
                        .disabled(!canScrollLeft())
                        .buttonStyle(PlainButtonStyle())
                    }

                    // App cards - show 5 at a time
                    HStack(spacing: 12 * scaleFactor) {
                        ForEach(getVisibleItemsWithOffset(), id: \.id) { item in
                            Preset2ItemCardView(
                                item: item,
                                isCompleted: inspectState.completedItems.contains(item.id),
                                isDownloading: inspectState.downloadingItems.contains(item.id),
                                isFailed: inspectState.failedItems.contains(item.id),
                                highlightColor: inspectState.uiConfiguration.highlightColor,
                                scale: scaleFactor,
                                resolvedIconPath: getIconPathForItem(item),
                                inspectState: inspectState,
                                localizedDisplayName: localizedDisplayName(for: item),
                                localizedStatusOverride: localizedStatusText(for: item),
                                onInfoTapped: {
                                    selectedItemForDetail = item
                                    showItemDetailOverlay = true
                                }
                            )
                        }

                        // Fill remaining slots with placeholder cards when scrolling
                        if !allItemsFit {
                            ForEach(0..<max(0, visibleCount - getVisibleItemsWithOffset().count), id: \.self) { _ in
                                Preset2PlaceholderCardView(scale: scaleFactor)
                            }
                        }
                    }
                    .animation(.easeInOut(duration: InspectConstants.standardAnimationDuration), value: scrollOffset)
                    .animation(.easeInOut(duration: InspectConstants.longAnimationDuration), value: inspectState.completedItems.count)
                    .animation(.easeInOut(duration: InspectConstants.longAnimationDuration), value: inspectState.downloadingItems.count)
                    .onChange(of: inspectState.downloadingItems) { _, _ in
                        updateScrollForProgress()
                    }
                    .onChange(of: inspectState.completedItems) { _, _ in
                        updateScrollForProgress()
                    }

                    // Right arrow (hidden when all items fit)
                    if !allItemsFit {
                        Button(action: {
                            scrollRight()
                        }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 28 * scaleFactor))
                                .foregroundStyle(canScrollRight() ? Color(hex: inspectState.uiConfiguration.highlightColor) : .gray.opacity(0.3))
                        }
                        .disabled(!canScrollRight())
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 40 * scaleFactor)
            }
            .padding(.top, 16)

            Spacer()
                //.frame(maxHeight: 30 * scaleFactor)

            // Bottom progress section
            VStack(spacing: 12) {
                // Progress bar
                ProgressView(value: Double(inspectState.completedItems.count), total: Double(inspectState.items.count))
                    .progressViewStyle(.linear)
                    .frame(width: 600 * scaleFactor)
                    .tint(Color(hex: inspectState.uiConfiguration.highlightColor))

                // Progress text (customizable via uiLabels.progressFormat)
                Text(getProgressText())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16 * scaleFactor)

            // Bottom section — info link left, buttons right
            HStack {
                // Info link on the left
                Button(inspectState.uiConfiguration.popupButtonText) {
                    showingAboutPopover.toggle()
                }
                .buttonStyle(.plain)
                .foregroundStyle(primaryColor)
                .font(.system(size: 13))
                .popover(isPresented: $showingAboutPopover) {
                    InstallationInfoPopoverView(inspectState: inspectState)
                }

                Spacer()

                // Action buttons on the right
                HStack(spacing: 12) {
                    // About button or Button2 if configured
                    if inspectState.buttonConfiguration.button2Visible {
                        Button(action: {
                            // Check if we're in demo mode and button says "Create Config"
                            if inspectState.configurationSource == .testData && inspectState.buttonConfiguration.button2Text == "Create Config" {
                                writeLog("Preset2LayoutServiceBased: Creating sample configuration", logLevel: .info)
                                inspectState.createSampleConfiguration()
                            } else {
                                // Normal button2 action - typically quits with code 2
                                writeLog("Preset2LayoutServiceBased: User clicked button2", logLevel: .info)
                                exit(2)
                            }
                        }) {
                            Text(inspectState.buttonConfiguration.button2Text)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        // Show immediately in demo mode, otherwise show when complete
                        .opacity((inspectState.configurationSource == .testData || inspectState.completedItems.count == inspectState.items.count) ? 1.0 : 0.0)
                    }

                    // Main action button - uses finalButtonText with fallback chain
                    let finalButtonText = inspectState.config?.finalButtonText ??
                                         inspectState.config?.button1Text ??
                                         (inspectState.buttonConfiguration.button1Text.isEmpty ? "Continue" : inspectState.buttonConfiguration.button1Text)

                    Button(action: {
                        if let action = summaryScreenButtonAction {
                            writeLog("Preset2View: User clicked button1 (\(finalButtonText)) - transition to summary", logLevel: .info)
                            action()
                        } else {
                            writeLog("Preset2View: User clicked button1 (\(finalButtonText)) - exiting with code 0", logLevel: .info)
                            exit(0)
                        }
                    }) {
                        Text(finalButtonText)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(primaryColor)
                    .disabled(inspectState.buttonConfiguration.button1Disabled)
                    .opacity(inspectState.buttonConfiguration.button1Disabled ? 0.0 : 1.0)
                }
            }
            .padding(.horizontal, 40 * scaleFactor)
            .padding(.bottom, 24 * scaleFactor)
        }
        //.frame(width: windowSize.width, height: windowSize.height)
        .background(Color(NSColor.windowBackgroundColor))
        .ignoresSafeArea()
        .overlay {
            // Help button (positioned according to config)
            // Supports action types: overlay (default), url, custom
            if let helpButtonConfig = inspectState.config?.helpButton,
               helpButtonConfig.enabled ?? true {
                PositionedHelpButton(
                    config: helpButtonConfig,
                    action: {
                        handleHelpButtonAction(
                            config: helpButtonConfig,
                            showOverlay: $showDetailOverlay
                        )
                    },
                    padding: 16
                )
            }
        }
        .detailOverlay(
            inspectState: inspectState,
            isPresented: $showDetailOverlay,
            config: inspectState.config?.detailOverlay
        )
        .itemDetailOverlay(
            inspectState: inspectState,
            isPresented: $showItemDetailOverlay,
            item: selectedItemForDetail
        )
        .onAppear {
            if let locConfig = inspectState.config?.localization {
                let basePath = inspectState.uiConfiguration.iconBasePath ?? ""
                localizationService.loadLanguages(from: locConfig, basePath: basePath)
            }
            writeLog("Preset2LayoutServiceBased: Using InspectState", logLevel: .info)
        }
    }

    // MARK: - Localization

    /// The auto-detected or hardcoded default language (no picker in Preset2)
    private var effectiveLanguage: String? {
        guard let locConfig = inspectState.config?.localization else { return nil }
        return localizationService.resolveDefaultLanguage(from: locConfig)
    }

    /// Resolve a localized string, falling back to the provided default
    private func localized(_ key: String, fallback: String?) -> String? {
        guard let lang = effectiveLanguage else { return fallback }
        return localizationService.string(forLanguage: lang, key: key) ?? fallback
    }

    /// Resolve a localized string array, falling back to the provided default
    private func localizedArray(_ key: String, fallback: [String]?) -> [String]? {
        guard let lang = effectiveLanguage else { return fallback }
        return localizationService.stringArray(forLanguage: lang, key: key) ?? fallback
    }

    /// Get the current side message with localization applied
    private func localizedSideMessage() -> String? {
        let messages = localizedArray("sideMessages", fallback: inspectState.uiConfiguration.sideMessages) ?? inspectState.uiConfiguration.sideMessages
        guard !messages.isEmpty else { return nil }
        let index = min(inspectState.uiConfiguration.currentSideMessageIndex, messages.count - 1)
        return messages[index]
    }

    /// Get localized display name for an item
    private func localizedDisplayName(for item: InspectConfig.ItemConfig) -> String {
        localized("\(item.id).displayName", fallback: item.displayName) ?? item.displayName
    }

    /// Get localized status text for an item
    private func localizedStatusText(for item: InspectConfig.ItemConfig) -> String? {
        guard effectiveLanguage != nil else { return nil }
        if inspectState.failedItems.contains(item.id) {
            return localized("\(item.id).failedStatus", fallback: nil)
                ?? localized("failedStatus", fallback: nil)
        } else if inspectState.completedItems.contains(item.id) {
            return localized("\(item.id).completedStatus", fallback: nil)
                ?? localized("completedStatus", fallback: nil)
        } else if inspectState.downloadingItems.contains(item.id) {
            return localized("\(item.id).downloadingStatus", fallback: nil)
                ?? localized("downloadingStatus", fallback: nil)
        } else {
            return localized("\(item.id).pendingStatus", fallback: nil)
                ?? localized("pendingStatus", fallback: nil)
        }
    }

    // MARK: - Navigation Methods

    private func canScrollLeft() -> Bool {
        scrollOffset > 0
    }

    private func canScrollRight() -> Bool {
        let visibleCount = sizeMode == "compact" ? 4 : (sizeMode == "large" ? 6 : 5)
        return scrollOffset + visibleCount < inspectState.items.count
    }

    private func scrollLeft() {
        if canScrollLeft() {
            scrollOffset = max(0, scrollOffset - 1)  // Shift by 1 for smoother navigation
        }
    }

    private func scrollRight() {
        if canScrollRight() {
            let visibleCount = sizeMode == "compact" ? 4 : (sizeMode == "large" ? 6 : 5)
            scrollOffset = min(inspectState.items.count - visibleCount, scrollOffset + 1)  // Shift by 1
        }
    }

    private func getVisibleItemsWithOffset() -> [InspectConfig.ItemConfig] {
        // Adjust visible cards based on size mode
        let visibleCount: Int
        switch sizeMode {
        case "compact": visibleCount = 4  // increased from 3 to 4
        case "large": visibleCount = 6
        default: visibleCount = 5  // standard - increased from 4 to 5
        }

        let startIndex = scrollOffset
        let endIndex = min(startIndex + visibleCount, inspectState.items.count)

        if startIndex >= inspectState.items.count {
            return []
        }

        return Array(inspectState.items[startIndex..<endIndex])
    }

    // MARK: - Icon Management

    private func getMainIconPath() -> String {
        return iconCache.getMainIconPath(for: inspectState)
    }




    private func getIconPathForItem(_ item: InspectConfig.ItemConfig) -> String {
        return iconCache.getItemIconPath(for: item, state: inspectState)
    }

    // MARK: - Auto-centering for downloading items

    private func updateScrollForProgress() {
        // Switch here to find the currently downloading item
        guard let downloadingItem = inspectState.downloadingItems.first,
              let downloadingIndex = inspectState.items.firstIndex(where: { $0.id == downloadingItem }) else {
            return
        }

        let visibleCount = sizeMode == "compact" ? 4 : (sizeMode == "large" ? 6 : 5)

        // Optimized try to keep downloading item in view position (index 1) when possible
        // Ther ordewr should be: [1 completed] [downloading] [penidng] [pending]...
        let preferredPositionFromLeft = 1

        // Calc offset to place downloading item at preferred position
        var targetOffset = downloadingIndex - preferredPositionFromLeft

        // Set up valid range
        targetOffset = max(0, targetOffset)  // We try to don't scroll before start
        targetOffset = min(targetOffset, max(0, inspectState.items.count - visibleCount))  // Don't scroll past end - needs observation if this works better

        // Scroll to target position if different
        if targetOffset != scrollOffset {
            withAnimation(.easeInOut(duration: 0.6)) {
                scrollOffset = targetOffset
            }

            // Update here for next change
            lastDownloadingItem = downloadingItem
        }
    }

    /// Get progress bar text with template support
    private func getProgressText() -> String {
        let completed = inspectState.completedItems.count
        let total = inspectState.items.count

        // Try localized progress format first, then config, then default
        let template = localized("progressFormat", fallback: inspectState.config?.uiLabels?.progressFormat)

        if let template {
            return template
                .replacingOccurrences(of: "{completed}", with: "\(completed)")
                .replacingOccurrences(of: "{total}", with: "\(total)")
        }

        return "\(completed) of \(total) completed"
    }
}

// MARK: - Enhanced Card Views for Preset2

private struct Preset2ItemCardView: View {
    let item: InspectConfig.ItemConfig
    let isCompleted: Bool
    let isDownloading: Bool
    let isFailed: Bool
    let highlightColor: String
    let scale: CGFloat
    let resolvedIconPath: String
    let inspectState: InspectState
    let localizedDisplayName: String
    let localizedStatusOverride: String?
    let onInfoTapped: (() -> Void)?

    init(item: InspectConfig.ItemConfig, isCompleted: Bool, isDownloading: Bool, isFailed: Bool = false, highlightColor: String, scale: CGFloat, resolvedIconPath: String, inspectState: InspectState, localizedDisplayName: String? = nil, localizedStatusOverride: String? = nil, onInfoTapped: (() -> Void)? = nil) {
        self.item = item
        self.isCompleted = isCompleted
        self.isDownloading = isDownloading
        self.isFailed = isFailed
        self.highlightColor = highlightColor
        self.scale = scale
        self.resolvedIconPath = resolvedIconPath
        self.inspectState = inspectState
        self.localizedDisplayName = localizedDisplayName ?? item.displayName
        self.localizedStatusOverride = localizedStatusOverride
        self.onInfoTapped = onInfoTapped
    }

    private var hasValidationWarning: Bool {
        // Only check validation for completed items
        guard isCompleted else { return false }
        
        // Check if item has any plist validation configuration
        let hasPlistValidation = item.plistKey != nil || 
                               inspectState.plistSources?.contains(where: { source in
                                   item.paths.contains(source.path)
                               }) == true
        
        // If item has plist validation, check the results
        if hasPlistValidation {
            return !(inspectState.plistValidationResults[item.id] ?? true)
        }
        
        return false
    }

    private func getStatusText() -> String {
        // Priority 1: Log monitor status (includes failure messages)
        if let logStatus = inspectState.logMonitorStatuses[item.id] {
            return logStatus
        }

        // Priority 2: Localized status override
        if let override = localizedStatusOverride {
            return override
        }

        if isFailed {
            // Use custom failed status if available
            return inspectState.config?.uiLabels?.failedStatus ?? "Failed"
        } else if isCompleted {
            if hasValidationWarning {
                // Use custom validation warning text if available, otherwise default
                return inspectState.config?.uiLabels?.failedStatus ?? "Failed"
            } else {
                // Use the new customization system for completed status
                if let customStatus = item.completedStatus {
                    return customStatus
                } else if let globalStatus = inspectState.config?.uiLabels?.completedStatus {
                    return globalStatus
                } else {
                    return "Completed"
                }
            }
        } else if isDownloading {
            // Use the new customization system for downloading status
            if let customStatus = item.downloadingStatus {
                return customStatus
            } else if let globalStatus = inspectState.config?.uiLabels?.downloadingStatus {
                return globalStatus
            } else {
                return "Installing..."
            }
        } else {
            // Use the new customization system for pending status
            if let customStatus = item.pendingStatus {
                return customStatus
            } else if let globalStatus = inspectState.config?.uiLabels?.pendingStatus {
                return globalStatus
            } else {
                return "Waiting"
            }
        }
    }

    private func getStatusColor() -> Color {
        if isFailed {
            return .red
        } else if isCompleted {
            return hasValidationWarning ? .orange : .green
        } else if isDownloading {
            return .blue
        } else {
            return .gray
        }
    }

    var body: some View {
        VStack(spacing: 4 * scale) {
            // Icon with status overlay — fixed height so text below doesn't shift it
            ZStack {
                // Item icon - larger size
                IconView(image: resolvedIconPath, defaultImage: "app.fill", defaultColour: "accent")
                    .frame(width: 90 * scale, height: 90 * scale)
                    .clipShape(.rect(cornerRadius: 16 * scale))

                // Info button overlay (top-left) - only show if detailOverlay or itemOverlay is configured
                if onInfoTapped != nil && (inspectState.config?.detailOverlay != nil || item.itemOverlay != nil) {
                    VStack {
                        HStack {
                            Button(action: {
                                onInfoTapped?()
                            }) {
                                ZStack {
                                    Circle()
                                        .foregroundStyle(.white.opacity(0.8))
                                    Image(systemName: "info")
                                        .font(.system(size: 8 * scale, weight: .semibold))
                                        .foregroundStyle(.blue)
                                }
                                .frame(width: 18 * scale, height: 18 * scale)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Show item information")

                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(4 * scale)
                }

                // Status indicator overlay (top-right)
                VStack {
                    HStack {
                        Spacer()
                        if isFailed {
                            // Red circle with X for failed
                            Circle()
                                .fill(Color.red)
                                .frame(width: 26 * scale, height: 26 * scale)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12 * scale, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                                .help("Installation failed")
                        } else if isCompleted {
                            Circle()
                                .fill(hasValidationWarning ? Color.orange : Color.green)
                                .frame(width: 26 * scale, height: 26 * scale)
                                .overlay(
                                    Image(systemName: hasValidationWarning ? "exclamationmark" : "checkmark")
                                        .font(.system(size: 12 * scale, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                                .help(hasValidationWarning ?
                                      "Configuration validation failed - check plist settings" :
                                      "\(getStatusText()) and validated")
                        } else if isDownloading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(Color(hex: highlightColor))
                                .frame(width: 26 * scale, height: 26 * scale)
                        }
                    }
                    Spacer()
                }
                .padding(2 * scale)
            }
            .frame(height: 90 * scale)

            // App name and status — fixed height to prevent icon shifting
            VStack(spacing: 2 * scale) {
                Text(localizedDisplayName)
                    .font(.system(size: 12 * scale, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isDownloading ? Color(hex: highlightColor) : .primary)

                // Status text
                Text(getStatusText())
                    .font(.system(size: 9 * scale))
                    .foregroundStyle(getStatusColor())

                // Bundle info subtitle (version, identifier, etc.)
                if let bundleInfo = inspectState.getBundleInfoForItem(item) {
                    Text(bundleInfo)
                        .font(.system(size: 8 * scale))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: 110 * scale)
            .frame(height: 50 * scale)
        }
        .frame(width: 130 * scale, height: 160 * scale)
        .padding(6 * scale)
        .background(
            RoundedRectangle(cornerRadius: 10 * scale)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10 * scale)
                        .stroke(isDownloading ? Color(hex: highlightColor).opacity(0.5) : Color.gray.opacity(0.15),
                               lineWidth: isDownloading ? 1.5 : 1)
                )
        )
        .opacity(isCompleted ? 1.0 : (isDownloading ? 1.0 : 0.75))
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
        .animation(.easeInOut(duration: 0.3), value: isDownloading)
    }
}

private struct Preset2PlaceholderCardView: View {
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 4 * scale) {
            RoundedRectangle(cornerRadius: 14 * scale)
                .fill(Color.gray.opacity(0.05))
                .frame(width: 72 * scale, height: 72 * scale)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.05))
                .frame(width: 70 * scale, height: 10 * scale)
        }
        .frame(width: 110 * scale, height: 120 * scale)
        .padding(6 * scale)
    }
}

// MARK: - Item Info Popover

private struct ItemInfoPopoverView: View {
    let item: InspectConfig.ItemConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with item name
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)

                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            Divider()

            // Installation paths info
            if !item.paths.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Installation Paths")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(item.paths, id: \.self) { path in
                        HStack(alignment: .top, spacing: 6) {
                            Text("→")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 12, alignment: .leading)

                            Text(path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            } else {
                Text("No additional installation details available.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
