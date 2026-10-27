//
//  StatCells.swift
//  dialog
//
//  Stat cells (9 min · 14 apps · 5 choices): a row of resolved figures with captions. Takes
//  strings only, so any screen can share one treatment; the Preset 5 completion screen draws it.
//

import SwiftUI

/// One fact: a big figure and the caption that says what it counts.
struct StatCell: Identifiable {
    let id = UUID()
    let value: String
    let label: String
}

/// A row of equal-width, equal-height stat cells. Values come from the config as written; the
/// only token resolved before display is `{itemCount}`, by the caller.
struct StatCellsRow: View {
    let cells: [StatCell]
    var scaleFactor: CGFloat = 1.0
    var alignment: HorizontalAlignment = .leading

    /// Cells per row; `nil` keeps a single row. Wrapping keeps captions whole on narrow windows.
    var columns: Int?

    var body: some View {
        if let columns, columns > 0, cells.count > columns {
            let rows = stride(from: 0, to: cells.count, by: columns).map {
                Array(cells[$0 ..< min($0 + columns, cells.count)])
            }
            VStack(spacing: 14 * scaleFactor) {
                ForEach(rows.indices, id: \.self) { r in
                    HStack(spacing: 14 * scaleFactor) {
                        ForEach(rows[r]) { cell in tile(cell) }
                        // A short final row keeps the same column widths as a full one.
                        if rows[r].count < columns {
                            ForEach(0 ..< (columns - rows[r].count), id: \.self) { _ in
                                Color.clear.frame(maxWidth: .infinity).frame(height: 84 * scaleFactor)
                            }
                        }
                    }
                }
            }
        } else {
            HStack(spacing: 14 * scaleFactor) {
                ForEach(cells) { cell in tile(cell) }
            }
        }
    }

    @ViewBuilder
    private func tile(_ cell: StatCell) -> some View {
        VStack(alignment: alignment, spacing: 4 * scaleFactor) {
            Text(cell.value)
                .font(.system(size: 26 * scaleFactor, weight: .bold))
                .tracking(-0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(cell.label)
                .font(.system(size: 13 * scaleFactor))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18 * scaleFactor)
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        // Fixed height: a two-line label must not make its tile taller than its neighbours.
        .frame(height: 84 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 12 * scaleFactor, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}
