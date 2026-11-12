//
//  Preset1Components.swift
//  dialog
//
//  Preset 1's content components: the icon sidebar and the status-grouped item list.
//

import SwiftUI

// MARK: - Sidebar panel

struct DeploymentSidebarPanel: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @ObservedObject var iconCache: PresetIconCache
    let accent: Color

    var body: some View {
        VStack {
            Spacer()
                .frame(height: 20)

            IconView(
                image: iconCache.getMainIconPath(for: inspectState),
                overlay: iconCache.getOverlayIconPath(for: inspectState),
                defaultImage: "apps.iphone.badge.plus",
                defaultColour: "accent"
            )
            .frame(width: 220 * scaleFactor, height: 220 * scaleFactor)
            .onAppear { iconCache.cacheMainIcon(for: inspectState) }

            if !inspectState.items.isEmpty {
                ProgressBar(
                    state: inspectState,
                    width: 200 * scaleFactor,
                    labelSize: 13,
                    tint: accent
                )
                .padding(.top, 20 * scaleFactor)

                // The list's only motion: one spinner here, static dots on the rows.
                if !inspectState.downloadingItems.isEmpty {
                    HStack(spacing: 8) {
                        IndeterminateRing(size: 14, color: accent, lineWidth: 2)
                        Text(ChromeCopy.installing)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 10 * scaleFactor)
                }
            }

            Spacer()
        }
        .frame(width: 280 * scaleFactor)
        .padding(.vertical)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        // No opaque fill: the panel sits on the edge-to-edge PhaseBackdrop.
    }
}

// MARK: - Status-grouped item list

struct DeploymentItemList: View, InspectLayoutProtocol {
    /// The active section header ("Currently Installing"); drops either ellipsis spelling.
    static func activeSectionHeader(downloadingStatus: String?) -> String {
        let label = (downloadingStatus ?? "Installing…")
            .replacingOccurrences(of: "...", with: "")
            .replacingOccurrences(of: "…", with: "")
        return "Currently \(label)"
    }

    @ObservedObject var inspectState: InspectState
    @ObservedObject var iconCache: PresetIconCache
    let accent: Color
    let loc: PresetLocalization
    let onItemInfo: (InspectConfig.ItemConfig) -> Void

    @Environment(\.palette) private var palette

    /// One `ItemSetModel.build` per body pass, with an id-keyed lookup over the same rows.
    private struct RowSet {
        /// Sorted; the order `body` renders in.
        let rows: [ItemSetModel.Row]
        let byID: [String: ItemSetModel.Row]

        func row(for item: InspectConfig.ItemConfig) -> ItemSetModel.Row? { byID[item.id] }
    }

    /// Build once per pass: `ItemSetModel.build` schedules plist validation as a side effect, so a
    /// computed model read per row would multiply it on every state publish.
    private func rowSet(from state: InspectState) -> RowSet {
        let rows = ItemSetModel.build(from: state).rows
        // Keep the first copy on a duplicate id rather than trap.
        let byID = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return RowSet(rows: rows, byID: byID)
    }

    private var order: PresetCommonViews.ItemOrder {
        .init(itemSortOrder: inspectState.config?.itemSortOrder)
    }

