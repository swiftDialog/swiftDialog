//
//  BookendScreenView.swift
//  dialog
//
//  The bookend (intro/outro) surface: the shared centred column plus the six named ceremony
//  layouts (overview / welcome / explainer, dock / receipt / nextsteps). Used by the preset
//  phase bookends and by Preset 6's intro/outro view.
//

import SwiftUI

/// The bookend surface. A named ceremony owns its footer; the centred column draws the shared
/// footer only when the host passes `onAction`.
struct BookendScreenView<Context: UserInputContext & ProgressContext & ObservableObject>: View {

    enum Role {
        case intro
        case outro
    }

    let role: Role

    /// "centered" or any unrecognised value is the plain column; a named ceremony needs its
    /// `intro`/`summary` config and falls back to the column without it.
    var layout: String = "centered"

    // Hero for the column arm. `heroSize == nil` sizes proportionally to the viewport.
    var heroPath: String?
    var heroShape: String = "none"
    var heroSize: Double?
    var heroPadding: Double?

    var title: String?
    var subtitle: String?

    /// Blocks the host has already localized and merged.
    var contentBlocks: [InspectConfig.GuidanceContent] = []

    /// A bento grid in place of `contentBlocks`, matching the config's `bentoCells ?? content`
    /// precedence.
    struct BentoBody {
        let cells: [InspectConfig.GuidanceContent.BentoCellConfig]
        var columns: Int = 2
        var rowHeight: CGFloat = 120
        var gap: CGFloat = 12
    }
    var bento: BentoBody?

    let accentColor: Color
    let scaleFactor: CGFloat
    var iconBasePath: String?
    let itemId: String
    @ObservedObject var inspectState: Context

    // MARK: Ceremony context (nil for column-only hosts)

    var intro: InspectConfig.PresetIntroScreen?
    var summary: InspectConfig.PresetSummaryScreen?
    var userName: String?
    var localize: ((String) -> String?)?
    /// Pre-scale footer inset; nil uses the shared footer token.
    var footerHorizontalPadding: CGFloat?
    /// Resolved label for the centered arm's primary button (ceremonies resolve their own).
    var primaryButtonText: String?
    /// Non-nil makes the centered column draw the shared footer.
    var onAction: (() -> Void)?

    private var metrics: InspectMetrics { InspectMetrics(scale: scaleFactor) }

    /// Wide block types need the wider measure or their cells pack to the left.
    private var contentMaxWidth: CGFloat {
        contentBlocks.contains { InspectConfig.GuidanceContent.wideLayoutTypes.contains($0.type) }
            ? metrics.wideContentMaxW
            : metrics.contentMaxW
    }

    var body: some View {
        switch (layout, intro, summary) {
        case ("overview", let intro?, _):
            PresetIntroOverviewView(
                config: intro, highlightColor: accentColor, scaleFactor: scaleFactor,
                basePath: iconBasePath, inspectState: inspectState, userName: userName,
                localize: localize, footerHorizontalPadding: footerHorizontalPadding,
                onContinue: onAction ?? {}
            )
        case ("welcome", let intro?, _):
            PresetIntroWelcomeView(
                config: intro, highlightColor: accentColor, scaleFactor: scaleFactor,
                basePath: iconBasePath, inspectState: inspectState, userName: userName,
                localize: localize, footerHorizontalPadding: footerHorizontalPadding,
                onContinue: onAction ?? {}
            )
        case ("explainer", let intro?, _):
            PresetIntroExplainerView(
                config: intro, highlightColor: accentColor, scaleFactor: scaleFactor,
                basePath: iconBasePath, inspectState: inspectState, userName: userName,
                localize: localize, footerHorizontalPadding: footerHorizontalPadding,
                onContinue: onAction ?? {}
            )
        case ("dock", _, let summary?):
            PresetOutroDockView(
                config: summary, highlightColor: accentColor, scaleFactor: scaleFactor,
                inspectState: inspectState, userName: userName, localize: localize,
                footerHorizontalPadding: footerHorizontalPadding,
                onClose: onAction ?? {}
            )
        case ("receipt", _, let summary?):
            PresetOutroReceiptView(
                config: summary, highlightColor: accentColor, scaleFactor: scaleFactor,
                inspectState: inspectState, userName: userName, localize: localize,
                footerHorizontalPadding: footerHorizontalPadding,
                onClose: onAction ?? {}
            )
        case ("nextsteps", _, let summary?):
            PresetOutroNextStepsView(
                config: summary, highlightColor: accentColor, scaleFactor: scaleFactor,
                inspectState: inspectState, userName: userName, localize: localize,
                footerHorizontalPadding: footerHorizontalPadding,
                onClose: onAction ?? {}
            )
        default:
            centeredScreen
        }
    }

