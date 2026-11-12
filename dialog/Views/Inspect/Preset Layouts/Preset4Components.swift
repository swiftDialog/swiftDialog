//
//  Preset4Components.swift
//  dialog
//
//  Preset 4's toast components: compact intro, check-report list, summary bar and info cards.
//

import SwiftUI

// MARK: - Icon helpers

/// Resolves a relative path against basePath.
private func toastResolvePath(_ path: String, basePath: String?) -> String? {
    guard !path.isEmpty else { return nil }
    if path.hasPrefix("/") { return path }
    guard let base = basePath else { return path }
    return (base as NSString).appendingPathComponent(path)
}

/// Synchronous icon from an already-cached path, with no spinner. Exactly one of SF symbol,
/// file image or fallback renders.
struct ToastCachedIcon: View {
    let path: String
    let fallbackSymbol: String
    var size: CGFloat = 48
    let accent: Color
    let basePath: String?

    @ViewBuilder
    var body: some View {
        let cornerRadius = size > 30 ? 10.0 : 5.0
        let symbolSize = size > 30 ? 28.0 : size * 0.6

        if let symbolName = IconRef.symbol(path) {
            Image(systemName: symbolName)
                .font(.system(size: symbolSize))
                .foregroundStyle(accent)
                .frame(width: size, height: size)
        } else if let resolvedPath = toastResolvePath(path, basePath: basePath),
                  // ItemArt, not NSImage(contentsOfFile:): the path may be an `.app` bundle directory.
                  let nsImage = ItemArt.image(at: resolvedPath) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            Image(systemName: fallbackSymbol)
                .font(.system(size: symbolSize))
                .foregroundStyle(accent.opacity(0.6))
                .frame(width: size, height: size)
        }
    }
}

/// Async icon for the intro and summary heroes.
struct ToastHeroIcon: View {
    let path: String
    let fallbackSymbol: String
    let accent: Color
    let basePath: String?
    /// Icon size: 48 for a hero, 36 for an info card glyph.
    var size: CGFloat = 48

    var body: some View {
        if !path.isEmpty {
            AsyncImageView(
                iconPath: path,
                basePath: basePath,
                maxWidth: size,
                maxHeight: size,
                imageFit: .fit
            ) {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: size * 7 / 12))
                    .foregroundStyle(accent.opacity(0.6))
                    .frame(width: size, height: size)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: fallbackSymbol)
                .font(.system(size: size * 7 / 12))
                .foregroundStyle(accent.opacity(0.6))
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Info cards (`messageStyle: "info"`)

/// A single-answer info card: one glyph, one line of context, one answer, one button.
/// `messageStyle: "info"` shows one per item, or one from the intro screen and `message` when there are none.
struct InfoCardContent: Equatable {
    let id: String
    let title: String
    let context: String?
    let glyph: String?
    let answer: String
    let buttonText: String

    /// One card per item: displayName, subtitle, icon, claim, continueButtonText.
    init(item: InspectConfig.ItemConfig) {
        id = item.id
        title = item.displayName
        context = item.subtitle
        glyph = item.icon
        answer = item.claim ?? ""
        buttonText = item.continueButtonText ?? "Got it"
    }

    /// No items: the intro screen (title, subtitle, heroImage, buttonText) plus the root message.
    init(config: InspectConfig?) {
        let intro = config?.introScreen
        id = "info"
        title = intro?.title ?? config?.title ?? ""
        context = intro?.subtitle
        glyph = intro?.heroImage
        answer = config?.message ?? ""
        buttonText = intro?.buttonText ?? "Got it"
    }

    static func cards(for config: InspectConfig?, items: [InspectConfig.ItemConfig]) -> [InfoCardContent] {
        items.isEmpty ? [InfoCardContent(config: config)] : items.map(InfoCardContent.init(item:))
    }
}

/// Shows cards one at a time; each button posts which card was acknowledged, and the last closes the dialog.
struct ToastInfoSequence: View {
    @ObservedObject var state: InspectState
    let accent: Color
    let basePath: String?
    let onDone: () -> Void
    @State private var index = 0

