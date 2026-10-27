//
//  DockPicker.swift
//  dialog
//
//  Dock picker for guided setup: "flavors" (pick one preset dock) or "build" (choose and order
//  apps), each with a live mockup. The choice goes to the interaction log and a `selection`
//  notification; the dialog records only, the orchestrator applies the dock.
//

import SwiftUI

// MARK: - Dock Mockup

/// A dock preview strip; tiles for apps not installed are greyed.
struct DockMockupView: View {
    let items: [InspectConfig.DockItem]
    var scaleFactor: CGFloat = 1.0

    private func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath)
    }

    var body: some View {
        HStack(spacing: 6 * scaleFactor) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                tile(item)
            }
        }
        .padding(8 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 12 * scaleFactor, style: .continuous)
                .fill(Color.black.opacity(0.25))
        )
    }

    @ViewBuilder
    private func tile(_ item: InspectConfig.DockItem) -> some View {
        let present = exists(item.path)
        Group {
            if present {
                Image(nsImage: NSWorkspace.shared.icon(forFile: (item.path as NSString).expandingTildeInPath))
                    .resizable()
                    .scaledToFit()
            } else if let sf = item.sfSymbol {
                Image(systemName: sf).resizable().scaledToFit().foregroundStyle(.white)
            } else {
                Image(systemName: "app.dashed").resizable().scaledToFit().foregroundStyle(.white)
            }
        }
        .frame(width: 28 * scaleFactor, height: 28 * scaleFactor)
        .opacity(present ? 1 : 0.35)
        .help(item.label)
    }
}

// MARK: - Dock Picker

/// Generic over `UserInputContext`: the surface is config, `dockSelection` and the interaction log.
struct DockPickerView<Context: UserInputContext & ObservableObject>: View {
    let mode: String                          // "flavors" (default) | "build"
    let flavors: [InspectConfig.DockFlavor]
    let items: [InspectConfig.DockItem]       // build-mode candidates
    let selectionKey: String
    let confirmButtonText: String?            // nil emits on every change
    let showUnavailable: Bool
    /// Optional "change nothing" card, rendered after the flavours.
    var decline: InspectConfig.DeclineOption?
    var applyMode: String = "additive"        // "additive" | "replace"
    let scaleFactor: CGFloat
    /// The accent the host handed this picker; nil takes the palette's.
    var tint: Color?
    var centered: Bool = false
    /// The authored `dockLayout`; `"narrow"` is the one recognised value.
    var layout: String?
    @ObservedObject var inspectState: Context
    let itemId: String

    @State private var selectedFlavorId: String?
    @State private var buildOrder: [String] = []   // ordered selected paths (build mode)
    @State private var didInit = false

    /// Flavour names and summaries localize here so step, block and outro hosts agree.
    @Environment(\.inspectLocalization) private var l10n
    @Environment(\.palette) private var palette

