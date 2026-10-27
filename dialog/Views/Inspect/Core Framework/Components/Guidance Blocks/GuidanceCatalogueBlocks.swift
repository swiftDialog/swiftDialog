//
//  GuidanceCatalogueBlocks.swift
//  dialog
//
//  The software catalogue: the pure row rules, the `bundle-list` / `bundle-detail` blocks and the
//  rows they are built from. Blocks draw payloads the software arm has already resolved (a row has
//  five states; a block alone can see three). The handoff list lives in `SoftwareBundleViews.swift`.
//

import Foundation
import SwiftUI

/// What a software row offers, decided by `SoftwareRowRule` from status and identity alone.
struct SoftwareRowAction {
    var label: String?
    var action: String?
    var url: String?
    var requestId: String?
}

/// The status → action mapping for one catalogue row. Pure: the arm resolves identity and
/// status, then asks this rule.
enum SoftwareRowRule {
    static func action(for status: StepStatus, openURL: String?, appBundleId: String?, firstPath: String?) -> SoftwareRowAction {
        var result = SoftwareRowAction()
        switch status {
        case .completed:
            result.label = "Open"
            if let openURL, !openURL.isEmpty {
                result.action = "url"
                result.url = openURL
            } else {
                // `app`, not a bare scheme: apps may refuse a custom-scheme deeplink.
                result.action = "app"
                result.url = appBundleId ?? firstPath
            }
            // No identity to launch, no button.
            if result.url == nil { result.label = nil }
        case .active:
            result.label = "Cancel"
            result.action = "request"
            result.requestId = "cancel-item"
        case .failed:
            result.label = "Retry"
            result.action = "request"
            result.requestId = "retry-item"
        case .pending:
            result.label = "Install"
            result.action = "request"
            result.requestId = "install-item"
        case .skipped:
            // Offering "Install" would invite undoing a decision the flow already recorded.
            result.label = nil
        }
        return result
    }
}

/// Resolves an authored `BundleAction` to the verb its row carries: an action with no explicit
/// verb means "request". Resolved at fold time so an authored default-request action is never
/// mistaken for no action (which `BundleRow` routes to the detail screen). A handoff's default
/// verb is "app", a separate rule.
enum SoftwareBundleActionRule {
    static func resolvedVerb(for action: InspectConfig.SoftwareBundle.BundleAction?) -> String? {
        action.map { $0.action ?? "request" }
    }
}

// MARK: - Roll-up

/// What a bundle's members add up to, counted from `[StepStatus]` and never stored. The fold
/// counts live members; `BundleRow` counts a payload's resolved icon strip with the same tally.
struct BundleTally {
    let installed: Int
    let installing: Int
    let failed: Int
    let total: Int

    var missing: Int { max(0, total - installed - installing - failed) }
    var complete: Bool { total > 0 && installed == total }

    init(statuses: [StepStatus]) {
        total = statuses.count
        installed = statuses.filter { $0 == .completed }.count
        failed = statuses.filter { if case .failed = $0 { return true } else { return false } }.count
        installing = statuses.filter {
            switch $0 { case .active: return true; default: return false }
        }.count
    }

    /// The bundle's state pill.
    var pill: String {
        if failed > 0 { return "\(failed) failed" }
        if installing > 0 { return "Installing · \(installed + installing) of \(total)" }
        if complete { return "Installed" }
        if installed == 0 { return "Not installed" }
        return "\(installed) of \(total) installed"
    }

    /// Resolves `{missing}` / `{installed}` / `{total}` in an authored action label.
    func resolve(_ label: String) -> String {
        label.replacingOccurrences(of: "{missing}", with: "\(missing)")
             .replacingOccurrences(of: "{installed}", with: "\(installed)")
             .replacingOccurrences(of: "{total}", with: "\(total)")
    }

    /// The label when the config does not author one; it varies by state so the action says
    /// what it will do.
    var defaultActionLabel: String {
        if failed > 0 { return "Retry \(failed)" }
        if installing > 0 { return "Installing…" }
        // A complete bundle has nothing to install; the only honest offer is to show what is in it.
        if complete { return "Details" }
        if installed > 0 { return "Complete" }
        return "Install"
    }
}

