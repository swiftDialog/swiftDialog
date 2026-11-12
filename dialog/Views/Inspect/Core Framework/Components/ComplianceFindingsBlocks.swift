//
//  ComplianceFindingsBlocks.swift
//  Dialog
//
//  Plist-driven compliance summary and findings blocks for Presets 5 and 6, fed by the environment's
//  `\.complianceAggregator` (declared in `InspectEnvironmentKeys.swift`). Use with stepType "info".
//

import SwiftUI

// MARK: - Compliance Summary Block

/// The compliance score as one sentence ("5 of 7 checks pass"), a subheadline, a fraction bar and one row
/// per category; refreshes when the plist changes. Findings are drawn by `FindingsListBlock`.
struct ComplianceSummaryBlock: View {
    @Environment(\.inspectLocalization) private var l10n
    @Environment(\.palette) private var palette
    let block: InspectConfig.GuidanceContent
    let totalChecks: Int
    let totalPassed: Int
    let healthyLabel: String
    let attentionLabel: String
    let scaleFactor: CGFloat
    let colorThresholds: InspectConfig.ColorThresholds
    /// One row per category.
    var categories: [PlistAggregator.ComplianceCategory] = []
    var lastChecked: Date?

    private var totalFailed: Int { max(0, totalChecks - totalPassed) }
    private var criticalCount: Int {
        categories.flatMap { $0.items }.filter { $0.isCritical && !$0.finding }.count
    }

    private static let timeOnly: DateFormatter = {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("Hm"); return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14 * scaleFactor) {
            // The score is said once, as a sentence.
            HStack(alignment: .firstTextBaseline, spacing: 12 * scaleFactor) {
                VStack(alignment: .leading, spacing: 3 * scaleFactor) {
                    Text(l10n("ui.complianceScore", "{passed} of {total} checks pass")
                        .replacingOccurrences(of: "{passed}", with: "\(totalPassed)")
                        .replacingOccurrences(of: "{total}", with: "\(totalChecks)"))
                        .font(.system(size: 20 * scaleFactor, weight: .bold))
                        .tracking(-0.2)

                    Text(subheadline)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8 * scaleFactor)

                if let lastChecked {
                    Text(l10n("ui.complianceChecked", "checked {when}")
                        .replacingOccurrences(of: "{when}", with: Self.timeOnly.string(from: lastChecked)))
                        .font(.system(size: 11 * scaleFactor, design: .monospaced))
                        .foregroundStyle(palette.textFaint)
                }
            }

            FractionBar(fraction: totalChecks > 0 ? Double(totalPassed) / Double(totalChecks) : 0,
                        height: 5 * scaleFactor,
                        fill: totalFailed == 0 ? palette.success : palette.error)

            if !categories.isEmpty {
                Text(l10n("ui.complianceByCategory", "By category").uppercased())
                    .font(.system(size: 10 * scaleFactor, weight: .semibold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(palette.textFaint)
                    .padding(.top, 2 * scaleFactor)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(categories, id: \.name) { category in
                        categoryRow(category)
                        if category.name != categories.last?.name { Divider() }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "2 need attention · none critical": the two facts the headline cannot carry.
    private var subheadline: String {
        if totalFailed == 0 {
            return l10n("ui.complianceAllPassSub", "Nothing needs attention")
        }
        let need = l10n("ui.complianceNeedAttention", "{count} need attention")
            .replacingOccurrences(of: "{count}", with: "\(totalFailed)")
        let crit = criticalCount == 0
            ? l10n("ui.complianceNoneCritical", "none critical")
            : l10n("ui.complianceNCritical", "{count} critical")
                .replacingOccurrences(of: "{count}", with: "\(criticalCount)")
        return "\(need) · \(crit)"
    }

    /// A glyph, the name, the count, and one sentence saying why.
    @ViewBuilder
    private func categoryRow(_ category: PlistAggregator.ComplianceCategory) -> some View {
        let failing = category.items.filter { !$0.finding }
        let passed = failing.isEmpty

        HStack(alignment: .firstTextBaseline, spacing: 10 * scaleFactor) {
            Image(systemName: passed ? "checkmark" : "xmark")
                .font(.system(size: 12 * scaleFactor, weight: .semibold))
                .foregroundStyle(passed ? palette.success : palette.error)
                .frame(width: 14 * scaleFactor, alignment: .leading)

            Text(category.name)
                .font(.system(size: 13 * scaleFactor, weight: .medium))
                .frame(width: 150 * scaleFactor, alignment: .leading)

            Text(l10n("ui.complianceCategoryCount", "{passed} of {total}")
                .replacingOccurrences(of: "{passed}", with: "\(category.passed)")
                .replacingOccurrences(of: "{total}", with: "\(category.total)"))
                .font(.system(size: 12 * scaleFactor, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 66 * scaleFactor, alignment: .leading)

            Text(reason(failing: failing, passed: passed))
                .font(.system(size: 12 * scaleFactor))
                .foregroundStyle(passed ? .secondary : palette.error)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8 * scaleFactor)
    }

    /// The admin's sentence; with several failures, the count rather than one picked arbitrarily.
    private func reason(failing: [PlistAggregator.ComplianceItem], passed: Bool) -> String {
        if passed { return l10n("ui.complianceCategoryAllPass", "All checks pass") }
        if failing.count == 1, let only = failing.first {
            let authored = (only.explanation?.isEmpty == false) ? only.explanation! : only.displayName
            return l10n("compliance.\(only.id).explanation", authored)
        }
        return l10n("ui.complianceNFailing", "{count} checks need attention")
            .replacingOccurrences(of: "{count}", with: "\(failing.count)")
    }
}

// MARK: - Findings List Block

/// Category-grouped compliance findings. `content: "all"` shows every check (admin view); anything else
/// shows failing items only, with a "View all" disclosure.
struct FindingsListBlock: View {
    let block: InspectConfig.GuidanceContent
    let categories: [PlistAggregator.ComplianceCategory]
    let healthyLabel: String
    let attentionLabel: String
    let scaleFactor: CGFloat

    private var showAllByDefault: Bool {
        (block.content?.lowercased() ?? "") == "all"
    }

    @State private var showAll: Bool = false
    @Environment(\.palette) private var palette

    private var attentionItems: [(category: String, item: PlistAggregator.ComplianceItem)] {
        categories.flatMap { cat in
            cat.items.filter { !$0.finding }.map { (cat.name, $0) }
        }
    }

    private var effectiveShowAll: Bool { showAllByDefault || showAll }

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * scaleFactor) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12 * scaleFactor) {
                    if !effectiveShowAll {
                        attentionSection
                    } else {
                        allCategoriesSection
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4 * scaleFactor)
            }
            .frame(maxHeight: 340 * scaleFactor)

            if !showAllByDefault {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showAll.toggle() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: effectiveShowAll ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11 * scaleFactor, weight: .semibold))
                        Text(effectiveShowAll ? "Hide full list" : "View all \(totalCount) checks")
                            .font(.system(size: 13 * scaleFactor, weight: .medium))
                    }
                    .padding(.vertical, 8 * scaleFactor)
                    .padding(.horizontal, 14 * scaleFactor)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.12))
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var totalCount: Int {
        categories.reduce(0) { $0 + $1.total }
    }

