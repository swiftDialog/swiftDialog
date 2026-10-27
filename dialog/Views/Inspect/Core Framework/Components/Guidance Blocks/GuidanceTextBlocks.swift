//
//  GuidanceTextBlocks.swift
//  dialog
//
//  Text-family guidance blocks: text, highlight, arrow, callouts, prose, explainer, bullets,
//  label-value. Pure display; the dispatcher resolves template variables before these render.
//

import SwiftUI

/// Inline-markdown helper shared by the guidance text blocks (falls back to plain text).
func guidanceAttributedMarkdown(_ markdown: String) -> AttributedString {
    do {
        return try AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )
    } catch {
        return AttributedString(markdown)
    }
}

// MARK: - Text (type: "text")

struct GuidanceTextBlock: View {
    let content: String
    let isBold: Bool
    let textColor: Color
    let contentAlignment: HorizontalAlignment
    let scaleFactor: CGFloat

    @Environment(\.palette) private var palette

    var body: some View {
        let blocks = GuidanceMarkdown.split(content)
        // Block-level Markdown engages only when the content carries it.
        if blocks.count == 1, case .paragraph(let only) = blocks[0] {
            paragraph(only)
        } else {
            VStack(alignment: contentAlignment, spacing: 10 * scaleFactor) {
                ForEach(blocks.indices, id: \.self) { i in
                    blockView(blocks[i])
                }
            }
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: contentAlignment, vertical: .center))
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(guidanceAttributedMarkdown(text))
            .font(.system(size: 13 * scaleFactor, weight: isBold ? .semibold : .regular))
            .foregroundStyle(textColor)
            .multilineTextAlignment(contentAlignment == .center ? .center : .leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: contentAlignment, vertical: .center))
    }

    /// Each block renders through the view that owns its look; a Markdown list is a
    /// `GuidanceBulletsBlock`.
    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            paragraph(text)

        case .heading(let level, let text):
            // Two sizes only; this is a paragraph of guidance, not a document.
            Text(guidanceAttributedMarkdown(text))
                .font(.system(size: (level <= 2 ? 15 : 13) * scaleFactor, weight: .semibold))
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: contentAlignment, vertical: .center))

        case .list(let items):
            GuidanceBulletsBlock(items: items, numbered: false, icon: nil,
                                 accentColor: nil, scaleFactor: scaleFactor)

        case .orderedList(let items):
            GuidanceBulletsBlock(items: items, numbered: true, icon: nil,
                                 accentColor: nil, scaleFactor: scaleFactor)

        case .quote(let text):
            // A rule and an inset, no tinted card: an aside, not an alert.
            HStack(alignment: .top, spacing: 10 * scaleFactor) {
                Rectangle()
                    .fill(palette.textFaint)
                    .frame(width: 2 * scaleFactor)
                Text(guidanceAttributedMarkdown(text))
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .code(let text):
            Text(text)
                .font(.system(size: 12 * scaleFactor, design: .monospaced))
                .foregroundStyle(palette.textMuted)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10 * scaleFactor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6 * scaleFactor).fill(.quaternary))
        }
    }
}

// MARK: - Highlight (type: "highlight")

/// An emphasised lede: semibold prose, no chip box.
struct GuidanceHighlightBlock: View {
    let content: String
    let scaleFactor: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        Text(content)
            .font(.system(size: 14 * scaleFactor, weight: .semibold))
            .foregroundStyle(palette.text)
            // Left-aligned, on the one edge every other block shares.
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Arrow (type: "arrow")

struct GuidanceArrowBlock: View {
    let content: String
    let textColor: Color
    let accentColor: Color?
    let scaleFactor: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 6 * scaleFactor) {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(accentColor ?? palette.text)
                .font(.system(size: 14 * scaleFactor))
            Text(content)
                .font(.system(size: 13 * scaleFactor, weight: .medium))
                .foregroundStyle(textColor)
        }
    }
}

// MARK: - Callout box (types: "warning" / "info" / "success")

/// The warning / info / success callout, in card, chip or flat form.
struct GuidanceCalloutBlock: View {
    enum Style {
        case warning, info, success
    }

    /// Decided only by `resolveForm`; `isCard(_:)` and `body` both route through it.
    enum Form: Equatable {
        case card, chip, flat
    }

    let content: String
    let style: Style
    let scaleFactor: CGFloat
    /// The block's raw `"style"` value; only `resolveForm` branches on it.
    var rawStyle: String?
    /// The card's heading; a non-blank title promotes to the card form.
    var title: String?
    /// Card only: overrides the style's default glyph.
    var iconOverride: String?
    @Environment(\.palette) private var palette