    // MARK: - The centred column

    /// Column plus the shared footer when the host passes `onAction`.
    private var centeredScreen: some View {
        VStack(spacing: 0) {
            centeredColumn
            if let onAction {
                BookendFooterRow(
                    state: inspectState, highlightColor: accentColor, scaleFactor: scaleFactor,
                    showsRule: false, spacing: nil,
                    footerHorizontalPadding: footerHorizontalPadding,
                    buttonText: primaryButtonText ?? (role == .intro ? "Get Started" : "Close"),
                    onContinue: onAction
                )
            }
        }
        .sourceTag()
    }

    private var centeredColumn: some View {
        AnchoredStepContent(
            metrics: metrics,
            horizontalPadding: metrics.contentPadH,
            spacing: metrics.sectionGap,
            // A top-biased centre reads as slipped downward on a full-window bookend.
            symmetricCenter: true,
            viewportContent: { viewportHeight in
                VStack(spacing: metrics.sectionGap) {
                    if let heroPath, !heroPath.isEmpty {
                        let proportional = Double(min(max(viewportHeight * 0.28, 100), 180))
                        IntroHeroImage(
                            path: heroPath,
                            shape: heroShape,
                            size: heroSize ?? proportional,
                            accentColor: accentColor,
                            basePath: iconBasePath,
                            padding: heroPadding
                        )
                    }

                    VStack(spacing: metrics.titleSubtitle) {
                        if let title, !title.isEmpty {
                            Text(title)
                                .font(metrics.phaseTitle)
                                .multilineTextAlignment(.center)
                        }
                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(metrics.phaseSubtitle)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    if let bento, !bento.cells.isEmpty {
                        BentoGridView(
                            cells: bento.cells,
                            columns: bento.columns,
                            rowHeight: bento.rowHeight,
                            gap: bento.gap,
                            scaleFactor: scaleFactor,
                            accentColor: accentColor,
                            iconBasePath: iconBasePath,
                            tintColor: nil,
                            inspectState: inspectState
                        )
                    } else if !contentBlocks.isEmpty {
                        GuidanceContentView(
                            contentBlocks: contentBlocks,
                            scaleFactor: scaleFactor,
                            iconBasePath: iconBasePath,
                            inspectState: inspectState,
                            itemId: itemId,
                            accentColor: accentColor,
                            contentAlignment: .center
                        )
                        .frame(maxWidth: contentMaxWidth)
                    }
                }
            }
        )
    }
}

// MARK: - Intro Overview Variation

/// "overview" intro: hero band with a user-badge chip, left-aligned greeting, stat tiles and a
/// footer with footnote and item-list link. Stat values come from config; `{itemCount}` resolves.
struct PresetIntroOverviewView<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    @Environment(\.palette) private var palette

    let config: InspectConfig.PresetIntroScreen
    let highlightColor: Color
    let scaleFactor: CGFloat
    let basePath: String?
    @ObservedObject var inspectState: Context
    var userName: String?
    var localize: ((String) -> String?)?  // Sidecar lookup (nil = config strings, byte-identical)
    var footerHorizontalPadding: CGFloat?
    let onContinue: () -> Void

    @Environment(\.colorScheme) private var scheme

    private func withUserName(_ text: String) -> String {
        resolvePhaseText(text, userName: userName, itemCount: inspectState.items.count)
    }

    private func locText(_ key: String, _ configValue: String?, default defaultText: String? = nil) -> String? {
        resolveLocalizedPhaseText(key: key, config: configValue, default: defaultText,
                                  localize: localize, userName: userName,
                                  itemCount: inspectState.items.count)
    }

    /// Localization first, then `{itemCount}` and managed tokens (no `{userName}`).
    private func resolvedStatValue(key: String, _ value: String) -> String {
        let text = localizedPhaseValue(key, localize: localize, config: value) ?? value
        return resolveManagedLine(text.replacingOccurrences(of: "{itemCount}", with: "\(inspectState.items.count)"))
    }

    /// Badge text after managed-token/{userName} resolution; empty hides the chip.
    private var resolvedBadge: String {
        config.userBadge.map { withUserName($0) } ?? ""
    }

    /// Band leading (default), band trailing, or the footer's leading cluster.
    private var chipPlacement: BookendChipPlacement {
        BookendChipPlacement(position: config.userBadgePosition)
    }

    private var resolvedStats: [BookendStatStrip.Stat] {
        (config.stats ?? []).enumerated().map { index, stat in
            BookendStatStrip.Stat(
                value: resolvedStatValue(key: "introScreen.stats.\(index).value", stat.value),
                label: localizedPhaseValue("introScreen.stats.\(index).label",
                                           localize: localize, config: stat.label) ?? stat.label
            )
        }
    }

