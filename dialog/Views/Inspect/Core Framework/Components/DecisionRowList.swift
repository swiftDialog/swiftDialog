//
//  DecisionRowList.swift
//  dialog
//
//  Option cards drawn as rows through `ProvisioningRowStack`: mark, label, one detail line, one
//  trailing value. `OptionPickerView`'s `.rows` layout uses it. Holds no state; selection and
//  recording stay with the caller via `onTap` / `valueFor`.
//

import SwiftUI

struct DecisionRowList: View {
    let cards: [InspectConfig.OptionCard]
    let selected: Set<String>
    let recommendedValue: String?
    let accentColor: Color
    let scaleFactor: CGFloat
    let onTap: (InspectConfig.OptionCard) -> Void
    let valueFor: (InspectConfig.OptionCard) -> String

    /// The differentiator column exists when any card carries one; otherwise it is dropped.
    private var showDifferentiatorColumn: Bool {
        cards.contains { $0.differentiator?.isEmpty == false }
    }

    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme

    /// Selected-row wash: the backdrop palette for the current appearance, else the accent, at
    /// 12% so `.primary` text stays legible in both appearances.
    private var tint: Color {
        (palette.backdropTint(for: scheme) ?? accentColor).opacity(0.12)
    }

    var body: some View {
        // Width nil: the list fills whatever column its host measured.
        ProvisioningRowStack(
            rows: cards.map(model),
            width: nil,
            accent: accentColor,
            onSelect: { id in
                guard let card = cards.first(where: { valueFor($0) == id }) else { return }
                onTap(card)
            })
    }

    /// One card as a provisioning row; decides only what each slot means for an option.
    private func model(_ card: InspectConfig.OptionCard) -> ProvisioningRowModel {
        let adornments = DecisionCard.adornments(for: card, recommendedId: recommendedValue)
        let consequence = DecisionCard.consequence(for: adornments)
        return ProvisioningRowModel(
            id: valueFor(card),
            name: card.label,
            // The consequence when there is one, else the subtitle, which carries the reason a
            // disabled option cannot be chosen.
            detail: consequence?.text ?? card.subtitle,
            detailIsMachine: false,
            mark: .choice(selected: selected.contains(valueFor(card))),
            trailing: showDifferentiatorColumn
                ? .state(card.differentiator.flatMap { $0.isEmpty ? nil : $0 } ?? "—", failed: false)
                : .none,
            enabled: card.isSelectable)
    }
}