    /// An explicit `"style": "chip"` always wins; else a non-blank `title` makes a card; else
    /// `info` with no `style` is a chip and everything else is flat.
    nonisolated static func resolveForm(style: Style, rawStyle: String?, title: String?) -> Form {
        if rawStyle == "chip" { return .chip }
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .card }
        if style == .info && rawStyle == nil { return .chip }
        return .flat
    }

    /// Whether this block renders as a card, by the same rule `body` uses.
    static func isCard(_ block: InspectConfig.GuidanceContent) -> Bool {
        let style: Style
        switch block.type {
        case "info": style = .info
        case "success": style = .success
        default: style = .warning
        }
        return resolveForm(style: style, rawStyle: block.style, title: block.title) == .card
    }

    /// The flat and chip arms' glyph. `warning` keeps its tint but no triangle, as
    /// `BlockSemantics.mark(for:)` rules; the card arm uses `cardIcon`.
    private var icon: String? {
        switch style {
        case .warning: return nil
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }

    /// The card tile always carries a glyph; `iconOverride` wins when authored.
    static func resolveCardIcon(style: Style, iconOverride: String?) -> String {
        if let iconOverride { return iconOverride }
        switch style {
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }

    private var cardIcon: String { Self.resolveCardIcon(style: style, iconOverride: iconOverride) }

    private var iconColor: Color {
        switch style {
        case .warning: return palette.warning
        case .info: return palette.info
        case .success: return palette.success
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .warning: return palette.warningBackground
        case .info: return palette.infoBackground
        case .success: return palette.successBackground
        }
    }

    var body: some View {
        switch Self.resolveForm(style: style, rawStyle: rawStyle, title: title) {
        case .card:
            HStack(alignment: .top, spacing: 12 * scaleFactor) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 32 * scaleFactor, height: 32 * scaleFactor)
                    Image(systemName: cardIcon)
                        .font(.system(size: 14 * scaleFactor))
                        .foregroundStyle(iconColor)
                }
                VStack(alignment: .leading, spacing: 3 * scaleFactor) {
                    if let title {
                        Text(title)
                            .font(.system(size: 13 * scaleFactor, weight: .semibold))
                            .foregroundStyle(palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(guidanceAttributedMarkdown(content))
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
        case .chip:
            HStack(spacing: 6 * scaleFactor) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundStyle(palette.textMuted)
                }
                Text(guidanceAttributedMarkdown(content))
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10 * scaleFactor)
            .padding(.vertical, 5 * scaleFactor)
            .background(Capsule().fill(palette.text.opacity(0.06)))
            // Hugs its content and stays left.
            .frame(maxWidth: .infinity, alignment: .leading)
        case .flat:
            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(iconColor)
                }
                Text(guidanceAttributedMarkdown(content))
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
        }
    }
}

// MARK: - Prose (type: "prose")

/// A text block written to while the window is open, by anything that appends to the trigger
/// file. Empty content shows the placeholder; the body is `GuidanceTextBlock` plus a caret while
/// the stream is open. Scrolling to follow is the scroll owner's job.
struct GuidanceProseBlock: View {
    let content: String
    let placeholder: String?
    /// nil = never streamed (static), true = open, false = ended.
    let streaming: Bool?
    let scaleFactor: CGFloat

    @Environment(\.palette) private var palette

    /// From the block's `state`: "streaming" is open, "ended" is closed, anything else is static.
    static func streaming(from state: String?) -> Bool? {
        switch state?.lowercased() {
        case "streaming": return true
        case "ended": return false
        default: return nil
        }
    }