    var body: some View {
        let rows = rowSet(from: inspectState)

        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                let sortedItems = rows.rows.map(\.item)
                ForEach(sortedItems, id: \.id) { item in
                    if shouldShowGroupSeparator(for: item, in: sortedItems, rows: rows) {
                        HStack {
                            Text(getStatusHeaderText(for: getItemStatusType(for: item, rows: rows)))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        // A gap above the header, a smaller one below hugs it to its rows.
                        .padding(.top, InspectConstants.spacingInner * scaleFactor)
                        .padding(.bottom, InspectConstants.spacingIntra * scaleFactor)
                    }

                    itemRow(for: item, rows: rows)
                        .id(item.id)
                }
            }
            .padding(.vertical, InspectConstants.spacingInner * scaleFactor)
        }
        // Rows that scroll up under the header fade out instead of being cut at a hard edge.
        .mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 10)
                Rectangle()
            }
        }
        .onChange(of: inspectState.downloadingItems) { _, _ in follow(proxy) }
        .onChange(of: inspectState.completedItems) { _, _ in follow(proxy) }
        .onChange(of: inspectState.failedItems) { _, _ in follow(proxy) }
        }
    }

    private func follow(_ proxy: ScrollViewProxy) {
        let rows = ItemSetModel.build(from: inspectState).rows.map { ($0.id, $0.status) }
        guard order.followsActive, let top = Self.followTop(rows) else { return }
        // Pinned to a row's top edge, so no row sits half under the header; a list that fits never moves.
        // After the rows and section headers have taken their new state, as Preset 2's slide: in the same
        // transaction the headers cross-fade over each other while the list moves.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(top, anchor: .top) }
        }
    }

    /// The row the list starts at while following: two finished rows above the installing one (else the
    /// next waiting one), as Preset 2's cards keep two done cards in view.
    static func followTop(_ rows: [(id: String, status: StepStatus)]) -> String? {
        guard let focus = InstallMath.focusRow(rows), let index = rows.firstIndex(where: { $0.id == focus })
        else { return nil }
        return rows[max(0, index - 2)].id
    }

    // MARK: Rows

    @ViewBuilder
    private func itemRow(for item: InspectConfig.ItemConfig, rows: RowSet) -> some View {
        HStack(spacing: 12 * scaleFactor) {
            IconView(image: iconCache.getItemIconPath(for: item, state: inspectState))
                .frame(width: 48 * scaleFactor, height: 48 * scaleFactor)
                .aspectRatio(1, contentMode: .fit)
                .clipped()

            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                HStack(spacing: 4) {
                    Text(loc.string("\(item.id).displayName", fallback: item.displayName) ?? item.displayName)
                        .font(.system(size: 16 * scaleFactor, weight: .medium))
                        .foregroundStyle(.primary)

                    if item.itemOverlay != nil {
                        ItemInfoButton(item: item, action: {
                            onItemInfo(item)
                        }, size: 18 * scaleFactor, tint: accent)
                    }
                }

                // Per-item description under the name (#663).
                if let description = loc.string("\(item.id).subtitle", fallback: item.subtitle),
                   !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ItemClaimAndIdentifier(claim: loc.string("\(item.id).claim", fallback: item.claim),
                                       identifier: item.displayIdentifier,
                                       scaleFactor: scaleFactor)

                Text(loc.itemStatus(for: item, baseStatus: getItemStatusWithValidation(for: item, rows: rows)))
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(getItemStatusColor(for: item, rows: rows))

                // Only when the script sent its own result text; otherwise the status line
                // above already shows the `failureMessage`.
                if getItemStatusType(for: item, rows: rows) == .failed,
                   inspectState.itemStatusText[item.id] != nil,
                   let fix = loc.string("\(item.id).failureMessage", fallback: item.failureMessage),
                   !fix.isEmpty {
                    Text(fix)
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let bundleInfo = inspectState.getBundleInfoForItem(item) {
                    Text(bundleInfo)
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundStyle(palette.textFaint)
                }
            }

            Spacer()

            statusIndicatorWithValidation(for: item)
        }
        .padding(.leading)
        // The status mark ends on the footer's rail, under the primary button.
        .padding(.trailing, FooterBandM.rail)
        .padding(.vertical, 8)
        .background(
            PresetCommonViews.resolveInstallStatus(for: item, state: inspectState) == .active
                ? accent.opacity(0.06)
                : Color.clear
        )
    }

    // MARK: Sorting & Status

    private func getItemStatusType(for item: InspectConfig.ItemConfig, rows: RowSet) -> StepStatus {
        rows.row(for: item)?.status ?? .pending
    }

    private func shouldShowGroupSeparator(for item: InspectConfig.ItemConfig, in sortedItems: [InspectConfig.ItemConfig], rows: RowSet) -> Bool {
        // Config order interleaves statuses, so a header per change would repeat.
        guard order != .guiIndex,
              let index = sortedItems.firstIndex(where: { $0.id == item.id }), index > 0 else { return false }

        let previousItem = sortedItems[index - 1]
        let currentStatus = getItemStatusType(for: item, rows: rows)
        let previousStatus = getItemStatusType(for: previousItem, rows: rows)

        return currentStatus != previousStatus
    }

    private func getStatusHeaderText(for statusType: StepStatus) -> String {
        let baseText: String
        switch statusType {
        case .completed:
            baseText = inspectState.config?.uiLabels?.sectionHeaderCompleted
                ?? inspectState.config?.uiLabels?.completedStatus
                ?? "Completed"
            return loc.string("sectionHeaderCompleted", fallback: baseText) ?? baseText
        case .active:
            if let header = inspectState.config?.uiLabels?.sectionHeaderPending {
                baseText = header
            } else {
                baseText = Self.activeSectionHeader(downloadingStatus: inspectState.config?.uiLabels?.downloadingStatus)
            }
            return loc.string("sectionHeaderDownloading", fallback: baseText) ?? baseText
        case .pending:
            baseText = inspectState.config?.uiLabels?.sectionHeaderPending ?? "Pending Installation"
            return loc.string("sectionHeaderPending", fallback: baseText) ?? baseText
        case .failed:
            baseText = inspectState.config?.uiLabels?.sectionHeaderFailed ?? "Installation Failed"
            return loc.string("sectionHeaderFailed", fallback: baseText) ?? baseText
        case .skipped:
            baseText = inspectState.config?.uiLabels?.sectionHeaderCompleted ?? "Skipped"
            return loc.string("sectionHeaderSkipped", fallback: baseText) ?? baseText
        }
    }

    // MARK: Validation Support

    private func hasValidationWarning(for item: InspectConfig.ItemConfig, rows: RowSet) -> Bool {
        rows.row(for: item)?.hasWarning ?? false
    }

    private func getItemStatusWithValidation(for item: InspectConfig.ItemConfig, rows: RowSet) -> String {
        rows.row(for: item)?.statusText
            ?? ItemSetModel.displayStatusText(for: item, state: inspectState)
    }

    private func getItemStatusColor(for item: InspectConfig.ItemConfig, rows: RowSet) -> Color {
        guard let row = rows.row(for: item) else { return .secondary }
        return ItemSetModel.itemStatusColor(row.status, hasWarning: row.hasWarning, palette: palette)
    }

    @ViewBuilder
    private func statusIndicatorWithValidation(for item: InspectConfig.ItemConfig) -> some View {
        StatusIndicatorCircle(
            status: PresetCommonViews.resolveInstallStatus(for: item, state: inspectState),
            hasWarning: PresetCommonViews.hasValidationWarning(for: item, state: inspectState),
            accent: accent,
            size: 20 * scaleFactor
        )
    }
}
