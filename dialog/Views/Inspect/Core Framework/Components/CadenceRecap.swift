//
//  CadenceRecap.swift
//  dialog
//
//  The cadence recap tiles and the view that lays them out.
//

import SwiftUI

/// The finished run as provisioning rows under a measured summary strip.
/// A timed-out entry renders queued, not ticked: it proved nothing.
struct CadenceRecapView: View {
    let model: CardRecapModel

    @Environment(\.palette) private var palette

    /// Recap width: it sits in a card, so it uses the summary strip's width, not the shell column.
    private static let recapWidth: CGFloat = 560

    private var rows: [ProvisioningRowModel] {
        model.tiles.enumerated().map { index, tile in
            let proven = !model.timedOut.contains(index)
            return ProvisioningRowModel(
                id: tile.id,
                name: tile.label,
                detail: tile.subtitle,
                detailIsMachine: false,
                mark: proven ? .done : .queued,
                trailing: .state(proven ? "Confirmed" : "Didn't finish", failed: false))
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ProvisioningRowStack(rows: rows, width: Self.recapWidth, accent: model.accent)
            HStack(spacing: 8) {
                Image(systemName: model.clean ? "checkmark.circle.fill" : "clock")
                    .foregroundStyle(model.clean ? palette.success : Color.secondary)
                Text(model.summary.joined(separator: " · "))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    // Keep the strip on one line; the closer's height depends on it.
                    .lineLimit(1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: Self.recapWidth)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05)))
        }
    }
}


// MARK: - Cadence recap (`showCadenceRecap`)

/// One entry of a finished run. The recap draws with the same row vocabulary as the cadence step.
struct CadenceRecapTile: Identifiable {
    let id: String
    let label: String
    let subtitle: String?
    let imagePath: String?
    let sfSymbol: String?
}