    private var bandColor: Color { palette.surfaceRaised }

    /// Same source as the main phase's banner, so the band edge holds across the transition.
    private var bandHeight: CGFloat {
        CGFloat(inspectState.uiConfiguration.bannerHeight) * scaleFactor
    }

    /// Explicit `heroImageSize` wins; otherwise capped by height and, from the trimmed aspect,
    /// by width so a wide wordmark stays sane.
    private func heroLogoHeight(for path: String) -> CGFloat {
        if let explicit = config.heroImageSize { return CGFloat(explicit) }
        let maxHeight = min(48 * scaleFactor, bandHeight * 0.34)
        let maxWidth = 300 * scaleFactor
        guard let mark = LogoTrimCache.image(for: path), mark.size.height > 0 else { return maxHeight }
        let aspect = mark.size.width / mark.size.height
        return min(maxHeight, maxWidth / max(aspect, 0.01))
    }

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                // Hero band, full bleed to the window top.
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [bandColor, bandColor.opacity(0.85)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )

                    if let heroPath = config.heroImage, !heroPath.isEmpty {
                        if IconRef.isSymbolReference(heroPath) || config.heroImageShape != nil {
                            IntroHeroImage(
                                path: heroPath,
                                shape: config.heroImageShape ?? "none",
                                size: config.heroImageSize ?? Double(bandHeight * 0.62),
                                accentColor: highlightColor,
                                basePath: basePath
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                        } else {
                            // Brand mark: sized by the trimmed mark, no drop shadow.
                            BrandLogoImage(
                                path: heroPath,
                                basePath: basePath,
                                height: heroLogoHeight(for: heroPath),
                                clearSpace: 0.1
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }

                    if !resolvedBadge.isEmpty, chipPlacement != .footerLeading {
                        BookendIdentityChip(text: resolvedBadge)
                            .padding(20)
                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                   alignment: chipPlacement == .bandTrailing ? .topTrailing : .topLeading)
                    }
                }
                .frame(height: bandHeight)
                .ignoresSafeArea(edges: .top)

                VStack(alignment: .leading, spacing: 14 * scaleFactor) {
                    if let title = locText("introScreen.title", config.title), !title.isEmpty {
                        Text(title)
                            .font(.system(size: 40 * scaleFactor, weight: .bold))
                            .tracking(-1)
                    }
                    if let subtitle = locText("introScreen.subtitle", config.subtitle), !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 15 * scaleFactor))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                            .frame(maxWidth: 560 * scaleFactor, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !resolvedStats.isEmpty {
                        BookendStatStrip(stats: resolvedStats, scaleFactor: scaleFactor)
                            .padding(.top, 12 * scaleFactor)
                    }

                    if let content = config.content, !content.isEmpty {
                        BookendBlockPayload(
                            blocks: content, accentColor: highlightColor, scaleFactor: scaleFactor,
                            iconBasePath: basePath, itemId: "introScreen", alignment: .leading,
                            inspectState: inspectState
                        )
                        .padding(.top, 4 * scaleFactor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 64 * scaleFactor)
                .padding(.top, 36 * scaleFactor)

                Spacer(minLength: 12)

                // Footnote over item-list link in the leading corner; an empty footnote hides.
                BookendFooterRow(
                    state: inspectState, highlightColor: highlightColor, scaleFactor: scaleFactor,
                    footnoteLine: locText("introScreen.footnote", config.footnote) ?? "",
                    linkText: localizedPhaseValue("introScreen.linkText", localize: localize,
                                                  config: config.linkText),
                    popoverStyle: .names,
                    spacing: nil,
                    footerHorizontalPadding: footerHorizontalPadding,
                    leadingAxis: .vertical,
                    chipText: chipPlacement == .footerLeading && !resolvedBadge.isEmpty
                        ? resolvedBadge : nil,
                    buttonText: localizedPhaseValue("introScreen.buttonText", localize: localize,
                                                    config: config.buttonText, default: "Get Started") ?? "Get Started",
                    onContinue: onContinue
                )
            }
        }
        .sourceTag()
    }
}

// MARK: - Intro Welcome Variation

