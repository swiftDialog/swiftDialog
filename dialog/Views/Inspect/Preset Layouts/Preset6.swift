//
//  Preset6.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 25/01/2026
//
//  Preset6: Modern Sidebar Variant
//  Modern sidebar navigation with Preset5-style clean design.
//
//  Features:
//  - Vertical sidebar navigation
//  - Clean, modern IntroStepContainer design
//  - GuidanceContent blocks for rich content display
//  - External command file monitoring
//  - Processing state machine support
//  - State persistence
//

import SwiftUI

// MARK: - Preset6 State Definition

struct Preset6State: InspectPersistableState {
    let completedSteps: Set<String>
    let currentStep: Int
    let guidanceFormInputs: [String: GuidanceFormInputState]
    let timestamp: Date
}

// MARK: - Navigation Direction

private enum NavigationDirection { case forward, backward }

// MARK: - Preset6 View

struct Preset6View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @Environment(\.palette) private var palette

    // MARK: - Module Services

    @StateObject private var dynamicState = InspectDynamicState()
    @StateObject private var complianceService = ComplianceAggregatorService()
    @StateObject private var introStepMonitor = IntroStepMonitorService()

    // MARK: - State Variables

    @State private var completedSteps: Set<String> = []
    @State private var downloadingItems: Set<String> = []
    @State private var currentStep: Int = 0
    @State private var navigationDirection: NavigationDirection = .forward
    @State private var processingState: InspectProcessingState = .idle
    @State private var processingCountdown: Int = 0
    @State private var processingTimer: Timer?
    @State private var failedSteps: [String: String] = [:]
    @State private var skippedSteps: Set<String> = []

    // MDM branding
    @State private var mdmOverrides: MDMBrandingOverrides?

    // File monitoring
    @State private var fileMonitorSource: DispatchSourceFileSystemObject?
    @State private var commandFileMonitorTimer: Timer?
    @State private var lastProcessedLineCount: Int = 0  // Line-offset tracking for trigger file (never clear, only advance)

    // Auto-navigation
    @State private var autoNavigationWorkItem: DispatchWorkItem?

    // Overlay state
    @State private var showDetailOverlay: Bool = false
    @State private var showItemDetailOverlay: Bool = false
    @State private var selectedItemForDetail: InspectConfig.ItemConfig?

    // Override dialog
    @State private var showOverrideDialog: Bool = false

    // Scroll hint overlay state (tracks content overflow for bottom fade indicator)
    @State private var contentPanelContentHeight: CGFloat = 0
    @State private var contentPanelScrollOffset: CGFloat = 0

    // Persistence
    private let persistenceService = InspectPersistence<Preset6State>(presetName: "preset6")

    // Localization
    @State private var localizationService = LocalizationService()

    // MARK: - Type Aliases

    typealias ProcessingState = InspectProcessingState
    typealias CompletionResult = InspectCompletionResult
    typealias OverrideLevel = InspectOverrideLevel

    // MARK: - Computed Properties

    private var branding: BrandingResolver {
        BrandingResolver(config: inspectState.config, mdmOverrides: mdmOverrides)
    }

    // MARK: - Localization

    /// The language code selected by the user (from a dropdown/radio in guidance content),
    /// falling back to the default language (auto-detected or hardcoded) if no manual selection exists.
    private var selectedLanguageCode: String? {
        if let manual = manualLanguageSelection { return manual }
        if let locConfig = inspectState.config?.localization {
            return localizationService.resolveDefaultLanguage(from: locConfig)
        }
        return nil
    }

    /// Manual language selection from form element (dropdown/radio)
    private var manualLanguageSelection: String? {
        let key = inspectState.config?.localization?.selectionKey ?? "preferredLanguage"
        guard let item = inspectState.items.first(where: { item in
            item.guidanceContent?.contains { $0.id == key } ?? false
        }),
        let formState = inspectState.guidanceFormInputs[item.id] else { return nil }
        return formState.dropdowns[key] ?? formState.radios[key]
    }

    /// Whether the current language was manually selected (vs auto-detected default)
    private var isManualLanguageSelection: Bool {
        manualLanguageSelection != nil
    }

    /// Index of the item that contains the language selection form element
    private var languagePickerStepIndex: Int? {
        let key = inspectState.config?.localization?.selectionKey ?? "preferredLanguage"
        return inspectState.items.firstIndex { item in
            item.guidanceContent?.contains { $0.id == key } ?? false
        }
    }

    /// Resolve a localized string for an item property.
    /// With manual selection: only applies to the picker step and steps after it.
    /// With default language (auto/hardcoded): applies to ALL items.
    private func localized(_ property: String, forItem item: InspectConfig.ItemConfig, fallback: String?) -> String? {
        guard let lang = selectedLanguageCode,
              localizationService.hasLanguage(lang) else {
            return fallback
        }
        if isManualLanguageSelection {
            guard let pickerIndex = languagePickerStepIndex,
                  let itemIndex = inspectState.items.firstIndex(where: { $0.id == item.id }),
                  itemIndex >= pickerIndex else {
                return fallback
            }
        }
        return localizationService.string(forLanguage: lang, key: "\(item.id).\(property)") ?? fallback
    }

    /// Copy a GuidanceContent block with localized text applied.
    /// With manual selection: only applies after the language picker step.
    /// With default language: applies to ALL items.
    private func localizedContentBlock(_ block: InspectConfig.GuidanceContent, itemId: String, blockIndex: Int) -> InspectConfig.GuidanceContent {
        guard let lang = selectedLanguageCode,
              localizationService.hasLanguage(lang) else { return block }
        if isManualLanguageSelection {
            guard let pickerIndex = languagePickerStepIndex,
                  let itemIndex = inspectState.items.firstIndex(where: { $0.id == itemId }),
                  itemIndex >= pickerIndex else { return block }
        }
        let prefix = "\(itemId).content.\(blockIndex)"
        var localized = block
        if let val = localizationService.string(forLanguage: lang, key: "\(prefix).content") { localized.content = val }
        if let val = localizationService.stringArray(forLanguage: lang, key: "\(prefix).items") { localized.items = val }
        if let val = localizationService.string(forLanguage: lang, key: "\(prefix).caption") { localized.caption = val }
        if let val = localizationService.string(forLanguage: lang, key: "\(prefix).helpText") { localized.helpText = val }
        if let val = localizationService.string(forLanguage: lang, key: "\(prefix).placeholder") { localized.placeholder = val }
        if let val = localizationService.string(forLanguage: lang, key: "\(prefix).label") { localized.label = val }
        return localized
    }

    /// Highlight color from config (MDM > JSON > uiConfiguration fallback)
    private var highlightColor: Color {
        if let hex = branding.effectiveHighlightColor ?? inspectState.uiConfiguration.highlightColor.nilIfEmpty {
            return Color(hex: hex)
        }
        return .accentColor
    }

    /// Fixed sidebar width — sized to avoid truncating step names like "Enrollment Status".
    /// This value is added to Preset5-equivalent content width to determine window size (see InspectSizes).
    private static let sidebarWidthConstant: CGFloat = 220

    private var sidebarWidth: CGFloat { Self.sidebarWidthConstant }

    /// Show step numbers in sidebar (default true)
    private var showStepNumbers: Bool {
        true  // Default to showing step numbers
    }

    /// Show completion marks in sidebar (default true)
    private var showCompletionMarks: Bool {
        true  // Default to showing completion marks
    }

    /// Current override level based on wait elapsed time
    private var currentOverrideLevel: OverrideLevel {
        OverrideLevel.level(for: processingState.waitElapsed)
    }

    /// Whether processing is currently active
    private var isProcessing: Bool {
        processingState.isActive
    }

    /// Whether navigation should be blocked during processing
    private var shouldBlockNavigation: Bool {
        guard isProcessing, let currentItem = inspectState.items[safe: currentStep] else {
            return false
        }
        let allowNav = currentItem.allowNavigationDuringProcessing ?? true
        return !allowNav
    }


    /// Whether current step is an intro step
    private var isIntroStep: Bool {
        guard let firstItem = inspectState.items.first else { return false }
        return currentStep == 0 && firstItem.stepType == "intro"
    }

    /// Whether current step is an outro step
    private var isOutroStep: Bool {
        guard let lastItem = inspectState.items.last else { return false }
        return currentStep == inspectState.items.count - 1 && lastItem.stepType == "outro"
    }

    /// Whether a banner should be shown
    private var hasBanner: Bool {
        inspectState.uiConfiguration.bannerImage != nil ||
        (inspectState.uiConfiguration.bannerTitle?.isEmpty == false)
    }

    // MARK: - Interaction Log Paths

    private var interactionLogPath: String {
        "/tmp/preset6_interaction.log"
    }

    private var interactionPlistPath: String {
        "/tmp/preset6_interaction.plist"
    }

    private var acknowledgmentLogPath: String {
        "/var/tmp/dialog-ack.log"
    }

    // MARK: - Trigger File Configuration

    private var triggerFilePath: String {
        if let customPath = inspectState.config?.triggerFile {
            return customPath
        }
        if appArguments.inspectMode.present {
            return "/tmp/swiftdialog_dev_preset6.trigger"
        }
        return "/tmp/swiftdialog_\(ProcessInfo.processInfo.processIdentifier)_preset6.trigger"
    }

    private var finalTriggerFilePath: String {
        if let customPath = inspectState.config?.triggerFile {
            let url = URL(fileURLWithPath: customPath)
            let ext = url.pathExtension
            let base = url.deletingPathExtension().path
            return ext.isEmpty ? "\(customPath)_final" : "\(base)_final.\(ext)"
        }
        if appArguments.inspectMode.present {
            return "/tmp/swiftdialog_dev_preset6_final.trigger"
        }
        return "/tmp/swiftdialog_\(ProcessInfo.processInfo.processIdentifier)_preset6_final.trigger"
    }

    private var triggerMode: String {
        if inspectState.config?.triggerFile != nil {
            return "custom"
        }
        return appArguments.inspectMode.present ? "dev" : "prod"
    }

    // MARK: - Initializer

    init(inspectState: InspectState) {
        self.inspectState = inspectState
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            // Show intro/outro full-screen OR normal sidebar layout
            if isIntroStep || isOutroStep {
                introOutroView(isOutro: isOutroStep)
            } else {
                mainLayout
            }

            // Persistent logo overlay (bottom-left, all views)
            if let logoConfig = inspectState.config?.logoConfig {
                BrandedLogoView(
                    logoConfig: logoConfig,
                    basePath: inspectState.uiConfiguration.iconBasePath
                )
                .transaction { $0.animation = nil }
            }
        }
        .environment(\.palette, ResolvedPalette(from: inspectState.config?.brandPalette, primaryColor: branding.primaryColor))
        .onAppear {
            mdmOverrides = AppConfigService.shared.loadMDMOverrides(source: inspectState.config?.appConfigSource)
            if let locConfig = inspectState.config?.localization {
                let basePath = inspectState.uiConfiguration.iconBasePath ?? ""
                localizationService.loadLanguages(from: locConfig, basePath: basePath)
            }
            writeLog("Preset6: View appearing, loading state...", logLevel: .info)
            loadPersistedState()
            setupFileMonitoring()
            startComplianceMonitoring()
            startIntroStepMonitoring()
            writeReadinessFile(config: inspectState.config, triggerFilePath: triggerFilePath)
            writeInteractionLog("launched", step: "preset6")
            logPreset6Event("view_appeared", details: [
                "totalSteps": inspectState.items.count,
                "triggerFile": triggerFilePath
            ])
        }
        .onChange(of: inspectState.completedItems) { _, newCompletedItems in
            handleExternalCompletions(newCompletedItems)
        }
        .onChange(of: inspectState.downloadingItems) { _, newDownloadingItems in
            withAnimation(.spring()) {
                downloadingItems = newDownloadingItems
            }
        }
        .onChange(of: currentStep) { oldStep, newStep in
            if oldStep != newStep {
                autoNavigationWorkItem?.cancel()
                autoNavigationWorkItem = nil
            }
        }
        .sheet(isPresented: $showOverrideDialog) {
            if let stepId = processingState.stepId {
                let cancelText = branding.button2Text ?? "Cancel"
                OverrideDialogView(
                    isPresented: $showOverrideDialog,
                    stepId: stepId,
                    cancelButtonText: cancelText,
                    onAction: { action in
                        handleOverrideAction(action: action, stepId: stepId)
                    }
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
        .onDisappear {
            savePersistedState()
            stopFileMonitoring()
            processingTimer?.invalidate()
            processingTimer = nil
        }
    }

    // MARK: - Main Layout

    private var mainLayout: some View {
        VStack(spacing: 0) {
            // Banner image OR accent border at top
            if let bannerPath = inspectState.uiConfiguration.bannerImage {
                let bannerH = CGFloat(inspectState.uiConfiguration.bannerHeight) * scaleFactor
                ZStack(alignment: .bottomLeading) {
                    AsyncImageView(
                        iconPath: bannerPath,
                        basePath: inspectState.uiConfiguration.iconBasePath,
                        maxWidth: .infinity,
                        maxHeight: bannerH,
                        imageFit: .fill
                    ) {
                        Rectangle()
                            .fill(highlightColor.opacity(0.15))
                            .frame(height: bannerH)
                    }

                    // Apple-style bottom fade for clean transition into content
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: bannerH * 0.5)

                    // Title/subtitle overlay on banner
                    VStack(alignment: .leading, spacing: 2) {
                        if let bannerTitle = inspectState.uiConfiguration.bannerTitle {
                            Text(bannerTitle)
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        }
                        if let message = inspectState.uiConfiguration.subtitleMessage {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity)
                .frame(height: bannerH)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 10, style: .continuous))
                .ignoresSafeArea(edges: .top)
            } else {
                Rectangle()
                    .fill(highlightColor)
                    .frame(height: 4)
            }

            // Main content area
            HStack(spacing: 0) {
                // Left: Sidebar navigation
                SidebarNavigationModule(
                    items: inspectState.items,
                    currentStep: currentStep,
                    completedSteps: completedSteps.union(inspectState.completedItems),
                    downloadingSteps: downloadingItems,
                    accentColor: highlightColor,
                    logoPath: nil,  // Logo in footer instead
                    title: inspectState.uiConfiguration.windowTitle,
                    subtitle: inspectState.uiConfiguration.subtitleMessage,
                    iconPath: inspectState.uiConfiguration.iconPath,
                    iconBasePath: inspectState.uiConfiguration.iconBasePath,
                    showStepNumbers: showStepNumbers,
                    showCompletionMarks: showCompletionMarks,
                    width: sidebarWidth,
                    scaleFactor: scaleFactor,
                    onStepSelected: handleStepSelection,
                    isNavigationBlocked: shouldBlockNavigation
                )
                .zIndex(1)

                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1)

                // Right: Content panel (clipped so slide transitions don't bleed under sidebar)
                contentPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }

            // Footer bar
            footerBar
        }
    }

    // MARK: - Content Panel

    @ViewBuilder
    private var contentPanel: some View {
        VStack(spacing: 0) {
            if let currentItem = inspectState.items[safe: currentStep] {
                // Content area with scroll hint overlay for long-form steps
                GeometryReader { contentGeo in
                    ZStack(alignment: .bottom) {
                        ScrollView(.vertical, showsIndicators: true) {
                            let sp = InspectSizes.SetupSpacing.self
                            VStack(alignment: .leading, spacing: sp.sectionGap) {
                                // Step heading
                                stepHeading(for: currentItem)

                                // Guidance content blocks
                                if let guidanceContent = currentItem.guidanceContent, !guidanceContent.isEmpty {
                                    // Apply localization then dynamic content updates to guidance blocks
                                    let updatedContent = guidanceContent.enumerated().map { index, block in
                                        let locBlock = localizedContentBlock(block, itemId: currentItem.id, blockIndex: index)
                                        return applyDynamicUpdates(to: locBlock, index: index, itemId: currentItem.id)
                                    }

                                    GuidanceContentView(
                                        contentBlocks: updatedContent,
                                        scaleFactor: scaleFactor,
                                        iconBasePath: inspectState.uiConfiguration.iconBasePath,
                                        inspectState: inspectState,
                                        itemId: currentItem.id,
                                        onOverlayTap: currentItem.itemOverlay != nil ? {
                                            selectedItemForDetail = currentItem
                                            showItemDetailOverlay = true
                                        } : nil,
                                        accentColor: highlightColor
                                    )
                                    // Force re-render when dynamic properties change for this item
                                    .id("guidance-\(currentItem.id)-\(dynamicState.dynamicGuidanceProperties[currentItem.id]?.hashValue ?? 0)")
                                } else {
                                    // Fallback for items without guidanceContent
                                    fallbackContentView(for: currentItem)
                                }

                                // Processing state display
                                if isProcessing && processingState.stepId == currentItem.id {
                                    processingStateView(for: currentItem)
                                }

                                // Success/Failure banner
                                resultBanner(for: currentItem)
                            }
                            .frame(maxWidth: 420, alignment: .leading)
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
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: navigationDirection == .forward ? .trailing : .leading)
                               .combined(with: .opacity),
                    removal:   .move(edge: navigationDirection == .forward ? .leading : .trailing)
                               .combined(with: .opacity)
                ))
            } else {
                // Completion state
                completionView
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Inline Back Button

    /// Whether to show the back button inline (inside scroll, above heading) vs in the footer bar.
    /// Controlled by config `backButtonStyle`: "inline" (default) or "footer".
    private var useInlineBackButton: Bool {
        let style = inspectState.config?.backButtonStyle ?? "inline"
        return style == "inline"
    }

    @ViewBuilder
    private var inlineBackButton: some View {
        let backText: String = {
            if let item = inspectState.items[safe: currentStep],
               let loc = localized("backButtonText", forItem: item, fallback: nil) { return loc }
            return branding.button2Text ?? "Back"
        }()

        HStack {
            Button(action: { goToPreviousStep() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.quaternary))
            }
            .buttonStyle(.plain)
            .help(backText)
            .accessibilityLabel(backText)

            Spacer()
        }
    }

    // MARK: - Step Heading

    @ViewBuilder
    private func stepHeading(for item: InspectConfig.ItemConfig) -> some View {
        VStack(alignment: .leading, spacing: InspectSizes.SetupSpacing.titleSubtitle) {
            HStack(spacing: 8) {
                if let guidanceTitle = localized("guidanceTitle", forItem: item, fallback: item.guidanceTitle) {
                    Text(guidanceTitle)
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                } else {
                    Text(item.displayName)
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                }

                // Info button for item overlay
                if item.itemOverlay != nil {
                    Button(action: {
                        selectedItemForDetail = item
                        showItemDetailOverlay = true
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("View details")
                }

                Spacer()
            }

            // Status badge
            if completedSteps.contains(item.id) || inspectState.completedItems.contains(item.id) {
                statusBadge(completed: true, failed: failedSteps[item.id] != nil)
            }
        }
        .padding(.bottom, InspectSizes.SetupSpacing.titleSubtitle)
    }

    @ViewBuilder
    private func statusBadge(completed: Bool, failed: Bool) -> some View {
        let statusColor = failed ? palette.error : palette.success
        HStack(spacing: 6) {
            StatusIconView(failed ? .failure : .success, size: 12)

            Text(failed ? "Failed" : "Completed")
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
    private func fallbackContentView(for item: InspectConfig.ItemConfig) -> some View {
        VStack(alignment: .leading, spacing: InspectSizes.SetupSpacing.sectionGap) {
            // Icon
            if let icon = item.icon {
                IntroHeroImage(
                    path: icon,
                    shape: "roundedSquare",
                    size: 80 * scaleFactor,
                    accentColor: highlightColor
                )
                .frame(maxWidth: .infinity)
            }

            // Description from paths
            if let description = item.paths.first, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Processing State View

    @ViewBuilder
    private func processingStateView(for item: InspectConfig.ItemConfig) -> some View {
        VStack(spacing: InspectSizes.SetupSpacing.sectionGap) {
            // Countdown or spinner
            if case .countdown(_, let remaining, _) = processingState {
                countdownRing(remaining: remaining, total: item.processingDuration ?? 5)
            } else if case .waiting = processingState {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .onTapGesture {
                        // Allow override during waiting state
                        if currentOverrideLevel != .none {
                            showOverrideDialog = true
                        }
                    }
                    .help(currentOverrideLevel != .none ? "Click to override" : "Waiting for result...")
            }

            // Processing message
            if let message = item.processingMessage {
                let displayMessage: String = {
                    if case .countdown(_, let remaining, _) = processingState {
                        return message.replacingOccurrences(of: "{countdown}", with: "\(remaining)")
                    } else if case .waiting = processingState {
                        return "Waiting for result..."
                    }
                    return message
                }()

                Text(displayMessage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Override option for long waits (shown at warning level and above)
            if currentOverrideLevel != .none, case .waiting = processingState {
                overrideBanner
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, InspectSizes.SetupSpacing.topInset)
    }

    @ViewBuilder
    private func countdownRing(remaining: Int, total: Int) -> some View {
        ZStack {
            Circle()
                .stroke(highlightColor.opacity(0.3), lineWidth: 4)
                .frame(width: 80 * scaleFactor, height: 80 * scaleFactor)

            Circle()
                .trim(from: 0, to: CGFloat(remaining) / CGFloat(total))
                .stroke(highlightColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 80 * scaleFactor, height: 80 * scaleFactor)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1.0), value: remaining)

            Text("\(max(0, remaining))")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(highlightColor)
        }
    }

    @ViewBuilder
    private var overrideBanner: some View {
        let isLarge = currentOverrideLevel == .large
        let waitTime = processingState.waitElapsed

        VStack(spacing: InspectSizes.SetupSpacing.blockGap) {
            HStack(spacing: InspectSizes.SetupSpacing.titleSubtitle) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text("Waiting for \(waitTime) seconds...")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()
            }

            // Override button - grows larger over time
            Button(action: {
                showOverrideDialog = true
            }) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                    Text("Override This Step")
                }
                .font(.system(size: isLarge ? 14 : 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, isLarge ? 20 : 16)
                .padding(.vertical, isLarge ? 10 : 8)
                .background(palette.warning)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(InspectSizes.SetupSpacing.blockGap)
        .background(palette.warningBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(palette.warning.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Result Banner

    @ViewBuilder
    private func resultBanner(for item: InspectConfig.ItemConfig) -> some View {
        let isCompleted = completedSteps.contains(item.id) || inspectState.completedItems.contains(item.id)
        let hasFailed = failedSteps[item.id] != nil
        let wasSkipped = skippedSteps.contains(item.id)

        if isCompleted && !isProcessing {
            let sp = InspectSizes.SetupSpacing.self
            if hasFailed {
                // Failure banner
                HStack(spacing: sp.blockGap) {
                    StatusIconView(.failure, size: 20 * scaleFactor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.failureMessage ?? "Step Failed")
                            .font(.body.weight(.semibold))

                        if let reason = failedSteps[item.id] {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(sp.blockGap)
                .background(palette.errorBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(palette.error.opacity(0.3), lineWidth: 1)
                )
            } else if wasSkipped {
                // Skipped banner
                HStack(spacing: sp.blockGap) {
                    StatusIconView(.warning, size: 20 * scaleFactor)

                    Text("Step Skipped")
                        .font(.body.weight(.semibold))

                    Spacer()
                }
                .padding(sp.blockGap)
                .background(palette.warningBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let successMessage = item.successMessage {
                // Success banner
                HStack(spacing: sp.blockGap) {
                    StatusIconView(.success, size: 20 * scaleFactor)

                    Text(successMessage)
                        .font(.body.weight(.semibold))

                    Spacer()
                }
                .padding(sp.blockGap)
                .background(palette.successBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Completion View

    @ViewBuilder
    private var completionView: some View {
        VStack(spacing: InspectSizes.SetupSpacing.sectionGap) {
            Spacer()

            StatusIconView(.success, size: 60 * scaleFactor)

            Text(inspectState.config?.uiLabels?.completionMessage ?? "All Steps Complete")
                .font(.system(size: 24, weight: .bold))

            Text(inspectState.config?.uiLabels?.completionSubtitle ?? "Your setup is now complete!")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer Bar

    @ViewBuilder
    private var footerBar: some View {
        let backText: String = {
            if let item = inspectState.items[safe: currentStep],
               let loc = localized("backButtonText", forItem: item, fallback: nil) { return loc }
            return branding.button2Text ?? "Back"
        }()

        IntroFooterView(
            footerText: branding.footerText,
            backButtonText: backText,
            continueButtonText: getContinueButtonText(),
            accentColor: highlightColor,
            showBackButton: canGoBack,
            onBack: goToPreviousStep,
            onContinue: handleContinue,
            continueDisabled: isContinueDisabled,
            inspectConfig: inspectState.config,
            buttonControlSize: .large,
            footerVerticalPadding: 16
        )
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .center) {
            // Step counter with Option-click reset
            Text("Step \(currentStep + 1) of \(inspectState.items.count)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .onTapGesture {
                    if NSEvent.modifierFlags.contains(.option) {
                        resetSteps()
                    }
                }
                .help("Option-click to reset progress")
        }
        .transaction { $0.animation = nil } // Prevent footer from springing during step transitions
    }

    // MARK: - Button Logic

    private var canGoBack: Bool {
        // Can't go back from first non-intro step
        let hasIntro = inspectState.items.first?.stepType == "intro"
        let minimumStep = hasIntro ? 1 : 0
        return currentStep > minimumStep && !shouldBlockNavigation
    }

    private var isContinueDisabled: Bool {
        if isProcessing {
            return true
        }
        // On last step, use global observe-only; otherwise per-item
        if currentStep >= inspectState.items.count - 1 {
            return isGlobalObserveOnly(config: inspectState.config)
        }
        return isItemObserveOnly(inspectState.items[safe: currentStep], config: inspectState.config)
    }

    private func getContinueButtonText() -> String {
        // Check if we're on the last step
        if currentStep >= inspectState.items.count - 1 {
            if let item = inspectState.items.last,
               let locText = localized("continueButtonText", forItem: item, fallback: nil) {
                return locText
            }
            return branding.button1Text ?? "Finish"
        }

        // Check for item-specific button text (localization > config)
        if let currentItem = inspectState.items[safe: currentStep] {
            if let locText = localized("continueButtonText", forItem: currentItem, fallback: nil) {
                return locText
            }
            if let customText = currentItem.continueButtonText {
                return customText
            }

            // If step failed, offer "Continue Anyway"
            if failedSteps[currentItem.id] != nil {
                return "Continue Anyway"
            }
        }

        return branding.button1Text ?? "Continue"
    }

    // MARK: - Intro/Outro View

    @ViewBuilder
    private func introOutroView(isOutro: Bool) -> some View {
        let item = isOutro ? inspectState.items.last : inspectState.items.first
        let layoutConfig = item?.introLayoutConfig

        IntroStepContainer(
            accentColor: highlightColor,
            accentBorderHeight: 4,
            showProgressDots: false,
            currentStep: 0,
            totalSteps: 1,
            footerConfig: IntroStepContainer.IntroFooterConfig(
                footerText: branding.footerText,
                backButtonText: {
                    if let item = item, let locText = localized("backButtonText", forItem: item, fallback: nil) {
                        return locText
                    }
                    return branding.button2Text ?? "Back"
                }(),
                continueButtonText: {
                    if let item = item, let locText = localized("continueButtonText", forItem: item, fallback: nil) {
                        return locText
                    }
                    return item?.continueButtonText ?? (isOutro ? "Finish" : "Continue")
                }(),
                showBackButton: isOutro && currentStep > 0,
                onBack: isOutro ? goToPreviousStep : nil,
                onContinue: {
                    if isOutro {
                        handleFinish()
                    } else {
                        // Mark intro as complete and navigate
                        if let item = item {
                            handleStepCompletion(item: item)
                        }
                        navigateToNextStep()
                    }
                }
            )
        ) {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 0)

                        // Hero image
                        if let iconPath = item?.icon {
                            let proportionalSize = min(max(geometry.size.height * 0.28, 100), 180)
                            IntroHeroImage(
                                path: iconPath,
                                shape: "none",
                                size: layoutConfig?.heroImageSize ?? proportionalSize,
                                accentColor: highlightColor,
                                padding: layoutConfig?.heroImagePadding
                            )
                            .padding(.bottom, InspectSizes.SetupSpacing.titleSubtitle)
                        }

                        // Title
                        if let title = item.flatMap({ localized("guidanceTitle", forItem: $0, fallback: $0.guidanceTitle) }) ?? item?.guidanceTitle {
                            Text(title)
                                .font(.system(size: 28, weight: .bold))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, InspectSizes.SetupSpacing.contentPadH)
                        }

                        // Content blocks (delegate all types to GuidanceContentView)
                        if let content = item?.guidanceContent, !content.isEmpty {
                            let itemId = item?.id ?? "intro"
                            let localizedBlocks = content.enumerated().map { index, block in
                                localizedContentBlock(block, itemId: itemId, blockIndex: index)
                            }
                            GuidanceContentView(
                                contentBlocks: localizedBlocks,
                                scaleFactor: scaleFactor,
                                iconBasePath: inspectState.uiConfiguration.iconBasePath,
                                inspectState: inspectState,
                                itemId: itemId,
                                accentColor: highlightColor,
                                contentAlignment: .center
                            )
                            .frame(maxWidth: InspectSizes.SetupSpacing.contentMaxW)
                            .padding(.horizontal, InspectSizes.SetupSpacing.contentPadH)
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollIndicators(.automatic)
            }
        }
    }

    // MARK: - Navigation

    private func handleStepSelection(_ index: Int) {
        guard !shouldBlockNavigation else {
            writeLog("Preset6: Navigation blocked during processing", logLevel: .debug)
            return
        }

        // Check observe-only on target step
        guard !isItemObserveOnly(inspectState.items[safe: index], config: inspectState.config) else {
            writeLog("Preset6: Navigation blocked - step is observe-only", logLevel: .debug)
            return
        }

        // Check if target step allows direct navigation
        guard let targetItem = inspectState.items[safe: index] else { return }

        // Skip intro/outro via sidebar
        if targetItem.stepType == "intro" || targetItem.stepType == "outro" {
            return
        }

        navigationDirection = index > currentStep ? .forward : .backward
        withAnimation(InspectConstants.stepTransition) {
            currentStep = index
        }

        restartIntroStepMonitoring()
        writeLog("Preset6: Navigated to step \(index) (\(targetItem.id))", logLevel: .info)
    }

    private func handleContinue() {
        guard let currentItem = inspectState.items[safe: currentStep] else {
            handleFinish()
            return
        }

        // Check if this is a processing step that needs to start
        if currentItem.stepType == "processing" && !completedSteps.contains(currentItem.id) {
            startProcessing(for: currentItem)
            return
        }

        // Mark step as complete and navigate
        handleStepCompletion(item: currentItem)

        if currentStep >= inspectState.items.count - 1 {
            handleFinish()
        } else {
            navigateToNextStep()
        }
    }

    private func navigateToNextStep() {
        guard currentStep < inspectState.items.count - 1 else { return }

        let oldStep = currentStep
        navigationDirection = .forward
        withAnimation(InspectConstants.stepTransition) {
            currentStep += 1
        }

        writeLog("Preset6: Advanced to step \(currentStep)", logLevel: .info)
        writeInteractionLog("navigate_next", step: "step_\(currentStep)")
        logPreset6Event("step_transition", details: [
            "from": oldStep,
            "to": currentStep,
            "reason": "navigate_next"
        ])

        // Restart plist monitoring for new step's monitors
        restartIntroStepMonitoring()

        // Auto-start processing if next step is a processing step
        if let nextItem = inspectState.items[safe: currentStep] {
            autoStartProcessingIfNeeded(for: nextItem)
        }
    }

    /// Automatically start processing if conditions are met
    private func autoStartProcessingIfNeeded(for item: InspectConfig.ItemConfig) {
        // Only auto-start if this is a processing step
        guard item.stepType == "processing" else { return }

        // Don't auto-start if already completed
        guard !completedSteps.contains(item.id) else { return }

        // Check if autoAdvance is enabled
        guard item.autoAdvance == true else { return }

        // Validate form inputs if this step has any
        if let guidanceContent = item.guidanceContent {
            let hasFormInputs = guidanceContent.contains { block in
                ["text_input", "dropdown", "slider", "toggle", "checkbox_group", "radio_group"].contains(block.type)
            }

            if hasFormInputs {
                // Check if form is filled
                if let formState = inspectState.guidanceFormInputs[item.id] {
                    // Check for required fields
                    for block in guidanceContent where block.required == true {
                        let fieldId = block.id ?? "field_\(guidanceContent.firstIndex(where: { $0.id == block.id }) ?? 0)"

                        // Check based on input type
                        let hasValue: Bool
                        switch block.type {
                        case "text_input":
                            hasValue = formState.textfields[fieldId]?.isEmpty == false
                        case "dropdown":
                            hasValue = formState.dropdowns[fieldId]?.isEmpty == false
                        case "slider":
                            hasValue = formState.sliders[fieldId] != nil
                        case "toggle":
                            hasValue = formState.toggles[fieldId] != nil
                        case "checkbox_group":
                            hasValue = formState.checkboxes.keys.contains { $0.hasPrefix(fieldId) }
                        case "radio_group":
                            hasValue = formState.radios[fieldId]?.isEmpty == false
                        default:
                            hasValue = true
                        }

                        if !hasValue {
                            writeLog("Preset6: Auto-start blocked - required field '\(fieldId)' not filled", logLevel: .debug)
                            return
                        }
                    }
                } else {
                    writeLog("Preset6: Auto-start blocked - no form input state for step '\(item.id)'", logLevel: .debug)
                    return
                }
            }
        }

        logPreset6Event("auto_start_processing", details: ["stepId": item.id])
        startProcessing(for: item)
    }

    private func goToPreviousStep() {
        guard canGoBack else { return }

        let oldStep = currentStep
        navigationDirection = .backward
        withAnimation(InspectConstants.stepTransition) {
            currentStep -= 1
        }

        restartIntroStepMonitoring()
        writeLog("Preset6: Went back to step \(currentStep)", logLevel: .info)
        writeInteractionLog("navigate_previous", step: "step_\(currentStep)")
        logPreset6Event("step_transition", details: [
            "from": oldStep,
            "to": currentStep,
            "reason": "navigate_previous"
        ])
    }

    private func handleStepCompletion(item: InspectConfig.ItemConfig) {
        completedSteps.insert(item.id)
        savePersistedState()
        writeLog("Preset6: Step '\(item.id)' marked as completed", logLevel: .info)
        writeInteractionLog("completed_step", step: item.id)
        logPreset6Event("step_completed", details: [
            "stepId": item.id,
            "stepIndex": inspectState.items.firstIndex(where: { $0.id == item.id }) ?? -1
        ])
    }

    /// Reset all progress (triggered by "reset" command or Option-click)
    private func resetSteps() {
        // Stop all timers first
        processingTimer?.invalidate()
        processingTimer = nil

        let previouslyCompleted = completedSteps.count

        withAnimation(.spring()) {
            completedSteps.removeAll()
            failedSteps.removeAll()
            skippedSteps.removeAll()
            currentStep = 0
            processingState = .idle
            inspectState.completedItems.removeAll()
        }

        // Clear dynamic state
        dynamicState.clearAllState()

        // Clear persistence
        persistenceService.clearState()

        // Reset trigger file line offset (truncate file and reset counter together)
        if FileManager.default.fileExists(atPath: triggerFilePath) {
            try? "".write(toFile: triggerFilePath, atomically: false, encoding: .utf8)
            lastProcessedLineCount = 0
        }

        writeLog("Preset6: All progress reset", logLevel: .info)
        writeInteractionLog("reset", step: "all")
        logPreset6Event("steps_reset", details: [
            "previouslyCompleted": previouslyCompleted,
            "totalSteps": inspectState.items.count
        ])
    }

    private func handleFinish() {
        // Write final state
        writeFinalTriggerFile()
        savePersistedState()

        // Write structured result file and clean up readiness signal
        let stepInfos = inspectState.items.map { ResultStepInfo(id: $0.id, stepType: $0.stepType ?? "info") }
        writeResultFile(
            config: inspectState.config, exitCode: Int(appDefaults.exit0.code),
            steps: stepInfos, completedSteps: completedSteps,
            failedSteps: failedSteps, skippedSteps: skippedSteps,
            currentStepIndex: currentStep
        )
        cleanupReadinessFile(config: inspectState.config, triggerFilePath: triggerFilePath)

        writeLog("Preset6: Completing with exit code 0", logLevel: .info)
        quitDialog(exitCode: appDefaults.exit0.code)
    }

    // MARK: - Processing

    private func startProcessing(for item: InspectConfig.ItemConfig) {
        guard let duration = item.processingDuration, duration > 0 else {
            // No duration - complete immediately
            handleCompletionTrigger(stepId: item.id, result: .success(message: nil))
            return
        }

        processingCountdown = duration
        processingState = .countdown(stepId: item.id, remaining: duration, waitElapsed: 0)

        // Output event for scripts
        print("[PRESET6_PROCESSING] step_started: \(item.id)")
        writeLog("Preset6: Processing started for step '\(item.id)'", logLevel: .info)
        writeInteractionLog("processing_started", step: item.id, data: ["duration": duration])
        logPreset6Event("processing_started", details: [
            "stepId": item.id,
            "duration": duration,
            "waitForTrigger": item.waitForExternalTrigger ?? false
        ])

        processingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            DispatchQueue.main.async {
                if case .countdown(let stepId, let remaining, let elapsed) = self.processingState {
                    if remaining <= 1 {
                        timer.invalidate()
                        self.processingTimer = nil

                        // Determine next state
                        let waitForTrigger = item.waitForExternalTrigger == true

                        if waitForTrigger {
                            self.processingState = .waiting(stepId: stepId, waitElapsed: 0)
                            self.startWaitingTimer(for: item)
                        } else {
                            // Complete with auto-result
                            let autoResult = item.autoResult ?? "success"
                            if autoResult == "failure" {
                                self.handleCompletionTrigger(stepId: stepId, result: .failure(message: item.failureMessage))
                            } else {
                                self.handleCompletionTrigger(stepId: stepId, result: .success(message: item.successMessage))
                            }
                        }
                    } else {
                        self.processingCountdown = remaining - 1
                        self.processingState = .countdown(stepId: stepId, remaining: remaining - 1, waitElapsed: elapsed + 1)
                    }
                }
            }
        }
    }

    private func startWaitingTimer(for item: InspectConfig.ItemConfig) {
        // Invalidate any existing timer first
        processingTimer?.invalidate()
        processingTimer = nil

        writeLog("Preset6: Starting waiting timer for step '\(item.id)'", logLevel: .debug)

        // Use RunLoop.main to ensure timer survives view updates
        // Note: Using [self] capture (not weak) because SwiftUI views are value types
        // and the @State property will persist across view recreations
        let timer = Timer(timeInterval: 1.0, repeats: true) { [self] _ in
            DispatchQueue.main.async {
                if case .waiting(let stepId, let waitElapsed) = self.processingState {
                    let newElapsed = waitElapsed + 1
                    self.processingState = .waiting(stepId: stepId, waitElapsed: newElapsed)

                    // Log at key thresholds
                    if newElapsed == 10 || newElapsed == 30 || newElapsed == 60 || newElapsed % 60 == 0 {
                        writeLog("Preset6: Waiting timer at \(newElapsed)s for step '\(stepId)'", logLevel: .debug)
                    }
                }
            }
        }

        // Add to main run loop to ensure it survives SwiftUI view updates
        RunLoop.main.add(timer, forMode: .common)
        processingTimer = timer
    }

    private func handleCompletionTrigger(stepId: String, result: CompletionResult) {
        // Stop timer
        processingTimer?.invalidate()
        processingTimer = nil
        processingState = .idle

        // Update state
        completedSteps.insert(stepId)

        switch result {
        case .success(let message):
            failedSteps.removeValue(forKey: stepId)
            skippedSteps.remove(stepId)
            print("[PRESET6_PROCESSING] result: \(stepId) = success")
            writeInteractionLog("success", step: stepId, data: ["message": message ?? ""])
            logPreset6Event("step_success", details: ["stepId": stepId, "message": message ?? ""])

        case .failure(let message):
            failedSteps[stepId] = message ?? "Step failed"
            print("[PRESET6_PROCESSING] result: \(stepId) = failed")
            writeInteractionLog("failure", step: stepId, data: ["message": message ?? "Step failed"])
            logPreset6Event("step_failure", details: ["stepId": stepId, "message": message ?? "Step failed"])

        case .warning(let message):
            print("[PRESET6_PROCESSING] result: \(stepId) = warning")
            writeInteractionLog("warning", step: stepId, data: ["message": message ?? ""])
            logPreset6Event("step_warning", details: ["stepId": stepId, "message": message ?? ""])

        case .cancelled:
            skippedSteps.insert(stepId)
            print("[PRESET6_PROCESSING] result: \(stepId) = skipped")
            writeInteractionLog("cancelled", step: stepId)
            logPreset6Event("step_cancelled", details: ["stepId": stepId])
        }

        writeLog("Preset6: Step '\(stepId)' completed with result: \(result)", logLevel: .info)
        savePersistedState()
    }

    private func handleOverrideAction(action: OverrideDialogView.OverrideAction, stepId: String) {
        logPreset6Event("override_action", details: ["stepId": stepId, "action": "\(action)"])

        switch action {
        case .success:
            writeInteractionLog("override_success", step: stepId)
            handleCompletionTrigger(stepId: stepId, result: .success(message: nil))
        case .failure:
            writeInteractionLog("override_failure", step: stepId)
            handleCompletionTrigger(stepId: stepId, result: .failure(message: "Marked as failed by user"))
        case .skip:
            writeInteractionLog("override_skip", step: stepId)
            handleCompletionTrigger(stepId: stepId, result: .cancelled)
        case .cancel:
            writeInteractionLog("override_cancel", step: stepId)
            break
        }
    }

    // MARK: - External Completions

    private func handleExternalCompletions(_ newCompletedItems: Set<String>) {
        withAnimation(.spring()) {
            var shouldAutoNavigate = false
            var completedCurrentStep = false

            for item in inspectState.items {
                if newCompletedItems.contains(item.id) && !completedSteps.contains(item.id) {
                    completedSteps.insert(item.id)

                    if let currentItem = inspectState.items[safe: currentStep],
                       currentItem.id == item.id {
                        completedCurrentStep = true
                    }
                }
            }

            if completedCurrentStep {
                if let currentItem = inspectState.items[safe: currentStep] {
                    let stepType = currentItem.stepType ?? "info"

                    if stepType == "processing" && processingState.isActive {
                        // Complete the active processing step via its normal completion path
                        handleCompletionTrigger(stepId: currentItem.id, result: .success(message: currentItem.successMessage))
                        return
                    }

                    if currentStep < inspectState.items.count - 1 {
                        let nextStepWaits = inspectState.items[safe: currentStep + 1]?.waitForExternalTrigger ?? false
                        if !nextStepWaits {
                            shouldAutoNavigate = true
                        }
                    }
                }
            }

            if shouldAutoNavigate {
                autoNavigationWorkItem?.cancel()
                let workItem = DispatchWorkItem {
                    navigateToNextStep()
                }
                autoNavigationWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
            }
        }
    }

    // MARK: - File Monitoring

    // MARK: - Service Initialization

    /// Start compliance aggregation from plistSources config
    private func startComplianceMonitoring() {
        if let plistSources = inspectState.config?.plistSources, !plistSources.isEmpty {
            writeLog("Preset6: Starting ComplianceAggregatorService with \(plistSources.count) sources", logLevel: .info)
            complianceService.startMonitoring(sources: plistSources, refreshInterval: 5.0)
        }
    }

    /// Start intro step monitoring for dynamic content state (phase-tracker, status-badge, comparison-table)
    private func startIntroStepMonitoring() {
        guard let currentItem = inspectState.items[safe: currentStep] else { return }
        introStepMonitor.startMonitoring(item: currentItem) { triggerItemId, result in
            writeLog("Preset6: Step monitor triggered for '\(triggerItemId)' with result: \(result)", logLevel: .info)
        }
    }

    /// Restart intro step monitoring when navigating to a new step
    private func restartIntroStepMonitoring() {
        introStepMonitor.stopMonitoring()
        startIntroStepMonitoring()
    }

    /// Create a DynamicContentState for compliance data
    private func makeComplianceState(passed: Int, total: Int, content: String? = nil) -> DynamicContentState {
        let state = DynamicContentState()
        state.passed = passed
        state.total = total
        if let content = content {
            state.content = content
        }
        return state
    }

    // MARK: - File Monitoring

    /// Zero-latency file monitoring using DispatchSource
    /// Replaces timer-based polling (500ms latency) with instant file change detection
    private func setupFileMonitoring() {
        // Create trigger file if needed
        if !FileManager.default.fileExists(atPath: triggerFilePath) {
            FileManager.default.createFile(atPath: triggerFilePath, contents: nil, attributes: nil)
        }

        // Skip past any stale content from a previous run
        if let existing = try? String(contentsOfFile: triggerFilePath, encoding: .utf8) {
            lastProcessedLineCount = existing.components(separatedBy: .newlines).count
        }

        // Open file descriptor
        let fileDescriptor = open(triggerFilePath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            writeLog("Preset6: Failed to open trigger file for monitoring", logLevel: .error)
            return
        }

        // Create dispatch source to monitor file changes
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.main
        )

        // Set event handler
        source.setEventHandler { [self] in
            checkForExternalTrigger()
        }

        // Set cancellation handler to close file descriptor
        source.setCancelHandler {
            close(fileDescriptor)
        }

        // Activate the source
        source.resume()

        // Store reference
        fileMonitorSource = source

        print("[SWIFTDIALOG] trigger_file: \(triggerFilePath)")
        print("[SWIFTDIALOG] trigger_mode: \(triggerMode)")
        writeLog("Preset6: File monitoring started with DispatchSource at \(triggerFilePath) (mode: \(triggerMode), zero-latency)", logLevel: .info)
    }

    /// Uses line-offset tracking: reads all lines, processes only new ones, never clears the file.
    /// This eliminates the read-then-clear race where commands appended between read and clear were lost.
    private func checkForExternalTrigger() {
        guard let content = try? String(contentsOfFile: triggerFilePath, encoding: .utf8) else { return }

        let lines = content.components(separatedBy: .newlines)
        let totalLines = lines.count

        guard totalLines > lastProcessedLineCount else { return }

        let newLines = Array(lines.dropFirst(lastProcessedLineCount))
        for line in newLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            writeLog("Preset6: Received trigger command: \(trimmed)", logLevel: .info)
            processExternalCommands(trimmed)
        }

        lastProcessedLineCount = totalLines
    }

    private func processExternalCommands(_ content: String) {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("complete:") {
                // Simple completion: complete:stepId
                let stepId = String(trimmed.dropFirst(9))
                if !completedSteps.contains(stepId) {
                    if inspectState.items.contains(where: { $0.id == stepId }) {
                        withAnimation(.spring()) {
                            completedSteps.insert(stepId)
                            inspectState.completedItems.insert(stepId)
                        }
                        writeLog("Preset6: Step '\(stepId)' marked complete via trigger", logLevel: .info)
                    }
                }
            } else if trimmed.hasPrefix("success:") {
                let parts = trimmed.dropFirst(8).split(separator: ":", maxSplits: 1)
                let stepId = String(parts[0])
                let message = parts.count > 1 ? String(parts[1]) : nil
                handleCompletionTrigger(stepId: stepId, result: .success(message: message))
            } else if trimmed.hasPrefix("failure:") {
                let parts = trimmed.dropFirst(8).split(separator: ":", maxSplits: 1)
                let stepId = String(parts[0])
                let reason = parts.count > 1 ? String(parts[1]) : "Step failed"
                handleCompletionTrigger(stepId: stepId, result: .failure(message: reason))
            } else if trimmed.hasPrefix("warning:") {
                // Warning result: warning:stepId:optional_message
                let parts = trimmed.dropFirst(8).split(separator: ":", maxSplits: 1)
                let stepId = String(parts[0])
                let message = parts.count > 1 ? String(parts[1]) : "Step warning"
                handleCompletionTrigger(stepId: stepId, result: .warning(message: message))
            } else if trimmed == "reset" {
                // Reset all progress
                resetSteps()
            } else if trimmed.hasPrefix("navigate:") {
                // Navigate by index: navigate:stepIndex
                let stepIndexString = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                if let stepIndex = Int(stepIndexString), stepIndex >= 0, stepIndex < inspectState.items.count {
                    autoNavigationWorkItem?.cancel()
                    autoNavigationWorkItem = nil
                    withAnimation(.spring()) {
                        currentStep = stepIndex
                    }
                    writeLog("Preset6: Navigated to step index \(stepIndex) via trigger", logLevel: .info)
                }
            } else if trimmed.hasPrefix("listitem:") {
                // Update list item status icon
                // Format: listitem:index:X,status:icon
                let remainder = String(trimmed.dropFirst(9))
                let components = remainder.components(separatedBy: ",")

                var itemIndex: Int?
                var statusIcon: String?

                for component in components {
                    let compTrimmed = component.trimmingCharacters(in: .whitespaces)
                    if compTrimmed.hasPrefix("index:") {
                        let indexStr = compTrimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                        itemIndex = Int(indexStr)
                    } else if compTrimmed.hasPrefix("status:") {
                        statusIcon = String(compTrimmed.dropFirst(7).trimmingCharacters(in: .whitespaces))
                    }
                }

                if let index = itemIndex, index >= 0, index < inspectState.items.count {
                    if let status = statusIcon, !status.isEmpty {
                        dynamicState.updateItemStatusIcon(index: index, icon: status)
                        writeLog("Preset6: Updated item \(index) status icon to '\(status)'", logLevel: .info)
                    } else {
                        dynamicState.updateItemStatusIcon(index: index, icon: nil)
                        writeLog("Preset6: Cleared item \(index) status icon", logLevel: .info)
                    }
                }
            } else if trimmed.hasPrefix("progress:") {
                // Update progress percentage: progress:stepId:percentage
                let parts = trimmed.dropFirst(9).split(separator: ":")
                if parts.count == 2 {
                    let stepId = String(parts[0])
                    if let percentage = Int(String(parts[1])) {
                        dynamicState.updateProgress(stepId: stepId, percentage: percentage)
                        writeLog("Preset6: Updated progress for '\(stepId)': \(percentage)%", logLevel: .info)
                    }
                }
            } else if trimmed.hasPrefix("update_guidance:") {
                // Update guidance content: update_guidance:stepId:blockIndex:prop=val
                let parts = trimmed.dropFirst(16).split(separator: ":", maxSplits: 2)
                if parts.count == 3 {
                    let stepId = String(parts[0])
                    if let blockIndex = Int(String(parts[1])) {
                        let valueString = String(parts[2])

                        // Validate stepId exists
                        guard inspectState.items.contains(where: { $0.id == stepId }) else {
                            writeAcknowledgment("update_guidance", stepId: stepId, index: blockIndex, status: "error", message: "Invalid stepId")
                            continue
                        }

                        // Check if this is a property update (contains '=')
                        if valueString.contains("=") {
                            let propParts = valueString.split(separator: "=", maxSplits: 1)
                            if propParts.count == 2 {
                                let property = String(propParts[0])
                                let value = String(propParts[1])
                                dynamicState.updateGuidanceProperty(stepId: stepId, blockIndex: blockIndex, property: property, value: value)
                                logPreset6Event("guidance_property_update", details: ["stepId": stepId, "index": blockIndex, "property": property, "value": value])
                                writeAcknowledgment("property_update", stepId: stepId, index: blockIndex, status: "success", property: property, value: value)
                            }
                        } else {
                            // Legacy content update
                            dynamicState.updateGuidanceContent(stepId: stepId, blockIndex: blockIndex, content: valueString)
                            logPreset6Event("guidance_content_update", details: ["stepId": stepId, "index": blockIndex, "content": valueString])
                            writeAcknowledgment("content_update", stepId: stepId, index: blockIndex, status: "success")
                        }
                    }
                }
            } else if trimmed.hasPrefix("update_message:") {
                // Update processing message: update_message:stepId:message
                let parts = trimmed.dropFirst(15).split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let stepId = String(parts[0])
                    let message = String(parts[1])
                    dynamicState.updateMessage(stepId: stepId, message: message)
                    writeLog("Preset6: Updated message for '\(stepId)': \(message)", logLevel: .info)
                }
            } else if trimmed == "recheck:" || trimmed.hasPrefix("recheck:") {
                // Trigger plist recheck: recheck: or recheck:itemId
                let targetItemId = trimmed == "recheck:" ? nil : String(trimmed.dropFirst(8))

                if let itemId = targetItemId {
                    inspectState.recheckPlistMonitorsForItem(itemId) { itemId, blockIndex, property, newValue in
                        dynamicState.updateGuidanceProperty(stepId: itemId, blockIndex: blockIndex, property: property, value: newValue)
                    }
                    writeLog("Preset6: Manual recheck triggered for item '\(itemId)'", logLevel: .info)
                } else {
                    inspectState.recheckAllPlistMonitors { itemId, blockIndex, property, newValue in
                        dynamicState.updateGuidanceProperty(stepId: itemId, blockIndex: blockIndex, property: property, value: newValue)
                    }
                    writeLog("Preset6: Manual recheck triggered for ALL items", logLevel: .info)
                }
            } else if trimmed == "next" {
                navigateToNextStep()
            } else if trimmed == "prev" || trimmed == "back" {
                goToPreviousStep()
            } else if trimmed.hasPrefix("goto:") {
                let stepId = String(trimmed.dropFirst(5))
                if let index = inspectState.items.firstIndex(where: { $0.id == stepId }) {
                    handleStepSelection(index)
                    writeInteractionLog("goto", step: stepId)
                }
            } else if trimmed.hasPrefix("display_data:") {
                // Display dynamic key-value data
                // Format: display_data:stepId:key:value[:color]
                let parts = trimmed.dropFirst(13).split(separator: ":", maxSplits: 2)
                if parts.count >= 3 {
                    let stepId = String(parts[0])
                    let key = String(parts[1])
                    let valueAndColor = String(parts[2])

                    // Check if the last segment is a color (starts with #)
                    var value = valueAndColor
                    var color: String?

                    if let lastColonIndex = valueAndColor.lastIndex(of: ":") {
                        let potentialColor = String(valueAndColor[valueAndColor.index(after: lastColonIndex)...])
                        if potentialColor.hasPrefix("#") {
                            color = potentialColor
                            value = String(valueAndColor[..<lastColonIndex])
                        }
                    }

                    dynamicState.updateDisplayData(stepId: stepId, key: key, value: value, color: color)
                    logPreset6Event("display_data_update", details: ["stepId": stepId, "key": key, "value": value, "color": color ?? "none"])
                    writeAcknowledgment("display_data", stepId: stepId, index: 0, status: "success", property: key, value: value)
                }
            }
        }
    }

    private func stopFileMonitoring() {
        commandFileMonitorTimer?.invalidate()
        commandFileMonitorTimer = nil
        fileMonitorSource?.cancel()
        fileMonitorSource = nil
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        guard let state = persistenceService.loadState() else {
            writeLog("Preset6: No persisted state found", logLevel: .debug)
            return
        }

        completedSteps = state.completedSteps
        currentStep = min(state.currentStep, inspectState.items.count - 1)

        // Restore form inputs
        for (itemId, formState) in state.guidanceFormInputs {
            inspectState.guidanceFormInputs[itemId] = formState
        }

        writeLog("Preset6: Restored state - step \(currentStep), \(completedSteps.count) completed", logLevel: .info)
    }

    private func savePersistedState() {
        let state = Preset6State(
            completedSteps: completedSteps,
            currentStep: currentStep,
            guidanceFormInputs: inspectState.guidanceFormInputs,
            timestamp: Date()
        )

        persistenceService.saveState(state)
        writeLog("Preset6: Saved state", logLevel: .debug)
    }

    private func writeFinalTriggerFile() {
        var output: [String] = []
        output.append("preset6_completed")
        output.append("completed_steps:\(completedSteps.joined(separator: ","))")
        output.append("failed_steps:\(failedSteps.keys.joined(separator: ","))")
        output.append("skipped_steps:\(skippedSteps.joined(separator: ","))")
        output.append("timestamp:\(ISO8601DateFormatter().string(from: Date()))")

        let content = output.joined(separator: "\n")
        try? content.write(toFile: finalTriggerFilePath, atomically: true, encoding: .utf8)

        // Also write final state plist
        writeFinalStatePlist()

        writeLog("Preset6: Wrote final trigger file", logLevel: .info)
        logPreset6Event("workflow_completed", details: [
            "completedSteps": completedSteps.count,
            "failedSteps": failedSteps.count,
            "skippedSteps": skippedSteps.count
        ])
        writeInteractionLog("completed", step: "all_steps")
    }

    private func writeFinalStatePlist() {
        var finalState: [String: Any] = [
            "completed": true,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "completedSteps": Array(completedSteps),
            "failedSteps": failedSteps,
            "skippedSteps": Array(skippedSteps),
            "currentStep": currentStep,
            "totalSteps": inspectState.items.count
        ]

        // Include form inputs if any
        if !inspectState.guidanceFormInputs.isEmpty {
            var formData: [String: Any] = [:]
            for (itemId, formState) in inspectState.guidanceFormInputs {
                var itemData: [String: Any] = [:]
                // Merge all input types
                for (fieldId, value) in formState.textfields {
                    itemData[fieldId] = value
                }
                for (fieldId, value) in formState.dropdowns {
                    itemData[fieldId] = value
                }
                for (fieldId, value) in formState.radios {
                    itemData[fieldId] = value
                }
                for (fieldId, value) in formState.toggles {
                    itemData[fieldId] = value
                }
                for (fieldId, value) in formState.checkboxes {
                    itemData[fieldId] = value
                }
                for (fieldId, value) in formState.sliders {
                    itemData[fieldId] = value
                }
                formData[itemId] = itemData
            }
            finalState["formInputs"] = formData
        }

        if let plistData = try? PropertyListSerialization.data(fromPropertyList: finalState,
                                                               format: .xml,
                                                               options: 0) {
            try? plistData.write(to: URL(fileURLWithPath: interactionPlistPath), options: .atomic)
        }
    }

    // MARK: - Interaction Logging

    private func logPreset6Event(_ event: String, details: [String: Any] = [:]) {
        var logDetails = details
        logDetails["preset"] = "6"
        logDetails["currentStep"] = currentStep
        logDetails["totalSteps"] = inspectState.items.count
        logDetails["completedSteps"] = completedSteps.count

        let detailsString = logDetails.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        writeLog("Preset6: \(event) - \(detailsString)", logLevel: .info)

        // Output to console for external monitoring
        print("[PRESET6_EVENT] \(event) \(detailsString)")
    }

    private func writeInteractionLog(_ event: String, step: String) {
        writeInteractionLog(event, step: step, data: [:])
    }

    private func writeInteractionLog(_ event: String, step: String, data: [String: Any]) {
        print("[PRESET6_INTERACTION] event=\(event) step=\(step) current=\(currentStep) completed=\(completedSteps.count)")

        // Write plist snapshot
        var interaction: [String: Any] = [
            "timestamp": Date(),
            "event": event,
            "step": step,
            "currentStep": currentStep,
            "completedSteps": Array(completedSteps),
            "completedCount": completedSteps.count
        ]

        // Merge additional data
        interaction.merge(data) { (_, new) in new }

        if let plistData = try? PropertyListSerialization.data(fromPropertyList: interaction,
                                                               format: .xml,
                                                               options: 0) {
            try? plistData.write(to: URL(fileURLWithPath: interactionPlistPath), options: .atomic)
        }

        // Append to log file
        let timestamp = ISO8601DateFormatter().string(from: Date())

        var extraFields = ""
        for (key, value) in data {
            extraFields += " \(key)=\(value)"
        }

        let logEntry = "\(timestamp) event=\(event) step=\(step) current=\(currentStep) completed=\(Array(completedSteps).joined(separator: ","))\(extraFields)\n"

        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: interactionLogPath) {
                if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: interactionLogPath)) {
                    _ = try? fileHandle.seekToEnd()
                    _ = try? fileHandle.write(contentsOf: data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: interactionLogPath))
            }
        }
    }

    // MARK: - Bidirectional Acknowledgment

    private func writeAcknowledgment(_ command: String, stepId: String, index: Int, status: String, property: String? = nil, value: String? = nil, message: String? = nil) {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        var ackEntry = "\(timestamp) command=\(command) stepId=\(stepId) index=\(index) status=\(status)"
        if let property = property {
            ackEntry += " property=\(property)"
        }
        if let value = value {
            ackEntry += " value=\(value)"
        }
        if let message = message {
            ackEntry += " message=\(message)"
        }
        ackEntry += "\n"

        if let data = ackEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: acknowledgmentLogPath) {
                if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: acknowledgmentLogPath)) {
                    _ = try? fileHandle.seekToEnd()
                    _ = try? fileHandle.write(contentsOf: data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: acknowledgmentLogPath))
            }
        }
    }

    // MARK: - Dynamic Content Updates

    /// Apply dynamic property updates to guidance content blocks
    /// Enables real-time updates via trigger file commands
    private func applyDynamicUpdates(to block: InspectConfig.GuidanceContent, index: Int, itemId: String) -> InspectConfig.GuidanceContent {
        // Check if there are dynamic updates for this block
        let hasDynamicContent = dynamicState.dynamicGuidanceContent[itemId]?[index] != nil
        let hasDynamicProps = dynamicState.dynamicGuidanceProperties[itemId]?[index] != nil

        guard hasDynamicContent || hasDynamicProps else {
            return block
        }

        let props = dynamicState.dynamicGuidanceProperties[itemId]?[index] ?? [:]

        // Create new block with updated properties
        return InspectConfig.GuidanceContent(
            type: block.type,
            content: dynamicState.dynamicGuidanceContent[itemId]?[index] ?? block.content,
            items: block.items,
            numbered: block.numbered,
            color: props["color"] ?? block.color,
            bold: props["bold"].flatMap { Bool($0) } ?? block.bold,
            visible: props["visible"].flatMap { Bool($0) } ?? block.visible,
            imageShape: block.imageShape,
            imageWidth: block.imageWidth,
            imageBorder: block.imageBorder,
            caption: block.caption,
            autoplay: block.autoplay,
            videoHeight: block.videoHeight,
            webHeight: block.webHeight,
            portalURL: block.portalURL,
            portalPath: block.portalPath,
            portalHeight: block.portalHeight,
            portalShowHeader: block.portalShowHeader,
            portalShowRefetch: block.portalShowRefetch,
            portalOfflineMessage: block.portalOfflineMessage,
            portalUserAgent: block.portalUserAgent,
            portalBrandingKey: block.portalBrandingKey,
            portalBrandingHeader: block.portalBrandingHeader,
            portalCustomHeaders: block.portalCustomHeaders,
            id: block.id,
            required: block.required,
            options: block.options,
            value: block.value,
            helpText: block.helpText,
            min: block.min,
            max: block.max,
            step: block.step,
            unit: block.unit,
            discreteSteps: block.discreteSteps,
            placeholder: block.placeholder,
            secure: block.secure,
            inherit: block.inherit,
            regex: block.regex,
            regexError: block.regexError,
            maxLength: block.maxLength,
            action: block.action,
            url: block.url,
            shell: block.shell,
            shellTimeout: block.shellTimeout,
            requestId: block.requestId,
            targetBadge: block.targetBadge,
            buttonStyle: block.buttonStyle,
            opensOverlay: block.opensOverlay,
            label: props["label"] ?? block.label,
            state: props["state"] ?? block.state,
            icon: props["icon"] ?? block.icon,
            autoColor: props["autoColor"].flatMap { Bool($0) } ?? block.autoColor,
            expected: props["expected"] ?? block.expected,
            actual: props["actual"] ?? block.actual,
            expectedLabel: props["expectedLabel"] ?? block.expectedLabel,
            actualLabel: props["actualLabel"] ?? block.actualLabel,
            expectedIcon: props["expectedIcon"] ?? block.expectedIcon,
            actualIcon: props["actualIcon"] ?? block.actualIcon,
            comparisonStyle: props["comparisonStyle"] ?? block.comparisonStyle,
            highlightCells: props["highlightCells"].flatMap { Bool($0) } ?? block.highlightCells,
            expectedColor: props["expectedColor"] ?? block.expectedColor,
            actualColor: props["actualColor"] ?? block.actualColor,
            category: block.category,
            currentPhase: props["currentPhase"].flatMap { Int($0) } ?? block.currentPhase,
            phases: block.phases,
            style: props["style"] ?? block.style,
            progress: props["progress"].flatMap { Double($0) } ?? block.progress,
            images: block.images,
            captions: block.captions,
            imageHeight: block.imageHeight,
            showDots: block.showDots,
            showArrows: block.showArrows,
            autoAdvance: block.autoAdvance,
            autoAdvanceDelay: block.autoAdvanceDelay,
            transitionStyle: block.transitionStyle,
            currentIndex: props["currentIndex"].flatMap { Int($0) } ?? block.currentIndex,
            categoryName: props["categoryName"] ?? block.categoryName,
            passed: props["passed"].flatMap { Int($0) } ?? block.passed,
            total: props["total"].flatMap { Int($0) } ?? block.total,
            cardIcon: props["cardIcon"] ?? block.cardIcon,
            checkDetails: props["checkDetails"] ?? block.checkDetails,
            columns: block.columns,
            rows: block.rows,
            wallpaperCategories: block.wallpaperCategories,
            wallpaperColumns: block.wallpaperColumns,
            wallpaperLayout: block.wallpaperLayout,
            wallpaperImageFit: block.wallpaperImageFit,
            wallpaperThumbnailHeight: block.wallpaperThumbnailHeight,
            wallpaperSelectionKey: block.wallpaperSelectionKey,
            wallpaperShowPath: block.wallpaperShowPath,
            wallpaperConfirmButton: block.wallpaperConfirmButton,
            wallpaperMultiSelect: block.wallpaperMultiSelect,
            installItems: block.installItems,
            bentoColumns: block.bentoColumns,
            bentoRowHeight: block.bentoRowHeight,
            bentoGap: block.bentoGap,
            bentoTintColor: block.bentoTintColor,
            bentoCells: block.bentoCells
        )
    }
}

// MARK: - Preset6 Wrapper

struct Preset6Wrapper: View {
    @ObservedObject var coordinator: InspectState

    var body: some View {
        Preset6View(inspectState: coordinator)
    }
}

// MARK: - String Extension

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
