//
//  PresetCommonViews.swift
//  dialog
//
//  Reusable view primitives shared across preset layouts.
//

import SwiftUI

/// `statusIndicator`'s pending ring, its own `View` so it can read the palette from the environment.
private struct PendingCircleIcon: View {
    let size: CGFloat

    @Environment(\.palette) private var palette

    var body: some View {
        Circle()
            .strokeBorder(palette.text.opacity(0.3), lineWidth: 2)
            .frame(width: size, height: size)
    }
}

private struct CompletedCheckmarkIcon: View {
    let size: CGFloat

    @Environment(\.palette) private var palette

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(palette.success)
            .font(.system(size: size))
    }
}

// MARK: - Common View Components
@MainActor
struct PresetCommonViews {

    // The progress bar lives in the `ProgressBar` component.

    // MARK: Status Indicator
    @ViewBuilder
    static func statusIndicator(
        for item: InspectConfig.ItemConfig,
        state: InspectState,
        size: CGFloat = 20
    ) -> some View {
        if state.completedItems.contains(item.id) {
            CompletedCheckmarkIcon(size: size)
        } else if state.downloadingItems.contains(item.id) {
            ProgressView()
                .scaleEffect(size / 25)
                .frame(width: size, height: size)
        } else {
            PendingCircleIcon(size: size)
        }
    }

    // MARK: Install Row Status (shared decision for preset item indicators)

    /// The row's `StepStatus`, derived once from InspectState's membership sets and shared by
    /// Preset1/2/3. A plist-validation warning is `.completed` plus `hasValidationWarning`, never
    /// a fifth state, and the wire's `status` never carries it.
    static func resolveInstallStatus(for item: InspectConfig.ItemConfig, state: InspectState) -> StepStatus {
        resolveInstallStatus(id: item.id, state: state)
    }

    /// The same ladder, by ID, so `ListItem` rows can use it. Every writer goes through
    /// `ItemLifecycle`, so failed and completed are exclusive; `failed` first is only a backstop.
    static func resolveInstallStatus(id: String, state: InspectState) -> StepStatus {
        if state.failedItems.contains(id) { return .failed }
        if state.completedItems.contains(id) { return .completed }
        if state.downloadingItems.contains(id) { return .active }
        return .pending
    }

    /// The completed-but-validation-failed (orange) state, shared by Preset1/2/3. A missing result
    /// triggers validation lazily and reads as "no warning" until it lands.
    static func hasValidationWarning(for item: InspectConfig.ItemConfig, state: InspectState) -> Bool {
        guard state.completedItems.contains(item.id) else { return false }
        let hasPlistValidation = item.plistKey != nil ||
            state.plistSources?.contains(where: { item.paths.contains($0.path) }) == true
        if hasPlistValidation {
            guard let result = state.plistValidationResults[item.id] else {
                // Missing result → kick off validation; assume passed until it completes.
                Task { @MainActor in
                    _ = state.validatePlistItem(item)
                }
                return false
            }
            return !result
        }
        return false
    }