/// "welcome" intro: centred greeting under the hero, a strip of the configured item icons with
/// an overflow chip, and a numbered what-to-expect list.
struct PresetIntroWelcomeView<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    let config: InspectConfig.PresetIntroScreen
    let highlightColor: Color
    let scaleFactor: CGFloat
    let basePath: String?
    @ObservedObject var inspectState: Context
    var userName: String?
    var localize: ((String) -> String?)?  // Sidecar lookup (nil = config strings, byte-identical)
    var footerHorizontalPadding: CGFloat?
    let onContinue: () -> Void

    private func locText(_ key: String, _ configValue: String?, default defaultText: String? = nil) -> String? {
        resolveLocalizedPhaseText(key: key, config: configValue, default: defaultText,
                                  localize: localize, userName: userName,
                                  itemCount: inspectState.items.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24 * scaleFactor)

            if let heroPath = config.heroImage, !heroPath.isEmpty {
                IntroHeroImage(
                    path: heroPath,
                    shape: config.heroImageShape ?? "none",
                    size: config.heroImageSize ?? 150,
                    accentColor: highlightColor,
                    basePath: basePath
                )
                .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
                .padding(.bottom, 24 * scaleFactor)
            }

            VStack(spacing: 12 * scaleFactor) {
                if let title = locText("introScreen.title", config.title), !title.isEmpty {
                    Text(title)
                        .font(.system(size: 40 * scaleFactor, weight: .bold))
                        .tracking(-1)
                        .multilineTextAlignment(.center)
                }
                if let subtitle = locText("introScreen.subtitle", config.subtitle), !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 15 * scaleFactor))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 540 * scaleFactor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 56 * scaleFactor)

            if config.showAppIcons ?? true, !inspectState.items.isEmpty {
                BookendIconStrip(items: inspectState.items, scaleFactor: scaleFactor)
                    .padding(.top, 28 * scaleFactor)
            }

            // Managed-token resolution may drop lines.
            let resolvedSteps = (config.steps ?? []).enumerated()
                .map { index, step in locText("introScreen.steps.\(index)", step) ?? "" }
                .filter { !$0.isEmpty }
            if !resolvedSteps.isEmpty {
                VStack(alignment: .leading, spacing: 14 * scaleFactor) {
                    ForEach(Array(resolvedSteps.enumerated()), id: \.offset) { index, step in
                        CardNumberedRow(index: index + 1, text: step, accent: highlightColor)
                    }
                }
                .padding(.top, 30 * scaleFactor)
                .padding(.horizontal, 72 * scaleFactor)
            }

            if let content = config.content, !content.isEmpty {
                BookendBlockPayload(
                    blocks: content, accentColor: highlightColor, scaleFactor: scaleFactor,
                    iconBasePath: basePath, itemId: "introScreen", alignment: .center,
                    inspectState: inspectState
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 72 * scaleFactor)
                .padding(.top, 18 * scaleFactor)
            }

            Spacer(minLength: 16)

            BookendFooterRow(
                state: inspectState, highlightColor: highlightColor, scaleFactor: scaleFactor,
                linkText: localizedPhaseValue("introScreen.linkText", localize: localize,
                                              config: config.linkText),
                popoverStyle: .names,
                showsRule: false,
                spacing: nil,
                footerHorizontalPadding: footerHorizontalPadding,
                buttonText: localizedPhaseValue("introScreen.buttonText", localize: localize,
                                                config: config.buttonText, default: "Get Started") ?? "Get Started",
                onContinue: onContinue
            )
        }
        .sourceTag()
    }
}

// MARK: - Intro Explainer Variation

