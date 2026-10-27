//
//  DetailSheetShell.swift
//  dialog
//
//  The chrome every inspect detail sheet shares: one dismissal (`‹ backLabel`, also Esc), a subject bar
//  instead of a banner, and a height that hugs content between `minHeight` and `maxHeight`.
//  `scrolls` is for generated content (system facts, live lists), which has no authored length.

import SwiftUI

/// Shared measures, so adopters compute widths against the same padding the shell applies.
enum DetailSheetMetrics {
    /// The sheet's outer padding — subject bar, content, and hint all sit on this edge.
    static let pad: CGFloat = 32
    /// Space between a text column and a media column.
    static let gutter: CGFloat = 24
    /// The smallest sheet height.
    static let minHeight: CGFloat = 320
    /// Same 44 as the card hero band (`InspectMetrics.cardHeroBox`).
    static let headerHeight: CGFloat = 44
    /// The action row for sheets with a `footer:`: the compact band, `FooterBandM.compact`.
    static let footerHeight: CGFloat = FooterBandM.compact
    /// Clearance between a sheet and each window edge, so it reads as a layer over the step.
    static let windowMargin: CGFloat = 40
}

struct DetailSheetShell<Content: View, Footer: View>: View {
    /// The leading header control's label ("Back", "All projects", or `closeButtonText`): where it returns to.
    /// nil leads with `title` instead, because the dismissal lives in the `footer`.
    let backLabel: String?
    /// Plain header title, for footer-dismissed sheets. Ignored when `backLabel` is set.
    var title: String?
    /// The subject bar's trailing line, e.g. "2 of 6 · Automation"; nil omits it.
    var subject: String?
    var accentColor: Color
    /// Explicit width; nil hugs the content.
    var width: CGFloat?
    var minHeight: CGFloat = DetailSheetMetrics.minHeight
    /// The tallest this sheet may be; overflow clips at the bottom unless `scrolls` is set.
    var maxHeight: CGFloat
    /// Config-supplied background, e.g. `detailOverlay.backgroundColor`.
    var background: Color?
    /// Generated content keeps a scroll view and a fixed height.
    var scrolls: Bool = false
    /// The keyboard hint; nil hides it. Whether the localized default applies is `usesDefaultEscapeHint`,
    /// because a default argument cannot read the localizer.
    var escapeHint: String?
    /// nil: `‹ backLabel` dismisses. Non-nil: it navigates within the sheet and the footer owns dismissal.
    var onBack: (() -> Void)?
    let onClose: () -> Void
    let content: Content
    /// A bottom row above `footerHeight`; `EmptyView` when `hasFooter` is false.
    let footer: Footer
    let hasFooter: Bool
    /// Callers that never mention an escape hint get the localized default; false for footer sheets.
    let usesDefaultEscapeHint: Bool

    @Environment(\.inspectLocalization) private var l10n
    @Environment(\.inspectHostSize) private var hostSize
    @Environment(\.palette) private var palette
    @FocusState private var isFocused: Bool