    // MARK: Button Area
    /// Shared button1/button2 footer. Pass `config` + `triggerFilePath` so exits clean up the
    /// readiness file. The disabled primary stays visible and greyed.
    @MainActor
    @ViewBuilder
    static func buttonArea(
        state: InspectState,
        spacing: CGFloat = 12,
        controlSize: ControlSize = .large,
        tintColor: Color? = nil,
        onButton1Action: (() -> Void)? = nil,
        config: InspectConfig? = nil,
        triggerFilePath: String? = nil
    ) -> some View {
        // The released label follows the release itself: completed or failed (`allRequiredItemsFinished`).
        let allItemsCompleted = state.allRequiredItemsFinished
        let shouldUseAutoEnableText = allItemsCompleted &&
                                      state.buttonConfiguration.autoEnableButton &&
                                      state.config?.autoEnableButtonText != nil

        // autoEnableButtonText (when complete) > finalButtonText > button1Text > buttonConfiguration > "Continue"
        let finalButtonText = shouldUseAutoEnableText
            ? (state.config?.autoEnableButtonText ?? "OK")
            : (state.config?.finalButtonText ??
               state.config?.button1Text ??
               (state.buttonConfiguration.button1Text.isEmpty ? ChromeCopy.continue : state.buttonConfiguration.button1Text))

        HStack(spacing: spacing) {
            // Button 2 shows in demo mode or when all complete.
            if (state.configurationSource == .testData || state.allRequiredItemsCompleted) &&
               state.buttonConfiguration.button2Visible &&
               !state.buttonConfiguration.button2Text.isEmpty {
                Button {
                    if state.configurationSource == .testData && (state.buttonConfiguration.button2Text.contains("Create") || state.buttonConfiguration.button2Text.contains("Config")) {
                        writeLog("Preset: Creating sample configuration", logLevel: .info)
                        state.createSampleConfiguration()
                    } else if ButtonExit.minimizeInsteadOfExiting(state.config?.button2Action, label: "Preset") {
                        return
                    } else {
                        writeLog("Preset: User clicked button2 - exiting with code 2", logLevel: .info)
                        writeItemPresetResultFile(state: state, exitCode: 2)
                        if let triggerFilePath {
                            cleanupReadinessFile(state: state, triggerFilePath: triggerFilePath, exitCode: 2)
                        }
                        exit(2)
                    }
                } label: {
                    ButtonSymbolLabel(text: state.buttonConfiguration.button2Text,
                                      spec: InspectButtonSymbolSpec.parse(state.buttonConfiguration.button2Symbol))
                }
                .buttonStyle(.bordered)
                .controlSize(controlSize)
            }

            // Button 1 goes through the shared PrimaryActionButton, like intro/outro.
            PrimaryActionButton(tint: tintColor, action: {
                if let action = onButton1Action {
                    writeLog("Preset: User clicked button1 (\(finalButtonText)) - custom action", logLevel: .info)
                    action()
                } else if ButtonExit.minimizeInsteadOfExiting(state.config?.button1Action, label: "Preset") {
                    return
                } else {
                    writeLog("Preset: User clicked button1 (\(finalButtonText)) - exiting with code 0", logLevel: .info)
                    writeItemPresetResultFile(state: state, exitCode: 0)
                    if let triggerFilePath {
                        cleanupReadinessFile(state: state, triggerFilePath: triggerFilePath, exitCode: 0)
                    }
                    exit(0)
                }
            }) {
                ButtonSymbolLabel(text: finalButtonText,
                                  spec: InspectButtonSymbolSpec.parse(state.buttonConfiguration.button1Symbol))
            }
            .disabled(state.buttonConfiguration.button1Disabled)
        }
    }

    // MARK: Progress Text
    /// Progress bar text from a template with `{completed}` and `{total}`.
    /// `localizedFormat` (when non-nil) wins over the config format.
    static func getProgressText(state: InspectState, localizedFormat: String? = nil) -> String {
        let completed = state.completedItems.count
        let total = state.items.count

        if let text = localizedFormat ?? state.config?.uiLabels?.progressFormat {
            return fillProgressTokens(text, completed: completed, total: total)
        }

        return "\(completed) of \(total) completed"
    }

    /// Forgiving tokens, all three spellings 3.1.1 accepted: {completed}/{total},
    /// $completed/$total, %completed%/%total%.
    nonisolated static func fillProgressTokens(_ format: String, completed: Int, total: Int) -> String {
        var text = format
        for token in ["{completed}", "$completed", "%completed%"] {
            text = text.replacingOccurrences(of: token, with: "\(completed)")
        }
        for token in ["{total}", "$total", "%total%"] {
            text = text.replacingOccurrences(of: token, with: "\(total)")
        }
        return text
    }

    // MARK: Sorted Items

    /// Ordering policy for status-sorted item lists; each preset picks its own.
    /// - `completedFirst` (Preset 1): Completed → Installing → Waiting
    /// - `activeFirst` (Preset 3): Installing → Completed → Waiting, stable by guiIndex
    /// - `upNext` (Preset 1's `itemSortOrder: "activeFirst"`): Installing → Waiting → Done
    /// - `guiIndex` (`itemSortOrder: "guiIndex"`): config order
    enum ItemOrder: Equatable {
        case completedFirst
        case activeFirst
        case upNext
        case guiIndex

        /// The root `itemSortOrder` key. Absent or unknown keeps today's order.
        init(itemSortOrder: String?) {
            switch itemSortOrder?.lowercased() {
            case "activefirst": self = .upNext
            case "guiindex": self = .guiIndex
            default: self = .completedFirst
            }
        }

        /// Whether the list scrolls to keep the installing item in view, so finished rows move out of
        /// sight. `.activeFirst` already seats it at the top.
        var followsActive: Bool { self != .activeFirst }
    }