/// "explainer" intro: three illustrated step cards. Built-in vignettes draw the configured item
/// icons; a per-step `image` overrides.
struct PresetIntroExplainerView<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    let config: InspectConfig.PresetIntroScreen
    let highlightColor: Color
    let scaleFactor: CGFloat
    let basePath: String?
    @ObservedObject var inspectState: Context
    var userName: String?
    var localize: ((String) -> String?)?  // Sidecar lookup (nil = config strings, byte-identical)
    var footerHorizontalPadding: CGFloat?
    let onContinue: () -> Void

    @State private var showAppList = false

    private func locText(_ key: String, _ configValue: String?, default defaultText: String? = nil) -> String? {
        resolveLocalizedPhaseText(key: key, config: configValue, default: defaultText,
                                  localize: localize, userName: userName,
                                  itemCount: inspectState.items.count)
    }

    /// Also quoted by the built-in step copy.
    private var continueLabel: String {
        localizedPhaseValue("introScreen.buttonText", localize: localize,
                            config: config.buttonText, default: "Get Started") ?? "Get Started"
    }

    /// Config steps, or the built-in trio; `introScreen.explainerSteps.N.*` keys override per index.
    private var explainerSteps: [InspectConfig.PresetIntroScreen.ExplainerStep] {
        config.explainerSteps ?? [
            .init(title: "Start",
                  body: "Press \(continueLabel) to start. Your apps download and install one by one.",
                  art: "start", image: nil),
            .init(title: "Install",
                  body: "Apps install one at a time. Each one gets a check mark when it's ready.",
                  art: "install", image: nil),
            .init(title: "Launch",
                  body: "When an app is ready, you can open it from the Applications folder.",
                  art: "launch", image: nil)
        ]
    }

    private var resolvedCards: [BookendExplainerCards.Card] {
        let labelFormat = localizedPhaseValue("introScreen.explainerStepLabel", localize: localize,
                                              config: config.explainerStepLabel, default: "Step {n}") ?? "Step {n}"
        return Array(explainerSteps.prefix(3)).enumerated().map { index, step in
            BookendExplainerCards.Card(
                eyebrow: labelFormat.replacingOccurrences(of: "{n}", with: "\(index + 1)"),
                title: locText("introScreen.explainerSteps.\(index).title", step.title) ?? "",
                body: locText("introScreen.explainerSteps.\(index).body", step.body) ?? "",
                art: step.art,
                image: step.image
            )
        }
    }

    /// Launch-vignette pill: a real item name, else the configured completed label.
    private var vignettePillText: String? {
        inspectState.items.first?.displayName
            ?? localizedPhaseValue("uiLabels.completedStatus", localize: localize,
                                   config: inspectState.config?.uiLabels?.completedStatus)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 9 * scaleFactor) {
                if let title = locText("introScreen.title", config.title), !title.isEmpty {
                    Text(title)
                        .font(.system(size: 27 * scaleFactor, weight: .bold))
                        .tracking(-0.5)
                }
                if let subtitle = locText("introScreen.subtitle", config.subtitle), !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14.5 * scaleFactor))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .frame(maxWidth: 560 * scaleFactor, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let linkText = localizedPhaseValue("introScreen.linkText", localize: localize,
                                                     config: config.linkText), !linkText.isEmpty {
                    Button {
                        showAppList = true
                    } label: {
                        Text(linkText)
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundStyle(highlightColor)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showAppList, arrowEdge: .bottom) {
                        BookendItemListPopover(style: .names, state: inspectState)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40 * scaleFactor)
            .padding(.top, 36 * scaleFactor)

            BookendExplainerCards(
                cards: resolvedCards,
                items: inspectState.items,
                accent: highlightColor,
                scaleFactor: scaleFactor,
                pillText: vignettePillText
            )
            .padding(.horizontal, 40 * scaleFactor)
            .padding(.top, 30 * scaleFactor)

            if let content = config.content, !content.isEmpty {
                BookendBlockPayload(
                    blocks: content, accentColor: highlightColor, scaleFactor: scaleFactor,
                    iconBasePath: basePath, itemId: "introScreen", alignment: .leading,
                    inspectState: inspectState
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40 * scaleFactor)
                .padding(.top, 18 * scaleFactor)
            }

            Spacer(minLength: 12)

            BookendFooterRow(
                state: inspectState, highlightColor: highlightColor, scaleFactor: scaleFactor,
                footnoteLine: locText("introScreen.footnote", config.footnote) ?? "",
                popoverStyle: .names,
                spacing: nil,
                footerHorizontalPadding: footerHorizontalPadding,
                buttonText: continueLabel,
                onContinue: onContinue
            )
        }
        .sourceTag()
    }
}

// MARK: - Shared helpers

/// String resolution + status partition shared by the three outro layouts.
private struct OutroContext<Context: UserInputContext & ProgressContext & ObservableObject> {
    let config: InspectConfig.PresetSummaryScreen
    let state: Context
    let userName: String?
    var localize: ((String) -> String?)?

    var completed: [InspectConfig.ItemConfig] { state.items.filter { state.completedItems.contains($0.id) } }
    var failed: [InspectConfig.ItemConfig] { state.items.filter { state.failedItems.contains($0.id) } }
    var skipped: [InspectConfig.ItemConfig] {
        state.items.filter { !state.completedItems.contains($0.id) && !state.failedItems.contains($0.id) }
    }

    @MainActor
    func resolve(_ text: String) -> String {
        var t = text
        t = t.replacingOccurrences(of: "{itemCount}", with: "\(state.items.count)")
        t = t.replacingOccurrences(of: "{completedCount}", with: "\(completed.count)")
        t = t.replacingOccurrences(of: "{failedCount}", with: "\(failed.count)")
        t = t.replacingOccurrences(of: "{skippedCount}", with: "\(skipped.count)")
        if let userName { t = substituteGreeting(t, userName: userName) }
        return resolveManagedLine(t)
    }

    /// Localization first, then the token pipeline above.
    @MainActor
    func resolve(key: String, config configValue: String?, default defaultText: String? = nil) -> String? {
        guard let text = localizedPhaseValue(key, localize: localize, config: configValue, default: defaultText)
        else { return nil }
        return resolve(text)
    }

