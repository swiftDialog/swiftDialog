//
//  ComplianceSheets.swift
//  Dialog
//
//  The compliance drill-down views: category detail, the details-button block, and the
//  all-categories sheet
//

import SwiftUI

// MARK: - Compliance Detail View (Drill-down)

/// Detail view showing all checks for a compliance category
struct ComplianceDetailView: View {
    let categoryName: String
    let icon: String?
    let passed: Int
    let total: Int
    let checkDetails: String
    let accentColor: Color

    @Environment(\.dismiss) private var dismiss
    @Environment(\.inspectLocalization) private var l10n
    @Environment(\.palette) private var palette

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(passed) / Double(total)
    }

    private var statusColor: Color {
        if percentage >= 1.0 {
            return palette.success
        } else if percentage >= 0.7 {
            return palette.warning
        } else {
            return palette.error
        }
    }

    private var checkLines: [String] {
        checkDetails.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private var failedChecks: [String] {
        checkLines.filter { $0.hasPrefix("✗") }
    }

    private var passedChecks: [String] {
        checkLines.filter { $0.hasPrefix("✓") }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let iconString = icon {
                    Image(systemName: iconString)
                        .font(.system(size: 28))
                        .foregroundStyle(accentColor)
                        .frame(width: 44, height: 44)
                        .background(accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(categoryName)
                        .font(.system(size: 18, weight: .semibold))

                    HStack(spacing: 12) {
                        Label("\(passed) passed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(palette.success)
                        Label("\(total - passed) failed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(palette.error)
                    }
                    .font(.system(size: 13))
                }

                Spacer()

                // Close button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Progress bar
            VStack(spacing: 8) {
                FractionBar(fraction: percentage, fill: statusColor)

                HStack {
                    Text(l10n("ui.complianceDetailPercent", "{percent}% compliant")
                        .replacingOccurrences(of: "{percent}", with: "\(Int(percentage * 100))"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(statusColor)
                    Spacer()
                    Text(l10n("ui.complianceDetailChecks", "{passed} of {total} checks")
                        .replacingOccurrences(of: "{passed}", with: "\(passed)")
                        .replacingOccurrences(of: "{total}", with: "\(total)"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(statusColor.opacity(0.05))

            Divider()

            // Check list
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Failed checks first
                    if !failedChecks.isEmpty {
                        Text(l10n("ui.complianceFailedChecks", "Failed Checks ({count})")
                            .replacingOccurrences(of: "{count}", with: "\(failedChecks.count)"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                        ForEach(Array(failedChecks.enumerated()), id: \.offset) { _, check in
                            ComplianceCheckRow(check: check, isFailed: true)
                        }
                    }

                    // Passed checks
                    if !passedChecks.isEmpty {
                        Text(l10n("ui.compliancePassedChecks", "Passed Checks ({count})")
                            .replacingOccurrences(of: "{count}", with: "\(passedChecks.count)"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                        ForEach(Array(passedChecks.enumerated()), id: \.offset) { _, check in
                            ComplianceCheckRow(check: check, isFailed: false)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .frame(width: 500, height: 600)
    }
}

/// Row for individual compliance check
struct ComplianceCheckRow: View {
    let check: String
    let isFailed: Bool

    @Environment(\.palette) private var palette

    private var cleanedText: String {
        check
            .replacingOccurrences(of: "✓ ", with: "")
            .replacingOccurrences(of: "✗ ", with: "")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isFailed ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isFailed ? palette.error : palette.success)
                .font(.system(size: 16))

            Text(cleanedText)
                .font(.system(size: 13))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(isFailed ? palette.error.opacity(0.05) : Color.clear)
    }
}

// MARK: - Compliance Details Button Block

/// A button that opens the all-categories compliance sheet. The service arrives through
/// `\.complianceAggregator` so `GuidanceContentView` can draw this block on every host.
struct ComplianceDetailsButtonBlock: View {
    let block: InspectConfig.GuidanceContent
    let accentColor: Color
    let maxWidth: CGFloat

    @State private var showingDetails = false
    @Environment(\.inspectLocalization) private var l10n
    @Environment(\.complianceAggregator) private var complianceService

    /// An authored `label` wins over the `ui.*` key.
    private var buttonText: String {
        block.label ?? l10n("ui.complianceViewAllDetails", "View All Details")
    }

    private var buttonStyle: String {
        block.style ?? "link"  // "link", "bordered", "prominent"
    }

    var body: some View {
        HStack {
            if buttonStyle == "prominent" {
                Button(buttonText) {
                    showingDetails = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            } else if buttonStyle == "bordered" {
                Button(buttonText) {
                    showingDetails = true
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            } else {
                // Default: link style
                Button(action: { showingDetails = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 14))
                        Text(buttonText)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showingDetails) {
            if let service = complianceService {
                ComplianceAllDetailsSheet(
                    complianceService: service,
                    accentColor: accentColor
                )
            } else {
                // Fallback if no service available
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(l10n("ui.complianceUnavailableTitle", "Compliance data not available"))
                        .font(.headline)
                    Text(l10n("ui.complianceUnavailableDetail", "Results aren't available right now."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 400, height: 300)
            }
        }
    }
}

// MARK: - Compliance All Details Sheet

/// The compliance disclosure sheet: every category with its failing checks named, and a
/// per-category drill-down with expected versus found, last pass and remedy. The score is stated
/// once, as counts; no percentages anywhere.
struct ComplianceAllDetailsSheet: View {
    @ObservedObject var complianceService: ComplianceAggregatorService
    let accentColor: Color

    @Environment(\.dismiss) private var dismiss
    /// Every fixed string goes through this; the default resolver returns the English fallback.
    @Environment(\.inspectLocalization) private var l10n
    @Environment(\.palette) private var palette
    @State private var selectedCategory: String?
    @State private var hidePassingCategories = false
    /// Check id whose `actionURL` had no handler, so the card can say so in place.
    @State private var openFailed: String?

    /// Localize, then substitute `{name}` placeholders, so a translation can reorder them.
    private func l(_ key: String, _ fallback: String, _ subs: KeyValuePairs<String, String> = [:]) -> String {
        var text = l10n(key, fallback)
        for (name, value) in subs {
            text = text.replacingOccurrences(of: "{\(name)}", with: value)
        }
        return text
    }

    /// 696 × 512 body; the shell's 44pt header and 60pt footer sit outside it.
    private static let bodyWidth: CGFloat = 696
    private static let bodyHeight: CGFloat = 512

    // MARK: Derived facts

    private var totalChecks: Int { complianceService.totalChecks }
    private var totalPassed: Int { complianceService.totalPassed }
    private var totalFailed: Int { complianceService.totalFailed }
    private var criticalCount: Int { complianceService.criticalFailures.count }

    private var lastRunFormatted: String {
        guard let date = complianceService.lastRefresh else {
            return l("ui.complianceNeverRun", "never")
        }
        return DateDisplayService.shared.format(date)
    }

    /// "Security Baseline · macOS 15.5"; with no configured source the baseline name is dropped.
    private var baselineSubject: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let version = "\(os.majorVersion).\(os.minorVersion)"
        guard let name = complianceService.sourceDisplayName else {
            return l("ui.complianceSubjectOSOnly", "macOS {version}", ["version": version])
        }
        return l("ui.complianceSubject", "{name} · macOS {version}",
                 ["name": name, "version": version])
    }

    /// "category 1 of 5 · auditing"
    private var categorySubject: String? {
        guard let name = selectedCategory,
              let index = complianceService.categories.firstIndex(where: { $0.name == name })
        else { return nil }
        return l("ui.complianceCategorySubject", "category {index} of {total} · {name}", [
            "index": "\(index + 1)",
            "total": "\(complianceService.categories.count)",
            "name": categoryLabel(name).lowercased()
        ])
    }

    private var visibleCategories: [PlistAggregator.ComplianceCategory] {
        hidePassingCategories
            ? complianceService.categories.filter { $0.passed < $0.total }
            : complianceService.categories
    }

    // MARK: Body

    var body: some View {
        // Back navigates within the sheet in the drill-down only; Done dismisses either way.
        // `scrolls: true` keeps the body fixed so forty failing checks scroll rather than clip.
        DetailSheetShell(
            backLabel: selectedCategory == nil ? nil : l("ui.complianceAllCategories", "All categories"),
            title: selectedCategory == nil ? l("ui.complianceTitle", "Compliance details") : nil,
            subject: selectedCategory == nil ? baselineSubject : categorySubject,
            accentColor: accentColor,
            width: Self.bodyWidth,
            maxHeight: DetailSheetMetrics.headerHeight + Self.bodyHeight + DetailSheetMetrics.footerHeight,
            scrolls: true,
            onBack: { selectedCategory = nil },
            onClose: { dismiss() },
            content: {
                if let name = selectedCategory,
                   let category = complianceService.category(named: name) {
                    categoryDetail(category)
                } else {
                    listBody
                }
            },
            footer: { footerRow }
        )
    }

    // MARK: - The list

    private var listBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            scoreBlock
                .padding(.top, 6)
                .padding(.bottom, 16)

            Divider()

            categoriesBar
                .padding(.vertical, 10)

            Divider()

            ForEach(Array(visibleCategories.enumerated()), id: \.element.name) { index, category in
                categoryRow(category)
                    .padding(.vertical, 11)

                if index < visibleCategories.count - 1 {
                    Divider()
                }
            }
        }
    }

    /// The one score statement; the critical count is the single fact the sentence cannot carry.
    private var scoreBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(l("ui.complianceScore", "{passed} of {total} checks pass",
                       ["passed": "\(totalPassed)", "total": "\(totalChecks)"]))
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.3)
                    .fixedSize(horizontal: false, vertical: true)

                if totalFailed > 0 {
                    Text(l("ui.complianceFailedCount", "{count} failed", ["count": "\(totalFailed)"]))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if criticalCount > 0 {
                    Text(l("ui.complianceCriticalCount", "{count} critical", ["count": "\(criticalCount)"]))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.error)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(palette.error.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            ComplianceScoreBar(passed: totalPassed, critical: criticalCount, total: totalChecks)
        }
    }

    private var categoriesBar: some View {
        HStack(spacing: 12) {
            Text(l("ui.complianceCategoriesHeading", "{count} CATEGORIES",
                   ["count": "\(complianceService.categories.count)"]))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Toggle(isOn: $hidePassingCategories) {
                Text(l("ui.complianceHidePassing", "Hide passing categories"))
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    /// Name, count and the failing checks named; no icon and no per-row bar.
    private func categoryRow(_ category: PlistAggregator.ComplianceCategory) -> some View {
        let failing = category.items.filter { !$0.finding }

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                // Only a fully passing category gets its own glyph; the failures carry theirs.
                if failing.isEmpty {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.success)
                }

                Text(categoryLabel(category.name))
                    .font(.system(size: 15, weight: .semibold))

                Text(l("ui.complianceCategoryCount", "{passed} of {total}",
                       ["passed": "\(category.passed)", "total": "\(category.total)"]))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textFaint)
            }

            ForEach(failing, id: \.id) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.error)

                    Text(checkSentence(item))
                        .font(.system(size: 13))
                        .fixedSize(horizontal: false, vertical: true)

                    if item.isCritical {
                        criticalTag
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedCategory = category.name }
    }

    // MARK: - The drill-down

    /// What the check wanted, what it got, when it last held, and what to do.
    private func categoryDetail(_ category: PlistAggregator.ComplianceCategory) -> some View {
        let failing = category.items.filter { !$0.finding }
        let passing = category.items.filter { $0.finding }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(categoryLabel(category.name))
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.3)

                Text(l("ui.complianceScore", "{passed} of {total} checks pass",
                       ["passed": "\(category.passed)", "total": "\(category.total)"]))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)

            ForEach(failing, id: \.id) { failingCheckCard($0) }

            ForEach(passing, id: \.id) { passingCheckRow($0) }

            if failing.contains(where: { $0.actionURL != nil }) {
                // Apply fix opens the setting; it writes nothing, and the note must say so.
                Text(l("ui.complianceApplyFixNote",
                       "Apply fix opens the setting this check reads — nothing is written from here. Re-run the checks once you have changed it."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(.bottom, 6)
    }

    private func failingCheckCard(_ item: PlistAggregator.ComplianceItem) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.error)

                Text(checkSentence(item))
                    .font(.system(size: 15, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 12)

                if item.isCritical {
                    criticalTag
                }
            }

            if let meta = checkMeta(item) {
                Text(meta)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Buttons beside the columns when they fit, on their own line when a translation
            // makes them too wide.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 26) {
                    metaColumns(item)
                    Spacer(minLength: 8)
                    remediationButtons(item)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 26) {
                        metaColumns(item)
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        remediationButtons(item)
                    }
                }
            }

            if openFailed == item.id {
                Text(l("ui.complianceApplyFixUnavailable",
                       "That setting could not be opened on this version of macOS. The remediation text has the steps."))
                    .font(.system(size: 11))
                    .foregroundStyle(palette.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(palette.error.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(palette.error.opacity(0.25), lineWidth: 1)
        )
    }

    /// Expected, found and last passed, each omitted when the plist did not supply it.
    @ViewBuilder
    private func metaColumns(_ item: PlistAggregator.ComplianceItem) -> some View {
        if let expected = item.expected {
            metaColumn(l("ui.complianceExpected", "expected"), expected, tint: .primary)
        }
        if let found = item.found {
            metaColumn(l("ui.complianceFound", "found"), found, tint: palette.error)
        }
        if let lastPassed = item.lastPassed {
            // Day and month only; the question is how long it has been failing.
            metaColumn(l("ui.complianceLastPassed", "last passed"),
                       Self.dayMonth.string(from: lastPassed), tint: .primary)
        }
    }

    @ViewBuilder
    private func remediationButtons(_ item: PlistAggregator.ComplianceItem) -> some View {
        HStack(spacing: 8) {
            if let urlString = item.actionURL, let url = URL(string: urlString) {
                // Per-check `actionButtonText` wins; the `ui.*` key is the last fallback.
                Button(l10n("compliance.\(item.id).actionButtonText",
                            item.actionButtonText ?? l("ui.complianceApplyFix", "Apply fix"))) {
                    // `x-apple.systempreferences:` URLs have no handler on a macOS that moved
                    // the pane; the card must say so rather than look like a success.
                    if !NSWorkspace.shared.open(url) {
                        openFailed = item.id
                        writeLog("ComplianceAllDetailsSheet: no handler for actionURL \(urlString) (check \(item.id))",
                                 logLevel: .error)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .controlSize(.small)
            }

            // `remediation` is prose, not a shell line, so the label says "remediation".
            if let remediation = item.remediation, !remediation.isEmpty {
                Button(l("ui.complianceCopyRemediation", "Copy remediation")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        l10n("compliance.\(item.id).remediation", remediation), forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func passingCheckRow(_ item: PlistAggregator.ComplianceItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.success)

            VStack(alignment: .leading, spacing: 2) {
                Text(checkSentence(item))
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)

                if let meta = checkMeta(item) {
                    Text(meta)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            if let date = complianceService.lastRefresh {
                Text(l("ui.complianceChecked", "checked {time}",
                       ["time": Self.timeOnly.string(from: date)]))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer

    /// One refresh with its last-run timestamp, one dismissal.
    @ViewBuilder
    private var footerRow: some View {
        // Without a `rescanCommand` the button can only re-read the plist, so it says "Refresh".
        Button(action: {
            openFailed = nil
            complianceService.rescan()
        }) {
            Text(complianceService.canRescan
                 ? l("ui.complianceRerun", "Re-run checks")
                 : l("ui.complianceRefresh", "Refresh"))
                .font(.system(size: 13))
        }
        .buttonStyle(.bordered)
        .disabled(complianceService.isLoading)

        Text(l("ui.complianceLastRun", "last run {date}", ["date": lastRunFormatted]))
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)

        Spacer(minLength: 12)

        DetailSheetEscapeHint(text: l("ui.complianceEscHint", "Esc to close"))

        Button(l("ui.complianceDone", "Done")) { dismiss() }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
    }

    // MARK: - Shared bits

    private var criticalTag: some View {
        Text(l("ui.complianceCriticalTag", "critical"))
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(palette.error)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(palette.error.opacity(0.1))
            .clipShape(Capsule())
    }

    /// The authored `explanation`, else `displayName`; the raw identifier is meta, not a title.
    private func checkSentence(_ item: PlistAggregator.ComplianceItem) -> String {
        let authored: String = {
            if let explanation = item.explanation, !explanation.isEmpty { return explanation }
            return item.displayName
        }()
        return l10n("compliance.\(item.id).explanation", authored)
    }

    /// Display only; `selectedCategory` still matches on the raw name.
    private func categoryLabel(_ rawName: String) -> String {
        l10n("compliance.category.\(rawName)", rawName)
    }

    /// One labelled value; monospaced because setting values are read by comparing them.
    private func metaColumn(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "audit_retention_configure · CIS 3.4" — for the person who has to grep for it.
    private func checkMeta(_ item: PlistAggregator.ComplianceItem) -> String? {
        let parts = [item.id, item.reference].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("Hm")
        return f
    }()

    /// "14 Jul", in the locale's order.
    private static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return f
    }()
}

// MARK: - Compliance Score Bar

/// Green passed, red critical failures, grey the rest.
private struct ComplianceScoreBar: View {
    let passed: Int
    let critical: Int
    let total: Int

    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                palette.success
                    .frame(width: segment(passed, of: geo.size.width))
                palette.error
                    .frame(width: segment(critical, of: geo.size.width))
                Color.secondary.opacity(0.18)
            }
        }
        .frame(height: 5)
        .clipShape(Capsule())
    }

    private func segment(_ count: Int, of full: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        return full * CGFloat(max(0, count)) / CGFloat(total)
    }
}