    static func getSortedItemsByStatus(_ state: InspectState, order: ItemOrder = .completedFirst) -> [InspectConfig.ItemConfig] {
        switch order {
        case .completedFirst:
            // One group per item: an item can sit in both sets, and completion wins as in
            // `resolveInstallStatus`.
            let completed = state.items.filter { state.completedItems.contains($0.id) }
            let downloading = state.items.filter {
                state.downloadingItems.contains($0.id) && !state.completedItems.contains($0.id)
            }
            let pending = state.items.filter { item in
                !state.completedItems.contains(item.id) &&
                !state.downloadingItems.contains(item.id)
            }
            return completed + downloading + pending

        case .activeFirst:
            func priority(_ item: InspectConfig.ItemConfig) -> Int {
                if state.downloadingItems.contains(item.id) { return 0 }   // Installing first
                if state.completedItems.contains(item.id) { return 1 }     // Completed second
                return 2                                                    // Pending last
            }
            return state.items.sorted { a, b in
                let pa = priority(a), pb = priority(b)
                if pa != pb { return pa < pb }
                return a.guiIndex < b.guiIndex   // Same status → original GUI order
            }

        case .upNext:
            // Done means completed OR failed: a failed item is finished, not waiting.
            func rank(_ item: InspectConfig.ItemConfig) -> Int {
                let done = state.completedItems.contains(item.id) || state.failedItems.contains(item.id)
                if done { return 2 }
                return state.downloadingItems.contains(item.id) ? 0 : 1
            }
            return state.items.sorted { a, b in
                let ra = rank(a), rb = rank(b)
                if ra != rb { return ra < rb }
                return a.guiIndex < b.guiIndex
            }

        case .guiIndex:
            return state.items.sorted { $0.guiIndex < $1.guiIndex }
        }
    }
}


// MARK: - Instruction Banner Component

/// Semi-transparent instruction banner with text and optional icon, shared by every preset.
struct InstructionBanner: View {
    let text: String
    let autoDismiss: Bool
    let dismissDelay: Double
    let backgroundColor: Color
    let icon: String?

    @State private var isVisible: Bool = true

    init(
        text: String,
        autoDismiss: Bool = true,
        dismissDelay: Double = 5.0,
        backgroundColor: Color = Color.black.opacity(0.7),
        icon: String? = nil
    ) {
        self.text = text
        self.autoDismiss = autoDismiss
        self.dismissDelay = dismissDelay
        self.backgroundColor = backgroundColor
        self.icon = icon
    }

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                if let iconName = icon {
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                }

                Text(text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Spacer()

                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Dismiss instruction")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                backgroundColor
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            // SwiftUI cancels the `.task` when the banner leaves, manual dismiss included.
            .task {
                guard autoDismiss else { return }
                do { try await Task.sleep(for: .seconds(dismissDelay)) } catch { return }
                dismiss()
            }
        }
    }

    /// Dismiss the banner with animation
    func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
    }
}

// MARK: - Source Stamp

extension View {
    /// Stamps the call site's "<fileID>:<line>" into the accessibility identifier so an AX dump
    /// maps every screen to the file that drew its root. Debug-only. #fileID, never #file, which
    /// would make AX baselines machine-specific.
    func sourceTag(_ file: String = #fileID, _ line: Int = #line) -> some View {
        #if DEBUG
        return accessibilityIdentifier("\(file):\(line)")
        #else
        return self
        #endif
    }
}

// MARK: - Item claim and identifier (presets 1–3 and the carousel)

/// An item's optional claim and identifier, rendered the same way wherever a preset shows a row.
/// Both are independent; a row with neither draws nothing.
struct ItemClaimAndIdentifier: View {
    let claim: String?
    let identifier: String?
    var scaleFactor: CGFloat = 1
    /// How many identifier characters survive before it clips (always from the left).
    var identifierChars: Int = 30

    @Environment(\.palette) private var palette

    var body: some View {
        let claimText = (claim?.isEmpty == false) ? claim : nil
        let idText = (identifier?.isEmpty == false) ? identifier : nil
        if claimText != nil || idText != nil {
            VStack(alignment: .leading, spacing: 1 * scaleFactor) {
                if let claimText {
                    // Full reading weight: the claim is written for a human, not metadata.
                    Text(claimText)
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let idText {
                    // Clipped from the left: the distinguishing part of a bundle id is its tail.
                    Text(CarouselM.truncatedIdentifier(idText, maxChars: identifierChars))
                        .font(.system(size: 10 * scaleFactor, design: .monospaced))
                        .foregroundStyle(palette.textFaint)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
        }
    }
}

// MARK: - Primary action button

/// The shared primary action button for intro, main and outro phases, so shape, prominence and
/// keyboard behavior match across phases.
struct PrimaryActionButton<Label: View>: View {
    /// Set once by `InspectMetrics.buttonControlSize` at the preset root.
    @Environment(\.footerControlSize) private var footerControlSize
    /// The flow's button flavour; see `InspectButtonShape`.
    @Environment(\.inspectButtonShape) private var buttonShape
    var tint: Color?
    /// An explicit size that overrides the environment; nil keeps the injected value.
    /// `IntroFooterView` passes one so Preset 6's `.large` survives a dense type scale.
    var controlSize: ControlSize?
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action, label: label)
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(controlSize ?? footerControlSize)
            .inspectButtonShape(buttonShape)
            .tint(tint)
    }
}