    /// Localization only, no token resolution.
    func label(_ key: String, _ configValue: String?, default defaultText: String? = nil) -> String? {
        localizedPhaseValue(key, localize: localize, config: configValue, default: defaultText)
    }
}

// MARK: - Dock outro

/// "dock" outro: greeting plus `DockPickerView`. The selection is emitted on the interaction
/// wire (`dock:<key>:additive:<paths>`); the orchestrator applies it, the dialog only records.
struct PresetOutroDockView<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    let config: InspectConfig.PresetSummaryScreen
    let highlightColor: Color
    let scaleFactor: CGFloat
    @ObservedObject var inspectState: Context
    var userName: String?
    var localize: ((String) -> String?)?  // Sidecar lookup (nil = config strings, byte-identical)
    var footerHorizontalPadding: CGFloat?
    let onClose: () -> Void

    @Environment(\.palette) private var palette

    private var ctx: OutroContext<Context> {
        OutroContext(config: config, state: inspectState, userName: userName, localize: localize)
    }
    private var dockSurface: Color { palette.cardSurface.opacity(0.9) }

    /// Completed items with real app paths. When any item sets `dockCandidate`, only flagged
    /// items are offered.
    private var dockCandidates: [InspectConfig.DockItem] {
        let apps = ctx.completed.isEmpty ? inspectState.items : ctx.completed
        let hasFlags = inspectState.items.contains { $0.dockCandidate == true }
        let pool = hasFlags ? apps.filter { $0.dockCandidate == true } : apps
        return pool.compactMap { item in
            guard let path = item.paths.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? item.paths.first
            else { return nil }
            return InspectConfig.DockItem(label: item.displayName, path: path, sfSymbol: nil)
        }
    }

    var body: some View {
        ZStack {
            PhaseBackdrop(config: inspectState.config)

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                BookendGreetingHeader(
                    title: ctx.resolve(key: "summaryScreen.title", config: config.title,
                                       default: "You're all set, {userName}") ?? "",
                    subtitle: ctx.resolve(key: "summaryScreen.subtitle", config: config.subtitle),
                    scaleFactor: scaleFactor
                )
                .padding(.horizontal, 56 * scaleFactor)

                Spacer(minLength: 16)

                // Build mode by default; `dockFlavors` switches to flavor mode. Every argument
                // is a default for an authored summary-screen key.
                VStack(spacing: 12 * scaleFactor) {
                    let flavors = config.dockFlavors ?? []
                    DockPickerView(
                        mode: config.dockMode ?? (flavors.isEmpty ? "build" : "flavors"),
                        flavors: flavors,
                        items: config.dockItems ?? dockCandidates,
                        selectionKey: config.dockSelectionKey ?? "outroDock",
                        confirmButtonText: config.dockConfirmButton,
                        showUnavailable: config.dockShowUnavailable ?? false,
                        decline: config.dockDecline,
                        applyMode: config.dockApplyMode ?? "additive",
                        scaleFactor: scaleFactor,
                        centered: true,
                        layout: config.dockLayout ?? "narrow",
                        inspectState: inspectState,
                        itemId: "outro-dock"
                    )

                    // No default caption: what happens to the picks is up to the admin's script.
                    if let caption = ctx.resolve(key: "summaryScreen.caption", config: config.caption,
                                                 default: nil), !caption.isEmpty {
                        Text(caption)
                            .font(.system(size: 12.5 * scaleFactor))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 20 * scaleFactor)

                if let content = config.content, !content.isEmpty {
                    BookendBlockPayload(
                        blocks: content, accentColor: highlightColor, scaleFactor: scaleFactor,
                        iconBasePath: nil, itemId: "summaryScreen", alignment: .center,
                        inspectState: inspectState
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 44 * scaleFactor)
                    .padding(.bottom, 18 * scaleFactor)
                }

                BookendFooterRow(
                    state: inspectState, highlightColor: highlightColor, scaleFactor: scaleFactor,
                    linkText: localizedPhaseValue("summaryScreen.linkText", localize: localize,
                                                  config: config.linkText),
                    popoverStyle: .status,
                    skippedLabel: ctx.label("uiLabels.skippedStatus",
                                            inspectState.config?.uiLabels?.skippedStatus,
                                            default: "Skipped") ?? "Skipped",
                    footerHorizontalPadding: footerHorizontalPadding,
                    buttonText: localizedPhaseValue("summaryScreen.buttonText", localize: localize,
                                                    config: config.buttonText, default: "Close") ?? "Close",
                    onContinue: onClose
                )
                .background(dockSurface.opacity(0.6))
            }
        }
        .sourceTag()
    }
}

// MARK: - Receipt outro

