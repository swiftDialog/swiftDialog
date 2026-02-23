//
//  TableContentBlocks.swift
//  Dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Table-based content blocks: feature-table, comparison-table
//

import SwiftUI

// MARK: - Feature Table Block

/// Displays a feature comparison matrix with columns and checkmarks
/// Example: Compare features across different products/options
struct FeatureTableBlock: View {
    let block: InspectConfig.GuidanceContent
    let accentColor: Color
    let maxWidth: CGFloat

    var body: some View {
        let columns = block.columns ?? []
        let rows = block.rows ?? []

        if !columns.isEmpty && !rows.isEmpty {
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    // Feature column header (empty or label)
                    Text("Feature")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                    // Column headers
                    ForEach(columns.indices, id: \.self) { index in
                        VStack(spacing: 4) {
                            if let icon = columns[index].icon {
                                Image(systemName: icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(accentColor)
                            }
                            Text(columns[index].label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .frame(width: 80)
                        .padding(.vertical, 10)
                    }
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))

                Divider()

                // Data rows
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 0) {
                        // Feature name
                        Text(rows[rowIndex].feature)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)

                        // Value cells
                        ForEach(rows[rowIndex].values.indices, id: \.self) { colIndex in
                            let hasFeature = colIndex < rows[rowIndex].values.count ? rows[rowIndex].values[colIndex] : false
                            Image(systemName: hasFeature ? "checkmark.circle.fill" : "xmark.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(hasFeature ? .green : .secondary.opacity(0.5))
                                .frame(width: 80)
                                .padding(.vertical, 8)
                        }
                    }
                    .background(rowIndex % 2 == 0 ? Color.clear : Color(NSColor.controlBackgroundColor).opacity(0.3))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Comparison Table Block

/// Displays a side-by-side comparison of expected vs actual values
/// Supports stacked and columns layout styles
struct ComparisonTableBlock: View {
    let block: InspectConfig.GuidanceContent
    let accentColor: Color
    let maxWidth: CGFloat
    var dynamicState: DynamicContentState?

    // Use dynamic actual value if available
    private var actualValue: String? {
        dynamicState?.actual ?? block.actual
    }

    private var isMatch: Bool {
        block.expected == actualValue
    }

    private var expectedColor: Color {
        if let hex = block.expectedColor {
            return Color(hex: hex)
        }
        return isMatch ? .green : .secondary
    }

    private var actualColor: Color {
        if let hex = block.actualColor {
            return Color(hex: hex)
        }
        return isMatch ? .green : .orange
    }

    var body: some View {
        let style = block.comparisonStyle ?? "stacked"
        let highlightCells = block.highlightCells ?? false

        VStack(spacing: 0) {
            // Label header if present
            if let label = block.label {
                HStack {
                    if let icon = block.icon {
                        Image(systemName: icon)
                            .foregroundStyle(accentColor)
                            .font(.system(size: 14))
                    }
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()

                    // Match indicator
                    Image(systemName: isMatch ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(isMatch ? .green : .orange)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            }

            if style == "columns" {
                // Side-by-side columns layout
                columnsLayout(highlightCells: highlightCells)
            } else {
                // Stacked layout (default)
                stackedLayout(highlightCells: highlightCells)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func columnsLayout(highlightCells: Bool) -> some View {
        HStack(spacing: 0) {
            // Expected column
            VStack(spacing: 4) {
                Text(block.expectedLabel ?? "Expected")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                if let icon = block.expectedIcon {
                    Image(systemName: icon)
                        .font(.system(size: highlightCells ? 24 : 18))
                        .foregroundStyle(expectedColor)
                }

                if let expected = block.expected {
                    Text(expected)
                        .font(.system(size: highlightCells ? 15 : 13, weight: highlightCells ? .semibold : .regular))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(expectedColor.opacity(highlightCells ? 0.15 : 0.08))

            Divider()

            // Actual column
            VStack(spacing: 4) {
                Text(block.actualLabel ?? "Actual")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                if let icon = block.actualIcon {
                    Image(systemName: icon)
                        .font(.system(size: highlightCells ? 24 : 18))
                        .foregroundStyle(actualColor)
                }

                if let actual = actualValue {
                    Text(actual)
                        .font(.system(size: highlightCells ? 15 : 13, weight: highlightCells ? .semibold : .regular))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(actualColor.opacity(highlightCells ? 0.15 : 0.08))
        }
    }

    @ViewBuilder
    private func stackedLayout(highlightCells: Bool) -> some View {
        VStack(spacing: 0) {
            // Expected row
            HStack {
                Text(block.expectedLabel ?? "Expected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)

                if let icon = block.expectedIcon {
                    Image(systemName: icon)
                        .foregroundStyle(expectedColor)
                }

                Text(block.expected ?? "-")
                    .font(.system(size: 13, weight: highlightCells ? .semibold : .regular))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Actual row
            HStack {
                Text(block.actualLabel ?? "Actual")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)

                if let icon = block.actualIcon {
                    Image(systemName: icon)
                        .foregroundStyle(actualColor)
                }

                Text(actualValue ?? "-")
                    .font(.system(size: 13, weight: highlightCells ? .semibold : .regular))
                    .foregroundStyle(actualColor)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
