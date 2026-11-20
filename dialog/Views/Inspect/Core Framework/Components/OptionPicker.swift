//
//  OptionPicker.swift
//  dialog
//
//  Pick one (or many) from option cards. Presents the choices and emits the selection as
//  `select:<key>:<value(s)>` on the interaction log plus a selection notification; the
//  orchestrator applies it. Dialog never applies the setting itself.
//

import SwiftUI

/// The option-picker's layouts. Both hosts route through this init, so the default is the same
/// for every preset; an unrecognised value falls back to `.rows`.
enum OptionPickerLayout: String {
    /// One full-width row per option, so consequence lines are not truncated. The default.
    case rows
    case grid
    case cards

    init(_ authored: String?) {
        self = authored.flatMap(OptionPickerLayout.init(rawValue:)) ?? .rows
    }
}

/// A config-driven card picker. Single-select by default; `multiSelect` allows several.
/// Generic over `UserInputContext`: its surface is config, user values and the interaction log.
struct OptionPickerView<Context: UserInputContext & ObservableObject>: View {
    let cards: [InspectConfig.OptionCard]
    let selectionKey: String
    let multiSelect: Bool
    let layout: OptionPickerLayout
    let confirmButtonText: String?     // nil ⇒ instant emit on tap
    let preferenceKey: String?         // reserved for preferences-plist output
    let scaleFactor: CGFloat
    /// The accent the host hands down, or nil for the flow's own.
    var tint: Color?
    var centered: Bool = false
    @ObservedObject var inspectState: Context
    let itemId: String

    @State private var selected: Set<String> = []
    @State private var didInit = false

    @Environment(\.palette) private var palette

    private var accentColor: Color { tint ?? palette.accent }

    private var recommendedValue: String? { DecisionCard.preselectedCard(from: cards) }

    /// The value emitted for a card: its explicit `value`, else its id.
    private func value(for card: InspectConfig.OptionCard) -> String {
        DecisionCard.emittedValue(of: card)
    }

    /// Cards with effort/exposure are taller, so the grid drops from three to two across. An
    /// empty string renders nothing and does not count.
    private var columns: [GridItem] {
        let hasConsequence = cards.contains {
            ($0.effort?.isEmpty == false) || ($0.exposure?.isEmpty == false)
        }
        let cap = hasConsequence ? 2 : 3
        let count = layout == .grid ? cap : max(1, min(cards.count, cap))
        return Array(repeating: GridItem(.flexible(), spacing: 12 * scaleFactor), count: count)
    }

    var body: some View {
        Group {
            if confirmButtonText == nil {
                // No gate: the host's container decides scrolling.
                cardList
            } else {
                // With a gate the picker owns scrolling, so the confirm button is pinned to the
                // viewport and can never scroll out of reach. Hosts must not wrap this case in a
                // ScrollView of their own.
                ScrollView(.vertical) { cardList }
                    .safeAreaInset(edge: .bottom, spacing: 0) { confirmBar }
            }
        }
        .frame(maxWidth: centered ? 680 * scaleFactor : .infinity)
        .onAppear {
            guard !didInit else { return }
            didInit = true
            // A restored answer always wins over the recommendation.
            if let existing = inspectState.userValues[selectionKey], !existing.isEmpty {
                selected = Set(existing.components(separatedBy: ",").filter { !$0.isEmpty })
                return
            }
            // Single-select only: the recommendation is pre-selected and recorded now, since a
            // user who simply agrees never taps a card. The card's action still waits.
            if !multiSelect, let recommended = recommendedValue {
                selected = [recommended]
                recordSelection()
            }
        }
    }