// MARK: - Command block

/// The command that will run, shown verbatim and selectable.
struct CommandBlock: View {
    let command: String
    let note: String?
    var scaleFactor: CGFloat = 1.0
    var caption: String?

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            if let caption {
                Text(caption)
                    .font(.system(size: 11 * scaleFactor, weight: .medium))
                    .foregroundStyle(palette.textMuted)
            }
            Text(command)
                .font(.system(size: 12 * scaleFactor, design: .monospaced))
                .foregroundStyle(palette.text)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12 * scaleFactor)
                .padding(.vertical, 9 * scaleFactor)
                .background(
                    RoundedRectangle(cornerRadius: 8 * scaleFactor, style: .continuous)
                        .fill(palette.surfaceRaised)
                )
            if let note {
                Text(note)
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(palette.textMuted)
            }
        }
    }
}

// MARK: - The software sort and row form

/// The catalogue's ordering rules: action-needed first, settled last; a fully installed list is
/// alphabetical; a not-ready launch states its state in words, not only in opacity.
enum SoftwareSortRule {
    /// Settled when every member is installed.
    static func isSettled(_ row: InspectConfig.GuidanceContent.BundleRowPayload) -> Bool {
        BundleTally.of(row).complete
    }

    /// Action-needed first, settled last, stable within each group.
    static func bundleOrder(_ rows: [InspectConfig.GuidanceContent.BundleRowPayload])
    -> [InspectConfig.GuidanceContent.BundleRowPayload] {
        rows.filter { !isSettled($0) } + rows.filter { isSettled($0) }
    }

    /// Action-needed first, then installed, each group alphabetical.
    static func detailOrder(_ rows: [InspectConfig.GuidanceContent.DetailRowPayload])
    -> [InspectConfig.GuidanceContent.DetailRowPayload] {
        func installed(_ r: InspectConfig.GuidanceContent.DetailRowPayload) -> Bool {
            if case .some(.completed) = r.status.flatMap(StepStatus.init(rawValue:)) { return true }
            return false
        }
        let byName: (InspectConfig.GuidanceContent.DetailRowPayload,
                     InspectConfig.GuidanceContent.DetailRowPayload) -> Bool = {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        return rows.filter { !installed($0) }.sorted(by: byName)
             + rows.filter { installed($0) }.sorted(by: byName)
    }

    /// A launch is unavailable while its item is still pending or installing.
    static func isUnavailable(_ status: StepStatus?) -> Bool {
        switch status {
        case .some(.pending), .some(.active): return true
        default: return false
        }
    }

    /// Shortcuts (handoffs with a `detail`) first, then launches, ready before unavailable, each
    /// group in authored order.
    static func handoffOrder(_ handoffs: [InspectConfig.SoftwareHandoff],
                             unavailable: (InspectConfig.SoftwareHandoff) -> Bool)
    -> (shortcuts: [InspectConfig.SoftwareHandoff], launches: [InspectConfig.SoftwareHandoff]) {
        let shortcuts = handoffs.filter { $0.detail != nil }
        let launches = handoffs.filter { $0.detail == nil }
        return (shortcuts, launches.filter { !unavailable($0) } + launches.filter { unavailable($0) })
    }

    /// The launch's state in words, merged with the authored note.
    static func launchNote(authored: String?, status: StepStatus?) -> String? {
        let word: String?
        switch status {
        case .some(.active): word = "installing"
        case .some(.pending): word = "not installed yet"
        default: word = nil
        }
        switch (word, authored) {
        case (nil, let note): return note
        case (let w?, nil): return w
        case (let w?, let note?): return note.lowercased().hasPrefix(w) ? note : "\(w) · \(note)"
        }
    }
}

/// The bundle list's row geometry.
enum SoftwareRowM {
    static let bundleRowHeight: CGFloat = 78
    /// The shortest a row may go before the list scrolls instead.
    static let bundleRowMin: CGFloat = 60
    static let rowPadH: CGFloat = 20
    static let rowGap: CGFloat = 10
    static let ruleAlpha: Double = 0.07
    /// The divider's height plus 2pt of padding either side.
    static let dividerBlock: CGFloat = 5

