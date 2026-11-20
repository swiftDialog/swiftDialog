//
//  ProvisioningRowBuilder.swift
//  dialog
//
//  Pure builders turning engine state into provisioning row states and bands.
//

import SwiftUI

enum ProvisioningRowBuilder {

    // MARK: - Packages

    /// Package rows. `claim` is carried for the card grid but never drawn by the row.
    static func itemRows(items: [any MonitoredItem],
                         statuses: [StepStatus],
                         removedIds: Set<String> = [],
                         vocabulary: ProvisioningVocabulary) -> [ProvisioningRowModel] {
        zip(items, statuses).map { item, status in
            let mark: ProvisioningRowMark
            let word: String
            switch status {
            case .completed:            mark = .done;   word = vocabulary.done
            case .active:               mark = .active; word = vocabulary.active
            case .failed:               mark = .failed; word = vocabulary.failed
            case .pending, .skipped:    mark = .queued; word = vocabulary.queued
            }
            // A removal is the pending state with a different word; a real status always outranks it.
            let removed = (status == .pending && removedIds.contains(item.id))
            let finalWord = removed ? vocabulary.removed : word
            let wantsDetail = (mark == .active || mark == .failed)
            return ProvisioningRowModel(
                id: item.id,
                name: item.displayName,
                detail: wantsDetail ? packageDetail(item) : nil,
                detailIsMachine: true,
                mark: mark,
                trailing: removed ? .notice(finalWord)
                                  : .state(finalWord, failed: status == .failed),
                art: item.resolvedArt,
                claim: item.claim)
        }
    }