    var body: some View {
        let cards = InfoCardContent.cards(for: state.config, items: state.items)
        let card = cards[min(index, cards.count - 1)]
        ToastInfoCard(content: card, accent: accent, basePath: basePath,
                        position: cards.count > 1 ? (index + 1, cards.count) : nil) {
            DialogNotifications.postButtonClick(stepId: card.id, label: card.buttonText, action: "done")
            if index < cards.count - 1 {
                withAnimation(InspectConstants.stepTransition) { index += 1 }
            } else {
                onDone()
            }
        }
        .id(card.id)
        .transition(.opacity)
    }
}

struct ToastInfoCard: View {
    @Environment(\.palette) private var palette
    let content: InfoCardContent
    let accent: Color
    let basePath: String?
    /// "1 of 3" in the footer when there is more than one card; nil for a single card.
    let position: (Int, Int)?
    let onDoor: () -> Void

    /// Inline markdown only, so `**bold**` works and nothing becomes a block.
    private var answer: AttributedString {
        guidanceAttributedMarkdown(content.answer)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                glyph
                VStack(alignment: .leading, spacing: 2) {
                    Text(content.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                    if let context = content.context, !context.isEmpty {
                        Text(context)
                            .font(.system(size: 12))
                            .foregroundStyle(palette.textMuted)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.bottom, 14)
            Rectangle().fill(palette.text.opacity(0.08)).frame(height: 0.5)
            Text(answer)
                .font(.system(size: 13.5))
                .foregroundStyle(palette.text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Rectangle().fill(palette.text.opacity(0.08)).frame(height: 0.5)
                HStack {
                    if let position {
                        Text("\(position.0) of \(position.1)")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.textMuted)
                            .monospacedDigit()
                    }
                    Spacer()
                    PrimaryActionButton(tint: accent, controlSize: .large, action: onDoor) {
                        Text(content.buttonText)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            }
        }
        .sourceTag()
    }

    /// An SF symbol draws the tinted 36 pt tile; an image path uses the toast's hero icon at that size.
    @ViewBuilder private var glyph: some View {
        let path = content.glyph ?? ""
        if path.lowercased().hasPrefix("sf=") {
            Image(systemName: String(path.dropFirst(3)))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 9).fill(accent.opacity(0.1)))
        } else {
            ToastHeroIcon(path: path, fallbackSymbol: "exclamationmark.circle", accent: accent,
                          basePath: basePath, size: 36)
        }
    }
}

// MARK: - Compact intro bar

struct ToastIntroBar: View {
    @ObservedObject var state: InspectState
    let accent: Color
    let basePath: String?
    let onContinue: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            let heroPath = state.config?.introScreen?.heroImage
                ?? state.uiConfiguration.iconPath ?? ""
            ToastHeroIcon(path: heroPath, fallbackSymbol: "info.circle.fill", accent: accent, basePath: basePath)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.config?.introScreen?.title ?? state.config?.title ?? "Welcome")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                if let subtitle = state.config?.introScreen?.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                // Defer menu: the shared deferral (exit code 10, result file, environment options).
                if state.buttonConfiguration.button2Visible || isDeferralEnabled(config: state.config) {
                    DeferralMenuView(
                        config: state.config,
                        accentColor: accent,
                        buttonText: state.buttonConfiguration.button2Text.isEmpty
                            ? nil : state.buttonConfiguration.button2Text,
                        style: .compact
                    )
                }

                // The shared primary button: Return presses it and the flow's button shape applies.
                PrimaryActionButton(tint: accent, controlSize: .small, action: {
                    DialogNotifications.postButtonClick(stepId: "intro", label: "Continue", action: "continue")
                    onContinue()
                }) {
                    Text(state.config?.introScreen?.buttonText ?? ChromeCopy.continue)
                }
            }
        }
        .padding(.horizontal, 20)
        .sourceTag()
    }
}