    /// Rows shrink from the 78 ceiling to the 60 floor to fit the band the arm measured; only
    /// past the floor does the list scroll. nil `available` keeps the ceiling.
    static func fittedRowHeight(available: CGFloat?, rows: Int, hasDivider: Bool) -> CGFloat {
        guard let available, available > 0, rows > 0 else { return bundleRowHeight }
        let fixed = rowGap * CGFloat(rows - 1) + (hasDivider ? dividerBlock + rowGap : 0)
        let fit = ((available - fixed) / CGFloat(rows)).rounded(.down)
        return min(bundleRowHeight, max(bundleRowMin, fit))
    }
}

/// The band height the software arm measured, so a block inside a ScrollView can still fit its
/// rows to the screen. nil where the arm did not measure.
private struct SoftwareBandHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}
extension EnvironmentValues {
    var softwareBandHeight: CGFloat? {
        get { self[SoftwareBandHeightKey.self] }
        set { self[SoftwareBandHeightKey.self] = newValue }
    }
}

extension BundleTally {
    /// A bundle row's tally: from its member icons when present, else from its counts.
    static func of(_ row: InspectConfig.GuidanceContent.BundleRowPayload) -> BundleTally {
        if let icons = row.icons, !icons.isEmpty {
            return BundleTally(statuses: icons.map {
                $0.status.flatMap(StepStatus.init(rawValue:)) ?? .pending
            })
        }
        let total = row.totalCount ?? 0
        let installed = min(row.installedCount ?? 0, total)
        return BundleTally(statuses: Array(repeating: .completed, count: installed)
            + Array(repeating: .pending, count: total - installed))
    }
}

// MARK: - Bundle row (block form)

/// One bundle as an icon strip plus its state pill and action; `bundle-list`'s row.
struct BundleRow: View {
    let bundle: InspectConfig.GuidanceContent.BundleRowPayload
    let accent: Color
    var scaleFactor: CGFloat = 1.0
    var tileSize: CGFloat = 42
    var iconBasePath: String?
    /// See `SoftwareRowM.fittedRowHeight`.
    var rowHeight: CGFloat = SoftwareRowM.bundleRowHeight
    var onAction: (() -> Void)?
    var onOpenDetail: (() -> Void)?

    private var tally: BundleTally { BundleTally.of(bundle) }

    /// A settled bundle shows no size and no button; tapping still opens its detail.
    private var settled: Bool { tally.complete }