/// "receipt" outro: header summary plus a per-item ledger. Items neither completed nor failed
/// show as skipped.
struct PresetOutroReceiptView<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    let config: InspectConfig.PresetSummaryScreen
    let highlightColor: Color
    let scaleFactor: CGFloat
    @ObservedObject var inspectState: Context
    var userName: String?
    var localize: ((String) -> String?)?  // Sidecar lookup (nil = config strings, byte-identical)
    var footerHorizontalPadding: CGFloat?
    let onClose: () -> Void

    @Environment(\.palette) private var palette

    private var ctx: OutroContext<Context> {
        OutroContext(config: config, state: inspectState, userName: userName, localize: localize)
    }

    private var skippedLabel: String {
        ctx.label("uiLabels.skippedStatus",
                  inspectState.config?.uiLabels?.skippedStatus,
                  default: "Skipped") ?? "Skipped"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 18 * scaleFactor) {
                ZStack {
                    Circle().fill(palette.successBackground)
                    Image(systemName: "checkmark")
                        .font(.system(size: 18 * scaleFactor, weight: .bold))
                        .foregroundStyle(palette.success)
                }
                .frame(width: 44 * scaleFactor, height: 44 * scaleFactor)

                VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                    Text(ctx.resolve(key: "summaryScreen.title", config: config.title,
                                     default: "Setup complete") ?? "")
                        .font(.system(size: 32 * scaleFactor, weight: .bold))
                        .tracking(-0.75)
                    if let subtitle = ctx.resolve(key: "summaryScreen.subtitle", config: config.subtitle),
                       !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 15 * scaleFactor))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 500 * scaleFactor, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 44 * scaleFactor)
            .padding(.top, 36 * scaleFactor)

            BookendStatusLedger(state: inspectState, skippedLabel: skippedLabel,
                                scaleFactor: scaleFactor)
                .padding(.horizontal, 44 * scaleFactor)
                .padding(.top, 22 * scaleFactor)

            if let content = config.content, !content.isEmpty {
                BookendBlockPayload(
                    blocks: content, accentColor: highlightColor, scaleFactor: scaleFactor,
                    iconBasePath: nil, itemId: "summaryScreen", alignment: .leading,
                    inspectState: inspectState
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 44 * scaleFactor)
                .padding(.top, 18 * scaleFactor)
            }

            Spacer(minLength: 10)

            if let line = ctx.resolve(key: "summaryScreen.infoNote", config: config.infoNote), !line.isEmpty {
                BookendInfoNote(text: line, scaleFactor: scaleFactor)
                    .padding(.horizontal, 44 * scaleFactor)
                    .padding(.bottom, 18 * scaleFactor)
            }

            BookendFooterRow(
                state: inspectState, highlightColor: highlightColor, scaleFactor: scaleFactor,
                linkText: localizedPhaseValue("summaryScreen.linkText", localize: localize,
                                              config: config.linkText),
                popoverStyle: .status,
                skippedLabel: skippedLabel,
                footerHorizontalPadding: footerHorizontalPadding,
                buttonText: localizedPhaseValue("summaryScreen.buttonText", localize: localize,
                                                config: config.buttonText, default: "Close") ?? "Close",
                onContinue: onClose
            )
        }
        .sourceTag()
    }
}

// MARK: - Next steps outro

