//
//  GuidanceAdvisoryBlock.swift
//  dialog
//
//  The advisory guidance block: a state headline, one explanatory sentence, a section label,
//  finding rows (glyph · title · detail · deadline · cost) and a footnote. Fills the measure its
//  host gives it; the timing column reflows under the title when narrow.
//

import SwiftUI

struct GuidanceAdvisoryBlock: View {
    let block: InspectConfig.GuidanceContent
    var accentColor: Color?
    let scaleFactor: CGFloat
    /// Relative icon paths resolve against this.
    var iconBasePath: String?
    @Environment(\.palette) private var palette

    private var findings: [InspectConfig.GuidanceContent.AdvisoryFinding] { block.findings ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14 * scaleFactor) {
            header

            if let sectionLabel = block.sectionLabel, !sectionLabel.isEmpty {
                GuidanceSectionLabel(text: sectionLabel, scaleFactor: scaleFactor)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(findings.enumerated()), id: \.offset) { index, finding in
                    findingRow(finding)
                    if index < findings.count - 1 { Divider() }
                }
            }

            if let footnote = block.footnote, !footnote.isEmpty {
                Text(footnote)
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header

    /// No default headline: an empty one is a config bug worth seeing.
    @ViewBuilder
    private var header: some View {
        if block.label?.isEmpty == false || block.content?.isEmpty == false {
            HStack(alignment: .top, spacing: 10 * scaleFactor) {
                stateGlyph(block.state, size: 15)

                VStack(alignment: .leading, spacing: 4 * scaleFactor) {
                    if let label = block.label, !label.isEmpty {
                        Text(label)
                            .font(.system(size: 17 * scaleFactor, weight: .semibold))
                            .foregroundStyle(palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let content = block.content, !content.isEmpty {
                        Text(content)
                            .font(.system(size: 12 * scaleFactor))
                            .foregroundStyle(palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func findingRow(_ finding: InspectConfig.GuidanceContent.AdvisoryFinding) -> some View {
        // Wide: timing in a right column. Narrow: timing under the text.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12 * scaleFactor) {
                rowText(finding)
                Spacer(minLength: 16 * scaleFactor)
                timing(finding, alignment: .trailing)
                    .frame(width: 130 * scaleFactor, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                rowText(finding)
                timing(finding, alignment: .leading)
            }
        }
        .padding(.vertical, 10 * scaleFactor)
    }

    @ViewBuilder
    private func rowText(_ finding: InspectConfig.GuidanceContent.AdvisoryFinding) -> some View {
        HStack(alignment: .top, spacing: 10 * scaleFactor) {
            // With an icon the state rides as a badge; without one the state glyph leads.
            if let icon = finding.icon, !icon.isEmpty {
                AdvisoryIcon(path: icon, basePath: iconBasePath, scaleFactor: scaleFactor)
                    .frame(width: 22 * scaleFactor, height: 22 * scaleFactor)
                    .overlay(alignment: .bottomTrailing) {
                        // The badge disc only when the state earns a signal; `pass` earns none.
                        if stateSignal(for: finding.state) != nil {
                            ZStack {
                                Circle().fill(.background)
                                stateGlyph(finding.state, size: 8)
                            }
                            .frame(width: 13 * scaleFactor, height: 13 * scaleFactor)
                            .offset(x: 4 * scaleFactor, y: 4 * scaleFactor)
                        }
                    }
            } else {
                stateGlyph(finding.state, size: 13)
            }

            VStack(alignment: .leading, spacing: 3 * scaleFactor) {
                Text(finding.title)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = finding.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Deadline above, cost below; two facts, never one line.
    @ViewBuilder
    private func timing(_ finding: InspectConfig.GuidanceContent.AdvisoryFinding,
                        alignment: HorizontalAlignment) -> some View {
        if finding.deadline?.isEmpty == false || finding.duration?.isEmpty == false {
            VStack(alignment: alignment, spacing: 2 * scaleFactor) {
                if let deadline = finding.deadline, !deadline.isEmpty {
                    Text(deadline)
                        .font(.system(size: 11 * scaleFactor, weight: .medium))
                        // The glyph carries severity; the deadline stays a plain quantity.
                        .foregroundStyle(palette.textMuted)
                }
                if let duration = finding.duration, !duration.isEmpty {
                    Text(duration)
                        .font(.system(size: 11 * scaleFactor, design: .monospaced))
                        .foregroundStyle(palette.textFaint)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: -

    /// A state with a `BlockSemantics` mark draws the glyph; one with only a tint draws a dot;
    /// `pass` draws nothing.
    private enum StateSignal {
        case mark(symbol: String, tint: Color?)
        case dot(tint: Color)
    }

    private func stateSignal(for state: String?) -> StateSignal? {
        let semanticState: BlockSemantics.State? = {
            switch state {
            case "success": return .pass
            case "error": return .fail
            case "warning": return .warning
            default: return nil
            }
        }()
        guard let semanticState else { return nil }

        if let mark = BlockSemantics.mark(for: semanticState) {
            return .mark(symbol: mark, tint: BlockSemantics.tint(for: semanticState, palette: palette))
        }
        if let tint = BlockSemantics.tint(for: semanticState, palette: palette) {
            return .dot(tint: tint)
        }
        return nil
    }

    @ViewBuilder
    private func stateGlyph(_ state: String?, size: CGFloat) -> some View {
        switch stateSignal(for: state) {
        case let .mark(symbol, tint):
            Image(systemName: symbol)
                .font(.system(size: size * scaleFactor, weight: .semibold))
                .foregroundStyle(tint ?? .primary)
        case let .dot(tint):
            Circle()
                .fill(tint)
                .frame(width: size * scaleFactor * 0.5, height: size * scaleFactor * 0.5)
        case nil:
            Color.clear.frame(width: size * scaleFactor, height: size * scaleFactor)
        }
    }
}


/// An advisory icon: an `.app` bundle's icon, an image file, an SF Symbol by name, or a neutral
/// placeholder when the file fails to load.
struct AdvisoryIcon: View {
    let path: String
    var basePath: String?
    let scaleFactor: CGFloat
    @Environment(\.palette) private var palette

    private var resolved: String {
        if path.hasPrefix("/") || path.hasPrefix("~") { return (path as NSString).expandingTildeInPath }
        if let basePath, !basePath.isEmpty, path.contains(".") {
            return (basePath as NSString).appendingPathComponent(path)
        }
        return path
    }

    /// Rooted, or ending in a loadable extension. SF Symbol names contain dots too.
    private var looksLikeFile: Bool {
        if path.hasPrefix("/") || path.hasPrefix("~") { return true }
        let ext = (path as NSString).pathExtension.lowercased()
        return ["app", "png", "jpg", "jpeg", "gif", "pdf", "tiff", "icns", "heic", "webp"].contains(ext)
    }

    var body: some View {
        if looksLikeFile {
            if let image = loadImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 5 * scaleFactor, style: .continuous))
            } else {
                placeholder
            }
        } else {
            Image(systemName: path)
                .font(.system(size: 15 * scaleFactor))
                .foregroundStyle(palette.textMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 5 * scaleFactor, style: .continuous)
            .fill(palette.textMuted.opacity(0.12))
    }

    private func loadImage() -> NSImage? {
        let p = resolved
        if p.hasSuffix(".app") { return NSWorkspace.shared.icon(forFile: p) }
        return InspectImageCache.shared.image(atPath: p)
    }
}