    private var accentColor: Color { tint ?? palette.accent }
    private func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath)
    }
    private var hasSelection: Bool { mode == "build" ? !buildOrder.isEmpty : selectedFlavorId != nil }

    /// `"narrow"` selects the 560pt measure; any other value takes the default.
    private var contentMaxWidth: CGFloat {
        if layout?.lowercased() == "narrow" { return 560 * scaleFactor }
        return centered ? 760 * scaleFactor : .infinity
    }

    /// Sidecar key `<itemId>.dockFlavors.<flavorId>.name`, authored string as fallback. `itemId`
    /// is a step id only at the step host; other hosts pass their own scope.
    private func displayName(_ flavor: InspectConfig.DockFlavor) -> String {
        l10n("\(itemId).dockFlavors.\(flavor.flavorId).name", flavor.name)
    }

    private func displaySummary(_ flavor: InspectConfig.DockFlavor) -> String? {
        flavor.summary.map { l10n("\(itemId).dockFlavors.\(flavor.flavorId).summary", $0) }
    }

    var body: some View {
        VStack(spacing: 16 * scaleFactor) {
            if mode == "build" { buildModeView } else { flavorsModeView }
            if let confirm = confirmButtonText, hasSelection {
                Button(confirm) { commit() }
                    .buttonStyle(.borderedProminent).tint(accentColor).controlSize(.large)
            }
        }
        .frame(maxWidth: contentMaxWidth)
        .onAppear {
            guard !didInit else { return }
            didInit = true
            if let existing = inspectState.dockSelection[selectionKey], !existing.isEmpty {
                buildOrder = existing.components(separatedBy: ",").filter { !$0.isEmpty }
            }
        }
    }

    // MARK: Flavors mode

    /// Sentinel id for the decline card, distinct from any flavour id.
    static var declineId: String { "__decline__" }

    private var flavorsModeView: some View {
        // The decline card is a peer option and counts toward the column split.
        let total = flavors.count + (decline == nil ? 0 : 1)
        let cols = Array(repeating: GridItem(.flexible(), spacing: 12 * scaleFactor),
                         count: max(1, min(total, 3)))
        return LazyVGrid(columns: cols, spacing: 12 * scaleFactor) {
            ForEach(flavors) { flavor in flavorCard(flavor) }
            if let decline { declineCard(decline) }
        }
    }

    /// Same card shell as a flavour, without a mockup: an empty strip would imply an empty Dock.
    private func declineCard(_ opt: InspectConfig.DeclineOption) -> some View {
        let isSelected = selectedFlavorId == Self.declineId
        return Button {
            selectedFlavorId = Self.declineId
            if confirmButtonText == nil { commit() }
        } label: {
            VStack(spacing: 8 * scaleFactor) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 26 * scaleFactor))
                    .foregroundStyle(.secondary)
                Text(opt.label).font(.system(size: 14 * scaleFactor, weight: .medium))
                if let subtitle = opt.subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 11 * scaleFactor)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14 * scaleFactor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(NSColor.controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? accentColor : palette.text.opacity(0.08), lineWidth: isSelected ? 2 : 1))
            .overlay(alignment: .topTrailing) {
                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(accentColor).padding(6 * scaleFactor) }
            }
        }.buttonStyle(.plain)
    }

    private func flavorCard(_ flavor: InspectConfig.DockFlavor) -> some View {
        let isSelected = selectedFlavorId == flavor.id
        return Button {
            selectedFlavorId = flavor.id
            if confirmButtonText == nil { commit() }
        } label: {
            VStack(spacing: 8 * scaleFactor) {
                if let sf = flavor.sfSymbol {
                    Image(systemName: sf).font(.system(size: 26 * scaleFactor)).foregroundStyle(accentColor)
                }
                Text(displayName(flavor)).font(.system(size: 14 * scaleFactor, weight: .medium))
                if let summary = displaySummary(flavor), !summary.isEmpty {
                    Text(summary).font(.system(size: 11 * scaleFactor)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
                DockMockupView(items: displayItems(flavor.items), scaleFactor: scaleFactor)
                // Tiles are not readable at this size, so the set is written out from the same
                // filtered items the mockup draws.
                let contents = displayItems(flavor.items).map(\.label)
                if !contents.isEmpty {
                    Text(contents.joined(separator: " · "))
                        .font(.system(size: 10 * scaleFactor))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14 * scaleFactor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(NSColor.controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? accentColor : palette.text.opacity(0.08), lineWidth: isSelected ? 2 : 1))
            .overlay(alignment: .topTrailing) {
                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(accentColor).padding(6 * scaleFactor) }
            }
        }.buttonStyle(.plain)
    }

    // MARK: Build mode

    private var buildModeView: some View {
        VStack(spacing: 12 * scaleFactor) {
            if !buildOrder.isEmpty {
                DockMockupView(items: buildOrder.map { path in
                    items.first { $0.path == path }
                        ?? InspectConfig.DockItem(label: (path as NSString).lastPathComponent, path: path, sfSymbol: nil)
                }, scaleFactor: scaleFactor)
            }
            let cols = Array(repeating: GridItem(.flexible(), spacing: 10 * scaleFactor), count: 4)
            LazyVGrid(columns: cols, spacing: 10 * scaleFactor) {
                ForEach(displayItems(items), id: \.path) { item in buildTile(item) }
            }
        }
    }

    private func buildTile(_ item: InspectConfig.DockItem) -> some View {
        let present = exists(item.path)
        let isIncluded = buildOrder.contains(item.path)
        return Button {
            guard present else { return }
            if isIncluded { buildOrder.removeAll { $0 == item.path } } else { buildOrder.append(item.path) }
            if confirmButtonText == nil { commit() }
        } label: {
            VStack(spacing: 4 * scaleFactor) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: (item.path as NSString).expandingTildeInPath))
                    .resizable().scaledToFit().frame(width: 36 * scaleFactor, height: 36 * scaleFactor)
                Text(item.label).font(.system(size: 10 * scaleFactor)).lineLimit(1)
            }
            .frame(maxWidth: .infinity).padding(8 * scaleFactor)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(isIncluded ? accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isIncluded ? accentColor : palette.text.opacity(0.08), lineWidth: isIncluded ? 2 : 1))
            .opacity(present ? 1 : 0.35)
        }.buttonStyle(.plain).disabled(!present)
    }

    private func displayItems(_ src: [InspectConfig.DockItem]) -> [InspectConfig.DockItem] {
        showUnavailable ? src : src.filter { exists($0.path) }
    }

    /// Stores and emits the ordered dock paths; order matters and the consumer splits on ",".
    private func commit() {
        let paths: [String]
        // Carried out of the branch so flavour id and paths cannot disagree.
        var chosenFlavorId: String?
        if mode == "build" {
            paths = buildOrder.filter { exists($0) }
        } else if let fid = selectedFlavorId, let flavor = flavors.first(where: { $0.id == fid }) {
            paths = flavor.items.map { $0.path }.filter { exists($0) }
            chosenFlavorId = fid
        } else {
            paths = []
        }
        // A decline is an answer and is emitted, so consumers can tell it from an unreached step.
        if mode != "build", selectedFlavorId == Self.declineId {
            let value = decline?.value ?? "none"
            inspectState.dockSelection[selectionKey] = value
            emit(.decline(value), payload: value)
            DialogNotifications.postSelection(key: selectionKey, values: [value], flavorId: value)
            return
        }
        let joined = paths.joined(separator: ",")
        inspectState.dockSelection[selectionKey] = joined
        emit(chosenFlavorId.map(DockEmission.Answer.flavor) ?? .built, payload: joined)
        DialogNotifications.postSelection(key: selectionKey, values: paths, flavorId: chosenFlavorId)
    }

    private func emit(_ answer: DockEmission.Answer, payload: String) {
        for line in DockEmission.lines(selectionKey: selectionKey, applyMode: applyMode,
                                       answer: answer, payload: payload).ordered {
            inspectState.writeToInteractionLog(line)
        }
    }
}


/// The interaction-log lines one dock commit produces. A `dock:` line with no `select:` before it
/// means the user built the Dock by hand, so the pairing is part of the contract.
enum DockEmission {

    enum Answer: Equatable {
        /// A flavour by id; the resolved path list on the `dock:` line is lossy, the id is not.
        case flavor(String)
        case decline(String)
        /// Hand-built: no flavour, so no `select:` line.
        case built
    }

    struct Lines: Equatable {
        /// Emitted first, when there is an identity to report.
        let select: String?
        /// Frozen shape: consumers split on ":" then ","; new facts go on new lines.
        let dock: String

        var ordered: [String] { [select, dock].compactMap { $0 } }
    }

    static func lines(selectionKey: String,
                      applyMode: String,
                      answer: Answer,
                      payload: String) -> Lines {
        let dock = "dock:\(selectionKey):\(applyMode):\(payload)"
        switch answer {
        case .flavor(let id):     return Lines(select: "select:\(selectionKey):\(id)", dock: dock)
        case .decline(let value): return Lines(select: "select:\(selectionKey):\(value)", dock: dock)
        case .built:              return Lines(select: nil, dock: dock)
        }
    }
}
