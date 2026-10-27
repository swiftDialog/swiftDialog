//
//  BentoFillGrid.swift
//  dialog
//
//  A bento grid that fills the frame its host gives it. The host decides where the band starts
//  and ends; rows are sized `(height − gaps) / rows` so the whole grid lands inside, whatever
//  `bentoRowHeight` says. Nothing here knows about headers, footers, presets or window size.
//
import SwiftUI

/// The fill arithmetic, kept pure so it can be tested.
enum BentoFillM {
    /// Rows the cells occupy: the last row any cell reaches, never fewer than one.
    static func rows(_ cells: [InspectConfig.GuidanceContent.BentoCellConfig]) -> Int {
        max(1, cells.map { $0.row + ($0.rowSpan ?? 1) }.max() ?? 1)
    }

    /// One track's height when `rows` equal tracks share `available` with `gap` between them.
    /// ponytail: no readability minimum; a band too short for its rows crushes them rather than
    /// scrolling. Add a scroll fallback when a grid needs more rows than the band can hold.
    static func rowHeight(available: CGFloat, rows: Int, gap: CGFloat) -> CGFloat {
        let n = CGFloat(max(1, rows))
        return max(0, ((available - gap * (n - 1)) / n).rounded(.down))
    }

    /// Gap between the compact header's title row and the grid.
    static let headerToGrid: CGFloat = 12
}

/// A bento grid that fills the frame it is given.
struct BentoFillGrid<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    let cells: [InspectConfig.GuidanceContent.BentoCellConfig]
    let columns: Int
    let gap: CGFloat
    let accent: Color
    let iconBasePath: String?
    let tintColor: Color?
    var showSlots: Bool = false
    @ObservedObject var inspectState: Context

    var body: some View {
        GeometryReader { geo in
            BentoGridView(
                cells: cells,
                columns: columns,
                rowHeight: BentoFillM.rowHeight(available: geo.size.height,
                                                rows: BentoFillM.rows(cells),
                                                gap: gap),
                gap: gap,
                scaleFactor: 1.0,
                accentColor: accent,
                iconBasePath: iconBasePath,
                tintColor: tintColor,
                inspectState: inspectState,
                inlineExpansion: true,
                showSlots: showSlots,
                containerHeight: geo.size.height
            )
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }
}