/// "nextsteps" outro: gradient hero band with the greeting, then suggested action rows whose
/// Open button hands the target to `NSWorkspace`.
struct PresetOutroNextStepsView<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    let config: InspectConfig.PresetSummaryScreen
    let highlightColor: Color
    let scaleFactor: CGFloat
    @ObservedObject var inspectState: Context
    var userName: String?
    var localize: ((String) -> String?)?  // Sidecar lookup (nil = config strings, byte-identical)
    var footerHorizontalPadding: CGFloat?
    let onClose: () -> Void

    private var ctx: OutroContext<Context> {
        OutroContext(config: config, state: inspectState, userName: userName, localize: localize)
    }

    /// The config's banner palette, with a built-in fallback.
    private var heroColors: [Color] {
        let palette = (inspectState.config?.gradientPalette ?? ["#2BD07A", "#2FB6D9", "#5B6EF5"]).compactMap { Color(hex: $0) }
        return palette.count >= 2 ? palette : [Color(hex: "#2BD07A"), Color(hex: "#2FB6D9"), Color(hex: "#5B6EF5")]
    }

    /// Row icon: explicit config icon, else the matching item's real icon.
    private func rowIcon(_ step: InspectConfig.PresetSummaryScreen.NextStep) -> String {
        if let icon = step.icon, !icon.isEmpty { return icon }
        if let match = inspectState.items.first(where: { step.title.localizedCaseInsensitiveContains($0.displayName) }) {
            return match.icon ?? "SF=app.fill"
        }
        return "SF=app.fill"
    }

    var body: some View {
        VStack(spacing: 0) {
            BookendHeroBand(
                colors: heroColors,
                title: ctx.resolve(key: "summaryScreen.title", config: config.title,
                                   default: "You're all set, {userName}") ?? "",
                subtitle: ctx.resolve(key: "summaryScreen.subtitle", config: config.subtitle),
                scaleFactor: scaleFactor
            )

            VStack(alignment: .leading, spacing: 12 * scaleFactor) {
                BookendSectionLabel(
                    text: ctx.resolve(key: "summaryScreen.sectionTitle", config: config.sectionTitle,
                                      default: "Suggested next") ?? "",
                    scaleFactor: scaleFactor
                )

                ForEach(Array((config.nextSteps ?? []).prefix(3).enumerated()), id: \.offset) { index, step in
                    BookendActionRow(
                        icon: rowIcon(step),
                        title: ctx.resolve(key: "summaryScreen.nextSteps.\(index).title",
                                           config: step.title) ?? "",
                        subtitle: ctx.resolve(key: "summaryScreen.nextSteps.\(index).subtitle",
                                              config: step.subtitle),
                        buttonText: (step.action?.isEmpty == false)
                            ? (ctx.label("summaryScreen.nextSteps.\(index).buttonText",
                                         step.buttonText, default: "Open") ?? "Open")
                            : nil,
                        action: (step.action?.isEmpty == false) ? {
                            guard let action = step.action else { return }
                            if let url = URL(string: action), url.scheme != nil {
                                NSWorkspace.shared.open(url)
                            } else {
                                NSWorkspace.shared.open(URL(fileURLWithPath: action))
                            }
                            writeLog("Outro nextsteps: opened \(action)", logLevel: .info)
                        } : nil,
                        scaleFactor: scaleFactor
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 44 * scaleFactor)
            .padding(.top, 26 * scaleFactor)

            if let content = config.content, !content.isEmpty {
                BookendBlockPayload(
                    blocks: content, accentColor: highlightColor, scaleFactor: scaleFactor,
                    iconBasePath: nil, itemId: "summaryScreen", alignment: .leading,
                    inspectState: inspectState
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 44 * scaleFactor)
                .padding(.top, 18 * scaleFactor)
            }

            Spacer(minLength: 12)

            BookendFooterRow(
                state: inspectState, highlightColor: highlightColor, scaleFactor: scaleFactor,
                footnoteLine: ctx.resolve(key: "summaryScreen.footnote", config: config.footnote) ?? "",
                linkText: localizedPhaseValue("summaryScreen.linkText", localize: localize,
                                              config: config.linkText),
                popoverStyle: .status,
                skippedLabel: ctx.label("uiLabels.skippedStatus",
                                        inspectState.config?.uiLabels?.skippedStatus,
                                        default: "Skipped") ?? "Skipped",
                footerHorizontalPadding: footerHorizontalPadding,
                buttonText: localizedPhaseValue("summaryScreen.buttonText", localize: localize,
                                                config: config.buttonText, default: "Close") ?? "Close",
                onContinue: onClose
            )
        }
        .sourceTag()
    }
}

// MARK: - Block payload inside a named ceremony

/// Authored `content` blocks rendered after a named ceremony's composed body, inheriting its
/// alignment and insets. Wide block types take the wider measure.
struct BookendBlockPayload<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    let blocks: [InspectConfig.GuidanceContent]
    let accentColor: Color
    let scaleFactor: CGFloat
    var iconBasePath: String?
    /// Scopes localization and form state; ceremonies pass a stable per-surface id.
    let itemId: String
    var alignment: HorizontalAlignment = .leading
    @ObservedObject var inspectState: Context

    private var shown: [InspectConfig.GuidanceContent] {
        blocks.filter { $0.visible != false }
    }

    private var measure: CGFloat {
        let metrics = InspectMetrics(scale: scaleFactor)
        return shown.contains { InspectConfig.GuidanceContent.wideLayoutTypes.contains($0.type) }
            ? metrics.wideContentMaxW
            : metrics.contentMaxW
    }

    var body: some View {
        if !shown.isEmpty {
            // The scroll absorbs the height left after the composed body and footer, so an
            // unbounded payload can never push the footer off the window.
            ScrollView(.vertical) {
                GuidanceContentView(
                    contentBlocks: shown,
                    scaleFactor: scaleFactor,
                    iconBasePath: iconBasePath,
                    inspectState: inspectState,
                    itemId: itemId,
                    accentColor: accentColor,
                    contentAlignment: alignment
                )
                .frame(maxWidth: measure,
                       alignment: alignment == .center ? .center : .leading)
                .frame(maxWidth: .infinity,
                       alignment: alignment == .center ? .center : .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