    /// Footer sheets: a plain title (or an intra-sheet `‹`) and a caller-owned bottom row that dismisses.
    init(
        backLabel: String? = nil,
        title: String? = nil,
        subject: String? = nil,
        accentColor: Color,
        width: CGFloat? = nil,
        minHeight: CGFloat = DetailSheetMetrics.minHeight,
        maxHeight: CGFloat,
        background: Color? = nil,
        scrolls: Bool = false,
        escapeHint: String? = nil,
        onBack: (() -> Void)? = nil,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.backLabel = backLabel
        self.title = title
        self.subject = subject
        self.accentColor = accentColor
        self.width = width
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.background = background
        self.scrolls = scrolls
        self.escapeHint = escapeHint
        self.onBack = onBack
        self.onClose = onClose
        self.content = content()
        self.footer = footer()
        self.usesDefaultEscapeHint = false
        self.hasFooter = true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            subjectBar

            if scrolls {
                ScrollView {
                    paddedContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                paddedContent
                Spacer(minLength: 16)
            }

            if hasFooter {
                Divider()
                HStack(spacing: 12) {
                    footer
                }
                .padding(.horizontal, DetailSheetMetrics.pad)
                .frame(height: DetailSheetMetrics.footerHeight)
            } else if let hint = resolvedEscapeHint {
                escapeHintView(hint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FixedWidth(clampedWidth))
        .modifier(HeightBudget(minHeight: min(minHeight, clampedMaxHeight),
                               maxHeight: clampedMaxHeight,
                               fixed: scrolls))
        .clipped()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(background ?? Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear {
            // Waits out the presentation animation before taking focus.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .onDisappear { isFocused = false }
        .onKeyPress(.escape) {
            isFocused = false
            onClose()
            return .handled
        }
    }

    // MARK: - Sizing against the host window

    /// The most this sheet may occupy in its host window; a `.zero` host (not yet measured) leaves it unchanged.
    private var hostLimit: CGSize? {
        guard hostSize.width > 0, hostSize.height > 0 else { return nil }
        return CGSize(width: max(0, hostSize.width - 2 * DetailSheetMetrics.windowMargin),
                      height: max(0, hostSize.height - 2 * DetailSheetMetrics.windowMargin))
    }

    /// An authored width is a request; `DetailOverlaySize.full` asks for more than an 800pt window allows.
    private var clampedWidth: CGFloat? {
        guard let width, let hostLimit else { return width }
        return min(width, hostLimit.width)
    }

    /// The height cap, clamped to the window; `scrolls` surfaces hand the overflow to their scroll view.
    private var clampedMaxHeight: CGFloat {
        guard let hostLimit else { return maxHeight }
        return min(maxHeight, hostLimit.height)
    }

    /// An explicit hint wins; otherwise header-dismissed callers get the localized default.
    private var resolvedEscapeHint: String? {
        if let escapeHint { return escapeHint }
        return usesDefaultEscapeHint ? l10n("ui.detailSheetEscHint", "Esc to close") : nil
    }

    private var paddedContent: some View {
        content
            .padding(.horizontal, DetailSheetMetrics.pad)
            .padding(.top, 4)
    }

    // MARK: - Subject bar (the only dismissal)

    private var subjectBar: some View {
        HStack(spacing: 12) {
            if let backLabel {
                Door.wordWithChevron(ink: accentColor, label: backLabel,
                                     action: onBack ?? onClose)
                .help(onBack == nil
                      ? l10n("ui.detailSheetBackEsc", "Back (Esc)")
                      : l10n("ui.detailSheetBack", "Back"))
            } else if let title {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if let subject {
                Text(subject)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, DetailSheetMetrics.pad)
        .frame(height: DetailSheetMetrics.headerHeight)
    }

    private func escapeHintView(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(palette.textFaint)
        }
        .padding(.horizontal, DetailSheetMetrics.pad)
        .padding(.bottom, 18)
    }
}

// MARK: - Header-dismissed sheets (no footer)

/// The header-dismissed signature, where `‹` is the single dismissal; a `Footer == EmptyView` convenience.
extension DetailSheetShell where Footer == EmptyView {
    init(
        backLabel: String,
        subject: String? = nil,
        accentColor: Color,
        width: CGFloat? = nil,
        minHeight: CGFloat = DetailSheetMetrics.minHeight,
        maxHeight: CGFloat,
        background: Color? = nil,
        scrolls: Bool = false,
        escapeHint: String?? = nil,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.backLabel = backLabel
        self.title = nil
        self.subject = subject
        self.accentColor = accentColor
        self.width = width
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.background = background
        self.scrolls = scrolls
        // Double optional: nil means "not mentioned" (localized default), .some(nil) means "none".
        self.escapeHint = escapeHint ?? nil
        self.usesDefaultEscapeHint = (escapeHint == nil)
        self.onBack = nil
        self.onClose = onClose
        self.content = content()
        self.footer = EmptyView()
        self.hasFooter = false
    }
}

/// The escape affordance, so a caller-owned footer can render the same hint the shell would.
struct DetailSheetEscapeHint: View {
    /// nil takes the localized default.
    var text: String?

    @Environment(\.inspectLocalization) private var l10n
    @Environment(\.palette) private var palette

    var body: some View {
        Text(text ?? l10n("ui.detailSheetEscHint", "Esc to close"))
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(palette.textFaint)
    }
}

// MARK: - Sizing modifiers

/// `.frame(width:)` only when a width was supplied; `frame(width: nil)` means flexible, not absent.
private struct FixedWidth: ViewModifier {
    let width: CGFloat?
    init(_ width: CGFloat?) { self.width = width }

    func body(content: Content) -> some View {
        if let width {
            content.frame(width: width)
        } else {
            content
        }
    }
}

/// Hug-with-a-cap, or a fixed height for the scrolling variant. Top-aligned so overflow leaves at the
/// bottom and the subject bar and title stay visible.
private struct HeightBudget: ViewModifier {
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let fixed: Bool

    func body(content: Content) -> some View {
        if fixed {
            content.frame(height: max(minHeight, maxHeight), alignment: .top)
        } else {
            content
                .frame(minHeight: minHeight, maxHeight: max(minHeight, maxHeight), alignment: .top)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