// MARK: - Compact check-report list

/// All items at once as a compact check report with live status colours.
struct ToastReportList: View {
    @Environment(\.palette) private var palette
    @ObservedObject var state: InspectState
    @ObservedObject var iconCache: PresetIconCache
    let accent: Color
    let basePath: String?
    let onDone: () -> Void

    /// Items in a terminal state (completed or failed).
    private var terminalCount: Int {
        state.trackedCompletedCount + state.trackedFailedCount
    }

    /// Whether every item is in a terminal state.
    private var allItemsTerminal: Bool {
        !state.trackedItems.isEmpty && terminalCount >= state.trackedItems.count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                let heroPath = state.config?.introScreen?.heroImage
                    ?? state.uiConfiguration.iconPath ?? ""
                ToastHeroIcon(path: heroPath, fallbackSymbol: "shield.checkered", accent: accent, basePath: basePath)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.config?.title ?? "System Check")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    Text(reportProgressText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if allItemsTerminal {
                    PrimaryActionButton(tint: accent, controlSize: .small, action: onDone) {
                        Text(state.config?.summaryScreen?.buttonText ?? ChromeCopy.done)
                    }
                } else {
                    IndeterminateRing(size: 16, color: accent, lineWidth: 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()
                .padding(.horizontal, 12)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(state.items, id: \.id) { item in
                        reportItemRow(item)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .sourceTag()
    }

    /// Report progress text, updated as checks complete.
    private var reportProgressText: String {
        if allItemsTerminal {
            let failedCount = state.trackedFailedCount
            if failedCount > 0 {
                return "\(state.trackedCompletedCount) passed, \(failedCount) failed"
            }
            return "All \(state.trackedItems.count) checks passed"
        }
        return "\(terminalCount) of \(state.trackedItems.count) checks complete"
    }

    /// One report row: status icon, item icon, name and status badge.
    @ViewBuilder
    private func reportItemRow(_ item: InspectConfig.ItemConfig) -> some View {
        HStack(spacing: 8) {
            reportItemStatusIcon(for: item)

            ToastCachedIcon(
                path: iconCache.getItemIconPath(for: item, state: state),
                // `app.dashed`, as AppIconView draws for "no icon"; `app.fill` reads as a broken image.
                fallbackSymbol: "app.dashed",
                size: 20,
                accent: accent,
                basePath: basePath
            )

            Text(item.displayName)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer()

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

    /// Status icon, text and colour for a report row from the shared row model
    /// (`ItemSetModel.row` / `itemStatusColor`).
    @ViewBuilder
    private func reportItemStatusIcon(for item: InspectConfig.ItemConfig) -> some View {
        let row = ItemSetModel.row(for: item, state: state)
        switch row.status {
        case .failed: StatusIconView(.failure, size: 14)
        case .completed: StatusIconView(row.hasWarning ? .warning : .success, size: 14)
        default: StatusIconView(.pending, size: 14)
        }
    }

    private func reportItemStatusText(for item: InspectConfig.ItemConfig) -> String {
        ItemSetModel.row(for: item, state: state).statusText
    }

    private func reportItemStatusColor(for item: InspectConfig.ItemConfig) -> Color {
        let row = ItemSetModel.row(for: item, state: state)
        return ItemSetModel.itemStatusColor(row.status, hasWarning: row.hasWarning, palette: palette)
    }
}

// MARK: - Compact summary bar

struct ToastSummaryBar: View {
    @ObservedObject var state: InspectState
    let accent: Color
    let basePath: String?
    let onClose: () -> Void

    @Environment(\.palette) private var palette

    /// Whether any item uses plist status monitoring.
    private var hasPlistMonitoring: Bool {
        state.items.contains(where: { $0.plistKey != nil })
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                // summaryScreen heroImage, else intro heroImage, else a status icon.
                summaryHeroIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.config?.summaryScreen?.title ?? "Installation Complete")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    if let subtitle = state.config?.summaryScreen?.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        summarySubtitleText
                    }
                }

                Spacer()

                PrimaryActionButton(tint: accent, controlSize: .small, action: {
                    DialogNotifications.postButtonClick(stepId: "summary", label: "Close", action: "close")
                    onClose()
                }) {
                    Text(state.config?.summaryScreen?.buttonText ?? "Close")
                }
            }

            // Per-item status dots. `summaryScreen.itemStrip`: "never" hides them; "auto" shows them only while
            // every name fits untruncated.
            if !state.items.isEmpty {
            switch Self.itemStripMode(state.config?.summaryScreen?.itemStrip) {
            case .never:
                EmptyView()
            case .always:
                itemStrip(truncating: true).padding(.horizontal, 20)
            case .auto:
                ViewThatFits(in: .horizontal) {
                    itemStrip(truncating: false)
                    EmptyView()
                }
                .padding(.horizontal, 20)
            }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .sourceTag()
    }

    /// Summary hero icon: summaryScreen heroImage, intro heroImage, config icon, or a status symbol.
    @ViewBuilder
    private var summaryHeroIcon: some View {
        let heroPath = state.config?.summaryScreen?.heroImage
            ?? state.config?.introScreen?.heroImage
            ?? state.uiConfiguration.iconPath ?? ""

        if !heroPath.isEmpty {
            ToastHeroIcon(path: heroPath, fallbackSymbol: summaryFallbackSymbol, accent: accent, basePath: basePath)
        } else {
            let failedCount = state.trackedFailedCount
            if failedCount == 0 {
                StatusIconView(.success, size: 36)
                    .frame(width: 48, height: 48)
            } else if failedCount < state.trackedItems.count {
                StatusIconView(.warning, size: 36)
                    .frame(width: 48, height: 48)
            } else {
                StatusIconView(.failure, size: 36)
                    .frame(width: 48, height: 48)
            }
        }
    }

    /// SF Symbol for the summary fallback, by result.
    private var summaryFallbackSymbol: String {
        let failedCount = state.trackedFailedCount
        if failedCount == 0 { return "checkmark.circle.fill" }
        if failedCount < state.trackedItems.count { return "exclamationmark.triangle.fill" }
        return "xmark.circle.fill"
    }

    /// Summary subtitle with counts.
    private var summarySubtitleText: some View {
        let failedCount = state.trackedFailedCount
        let passedCount = state.trackedCompletedCount
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

    enum ItemStripMode: Equatable { case always, never, auto }

    /// Parses `summaryScreen.itemStrip`; absent or unknown values show the strip.
    static func itemStripMode(_ raw: String?) -> ItemStripMode {
        switch raw?.lowercased() {
        case "never": return .never
        case "auto": return .auto
        default: return .always
        }
    }

    /// The dots and names. Untruncated names keep their full width, which is how `auto` detects overflow.
    private func itemStrip(truncating: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(state.items, id: \.id) { item in
                HStack(spacing: 3) {
                    itemStatusDot(for: item)
                    Text(shortName(item.displayName))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: !truncating, vertical: false)
                }
            }
            if truncating { Spacer() }
        }
    }

    /// Small coloured dot for the summary strip.
    @ViewBuilder
    private func itemStatusDot(for item: InspectConfig.ItemConfig) -> some View {
        if state.failedItems.contains(item.id) {
            Circle().fill(palette.error).frame(width: 6, height: 6)
        } else if state.completedItems.contains(item.id) {
            Circle().fill(palette.success).frame(width: 6, height: 6)
        } else {
            Circle().fill(Color.secondary.opacity(0.3)).frame(width: 6, height: 6)
        }
    }

    /// Shortens a display name for the summary strip.
    private func shortName(_ name: String) -> String {
        let shortened = name
            .replacingOccurrences(of: "Microsoft ", with: "")
        return shortened
    }
}