    /// Every member on every row, settled rows included.
    private var stripIcons: [InspectConfig.GuidanceContent.BundleMemberIcon] { bundle.icons ?? [] }

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .center, spacing: 14 * scaleFactor) {
            if !stripIcons.isEmpty {
                HStack(spacing: 7 * scaleFactor) {
                    ForEach(Array(stripIcons.enumerated()), id: \.offset) { _, icon in
                        AppIconView(iconPath: icon.icon, bundleId: icon.appBundleId,
                                    paths: icon.paths ?? [], size: tileSize * scaleFactor,
                                    status: icon.status.flatMap(StepStatus.init(rawValue:)) ?? .pending,
                                    accent: accent, basePath: iconBasePath)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 3 * scaleFactor) {
                HStack(spacing: 9 * scaleFactor) {
                    Text(bundle.title)
                        .font(.system(size: 15 * scaleFactor, weight: .semibold))
                        .foregroundStyle(palette.text)
                    StatePill(text: tally.pill, tally: tally, accent: accent, scaleFactor: scaleFactor)
                }
                if let summary = bundle.summary {
                    Text(summary)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8 * scaleFactor)
            if !settled {
                if let size = bundle.size {
                    Text(size)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(palette.textMuted)
                }
                if let label = bundle.actionLabel {
                    Button(label) {
                        if bundle.action == nil && bundle.hasDetail { onOpenDetail?() } else { onAction?() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(tally.installing > 0)
                }
            }
        }
        .padding(.horizontal, SoftwareRowM.rowPadH * scaleFactor)
        // One row height whatever the row carries.
        .frame(height: rowHeight * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 12 * scaleFactor, style: .continuous)
                .fill(palette.text.opacity(0.035))
        )
        .contentShape(Rectangle())
        .onTapGesture { if bundle.hasDetail { onOpenDetail?() } }
    }
}

struct StatePill: View {
    let text: String
    let tally: BundleTally
    let accent: Color
    var scaleFactor: CGFloat = 1.0
    @Environment(\.palette) private var palette

    private var tint: Color {
        if tally.failed > 0 { return palette.error }
        if tally.installing > 0 { return accent }
        if tally.complete { return palette.success }
        return .secondary
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11 * scaleFactor, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 9 * scaleFactor)
            .padding(.vertical, 4 * scaleFactor)
            .background(Capsule().fill(tint.opacity(0.12)))
    }
}

// MARK: - Per-app row (block form)

/// One app inside a bundle; present, installing, missing and failed are four different rows.
struct AppDetailRow: View {
    let member: InspectConfig.GuidanceContent.DetailRowPayload
    let accent: Color
    var scaleFactor: CGFloat = 1.0
    var iconSize: CGFloat = 38
    var iconBasePath: String?
    /// Off when every row is installed: the icon column then has no state to show.
    var showsIcon: Bool = true
    var onAction: (() -> Void)?
    @Environment(\.palette) private var palette

    private var resolvedStatus: StepStatus {
        member.status.flatMap(StepStatus.init(rawValue:)) ?? .pending
    }

    private var statusText: String? {
        switch resolvedStatus {
        case .failed: return "Download interrupted"
        case .active: return "Downloading"
        case .completed: return member.detail
        case .pending: return member.detail
        case .skipped: return member.detail
        }
    }

    var body: some View {
        HStack(spacing: 12 * scaleFactor) {
            if showsIcon {
                AppIconView(iconPath: member.icon, bundleId: member.appBundleId, paths: member.paths ?? [],
                            size: iconSize * scaleFactor, status: resolvedStatus,
                            accent: accent, basePath: iconBasePath)
            }

            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                Text(member.displayName)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(palette.text)
                if let statusText, !statusText.isEmpty {
                    Text(statusText)
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundStyle(isFailed ? palette.error : .secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8 * scaleFactor)

            if let label = member.actionLabel {
                Button(label) { onAction?() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 8 * scaleFactor)
    }

    private var isFailed: Bool {
        if case .failed = resolvedStatus { return true }
        return false
    }
}

// MARK: - bundle-list as a content block

/// `type: "bundle-list"`: the software step's `layout: "bundles"` as a block. Rows arrive
/// resolved; actions go through `handleRowAction`.
struct GuidanceBundleListBlock<Context: UserInputContext & ObservableObject>: View {
    let bundles: [InspectConfig.GuidanceContent.BundleRowPayload]
    let accent: Color
    let scaleFactor: CGFloat
    var iconBasePath: String?
    @ObservedObject var inspectState: Context
    var onOpenDetail: (String) -> Void = { _ in }
    @Environment(\.palette) private var palette
    @Environment(\.softwareBandHeight) private var bandHeight

    var body: some View {
        let ordered = SoftwareSortRule.bundleOrder(bundles)
        let firstSettled = ordered.firstIndex(where: SoftwareSortRule.isSettled)
        let hasDivider = (firstSettled ?? 0) > 0
        let rowHeight = SoftwareRowM.fittedRowHeight(available: bandHeight.map { $0 / scaleFactor },
                                                     rows: ordered.count, hasDivider: hasDivider)
        VStack(spacing: SoftwareRowM.rowGap * scaleFactor) {
            ForEach(Array(ordered.enumerated()), id: \.element.bundleId) { index, bundle in
                if let firstSettled, index == firstSettled, index > 0 {
                    Rectangle()
                        .fill(palette.text.opacity(SoftwareRowM.ruleAlpha))
                        .frame(height: 1)
                        .padding(.vertical, 2 * scaleFactor)
                }
                BundleRow(
                    bundle: bundle,
                    accent: accent,
                    scaleFactor: scaleFactor,
                    iconBasePath: iconBasePath,
                    rowHeight: rowHeight,
                    onAction: {
                        handleRowAction(action: bundle.action, url: bundle.actionURL,
                                        requestId: bundle.requestId, label: bundle.actionLabel ?? "",
                                        itemId: bundle.bundleId, inspectState: inspectState)
                    },
                    onOpenDetail: { onOpenDetail(bundle.bundleId) }
                )
            }
        }
    }
}

// MARK: - bundle-detail as a content block

/// `type: "bundle-detail"`: one bundle's apps as the software step's `layout: "detail"`, plus
/// the command that installs what is missing. The command belongs to the bundle, so it rides on
/// the block under its own keys (`bundleCommand` / `bundleCommandNote`), not on a row.
struct GuidanceBundleDetailBlock<Context: UserInputContext & ObservableObject>: View {
    let rows: [InspectConfig.GuidanceContent.DetailRowPayload]
    let accent: Color
    let scaleFactor: CGFloat
    var iconBasePath: String?
    @ObservedObject var inspectState: Context
    var command: String?
    var commandNote: String?

    /// Counted from the rows' resolved statuses; the failure line needs the failed count.
    private var tally: BundleTally {
        BundleTally(statuses: rows.map { $0.status.flatMap(StepStatus.init(rawValue:)) ?? .pending })
    }

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * scaleFactor) {
            VStack(spacing: 0) {
                ForEach(SoftwareSortRule.detailOrder(rows), id: \.itemId) { row in
                    AppDetailRow(
                        member: row,
                        accent: accent,
                        scaleFactor: scaleFactor,
                        iconBasePath: iconBasePath,
                        showsIcon: !tally.complete,
                        onAction: {
                            handleRowAction(action: row.action, url: row.actionURL,
                                            requestId: row.requestId, label: row.actionLabel ?? "",
                                            itemId: row.itemId, inspectState: inspectState)
                        }
                    )
                }
            }

            if let command {
                CommandBlock(command: command, note: commandNote, scaleFactor: scaleFactor,
                             caption: "Runs on your Mac")
            }

            if tally.failed > 0 {
                Text("\(tally.failed) failed · retry does not re-download the others")
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundStyle(palette.textMuted)
            }
        }
    }
}

// MARK: - The catalogue fold

/// The software step's three layouts, folded into the blocks that draw them, alongside
/// `foldGrid` / `foldMedia`. Every row is resolved here before it reaches a block. Pure: a
/// member's status and whether a detail step exists arrive as closures.
extension CardStepBlocks {

    /// Which bundle a `detail` step is about: the one it names, else the first. The arm and the
    /// fold both read this.
    static func detailBundle(in bundles: [InspectConfig.SoftwareBundle], named bundleId: String?)
    -> InspectConfig.SoftwareBundle? {
        bundles.first { $0.bundleId == (bundleId ?? "") } ?? bundles.first
    }

    /// One bundle's members, resolved, in `itemIds` order. An id with no matching item is dropped
    /// with an error log rather than drawn as a blank tile.
    static func catalogueMembers(bundleId: String,
                                 itemIds: [String],
                                 items: [InspectConfig.ListItem],
                                 resolve: (InspectConfig.ListItem) -> SoftwareMember,
                                 log: (String) -> Void = { writeLog($0, logLevel: .error) })
    -> [SoftwareMember] {
        // A repeated item id is an authoring mistake, not a reason to trap.
        let byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return itemIds.compactMap { id in
            guard let item = byId[id] else {
                log("Preset5 software: bundle '\(bundleId)' names unknown item '\(id)'")
                return nil
            }
            return resolve(item)
        }
    }

    /// One `bundle-list` row from a bundle and its resolved members. A button appears unless
    /// there is no authored action, nothing left to install and no detail to open. The verb goes
    /// through `SoftwareBundleActionRule.resolvedVerb`, never the raw optional.
    static func catalogueBundleRow(for bundle: InspectConfig.SoftwareBundle,
                                   members: [SoftwareMember],
                                   hasDetail: Bool)
    -> InspectConfig.GuidanceContent.BundleRowPayload {
        let tally = BundleTally(statuses: members.map(\.status))
        let showButton = bundle.action != nil || !tally.complete || hasDetail
        return InspectConfig.GuidanceContent.BundleRowPayload(
            bundleId: bundle.bundleId,
            title: bundle.title,
            summary: bundle.summary,
            size: bundle.size,
            icons: members.map {
                InspectConfig.GuidanceContent.BundleMemberIcon(
                    icon: $0.icon, appBundleId: $0.bundleId, paths: $0.paths, status: $0.status.rawValue)
            },
            installedCount: tally.installed,
            totalCount: tally.total,
            hasDetail: hasDetail,
            actionLabel: showButton
                ? (bundle.action.map { tally.resolve($0.label) } ?? tally.defaultActionLabel)
                : nil,
            action: SoftwareBundleActionRule.resolvedVerb(for: bundle.action),
            actionURL: bundle.action?.url,
            requestId: bundle.action?.requestId)
    }

    /// One `bundle-detail` row from a resolved member.
    static func catalogueDetailRow(for member: SoftwareMember)
    -> InspectConfig.GuidanceContent.DetailRowPayload {
        InspectConfig.GuidanceContent.DetailRowPayload(
            itemId: member.id,
            displayName: member.name,
            icon: member.icon,
            appBundleId: member.bundleId,
            paths: member.paths,
            status: member.status.rawValue,
            detail: member.detail,
            actionLabel: member.actionLabel,
            action: member.action,
            actionURL: member.actionURL,
            requestId: member.requestId)
    }

    /// What a software step folds from: its bundles, the bundle a detail screen shows, its
    /// items and its handoffs.
    struct CatalogueSources {
        var bundles: [InspectConfig.SoftwareBundle] = []
        var detailBundle: InspectConfig.SoftwareBundle?
        var items: [InspectConfig.ListItem] = []
        var handoffs: [InspectConfig.SoftwareHandoff] = []
    }

    /// Appends the block this step's `layout` asks for: `bundle-list`, `bundle-detail` or
    /// `handoff-list`. An authored block of the same type wins, so nothing renders twice.
    static func foldCatalogue(content: [InspectConfig.GuidanceContent],
                              layout: String?,
                              sources: CatalogueSources,
                              member: (InspectConfig.ListItem) -> SoftwareMember,
                              hasDetail: (String) -> Bool)
    -> [InspectConfig.GuidanceContent] {
        let bundles = sources.bundles, detailBundle = sources.detailBundle
        let items = sources.items, handoffs = sources.handoffs
        switch (layout ?? "bundles").lowercased() {
        case "detail":
            guard !content.contains(where: { $0.type == "bundle-detail" }) else { return content }
            guard let bundle = detailBundle else { return content }
            let members = catalogueMembers(bundleId: bundle.bundleId, itemIds: bundle.itemIds,
                                           items: items, resolve: member)
            // No empty-members guard: the bundle may still carry a command worth drawing.
            var payload: [String: Any] = [
                "type": "bundle-detail",
                "detailRows": wire(members.map(catalogueDetailRow(for:)))
            ]
            if let command = bundle.command { payload["bundleCommand"] = command }
            if let note = bundle.commandNote { payload["bundleCommandNote"] = note }
            return append(payload, to: content)

        case "handoff":
            guard !handoffs.isEmpty,
                  !content.contains(where: { $0.type == "handoff-list" }) else { return content }
            return append(["type": "handoff-list", "handoffs": wire(handoffs)], to: content)

        default:
            guard !bundles.isEmpty,
                  !content.contains(where: { $0.type == "bundle-list" }) else { return content }
            let rows = bundles.map { bundle in
                catalogueBundleRow(
                    for: bundle,
                    members: catalogueMembers(bundleId: bundle.bundleId, itemIds: bundle.itemIds,
                                              items: items, resolve: member),
                    hasDetail: hasDetail(bundle.bundleId))
            }
            return append(["type": "bundle-list", "bundleRows": wire(rows)], to: content)
        }
    }

    /// Encodes typed payloads to the wire shape `decodeBlock` reads; nil fields stay absent, as
    /// in an authored block.
    private static func wire<T: Encodable>(_ values: [T]) -> [[String: Any]] {
        guard let data = try? JSONEncoder().encode(values),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return array
    }

    private static func append(_ payload: [String: Any],
                               to content: [InspectConfig.GuidanceContent])
    -> [InspectConfig.GuidanceContent] {
        guard let block = decodeBlock(payload) else { return content }
        return content + [block]
    }
}