    @ViewBuilder
    private var attentionSection: some View {
        if attentionItems.isEmpty {
            emptyState(
                symbol: "checkmark.seal.fill",
                title: "All checks \(healthyLabel.lowercased())",
                subtitle: "No findings need attention."
            )
        } else {
            VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                sectionHeader("\(attentionLabel) · \(attentionItems.count)")
                ForEach(attentionItems.indices, id: \.self) { idx in
                    let row = attentionItems[idx]
                    findingRow(row.item, categoryHint: row.category)
                }
            }
        }
    }

    @ViewBuilder
    private var allCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 14 * scaleFactor) {
            ForEach(categories, id: \.name) { cat in
                VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                    sectionHeader("\(cat.name) · \(cat.passed)/\(cat.total)")
                    ForEach(cat.items.indices, id: \.self) { idx in
                        findingRow(cat.items[idx], categoryHint: nil)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10 * scaleFactor, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func findingRow(_ item: PlistAggregator.ComplianceItem, categoryHint: String?) -> some View {
        HStack(spacing: 10 * scaleFactor) {
            Image(systemName: item.finding ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 14 * scaleFactor))
                .foregroundStyle(item.finding ? palette.success : palette.warning)
                .frame(width: 18 * scaleFactor)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                if let hint = categoryHint {
                    Text(hint)
                        .font(.system(size: 10 * scaleFactor))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Text(item.finding ? healthyLabel : attentionLabel)
                .font(.system(size: 11 * scaleFactor, weight: .semibold))
                .foregroundStyle(item.finding ? palette.success : palette.warning)
        }
        .padding(.vertical, 8 * scaleFactor)
        .padding(.horizontal, 12 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }

    @ViewBuilder
    private func emptyState(symbol: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12 * scaleFactor) {
            Image(systemName: symbol)
                .font(.system(size: 24 * scaleFactor))
                .foregroundStyle(palette.success)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14 * scaleFactor, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(palette.success.opacity(0.08))
        )
    }
}