    /// Size and bundle id, both authored; nil when neither is.
    static func packageDetail(_ item: any MonitoredItem) -> String? {
        let bundleId = item.requirements?.compactMap(\.bundleId).first
        let parts = [item.size, bundleId].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func itemBand(items: [any MonitoredItem],
                         statuses: [StepStatus],
                         vocabulary: ProvisioningVocabulary) -> ProvisioningBandContent {
        let done = statuses.filter { $0 == .completed }.count
        let stopped = statuses.contains(.failed)
        let total = max(items.count, 1)
        return .progress(count: "\(done) of \(items.count) \(vocabulary.done.lowercased())",
                         detail: remainingEstimate(items: items, statuses: statuses),
                         fraction: Double(done) / Double(total),
                         stopped: stopped)
    }

    /// Sum of `timeEstimate` over items not yet done; nil when none is authored.
    static func remainingEstimate(items: [any MonitoredItem],
                                  statuses: [StepStatus]) -> String? {
        let seconds = zip(items, statuses)
            .filter { $0.1 != .completed }
            .compactMap { $0.0.timeEstimate }
            .reduce(0, +)
        guard seconds > 0 else { return nil }
        let minutes = Int((seconds / 60).rounded(.up))
        return minutes >= 1 ? "~\(minutes) min left" : "~\(Int(seconds)) s left"
    }

    // MARK: - Options

    /// Single-select option rows; an unavailable card is dimmed and unselectable, its subtitle
    /// the only explanation.
    static func optionRows(cards: [InspectConfig.OptionCard],
                           selectedId: String?) -> [ProvisioningRowModel] {
        cards.map { card in
            let available = card.state?.lowercased() != "unavailable"
            return ProvisioningRowModel(
                id: card.cardId,
                name: card.label,
                detail: card.subtitle,
                detailIsMachine: false,
                mark: .choice(selected: available && card.cardId == selectedId),
                trailing: .none,
                enabled: available)
        }
    }

    /// Multi-select rows in their category sections, with the plan applied: an included option
    /// shows on and fixed, a cancelled one off and fixed; a card with `exposure` shows it as its
    /// line in the error colour.
    static func multiOptionSections(cards: [InspectConfig.OptionCard], picked: Set<String>,
                                    switches: Bool) -> [ProvisioningRowSection] {
        let plan = OptionPlan.resolve(cards: cards, picked: picked)
        let label = Dictionary(cards.map { ($0.value ?? $0.cardId, $0.label) }, uniquingKeysWith: { a, _ in a })
        func row(_ card: InspectConfig.OptionCard) -> ProvisioningRowModel {
            let value = card.value ?? card.cardId
            let available = card.state?.lowercased() != "unavailable"
            let warns = card.exposure?.isEmpty == false
            var on = available && picked.contains(value)
            var enabled = available
            var detail = warns ? card.exposure : card.subtitle
            if let by = plan.cancelledBy[value] {
                on = false; enabled = false
                detail = "Cancelled by \(label[by] ?? by)"
            } else if let by = plan.includedBy[value], !picked.contains(value) {
                on = true; enabled = false
                detail = "Included in \(label[by] ?? by)"
            }
            let symbol = card.sfSymbol ?? "circle"
            var model = ProvisioningRowModel(
                id: value, name: card.label, detail: detail, detailIsMachine: false,
                mark: switches ? .symbol(symbol, on: on) : .check(selected: on),
                trailing: switches ? .toggle(on: on)
                    : (card.differentiator.map { .state($0, failed: warns) } ?? .none),
                enabled: enabled)
            if switches { model.art = card.iconPath }
            return model
        }
        // Sections in first-appearance order; uncategorised cards form one unlabelled section.
        var order: [String] = []
        var groups: [String: [InspectConfig.OptionCard]] = [:]
        for card in cards {
            let key = card.category ?? ""
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(card)
        }
        return order.map { key in
            let members = groups[key] ?? []
            return ProvisioningRowSection(
                id: key.isEmpty ? "_" : key,
                title: key.isEmpty ? nil : key,
                warns: members.contains { $0.exposure?.isEmpty == false },
                rows: members.map(row))
        }
    }

    /// Review rows: what runs, in card order, then each picked option that will not run, dimmed.
    /// None of them is a choice.
    static func reviewRows(cards: [InspectConfig.OptionCard], picked: Set<String>,
                           plan: OptionPlan) -> [ProvisioningRowModel] {
        let label = Dictionary(cards.map { ($0.value ?? $0.cardId, $0.label) }, uniquingKeysWith: { a, _ in a })
        let byValue = Dictionary(cards.map { ($0.value ?? $0.cardId, $0) }, uniquingKeysWith: { a, _ in a })
        let runs = plan.run.compactMap { id -> ProvisioningRowModel? in
            guard let card = byValue[id] else { return nil }
            let warns = card.exposure?.isEmpty == false
            let detail = plan.includedBy[id].flatMap { picked.contains(id) ? nil : "Included in \(label[$0] ?? $0)" }
                ?? (warns ? card.exposure : card.subtitle)
            var model = ProvisioningRowModel(
                id: id, name: card.label, detail: detail, detailIsMachine: false,
                mark: .symbol(card.sfSymbol ?? "circle", on: true),
                trailing: .state(warns ? (card.differentiator ?? "Runs") : "Runs", failed: warns))
            model.art = card.iconPath
            return model
        }
        let skips = cards.map { $0.value ?? $0.cardId }
            .filter { picked.contains($0) && !plan.run.contains($0) }
            .map { id -> ProvisioningRowModel in
                var model = ProvisioningRowModel(
                    id: id, name: label[id] ?? id,
                    detail: plan.cancelledBy[id].map { "Cancelled by \(label[$0] ?? $0)" },
                    detailIsMachine: false,
                    mark: .symbol(byValue[id]?.sfSymbol ?? "circle", on: false),
                    trailing: .state("Skipped", failed: false), enabled: false)
                model.art = byValue[id]?.iconPath
                return model
            }
        return runs + skips
    }

    /// The stored multi-select answer: picked values in card order, comma-joined.
    static func multiOptionValue(cards: [InspectConfig.OptionCard], selected: Set<String>) -> String {
        cards.map { $0.value ?? $0.cardId }.filter(selected.contains).joined(separator: ",")
    }

    /// Picked count against the whole list; names the run count when it differs from the picks.
    static func multiOptionBand(count: Int, total: Int, runs: Int? = nil) -> ProvisioningBandContent {
        guard count > 0 else {
            return .consequence(text: "Nothing selected · \(total) options", detail: nil, swatch: nil)
        }
        let picked = "\(count) of \(total) selected"
        if let runs, runs != count {
            return .consequence(text: "\(picked) · \(runs) will run", detail: nil, swatch: nil)
        }
        return .consequence(text: picked, detail: nil, swatch: nil)
    }

    /// Option tiles from the same cards as the rows; `optionLayout` picks which is drawn.
    static func optionTiles(cards: [InspectConfig.OptionCard],
                            selectedId: String?) -> [ProvisioningTileModel] {
        cards.map { card in
            let available = card.state?.lowercased() != "unavailable"
            return ProvisioningTileModel(
                id: card.cardId, name: card.label, detail: card.subtitle,
                // Artwork precedence: iconPath, then a drawn preview, then sfSymbol.
                art: {
                    if let iconPath = card.iconPath { return .appIcon(path: iconPath, bundleId: nil) }
                    if let preview = card.preview, AppearanceSwatch.known.contains(preview) {
                        return .appearance(preview)
                    }
                    if let sf = card.sfSymbol { return .symbol(sf) }
                    return .none
                }(),
                selected: available && card.cardId == selectedId,
                enabled: available)
        }
    }

    /// Dock flavour tiles, each carrying its apps as icons plus names; the decline is a tile too.
    static func dockTiles(flavors: [InspectConfig.DockFlavor],
                          decline: InspectConfig.DeclineOption?,
                          selectedId: String?) -> [ProvisioningTileModel] {
        var tiles = flavors.map { flavor in
            ProvisioningTileModel(
                id: flavor.flavorId, name: flavor.name, detail: flavor.summary,
                art: .appRow(flavor.items.map { (label: $0.label, path: $0.path) }),
                selected: flavor.flavorId == selectedId)
        }
        if let decline {
            tiles.append(ProvisioningTileModel(
                id: decline.value ?? "decline", name: decline.label, detail: decline.subtitle,
                art: .symbol("hand.raised"),
                selected: (decline.value ?? "decline") == selectedId))
        }
        return tiles
    }

    /// The flavours, then the decline as a row of its own: it is a real option, not an escape hatch.
    static func dockRows(flavors: [InspectConfig.DockFlavor],
                         decline: InspectConfig.DeclineOption?,
                         selectedId: String?) -> [ProvisioningRowModel] {
        var rows = flavors.map { flavor in
            ProvisioningRowModel(
                id: flavor.flavorId,
                name: flavor.name,
                detail: flavor.items.map(\.label).joined(separator: " · "),
                detailIsMachine: false,
                mark: .choice(selected: flavor.flavorId == selectedId),
                trailing: .none)
        }
        if let decline {
            rows.append(ProvisioningRowModel(
                id: decline.value ?? "decline",
                name: decline.label,
                detail: decline.subtitle,
                detailIsMachine: false,
                mark: .choice(selected: (decline.value ?? "decline") == selectedId),
                trailing: .none))
        }
        return rows
    }

    /// Restored answer, then recommended, then nothing. A restored Dock answer is a comma-joined
    /// path list, matched back to the flavour that produced it.
    static func selectedDock(flavors: [InspectConfig.DockFlavor],
                             decline: InspectConfig.DeclineOption?,
                             restored: String?) -> String? {
        if let restored, restored.isEmpty == false {
            if let decline, (decline.value ?? "none") == restored { return decline.value ?? "decline" }
            let paths = Set(restored.split(separator: ",").map(String.init))
            if let match = flavors.first(where: { Set($0.items.map(\.path)) == paths }) {
                return match.flavorId
            }
        }
        return flavors.first(where: { $0.recommended == true })?.flavorId
    }

    /// Restored answer, then recommended, then nothing.
    static func selectedOption(cards: [InspectConfig.OptionCard], restored: String?) -> String? {
        if let restored, restored.isEmpty == false,
           let first = restored.components(separatedBy: ",").first(where: { !$0.isEmpty }) {
            return first
        }
        return cards.first(where: { $0.recommended == true && $0.state?.lowercased() != "unavailable" })?.cardId
    }

    /// The chosen option's subtitle as the band's consequence line; never a synthesised claim.
    static func optionBand(cards: [InspectConfig.OptionCard],
                           selectedId: String?) -> ProvisioningBandContent {
        guard let card = cards.first(where: { $0.cardId == selectedId }) else {
            return .consequence(text: "Nothing selected", detail: nil, swatch: nil)
        }
        return .consequence(text: card.subtitle ?? card.label, detail: nil, swatch: nil)
    }

    // MARK: - Brands

    /// The longest name the 120pt lockup box sets as a wordmark at 13pt semibold. A shortened
    /// wordmark is an authored fact this code never invents.
    static let wordmarkCharacterBudget = 11

    /// Aspect ratio of the mark after the transparent trim: baked-in canvas padding would otherwise
    /// let a wide wordmark through the ceiling. Nil when the asset cannot be read, so an unreadable
    /// mark takes the fallback rung rather than being assumed to fit.
    static func trimmedRatio(ofMarkAt path: String) -> CGFloat? {
        guard let trimmed = LogoTrimCache.image(for: path) else { return nil }
        let size = trimmed.size
        guard size.width > 0, size.height > 0 else { return nil }
        return size.width / size.height
    }

    static func brandRows(brands: [InspectConfig.BrandConfig],
                          selectedId: String?,
                          scheme: ColorScheme) -> [ProvisioningRowModel] {
        brands.map { brand in
            ProvisioningRowModel(
                id: brand.id,
                name: brand.displayName,
                detail: brand.subtitle,
                detailIsMachine: false,
                mark: .choice(selected: brand.id == selectedId),
                trailing: .identity(identity(for: brand, scheme: scheme)))
        }
    }

    /// The identity ladder: a supplied mark within the ratio ceiling, an authored SF Symbol, a
    /// wordmark plus swatch, then the swatch carrying an initial. Every rung fills the same box.
    /// A mark over the ceiling falls through rather than being shrunk to fit.
    static func identity(for brand: InspectConfig.BrandConfig,
                         scheme: ColorScheme,
                         ceiling: CGFloat = ProvisioningM.identityRatioCeiling) -> ProvisioningIdentity {
        let swatch = brandSwatch(brand.highlightColor, scheme: scheme)
        if let logoPath = brand.logoPath,
           let ratio = trimmedRatio(ofMarkAt: logoPath),
           ratio <= ceiling {
            return .mark(path: logoPath)
        }
        if let symbol = brand.sfSymbol, !symbol.isEmpty {
            return .symbol(symbol, color: swatch)
        }
        if brand.displayName.count <= wordmarkCharacterBudget {
            return .wordmark(brand.displayName.uppercased(), swatch: swatch)
        }
        let initial = brand.displayName.first.map(String.init)?.uppercased() ?? "?"
        return .swatch(initial: initial, color: swatch)
    }

    /// Brand colour lightened for the dark shell by the same pass `BrandingResolver` applies to the
    /// primary colour, so swatch and accent cannot drift.
    static func brandSwatch(_ hex: String?, scheme: ColorScheme) -> Color {
        guard let hex else { return .accentColor }
        let raw = Color(hex: hex)
        return scheme == .dark ? raw.darkModeAdapted : raw
    }

    /// The chosen brand's `footerText` as the consequence line, else the one certain consequence,
    /// its accent.
    static func brandBand(brands: [InspectConfig.BrandConfig],
                          selectedId: String?,
                          scheme: ColorScheme) -> ProvisioningBandContent {
        guard let brand = brands.first(where: { $0.id == selectedId }) ?? brands.first else {
            return .consequence(text: "No brands configured", detail: nil, swatch: nil)
        }
        let text = brand.footerText ?? "\(brand.displayName) accent"
        return .consequence(text: text,
                            detail: nil,
                            swatch: brandSwatch(brand.highlightColor, scheme: scheme))
    }

}
