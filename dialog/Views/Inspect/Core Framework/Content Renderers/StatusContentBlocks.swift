//
//  StatusContentBlocks.swift
//  Dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Status-based content blocks: compliance-card, progress-bar
//

import SwiftUI

// MARK: - Compliance Card Block

/// Displays a compliance status card with pass/fail counts
/// Shows category name, icon, progress, and optional check details
/// Tap to drill down into detailed check list
struct ComplianceCardBlock: View {
    let block: InspectConfig.GuidanceContent
    let accentColor: Color
    let maxWidth: CGFloat
    var dynamicState: DynamicContentState?

    @State private var showingDetail = false

    // Use dynamic values if available, otherwise fall back to static block values
    private var passed: Int { dynamicState?.passed ?? block.passed ?? 0 }
    private var total: Int { dynamicState?.total ?? block.total ?? 0 }
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(passed) / Double(total)
    }

    private var categoryName: String {
        block.categoryName ?? block.content ?? "Category"
    }

    private var checkDetails: String? {
        dynamicState?.content ?? block.checkDetails
    }

    private var statusColor: Color {
        if percentage >= 1.0 {
            return .green
        } else if percentage >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row with icon, name, and counts
            HStack(spacing: 12) {
                // Category icon
                if let iconString = block.cardIcon {
                    Image(systemName: iconString)
                        .font(.system(size: 24))
                        .foregroundStyle(accentColor)
                        .frame(width: 36, height: 36)
                        .background(accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 2) {
                    // Category name (use categoryName, then content, then fallback)
                    Text(categoryName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    // Pass/fail counts
                    Text("\(passed) of \(total) passed")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Percentage badge
                Text("\(Int(percentage * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .clipShape(Capsule())

                // Drill-down indicator (only if we have details)
                if checkDetails != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor)
                        .frame(width: geometry.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)

            // Check details (if provided)
            if let details = block.checkDetails, !details.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(details.components(separatedBy: "\n"), id: \.self) { detail in
                        if !detail.isEmpty {
                            HStack(spacing: 8) {
                                // Determine icon based on content
                                if detail.contains("✓") || detail.contains("✅") {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.system(size: 12))
                                } else if detail.contains("✗") || detail.contains("❌") {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.system(size: 12))
                                } else {
                                    Image(systemName: "circle.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 6))
                                }

                                Text(detail.replacingOccurrences(of: "✓ ", with: "")
                                         .replacingOccurrences(of: "✗ ", with: "")
                                         .replacingOccurrences(of: "✅ ", with: "")
                                         .replacingOccurrences(of: "❌ ", with: ""))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if checkDetails != nil {
                showingDetail = true
            }
        }
        .sheet(isPresented: $showingDetail) {
            ComplianceDetailView(
                categoryName: categoryName,
                icon: block.cardIcon,
                passed: passed,
                total: total,
                checkDetails: checkDetails ?? "",
                accentColor: accentColor
            )
        }
    }
}

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

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(passed) / Double(total)
    }

    private var statusColor: Color {
        if percentage >= 1.0 {
            return .green
        } else if percentage >= 0.7 {
            return .orange
        } else {
            return .red
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
                            .foregroundStyle(.green)
                        Label("\(total - passed) failed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
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
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor)
                            .frame(width: geometry.size.width * percentage, height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(Int(percentage * 100))% compliant")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(statusColor)
                    Spacer()
                    Text("\(passed) of \(total) checks")
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
                        Text("Failed Checks (\(failedChecks.count))")
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
                        Text("Passed Checks (\(passedChecks.count))")
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

    private var cleanedText: String {
        check
            .replacingOccurrences(of: "✓ ", with: "")
            .replacingOccurrences(of: "✗ ", with: "")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isFailed ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isFailed ? .red : .green)
                .font(.system(size: 16))

            Text(cleanedText)
                .font(.system(size: 13))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(isFailed ? Color.red.opacity(0.05) : Color.clear)
    }
}

// MARK: - Compliance Dashboard Header Block

/// Wrapper view for ComplianceDashboardHeader to be used in intro steps
/// Displays overall compliance statistics with passed/failed counts and progress bar
struct ComplianceDashboardHeaderBlock: View {
    let block: InspectConfig.GuidanceContent
    let accentColor: Color
    let maxWidth: CGFloat
    var dynamicState: DynamicContentState?

    // Use dynamic values if available, otherwise fall back to static block values
    private var passed: Int { dynamicState?.passed ?? block.passed ?? 0 }
    private var total: Int { dynamicState?.total ?? block.total ?? 0 }
    private var failed: Int { total - passed }

    var body: some View {
        ComplianceDashboardHeader(
            title: block.label ?? "Compliance Status",
            subtitle: block.content,
            icon: block.icon,
            passed: passed,
            failed: failed,
            scaleFactor: 1.0,
            colorThresholds: InspectConfig.ColorThresholds.default
        )
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Progress Bar Block

/// Displays a progress bar (determinate or indeterminate)
struct ProgressBarBlock: View {
    let block: InspectConfig.GuidanceContent
    let accentColor: Color
    let maxWidth: CGFloat
    var dynamicState: DynamicContentState?

    @State private var animationOffset: CGFloat = -1.0

    private var isDeterminate: Bool {
        block.style == "determinate"
    }

    // Use dynamic progress if available, otherwise fall back to static block value
    private var progress: Double {
        min(max(dynamicState?.progress ?? block.progress ?? 0, 0), 1.0)
    }

    // Use dynamic label if available
    private var displayLabel: String? {
        dynamicState?.label ?? block.label
    }

    // Use dynamic content if available
    private var displayContent: String? {
        dynamicState?.content ?? block.content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label row
            if let label = displayLabel {
                HStack {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    if isDeterminate {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))

                    if isDeterminate {
                        // Determinate progress fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(accentColor)
                            .frame(width: geometry.size.width * progress)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    } else {
                        // Indeterminate animation
                        RoundedRectangle(cornerRadius: 4)
                            .fill(accentColor)
                            .frame(width: geometry.size.width * 0.3)
                            .offset(x: animationOffset * geometry.size.width)
                            .onAppear {
                                withAnimation(
                                    .easeInOut(duration: 1.2)
                                    .repeatForever(autoreverses: true)
                                ) {
                                    animationOffset = 0.7
                                }
                            }
                    }
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // Content/description
            if let content = displayContent {
                Text(content)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compliance Details Button Block

/// A button that opens a comprehensive compliance details sheet
/// Shows all categories, all checks, and recommendations
struct ComplianceDetailsButtonBlock: View {
    let block: InspectConfig.GuidanceContent
    let accentColor: Color
    let maxWidth: CGFloat
    var complianceService: ComplianceAggregatorService?

    @State private var showingDetails = false

    private var buttonText: String {
        block.label ?? "View All Details"
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
                    Text("Compliance data not available")
                        .font(.headline)
                    Text("The compliance service is not initialized.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 400, height: 300)
            }
        }
    }
}

// MARK: - Compliance All Details Sheet

/// Comprehensive details sheet showing all compliance data
/// Similar to Preset5's ComplianceDetailsPopoverView but as a full sheet
struct ComplianceAllDetailsSheet: View {
    @ObservedObject var complianceService: ComplianceAggregatorService
    let accentColor: Color

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String?
    @State private var showFailedOnly = false

    private var overallPercentage: Double {
        complianceService.overallScore
    }

    private var statusColor: Color {
        if overallPercentage >= 0.9 {
            return .green
        } else if overallPercentage >= 0.7 {
            return .orange
        }else {
            return .red
        }
    }

    private var lastCheckFormatted: String {
        guard let date = complianceService.lastRefresh else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Overall progress
            overallProgressView

            Divider()

            // Category tabs / filter
            filterBar

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedCategory == nil {
                        // Show all categories overview
                        allCategoriesView
                    } else {
                        // Show selected category details
                        categoryDetailView
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            footerView
        }
        .frame(width: 600, height: 700)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Compliance Details")
                    .font(.system(size: 20, weight: .semibold))

                Text("Last Check: \(lastCheckFormatted)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Overall status badge
            HStack(spacing: 8) {
                Text("\(Int(overallPercentage * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)

                Text("Compliant")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(statusColor.opacity(0.1))
            .clipShape(Capsule())

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Overall Progress

    private var overallProgressView: some View {
        VStack(spacing: 12) {
            // Stats row
            HStack(spacing: 24) {
                // Total
                VStack(spacing: 2) {
                    Text("\(complianceService.totalChecks)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Total Checks")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                // Passed
                VStack(spacing: 2) {
                    Text("\(complianceService.totalPassed)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    Text("Passed")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                // Failed
                VStack(spacing: 2) {
                    Text("\(complianceService.totalFailed)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                    Text("Failed")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Critical failures warning
                if complianceService.hasCriticalFailures {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("\(complianceService.criticalFailures.count) Critical")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor)
                        .frame(width: geometry.size.width * overallPercentage, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(statusColor.opacity(0.03))
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 12) {
            // Category selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // All categories button
                    Button(action: { selectedCategory = nil }) {
                        Text("All Categories")
                            .font(.system(size: 12, weight: selectedCategory == nil ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedCategory == nil ? accentColor.opacity(0.15) : Color.clear)
                            .foregroundStyle(selectedCategory == nil ? accentColor : .secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    ForEach(complianceService.categories, id: \.name) { category in
                        Button(action: { selectedCategory = category.name }) {
                            HStack(spacing: 4) {
                                Text(category.name)
                                    .font(.system(size: 12, weight: selectedCategory == category.name ? .semibold : .regular))
                                Text("(\(category.passed)/\(category.total))")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedCategory == category.name ? accentColor.opacity(0.15) : Color.clear)
                            .foregroundStyle(selectedCategory == category.name ? accentColor : .primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            // Show failed only toggle
            Toggle(isOn: $showFailedOnly) {
                Text("Failed only")
                    .font(.system(size: 12))
            }
            .toggleStyle(.checkbox)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - All Categories View

    private var allCategoriesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(complianceService.categories, id: \.name) { category in
                CategorySummaryCard(
                    category: category,
                    accentColor: accentColor,
                    showFailedOnly: showFailedOnly,
                    onSelect: { selectedCategory = category.name }
                )
            }
        }
    }

    // MARK: - Category Detail View

    @ViewBuilder
    private var categoryDetailView: some View {
        if let categoryName = selectedCategory,
           let category = complianceService.category(named: categoryName) {
            VStack(alignment: .leading, spacing: 16) {
                // Category header
                HStack {
                    Button(action: { selectedCategory = nil }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                // Category info
                HStack(spacing: 16) {
                    Image(systemName: category.icon)
                        .font(.system(size: 32))
                        .foregroundStyle(accentColor)
                        .frame(width: 48, height: 48)
                        .background(accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.system(size: 18, weight: .semibold))

                        HStack(spacing: 16) {
                            Label("\(category.passed) passed", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Label("\(category.total - category.passed) failed", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .font(.system(size: 13))
                    }

                    Spacer()

                    // Category percentage
                    Text("\(Int(category.score * 100))%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(category.score >= 0.9 ? .green : category.score >= 0.7 ? .orange : .red)
                }

                Divider()

                // Items list
                let items = showFailedOnly ? category.items.filter { !$0.finding } : category.items
                let sortedItems = items.sorted { !$0.finding && $1.finding }  // Failed first

                ForEach(sortedItems, id: \.id) { item in
                    ComplianceItemRow(item: item, accentColor: accentColor)
                }
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            // Refresh button
            Button(action: { complianceService.refresh() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 13))
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(20)
    }
}

// MARK: - Category Summary Card

/// Card showing category overview with option to expand
private struct CategorySummaryCard: View {
    let category: PlistAggregator.ComplianceCategory
    let accentColor: Color
    let showFailedOnly: Bool
    let onSelect: () -> Void

    private var statusColor: Color {
        if category.score >= 0.9 {
            return .green
        } else if category.score >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: category.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(accentColor)
                    .frame(width: 32, height: 32)
                    .background(accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.system(size: 15, weight: .semibold))

                    Text("\(category.passed) of \(category.total) passed")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Score
                Text("\(Int(category.score * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())

                // Expand button
                Button(action: onSelect) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(statusColor)
                        .frame(width: geometry.size.width * category.score, height: 6)
                }
            }
            .frame(height: 6)

            // Show first few failing items if any
            let failingItems = category.items.filter { !$0.finding }
            if !failingItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    let previewItems = Array(failingItems.prefix(3))
                    ForEach(previewItems, id: \.id) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 10))
                            Text(formatCheckName(item.id))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    if failingItems.count > 3 {
                        Text("+ \(failingItems.count - 3) more...")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 18)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private func formatCheckName(_ id: String) -> String {
        id.replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

// MARK: - Compliance Item Row

/// Row showing individual compliance item with status
private struct ComplianceItemRow: View {
    let item: PlistAggregator.ComplianceItem
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: item.finding ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(item.finding ? .green : .red)
                .font(.system(size: 16))

            // Item details
            VStack(alignment: .leading, spacing: 2) {
                Text(formatCheckName(item.id))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Text(item.id)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Critical badge
            if item.isCritical {
                Text("Critical")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(item.finding ? Color.clear : Color.red.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatCheckName(_ id: String) -> String {
        // Remove common prefixes
        var cleanId = id
        let prefixes = ["audit_", "os_", "pwpolicy_", "system_settings_", "system_", "auth_", "icloud_"]
        for prefix in prefixes where cleanId.hasPrefix(prefix) {
            cleanId = String(cleanId.dropFirst(prefix.count))
            break
        }
        return cleanId.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
