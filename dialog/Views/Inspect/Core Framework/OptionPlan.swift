//
//  OptionPlan.swift
//  dialog
//
//  The option-card plan: which cards a step offers and how a pick resolves.
//

import SwiftUI


/// What a multi-select step's picks resolve to: the picks, plus everything a picked or included
/// option `includes`, less everything a running option `cancels`. A cancel beats an include and a
/// pick. The one resolver for the rows, the progress step and the review.
struct OptionPlan: Equatable {
    /// What runs, in card order.
    let run: [String]
    /// Option → the picked option that includes it.
    let includedBy: [String: String]
    /// Option → the running option that cancels it.
    let cancelledBy: [String: String]

    static func resolve(cards: [InspectConfig.OptionCard], picked: Set<String>) -> OptionPlan {
        let value = { (card: InspectConfig.OptionCard) in card.value ?? card.cardId }
        var includedBy: [String: String] = [:]
        for card in cards where picked.contains(value(card)) {
            for id in expand(card.includes ?? [], in: cards) where includedBy[id] == nil && id != value(card) {
                includedBy[id] = value(card)
            }
        }
        let active = picked.union(includedBy.keys)
        var cancelledBy: [String: String] = [:]
        for card in cards where active.contains(value(card)) {
            for id in expand(card.cancels ?? [], in: cards) where cancelledBy[id] == nil && id != value(card) {
                cancelledBy[id] = value(card)
            }
        }
        // A canceller that is itself cancelled cancels nothing: drop its marks and settle once.
        for (id, by) in cancelledBy where cancelledBy[by] != nil { cancelledBy[id] = nil }
        let run = cards.map(value).filter { active.contains($0) && cancelledBy[$0] == nil }
        return OptionPlan(run: run, includedBy: includedBy, cancelledBy: cancelledBy)
    }

    /// Prefix in `includes` / `cancels` that names every card in a category.
    static let categoryPrefix = "category:"

    /// A rule list with its category selectors expanded to card values, in card order.
    static func expand(_ refs: [String], in cards: [InspectConfig.OptionCard]) -> [String] {
        refs.flatMap { ref -> [String] in
            guard ref.hasPrefix(categoryPrefix) else { return [ref] }
            let name = String(ref.dropFirst(categoryPrefix.count))
            return cards.filter { $0.category == name }.map { $0.value ?? $0.cardId }
        }
    }

    /// The multi-select key a review or progress step follows: the one it names, else the flow's
    /// only multi-select step; nil when there are several and no name.
    static func followedKey(explicit: String?, in steps: [InspectConfig.IntroStep]) -> String? {
        if let explicit, !explicit.isEmpty { return explicit }
        let choosers = steps.filter { $0.stepType == "options" && $0.optionMultiSelect == true }
        guard choosers.count == 1 else { return nil }
        return choosers[0].optionKey ?? choosers[0].id
    }

    /// Every derived entry is satisfied over IPC (`cadence:satisfy:<id>`), not detected.
    private static let ipcAttribute: InspectConfig.CadenceAttribute? =
        try? JSONDecoder().decode(InspectConfig.CadenceAttribute.self, from: Data(#"{"source":"ipc"}"#.utf8))

    /// Cadence entries derived from the cards in `run`, ordered by `runOrder` (absent = 0) with
    /// ties in card order; the message is `runMessage` or the label.
    static func cadenceEntries(cards: [InspectConfig.OptionCard], run: [String],
                               minDwell: Double?, timeout: Double?) -> [InspectConfig.CadenceEntry] {
        guard let attribute = ipcAttribute else { return [] }
        let running = Set(run)
        return cards.enumerated()
            .filter { running.contains($0.element.value ?? $0.element.cardId) }
            .sorted { ($0.element.runOrder ?? 0, $0.offset) < ($1.element.runOrder ?? 0, $1.offset) }
            .map { _, card in
                InspectConfig.CadenceEntry(
                    id: card.value ?? card.cardId,
                    message: card.runMessage ?? "\(card.label)…",
                    attribute: attribute, minDwell: minDwell, timeout: timeout ?? 600,
                    sfSymbol: card.sfSymbol, imagePath: card.iconPath, iconColor: nil,
                    label: card.label, subtitle: card.subtitle, timeEstimate: nil, size: nil)
            }
    }

    /// The key the resolved plan is stored under, beside the picks.
    static func runKey(_ key: String) -> String { "\(key).run" }
    static func acknowledgedKey(_ key: String) -> String { "\(key).acknowledged" }
}
