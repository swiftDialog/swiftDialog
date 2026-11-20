//
//  DecisionCardLogic.swift
//  Dialog
//
//  Decision cards show the inventory and policy the config states; nothing here infers them.
//  These functions decide what each option costs and which is recommended, out of the view.
//

import Foundation

enum DecisionCard {

    /// Cards grouped by `category` in first-seen order, never re-sorted. Uncategorized cards
    /// form a band with an empty title, which renders header-less.
    static func categoryBands(_ cards: [InspectConfig.OptionCard])
        -> [(title: String, cards: [InspectConfig.OptionCard])] {
        var order: [String] = []
        var byCategory: [String: [InspectConfig.OptionCard]] = [:]
        for card in cards {
            let key = (card.category?.isEmpty == false) ? card.category! : ""
            if byCategory[key] == nil { order.append(key) }
            byCategory[key, default: []].append(card)
        }
        return order.map { (title: $0, cards: byCategory[$0] ?? []) }
    }

    /// What a card renders beyond its label and subtitle.
    struct Adornments: Equatable {
        let effort: String?
        let exposure: String?
        let showBadge: Bool
        let reason: String?
    }

    /// The value a card emits: `value` when authored, else `id`. This is what reaches `userValues`
    /// and the `select:` line, and what the duplicate check compares.
    static func emittedValue(of card: InspectConfig.OptionCard) -> String { card.value ?? card.id }

    /// Emitted values carried by more than one card, in first-seen order. A duplicate makes the
    /// recommendation, the fired `url` and the selection ambiguous; `id` and `value` share one namespace.
    static func duplicateEmittedValues(in cards: [InspectConfig.OptionCard]) -> [String] {
        var seen: Set<String> = []
        var reported: Set<String> = []
        var duplicates: [String] = []
        for card in cards {
            let value = emittedValue(of: card)
            if !seen.insert(value).inserted, reported.insert(value).inserted {
                duplicates.append(value)
            }
        }
        return duplicates
    }

    /// The emitted value of the card to pre-select, or nil. Only the first selectable recommendation
    /// counts; extras and recommendations on `unavailable` cards are logged and dropped.
    /// Also runs the duplicate-value check, before the no-recommendation early return.
    static func preselectedCard(from cards: [InspectConfig.OptionCard]) -> String? {
        for duplicate in duplicateEmittedValues(in: cards) {
            writeLog("DecisionCard: more than one card emits '\(duplicate)' — a card's emitted "
                     + "value is its 'value' if authored, else its 'id', and they share one "
                     + "namespace. Selection, the recommendation badge and the card's action all "
                     + "key off it, so duplicates render two recommendations and can fire the "
                     + "wrong card's url. Author distinct values.", logLevel: .error)
        }

        let recommended = cards.filter { $0.recommended == true }
        guard !recommended.isEmpty else { return nil }

        for dropped in recommended where !dropped.isSelectable {
            writeLog("DecisionCard: '\(dropped.id)' is recommended but state is "
                     + "'unavailable' — recommendation dropped", logLevel: .error)
        }

        let eligible = recommended.filter { $0.isSelectable }
        guard let winner = eligible.first else { return nil }

        if eligible.count > 1 {
            writeLog("DecisionCard: \(eligible.count) cards marked recommended "
                     + "(\(eligible.map(\.id).joined(separator: ", "))) — first wins, "
                     + "the rest are ignored", logLevel: .error)
        }
        return emittedValue(of: winner)
    }

    /// `recommendedId` is the result of `preselectedCard(from:)`, so "first wins" needs no re-scan.
    static func adornments(for card: InspectConfig.OptionCard,
                           recommendedId: String?) -> Adornments {
        let isWinner = recommendedId != nil && emittedValue(of: card) == recommendedId
        return Adornments(effort: card.effort,
                          exposure: card.exposure,
                          showBadge: isWinner,
                          reason: isWinner ? card.recommendReason : nil)
    }

    /// The single consequence line a row shows, and whether it is the recommendation.
    /// Order: recommendation reason, then exposure, then effort. Empty strings count as absent.
    static func consequence(for adornments: Adornments) -> (text: String, isRecommendation: Bool)? {
        if adornments.showBadge, let reason = adornments.reason, !reason.isEmpty {
            return (reason, true)
        }
        if let exposure = adornments.exposure, !exposure.isEmpty {
            return (exposure, false)
        }
        if let effort = adornments.effort, !effort.isEmpty {
            return (effort, false)
        }
        return nil
    }
}
