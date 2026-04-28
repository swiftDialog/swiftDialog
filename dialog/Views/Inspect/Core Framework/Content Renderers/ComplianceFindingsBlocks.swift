//
//  ComplianceFindingsBlocks.swift
//  Dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/04/2026
//
//  Plist-driven content blocks for static compliance/health-check findings.
//  Use with stepType: "info" so Continue is never gated on completion.
//  Shared across Preset 5 and Preset 6 via an environment-injected aggregator.
//

import SwiftUI

// The `\.complianceAggregator` environment key this file uses lives in
// `InspectEnvironmentKeys.swift`.

// MARK: - Compliance Summary Block

/// Hero summary with overall compliance % and 3 stat cards (Total / Healthy / Needs Attention).
/// Feeds from ComplianceAggregatorService so counts refresh when the plist changes.
/// Optional `findings-list` can be rendered inline below this when `showFindingsInline` is true.
struct ComplianceSummaryBlock: View {
    let block: InspectConfig.GuidanceContent
    let totalChecks: Int
    let totalPassed: Int
    let healthyLabel: String
    let attentionLabel: String
    let scaleFactor: CGFloat
    let colorThresholds: InspectConfig.ColorThresholds

    private var totalFailed: Int { max(0, totalChecks - totalPassed) }
    private var score: Double {
        guard totalChecks > 0 else { return 0 }
        return Double(totalPassed) / Double(totalChecks)
    }
    private var statusText: String { colorThresholds.getLabel(for: score) }
    private var statusColor: Color { colorThresholds.getColor(for: score) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16 * scaleFactor) {
            overallBanner
            statCards
        }
        .frame(maxWidth: .infinity)
    }

    private var overallBanner: some View {
        HStack(spacing: 12 * scaleFactor) {
            Circle()
                .fill(statusColor)
                .frame(width: 12 * scaleFactor, height: 12 * scaleFactor)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.label ?? "Overall compliance")
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(statusText)
                    .font(.system(size: 15 * scaleFactor, weight: .semibold))
            }
            Spacer()
        }
        .padding(14 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }

    private var statCards: some View {
        HStack(spacing: 12 * scaleFactor) {
            statCard(
                label: "Total Checks",
                value: "\(totalChecks)",
                footer: "executed",
                tint: .secondary
            )
            statCard(
                label: healthyLabel,
                value: "\(totalPassed)",
                footer: totalPassed == 1 ? "check" : "checks",
                tint: .semanticSuccess
            )
            statCard(
                label: attentionLabel,
                value: "\(totalFailed)",
                footer: totalFailed == 1 ? "check" : "checks",
                tint: totalFailed == 0 ? Color.secondary : .semanticWarning
            )
        }
    }

    @ViewBuilder
    private func statCard(label: String, value: String, footer: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 28 * scaleFactor, weight: .bold))
                .foregroundStyle(tint == .secondary ? Color.primary : tint)
            Text(label)
                .font(.system(size: 14 * scaleFactor, weight: .semibold))
            Text(footer)
                .font(.system(size: 11 * scaleFactor))
                .foregroundStyle(.secondary)
        }
        .padding(14 * scaleFactor)
        .frame(maxWidth: .infinity, minHeight: 120 * scaleFactor, alignment: .leading)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.16), tint.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Findings List Block

/// Category-grouped list of compliance findings with a "View all" disclosure.
/// `showOnly`: "attention" surfaces only failing items (audience-friendly default);
/// "all" shows every check grouped by category (drilldown / admin view).
struct FindingsListBlock: View {
    let block: InspectConfig.GuidanceContent
    let categories: [PlistAggregator.ComplianceCategory]
    let healthyLabel: String
    let attentionLabel: String
    let scaleFactor: CGFloat

    // "all" in block.content flips the default to the full grouped list (admin view).
    // Otherwise default to the audience-friendly "attention-only" view with a disclosure.
    private var showAllByDefault: Bool {
        (block.content?.lowercased() ?? "") == "all"
    }

    @State private var showAll: Bool = false

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
                .foregroundStyle(item.finding ? Color.semanticSuccess : Color.semanticWarning)
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
                .foregroundStyle(item.finding ? Color.semanticSuccess : Color.semanticWarning)
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
                .foregroundStyle(Color.semanticSuccess)
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
                .fill(Color.green.opacity(0.08))
        )
    }
}