    /// The cards for every layout; nothing here gates the step.
    @ViewBuilder
    private var cardList: some View {
        VStack(spacing: 16 * scaleFactor) {
            if layout == .rows {
                DecisionRowList(
                    cards: cards,
                    selected: selected,
                    recommendedValue: recommendedValue,
                    accentColor: accentColor,
                    scaleFactor: scaleFactor,
                    onTap: { toggle($0) },
                    valueFor: { value(for: $0) }
                )
            } else if cards.contains(where: { $0.category?.isEmpty == false }) {
                // Categories are labelled bands on one screen; symbol-only catalogues pack four across.
                let bands = DecisionCard.categoryBands(cards)
                let symbolOnly = cards.allSatisfy {
                    $0.preview == nil && $0.dockPreview == nil
                        && ($0.effort?.isEmpty ?? true) && ($0.exposure?.isEmpty ?? true)
                }
                let bandColumns = Array(repeating: GridItem(.flexible(), spacing: 12 * scaleFactor),
                                        count: symbolOnly ? 4 : columns.count)
                VStack(alignment: .leading, spacing: 22 * scaleFactor) {
                    ForEach(bands.indices, id: \.self) { b in
                        VStack(alignment: .leading, spacing: 10 * scaleFactor) {
                            if !bands[b].title.isEmpty {
                                HStack(spacing: 6 * scaleFactor) {
                                    Text(bands[b].title)
                                        .font(.system(size: 13 * scaleFactor, weight: .semibold))
                                        .foregroundStyle(.primary.opacity(0.85))
                                    Text("· \(bands[b].cards.count)")
                                        .font(.system(size: 12.5 * scaleFactor))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            LazyVGrid(columns: bandColumns, spacing: 12 * scaleFactor) {
                                ForEach(bands[b].cards) { card in
                                    cardView(card)
                                }
                            }
                        }
                    }
                }
            } else {
                LazyVGrid(columns: columns, spacing: 12 * scaleFactor) {
                    ForEach(cards) { card in
                        cardView(card)
                    }
                }
            }
        }
    }

    /// The gate, shown once something is selected. Opaque because cards scroll underneath it.
    @ViewBuilder
    private var confirmBar: some View {
        if let confirm = confirmButtonText, !selected.isEmpty {
            Button(confirm) { commit() }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .controlSize(.large)
                .padding(.top, 16 * scaleFactor)
                .padding(.bottom, 4 * scaleFactor)
                .frame(maxWidth: .infinity)
                .background(.background)
        }
    }

    @ViewBuilder
    private func cardView(_ card: InspectConfig.OptionCard) -> some View {
        let isSelected = selected.contains(value(for: card))
        // An unavailable option stays on screen, disabled, with `subtitle` as the reason.
        let selectable = card.isSelectable
        let adornments = DecisionCard.adornments(for: card, recommendedId: recommendedValue)
        Button {
            toggle(card)
        } label: {
            VStack(spacing: 8 * scaleFactor) {
                // A built-in preview gets a taller slot; icons keep the 40pt slot.
                iconView(for: card)
                    .frame(height: (card.preview.map(AppearanceSwatch.known.contains) ?? false
                                    ? 64 : 40) * scaleFactor)
                Text(card.label)
                    .font(.system(size: 14 * scaleFactor, weight: .medium))
                    .foregroundStyle(.primary)
                if let subtitle = card.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Same conditions as adornmentBody, so an empty block never costs stack spacing.
                if (adornments.effort?.isEmpty == false) || (adornments.exposure?.isEmpty == false)
                    || (adornments.showBadge && adornments.reason?.isEmpty == false) {
                    adornmentStack(adornments)
                }
                if let preview = card.dockPreview, !preview.isEmpty {
                    DockMockupView(items: preview, scaleFactor: scaleFactor)
                }
            }
            .padding(14 * scaleFactor)
            // Every card in a row is the same size.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                // The hairline is constant; selection is the ring below, not a thicker border.
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accentColor)
                        .padding(6 * scaleFactor)
                }
            }
            // A constant 4pt gutter holds the ring, so selection never changes the tile's frame.
            .padding(4)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(accentColor, lineWidth: 2)
                }
            }
            .opacity(selectable ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
        .help(selectable ? "" : (card.subtitle ?? "Not available"))
    }

    /// The consequence block: effort → exposure → recommendation reason.
    @ViewBuilder
    private func adornmentStack(_ adornments: DecisionCard.Adornments,
                                alignment: HorizontalAlignment = .center) -> some View {
        VStack(alignment: alignment, spacing: 4 * scaleFactor) {
            adornmentBody(adornments)
        }
    }

    @ViewBuilder
    private func adornmentBody(_ adornments: DecisionCard.Adornments) -> some View {
                if let effort = adornments.effort, !effort.isEmpty {
                    Text(effort)
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let exposure = adornments.exposure, !exposure.isEmpty {
                    Label(exposure, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundStyle(palette.warning)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // The recommendation is its reason in the accent colour; no badge or star.
                if adornments.showBadge, let reason = adornments.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.system(size: 11 * scaleFactor, weight: .medium))
                        .foregroundStyle(accentColor)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
    }

    /// Artwork precedence: image file at `iconPath` → that file's app icon → built-in `preview`
    /// swatch → SF Symbol → placeholder.
    @ViewBuilder
    private func iconView(for card: InspectConfig.OptionCard) -> some View {
        if let iconPath = card.iconPath,
           let nsImage = InspectImageCache.shared.image(atPath: (iconPath as NSString).expandingTildeInPath) {
            Image(nsImage: nsImage).resizable().scaledToFit()
        } else if let iconPath = card.iconPath,
                  FileManager.default.fileExists(atPath: (iconPath as NSString).expandingTildeInPath) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: (iconPath as NSString).expandingTildeInPath))
                .resizable()
                .scaledToFit()
        } else if let preview = card.preview, AppearanceSwatch.known.contains(preview) {
            AppearanceSwatch(kind: preview, scaleFactor: scaleFactor)
        } else if let sf = card.sfSymbol {
            Image(systemName: sf)
                .font(.system(size: 30 * scaleFactor))
                .foregroundStyle(accentColor)
        } else {
            Image(systemName: "square.dashed")
                .font(.system(size: 30 * scaleFactor))
                .foregroundStyle(.secondary)
        }
    }

    private func toggle(_ card: InspectConfig.OptionCard) {
        // Guards selections that bypass the disabled button (IPC, restored values).
        guard card.isSelectable else { return }
        let v = value(for: card)
        if multiSelect {
            if selected.contains(v) { selected.remove(v) } else { selected.insert(v) }
        } else {
            selected = [v]
        }
        if confirmButtonText == nil { commit() }
    }

    /// Writes the answer down: user values, the `select:<key>:<value(s)>` log line and the
    /// selection notification. Separate from `commit()` so a pre-selected recommendation is
    /// recorded too. The `SelectionEmission` guard lives here, not in `commit()`: an explicit
    /// confirm still fires the card's action but must not append a duplicate `select:` line.
    private func recordSelection() {
        let ordered = selected.sorted()
        let joined = ordered.joined(separator: ",")
        guard SelectionEmission.shouldEmit(newValue: joined,
                                           recorded: inspectState.userValues[selectionKey],
                                           trigger: .committed) else { return }
        inspectState.userValues[selectionKey] = joined
        inspectState.writeToInteractionLog("select:\(selectionKey):\(joined)")
        DialogNotifications.postSelection(key: selectionKey, values: ordered)
    }

    private func commit() {
        recordSelection()
        let ordered = selected.sorted()

        // Record first, then act: a handoff URL may take focus or end this dialog before the
        // selection is written. Only an explicit choice reaches here; a pre-selection never acts.
        guard !multiSelect, ordered.count == 1,
              let chosen = cards.first(where: { value(for: $0) == ordered[0] }),
              chosen.action != nil else { return }
        handleRowAction(action: chosen.action, url: chosen.url, requestId: nil,
                        label: chosen.label, itemId: itemId, inspectState: inspectState)
    }
}