    var body: some View {
        if content.isEmpty, streaming != false {
            Text(placeholder ?? "…")
                .font(.system(size: 13 * scaleFactor))
                .foregroundStyle(palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .bottom, spacing: 2) {
                GuidanceTextBlock(content: content, isBold: false, textColor: palette.text.opacity(0.85),
                                  contentAlignment: .leading, scaleFactor: scaleFactor)
                if streaming == true {
                    // Decoration, hidden from accessibility.
                    Text("▍")
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(palette.textMuted)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

// MARK: - Explainer (type: "explainer")

/// Inline-Markdown prose in an optional tinted box: `style` "plain", "info", "warning" or
/// "success".
struct GuidanceExplainerBlock: View {
    let content: String
    let style: String?
    let icon: String?            // the "plain" + accent variant's icon
    let accentColor: Color?
    let scaleFactor: CGFloat
    /// The authored `label`, drawn as a heading in the callout's treatment; nil draws none.
    var label: String?
    @Environment(\.palette) private var palette

    /// nil unless a non-blank heading was authored, so `""` opts out.
    private var resolvedLabel: String? {
        guard let label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return label
    }

    @ViewBuilder
    private var labelText: some View {
        if let resolvedLabel {
            Text(resolvedLabel)
                .font(.system(size: 13 * scaleFactor, weight: .semibold))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var body: some View {
        let explainerStyle = style ?? "plain"

        let (resolvedIcon, iconColor, backgroundColor): (String?, Color, Color) = {
            switch explainerStyle {
            case "info":
                return ("info.circle.fill", palette.info, palette.infoBackground)
            case "warning":
                return ("exclamationmark.triangle.fill", palette.warning, palette.warningBackground)
            case "success":
                return ("checkmark.circle.fill", palette.success, palette.successBackground)
            default:
                if let accent = accentColor {
                    return (icon, accent, accent.opacity(0.06))
                }
                return (nil, .primary, .clear)
            }
        }()

        Group {
            if let iconName = resolvedIcon {
                HStack(alignment: .top, spacing: 8 * scaleFactor) {
                    Image(systemName: iconName)
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(iconColor)

                    // Heading and body share the text column beside the glyph.
                    VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                        labelText
                        Text(guidanceAttributedMarkdown(content))
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundStyle(palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12 * scaleFactor)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundColor)
                )
            } else {
                VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                    labelText
                    Text(guidanceAttributedMarkdown(content))
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Bullets (type: "bullets")

struct GuidanceBulletsBlock: View {
    enum Form: Equatable { case list, rows }

    let items: [String]?
    let numbered: Bool
    let icon: String?
    let accentColor: Color?
    let scaleFactor: CGFloat
    /// The block's raw `"style"` value; only `"rows"` promotes to bordered icon rows.
    var style: String?
    @Environment(\.palette) private var palette

    /// The list/rows decision, stated once; `body` switches on exactly this.
    static func resolveForm(style: String?) -> Form {
        style == "rows" ? .rows : .list
    }

    var body: some View {
        if let items = items {
            switch Self.resolveForm(style: style) {
            case .list:
                listBody(items)
            case .rows:
                rowsBody(items)
            }
        }
    }

    /// The marker-column list, the default form. One row rhythm whichever marker a list uses.
    private func listBody(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14 * scaleFactor) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if !item.isEmpty {
                    HStack(alignment: .top, spacing: 12 * scaleFactor) {
                        // One frame outside the branch keeps the text's left edge the same for
                        // every marker.
                        markerView(for: BulletMarker.resolve(numbered: numbered,
                                                             icon: icon,
                                                             index: index))
                            .frame(width: BulletMarker.columnWidth(scaleFactor: scaleFactor),
                                   alignment: .trailing)
                        Text(guidanceAttributedMarkdown(item))
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundStyle(palette.text)
                            // Tighter than the gap between items, so wrapped lines read as one.
                            .lineSpacing(3 * scaleFactor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    /// Bordered rows with the block's `icon` in a tile on every row; no icon falls back to a dot,
    /// never an empty tile.
    private func rowsBody(_ items: [String]) -> some View {
        let tint = accentColor ?? palette.accent
        let glyph = (icon?.isEmpty == false) ? icon! : "circle.fill"
        return VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                if !item.isEmpty {
                    HStack(alignment: .top, spacing: 12 * scaleFactor) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(tint.opacity(0.14))
                            Image(systemName: glyph)
                                .font(.system(size: 13 * scaleFactor))
                                .foregroundStyle(tint)
                        }
                        .frame(width: 28 * scaleFactor, height: 28 * scaleFactor)
                        Text(guidanceAttributedMarkdown(item))
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundStyle(palette.text)
                            .lineSpacing(3 * scaleFactor)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10 * scaleFactor)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(palette.textMuted.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func markerView(for marker: BulletMarker) -> some View {
        switch marker {
        case .numbered(let n):
            // The numeral is the marker; a filled circle per item reads as a row of badges.
            Text("\(n).")
                .font(.system(size: 13 * scaleFactor, design: .monospaced))
                .foregroundStyle(palette.textMuted)
        case .icon(let sfIcon):
            Image(systemName: sfIcon)
                .font(.system(size: 13 * scaleFactor))
                .foregroundStyle(accentColor ?? palette.textMuted)
        case .bullet:
            Text("•")
                .font(.system(size: 13 * scaleFactor))
                .foregroundStyle(palette.textMuted)
        }
    }
}

// MARK: - Label/Value (type: "label-value")

/// A label-value pair, from separate `label`/`value` fields or "Label: Value" content. `style`:
/// "default", "success" (green label) or "table" (green label, no bullet).
struct GuidanceLabelValueBlock: View {
    let block: InspectConfig.GuidanceContent
    let resolvedContent: String
    let scaleFactor: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        let style = block.style ?? "default"

        let (label, value): (String, String) = {
            if let blockLabel = block.label, let blockValue = block.value {
                return (blockLabel, blockValue)
            }

            // Split on the first colon; no colon makes the whole content the value.
            if let colonIndex = resolvedContent.firstIndex(of: ":") {
                let labelPart = String(resolvedContent[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let valuePart = String(resolvedContent[resolvedContent.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                return (labelPart, valuePart)
            }

            return ("", resolvedContent)
        }()

        let (labelColor, valueFontSize, showBullet): (Color, CGFloat, Bool) = {
            switch style {
            case "success":
                return (palette.success, 15, true)
            case "table":
                return (palette.success, 15, false)
            default:
                return (.secondary, 13, true)
            }
        }()

        HStack(alignment: .top, spacing: 8 * scaleFactor) {
            if showBullet {
                Text("•")
                    .font(.system(size: 13 * scaleFactor, weight: .bold))
                    .foregroundStyle(palette.text)
            }

            if !label.isEmpty {
                Text(label + ":")
                    .font(.system(size: 13 * scaleFactor, weight: .regular))
                    .foregroundStyle(labelColor)
            }

            Text(value)
                .font(.system(size: valueFontSize * scaleFactor, weight: .bold))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, showBullet ? 0 : 6 * scaleFactor)
    }
}
