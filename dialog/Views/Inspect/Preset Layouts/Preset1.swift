//
//  Preset1.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//
//  Classic sidebar layout with FSevents based progress tracking
//  
//

import SwiftUI

struct Preset1View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @State private var showingAboutPopover = false
    @State private var showDetailOverlay = false
    @State private var showItemDetailOverlay = false
    @State private var selectedItemForDetail: InspectConfig.ItemConfig?
    @StateObject private var iconCache = PresetIconCache()
    @State private var localizationService = LocalizationService()
    @State private var currentPhase: PresetPhase = .main

    let systemImage: String = isLaptop ? "laptopcomputer.and.arrow.down" : "desktopcomputer.and.arrow.down"

    /// Highlight color derived from config (matches Preset2 pattern)
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
                    .frame(width: windowSize.width, height: windowSize.height)
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
                            writeLog("Preset1View: Summary screen closed", logLevel: .info)
                            exit(0)
                        }
                    )
                    .frame(width: windowSize.width, height: windowSize.height)
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }
        }
        .onAppear {
            // Start on intro phase if configured
            if inspectState.config?.introScreen != nil {
                currentPhase = .intro
            }
        }
        .onChange(of: inspectState.completedItems.count) { _, _ in
            checkAutoTransitionToSummary()
        }
        .onChange(of: currentPhase) { _, newPhase in
            // When entering main, check if items already completed during intro
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

    // MARK: - Main Phase (Original Preset1 Layout)

    private var mainPhaseView: some View {
        HStack(spacing: 0) {
            // Left sidebar with icon/image
            VStack {
                Spacer()
                    .frame(height: 20)  // Top-align icon with title area

                IconView(
                    image: iconCache.getMainIconPath(for: inspectState),
                    overlay: iconCache.getOverlayIconPath(for: inspectState),
                    defaultImage: "apps.iphone.badge.plus",
                    defaultColour: "accent"
                )
                .frame(width: 220 * scaleFactor, height: 220 * scaleFactor)
                .onAppear { iconCache.cacheMainIcon(for: inspectState) }

                // Progress bar
                if !inspectState.items.isEmpty {
                    PresetCommonViews.progressBar(
                        state: inspectState,
                        width: 200 * scaleFactor,
                        labelSize: 13,
                        tintColor: primaryColor
                    )
                    .padding(.top, 20 * scaleFactor)
                }

                Spacer()

                // Install info button - shows sheet if detailOverlay configured, otherwise popover
                Button(inspectState.uiConfiguration.popupButtonText) {
                    if inspectState.config?.detailOverlay != nil {
                        showDetailOverlay = true
                    } else {
                        showingAboutPopover.toggle()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(primaryColor)
                .font(.body)
                .padding(.bottom, 20 * scaleFactor)
                .popover(isPresented: $showingAboutPopover, arrowEdge: .top) {
                    InstallationInfoPopoverView(inspectState: inspectState)
                }
            }
            .frame(width: 280 * scaleFactor)
            .padding(.vertical)
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .background(Color(NSColor.controlBackgroundColor))

            // Right content area
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text(localized("title", fallback: inspectState.uiConfiguration.windowTitle) ?? "")
                        .font(.system(size: 26, weight: .bold))
                    Spacer()

                    PresetCommonViews.buttonArea(
                        state: inspectState,
                        tintColor: primaryColor,
                        onButton1Action: summaryScreenButtonAction
                    )
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if let currentMessage = localizedSideMessage() {
                    Text(currentMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .frame(minHeight: 50)
                        .animation(.easeInOut(duration: 0.5), value: inspectState.uiConfiguration.currentSideMessageIndex)
                }

                Divider()

                // Item list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let sortedItems = PresetCommonViews.getSortedItemsByStatus(inspectState)
                        ForEach(sortedItems, id: \.id) { item in
                            // Add group separator if needed
                            if shouldShowGroupSeparator(for: item, in: sortedItems) {
                                HStack {
                                    Text(getStatusHeaderText(for: getItemStatusType(for: item)))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top, 10 * scaleFactor)
                                .padding(.bottom, 5 * scaleFactor)
                            }

                            itemRow(for: item)
                        }
                    }
                    .padding(.vertical, 10 * scaleFactor)
                }

                Divider()

                // Status bar
                HStack {
                    Text(inspectState.uiConfiguration.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .background(Color(NSColor.windowBackgroundColor))
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
            writeLog("Preset1View: Using refactored InspectState", logLevel: .info)
        }
    }

    // MARK: - Localization

    /// The auto-detected or hardcoded default language (no picker in Preset1)
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

    /// Get localized item status text (completed/downloading/pending/failed)
    private func localizedItemStatus(for item: InspectConfig.ItemConfig) -> String {
        let baseStatus = getItemStatusWithValidation(for: item)
        guard effectiveLanguage != nil else { return baseStatus }

        // Try item-specific status key first, then global status keys
        if inspectState.completedItems.contains(item.id) {
            return localized("\(item.id).completedStatus", fallback: nil)
                ?? localized("completedStatus", fallback: nil)
                ?? baseStatus
        } else if inspectState.downloadingItems.contains(item.id) {
            return localized("\(item.id).downloadingStatus", fallback: nil)
                ?? localized("downloadingStatus", fallback: nil)
                ?? baseStatus
        } else if inspectState.failedItems.contains(item.id) {
            return localized("\(item.id).failedStatus", fallback: nil)
                ?? localized("failedStatus", fallback: nil)
                ?? baseStatus
        } else {
            return localized("\(item.id).pendingStatus", fallback: nil)
                ?? localized("pendingStatus", fallback: nil)
                ?? baseStatus
        }
    }

    /// Get the current side message with localization applied
    private func localizedSideMessage() -> String? {
        let messages = localizedArray("sideMessages", fallback: inspectState.uiConfiguration.sideMessages) ?? inspectState.uiConfiguration.sideMessages
        guard !messages.isEmpty else { return nil }
        let index = min(inspectState.uiConfiguration.currentSideMessageIndex, messages.count - 1)
        return messages[index]
    }

    // MARK: - Helper Methods

    @ViewBuilder
    private func itemRow(for item: InspectConfig.ItemConfig) -> some View {
        HStack(spacing: 12 * scaleFactor) {
            // Icon
            IconView(image: iconCache.getItemIconPath(for: item, state: inspectState))
                .frame(width: 48 * scaleFactor, height: 48 * scaleFactor)
                .aspectRatio(1, contentMode: .fit)
                .clipped()

            // Item info
            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                HStack(spacing: 4) {
                    Text(localized("\(item.id).displayName", fallback: item.displayName) ?? item.displayName)
                        .font(.system(size: 16 * scaleFactor, weight: .medium))
                        .foregroundStyle(.primary)

                    // Info button - only show if item has itemOverlay configured
                    if item.itemOverlay != nil {
                        Button(action: {
                            selectedItemForDetail = item
                            showItemDetailOverlay = true
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14 * scaleFactor))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("View details about \(item.displayName)")
                    }
                }

                Text(localizedItemStatus(for: item))
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(getItemStatusColor(for: item))

                // Bundle info subtitle (version, identifier, etc.)
                if let bundleInfo = inspectState.getBundleInfoForItem(item) {
                    Text(bundleInfo)
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Status indicator with validation support
            statusIndicatorWithValidation(for: item)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Sorting & Status

    private func getItemStatusType(for item: InspectConfig.ItemConfig) -> InspectItemStatus {
        if inspectState.failedItems.contains(item.id) { return .failed("") }
        if inspectState.completedItems.contains(item.id) { return .completed }
        if inspectState.downloadingItems.contains(item.id) { return .downloading }
        return .pending
    }

    private func shouldShowGroupSeparator(for item: InspectConfig.ItemConfig, in sortedItems: [InspectConfig.ItemConfig]) -> Bool {
        guard let index = sortedItems.firstIndex(where: { $0.id == item.id }), index > 0 else { return false }

        let previousItem = sortedItems[index - 1]
        let currentStatus = getItemStatusType(for: item)
        let previousStatus = getItemStatusType(for: previousItem)

        return currentStatus != previousStatus
    }

    private func getStatusHeaderText(for statusType: InspectItemStatus) -> String {
        let baseText: String
        switch statusType {
        case .completed:
            baseText = inspectState.config?.uiLabels?.sectionHeaderCompleted
                ?? inspectState.config?.uiLabels?.completedStatus
                ?? "Completed"
            return localized("sectionHeaderCompleted", fallback: baseText) ?? baseText
        case .downloading:
            if let header = inspectState.config?.uiLabels?.sectionHeaderPending {
                baseText = header
            } else {
                let downloadingText = inspectState.config?.uiLabels?.downloadingStatus ?? "Installing..."
                let cleanText = downloadingText.replacingOccurrences(of: "...", with: "")
                baseText = "Currently \(cleanText)"
            }
            return localized("sectionHeaderDownloading", fallback: baseText) ?? baseText
        case .pending:
            baseText = inspectState.config?.uiLabels?.sectionHeaderPending ?? "Pending Installation"
            return localized("sectionHeaderPending", fallback: baseText) ?? baseText
        case .failed:
            baseText = inspectState.config?.uiLabels?.sectionHeaderFailed ?? "Installation Failed"
            return localized("sectionHeaderFailed", fallback: baseText) ?? baseText
        }
    }

    // MARK: - Validation Support

    private func hasValidationWarning(for item: InspectConfig.ItemConfig) -> Bool {
        // Only check validation for completed items  
        guard inspectState.completedItems.contains(item.id) else { return false }
        
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

    private func getItemStatusWithValidation(for item: InspectConfig.ItemConfig) -> String {
        if inspectState.completedItems.contains(item.id) {
            if hasValidationWarning(for: item) {
                return inspectState.config?.uiLabels?.failedStatus ?? "Failed"
            } else {
                return getItemStatus(for: item)
            }
        } else {
            return getItemStatus(for: item)
        }
    }

    private func getItemStatusColor(for item: InspectConfig.ItemConfig) -> Color {
        if inspectState.failedItems.contains(item.id) {
            return .red
        } else if inspectState.completedItems.contains(item.id) {
            return hasValidationWarning(for: item) ? .orange : .green
        } else if inspectState.downloadingItems.contains(item.id) {
            return .blue
        } else {
            return .secondary
        }
    }

    @ViewBuilder
    private func statusIndicatorWithValidation(for item: InspectConfig.ItemConfig) -> some View {
        let size: CGFloat = 20 * scaleFactor

        if inspectState.failedItems.contains(item.id) {
            // Failed - show red X
            Circle()
                .fill(Color.red)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "xmark")
                        .font(.system(size: size * 0.6, weight: .bold))
                        .foregroundStyle(.white)
                )
                .help("Installation failed")
        } else if inspectState.completedItems.contains(item.id) {
            // Completed - check for validation warnings
            Circle()
                .fill(hasValidationWarning(for: item) ? Color.orange : Color.green)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: hasValidationWarning(for: item) ? "exclamationmark" : "checkmark")
                        .font(.system(size: size * 0.6, weight: .bold))
                        .foregroundStyle(.white)
                )
                .help(hasValidationWarning(for: item) ?
                      "Configuration validation failed - check plist settings" :
                      "Installed and validated")
        } else if inspectState.downloadingItems.contains(item.id) {
            // Downloading — tint with brand color
            ProgressView()
                .scaleEffect(0.7)
                .tint(primaryColor)
                .frame(width: size, height: size)
        } else {
            // Pending
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: size, height: size)
        }
    }
}