//
//  BentoRow.swift
//  Dialog
//
//  The rows zone of a bento tile: one row per installable thing, each with its own button. A
//  tile with rows is a plain container (`BentoCellView.swift`); a tile without rows is one button.
//

import SwiftUI

/// One row inside a bento tile: an icon, what the thing is, and the single action that belongs
/// to it. A model, not a view over preset state, so any preset can render it.
struct BentoRowModel: Identifiable, Equatable {
    let id: String
    let title: String
    /// The one clarifying line, when the name is not enough.
    let detail: String?
    /// A fact about the download ("1.2 GB"), never a status; status lives in the affordance.
    let badge: String?
    let iconName: String?

    /// Config-authored, same vocabulary as `OptionCard`: nil, "installed", "pending", "unavailable".
    let state: String?

    /// Authored verb (Install, Download, Open); never guessed from the title or path.
    let verb: String?

    /// What the row offers once its state is taken into account. A case, not a string, so the
    /// view can localise the label.
    enum Affordance: Equatable {
        /// `verb` is nil when the config authored none; the view supplies the localised default.
        case action(verb: String?)
        case installed
        case pending
        case unavailable
    }

    var affordance: Affordance {
        switch state?.lowercased() {
        case "installed":   return .installed
        case "pending":     return .pending
        case "unavailable": return .unavailable
        // Unrecognised values keep the button rather than silently losing it.
        default:            return .action(verb: verb)
        }
    }

    /// Hairlines go between rows, under every row but the last.
    static func showsHairline(at index: Int, of total: Int) -> Bool {
        index < total - 1
    }

    /// Spelled out because `init(from:)` suppresses the synthesized memberwise initializer.
    init(id: String, title: String, detail: String? = nil, badge: String? = nil,
         iconName: String? = nil, state: String? = nil, verb: String? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.badge = badge
        self.iconName = iconName
        self.state = state
        self.verb = verb
    }

    /// Builds a row from the `InstallItem` wire shape shared with `install-list` and `detail-rows`.
    init(from item: InspectConfig.GuidanceContent.InstallItem) {
        // `itemId` is optional; the title is the only field always present.
        self.id = item.itemId ?? item.title
        self.title = item.title
        // `subtitle` is the one-line clarifier; `detail` may be a paragraph, so it is only the fallback.
        self.detail = item.subtitle ?? item.detail
        self.badge = item.badge
        self.iconName = item.icon
        // `state` (catalogue presence), not `status` (run outcome).
        self.state = item.state
        self.verb = item.actionLabel
    }
}

extension InspectConfig.GuidanceContent.BentoCellConfig {
    /// The tile's rows, ready to draw; empty when the cell authors none.
    var bentoRows: [BentoRowModel] {
        (rows ?? []).map(BentoRowModel.init(from:))
    }
}

// MARK: - Geometry

/// The row's metrics in unscaled points. Sizes only; colour comes from the palette at the use site.
enum BentoRowM {
    static let iconSize: CGFloat = 26
    static let iconRadius: CGFloat = 6
    static let horizontalGap: CGFloat = 13
    static let verticalPadding: CGFloat = 11

    /// Derived so a padding change moves the height with it.
    static let rowHeight: CGFloat = iconSize + 2 * verticalPadding

    /// The same radius applies to every button in the installer.
    static let buttonRadius: CGFloat = 8
    static let buttonPaddingH: CGFloat = 15
    static let buttonPaddingV: CGFloat = 8

    static let badgeRadius: CGFloat = 5
    static let badgePaddingH: CGFloat = 7
    static let badgePaddingV: CGFloat = 3

    /// Height reserved above the rows for the heading zone. An allowance, not a measurement, and
    /// generous on purpose: too much costs whitespace, too little clips a row.
    static let headingAllowance: CGFloat = 104

    /// What a group of rows costs a tile; hairlines are overlays and add no height.
    static func rowsZoneHeight(count: Int) -> CGFloat {
        CGFloat(max(0, count)) * rowHeight
    }
}

// MARK: - View

/// One row of a bento tile's rows zone; reads only the environment, never preset state.
struct BentoRowView: View {
    @Environment(\.palette) private var palette
    @Environment(\.inspectLocalization) private var l10n

    let row: BentoRowModel
    /// From `BentoRowModel.showsHairline(at:of:)`.
    let showsHairline: Bool
    var scaleFactor: CGFloat = 1
    var action: ((BentoRowModel) -> Void)?

    var body: some View {
        HStack(spacing: BentoRowM.horizontalGap * scaleFactor) {
            iconSlot

            // Title and detail truncate rather than wrap; the tile height assumes one-line rows.
            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                Text(row.title)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                if let detail = row.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(1)
                }
            }
            // The label takes what the fixed-size trailing items leave; a Spacer here would squeeze it.
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if let badge = row.badge, !badge.isEmpty {
                Text(badge)
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(palette.textMuted)
                    .padding(.horizontal, BentoRowM.badgePaddingH * scaleFactor)
                    .padding(.vertical, BentoRowM.badgePaddingV * scaleFactor)
                    .background(
                        RoundedRectangle(cornerRadius: BentoRowM.badgeRadius * scaleFactor)
                            .fill(palette.accent.opacity(0.09))
                    )
                    // A truncated "1.2 GB" states nothing, so the badge never compresses.
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(2)
            }

            affordance
        }
        .padding(.vertical, BentoRowM.verticalPadding * scaleFactor)
        // An overlay, not a divider, so the hairline adds no height and `rowsZoneHeight` holds.
        .overlay(alignment: .bottom) {
            if showsHairline {
                Rectangle()
                    .fill(palette.text.opacity(0.08))
                    .frame(height: 0.5)
            }
        }
    }

    /// A missing icon renders an empty slot, never a stand-in glyph.
    @ViewBuilder
    private var iconSlot: some View {
        let side = BentoRowM.iconSize * scaleFactor
        if let name = row.iconName, !name.isEmpty {
            Image(systemName: name)
                .font(.system(size: 15 * scaleFactor))
                .foregroundStyle(palette.accent)
                .frame(width: side, height: side)
        } else {
            RoundedRectangle(cornerRadius: BentoRowM.iconRadius * scaleFactor)
                .fill(palette.text.opacity(0.08))
                .frame(width: side, height: side)
        }
    }

    @ViewBuilder
    private var affordance: some View {
        switch row.affordance {
        case .action(let verb):
            Button {
                action?(row)
            } label: {
                Text(verb ?? l10n("ui.install", "Install"))
                    .font(.system(size: 12 * scaleFactor, weight: .medium))
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, BentoRowM.buttonPaddingH * scaleFactor)
                    .padding(.vertical, BentoRowM.buttonPaddingV * scaleFactor)
                    .background(
                        RoundedRectangle(cornerRadius: BentoRowM.buttonRadius * scaleFactor)
                            .strokeBorder(palette.text.opacity(0.16), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            // The action never compresses; the title gives way instead.
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
        case .installed:
            statusLabel(l10n("ui.installed", "Installed"))
        case .pending:
            statusLabel(l10n("ui.pending", "Pending"))
        case .unavailable:
            statusLabel(l10n("ui.unavailable", "Unavailable"))
        }
    }

    private func statusLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12 * scaleFactor))
            .foregroundStyle(palette.textMuted)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
    }
}
