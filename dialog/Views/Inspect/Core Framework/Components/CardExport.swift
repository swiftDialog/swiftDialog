//
//  CardExport.swift
//  dialog
//
//  Export: the selection becomes files (CardExportEngine, CardExportView, CardStripePlaceholder).
//

import SwiftUI

// MARK: - Export

/// The facts behind the export screen, kept out of the view so the write path is testable. Sizes and
/// editors are measured and detected on disk, never authored.
enum CardExportEngine {
    struct MeasuredItem {
        let name: String
        let note: String?
        let size: Int64?          // nil → source missing (stated, not hidden)
    }
    struct DetectedEditor: Identifiable {
        var id: String { bundleId }
        let bundleId: String
        let name: String
        let version: String?
        let icon: NSImage?
        let url: URL?             // nil → not installed
    }

    static func expand(_ path: String) -> String { (path as NSString).expandingTildeInPath }

    /// Size of a file, or the recursive size of a directory.
    static func measure(_ item: InspectConfig.IntroStep.ExportItem) -> MeasuredItem {
        let fm = FileManager.default
        let src = expand(item.source)
        let name = item.name ?? (src as NSString).lastPathComponent
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: src, isDirectory: &isDir) else {
            return MeasuredItem(name: name, note: item.note, size: nil)
        }
        if isDir.boolValue {
            var total: Int64 = 0
            if let e = fm.enumerator(atPath: src) {
                for case let sub as String in e {
                    // Regular files only; directory inode sizes would inflate the total.
                    let attrs = try? fm.attributesOfItem(atPath: (src as NSString).appendingPathComponent(sub))
                    guard (attrs?[.type] as? FileAttributeType) == .typeRegular else { continue }
                    total += (attrs?[.size] as? Int64) ?? 0
                }
            }
            return MeasuredItem(name: name + "/", note: item.note, size: total)
        }
        let attrs = try? fm.attributesOfItem(atPath: src)
        return MeasuredItem(name: name, note: item.note, size: attrs?[.size] as? Int64)
    }

    /// The shared name-column width: the widest filename in the row's monospaced font, capped at `limit`
    /// so the note column starts at one x in every row. Must match the row's
    /// `.system(size: 13.5, weight: .medium, design: .monospaced)`.
    static func nameColumnWidth(_ items: [MeasuredItem], limit: CGFloat = 240) -> CGFloat {
        guard !items.isEmpty else { return 0 }
        let font = NSFont.monospacedSystemFont(ofSize: 13.5, weight: .medium)
        let widest = items
            .map { ($0.name as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        return min(widest.rounded(.up), limit)
    }

    static func sizeLabel(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }

    /// "4 items · 247 KB"; missing sources are counted but not sized.
    static func totalLabel(_ measured: [MeasuredItem]) -> String {
        let total = measured.compactMap(\.size).reduce(0, +)
        return "\(measured.count) item\(measured.count == 1 ? "" : "s") · \(sizeLabel(total))"
    }

    /// Only installed editors get a live tile; a missing one returns `url: nil` so the row says so.
    static func detect(_ bundleId: String) -> DetectedEditor {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            let fallback = bundleId.components(separatedBy: ".").last ?? bundleId
            return DetectedEditor(bundleId: bundleId, name: fallback, version: nil, icon: nil, url: nil)
        }
        let bundle = Bundle(url: url)
        let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return DetectedEditor(bundleId: bundleId, name: name, version: version,
                              icon: NSWorkspace.shared.icon(forFile: url.path), url: url)
    }

    /// The write: creates the destination, copies each existing source in (replacing same-named entries),
    /// skips missing ones, returns the destination URL. Called from a button press and tests, never a render.
    @discardableResult
    static func performExport(items: [InspectConfig.IntroStep.ExportItem],
                              destination: String) throws -> URL {
        let fm = FileManager.default
        let destDir = URL(fileURLWithPath: expand(destination), isDirectory: true)
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        for item in items {
            let src = expand(item.source)
            guard fm.fileExists(atPath: src) else { continue }
            let target = destDir.appendingPathComponent((src as NSString).lastPathComponent)
            if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
            try fm.copyItem(at: URL(fileURLWithPath: src), to: target)
        }
        return destDir
    }
}

/// The export payload: the file list, then the detected-editor row. A missing editor is a dashed tile.
struct CardExportView: View {
    @Environment(\.palette) private var palette
    let measured: [CardExportEngine.MeasuredItem]
    let editors: [CardExportEngine.DetectedEditor]
    let selectedEditor: String?
    let onSelectEditor: (String) -> Void
    let accent: Color

    var body: some View {
        // One width for every row.
        let nameColumn = CardExportEngine.nameColumnWidth(measured)
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(measured.indices, id: \.self) { i in
                    if i > 0 {
                        Rectangle().fill(palette.text.opacity(0.09))
                            .frame(height: 0.5).frame(maxWidth: .infinity)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        // The name is served first at the shared column width; the note absorbs the squeeze.
                        Text(measured[i].name)
                            .font(.system(size: 13.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(palette.text.opacity(0.9))
                            .frame(width: nameColumn, alignment: .leading)
                        if let note = measured[i].note {
                            Text(note)
                                .font(.system(size: 12.5))
                                .foregroundStyle(palette.text.opacity(0.5))
                        }
                        Spacer()
                        // Words, not a warning colour, carry the missing state (palette rule).
                        Text(measured[i].size.map(CardExportEngine.sizeLabel) ?? "not found")
                            .font(.system(size: 12.5, design: .monospaced))
                            .foregroundStyle(palette.text.opacity(0.5))
                    }
                    .padding(.vertical, 9)
                }
            }
            if !editors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OPEN IN")
                        .font(.system(size: 11.5, weight: .medium))
                        .kerning(0.55)
                        .foregroundStyle(palette.text.opacity(0.5))
                    // A flexible two-column grid, so editor tiles wrap instead of widening the card.
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                        GridItem(.flexible(), spacing: 10)],
                              alignment: .leading, spacing: 10) {
                        ForEach(editors) { editor in
                            editorTile(editor)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func editorTile(_ editor: CardExportEngine.DetectedEditor) -> some View {
        let installed = editor.url != nil
        let isSelected = installed && selectedEditor == editor.bundleId
        Button {
            if installed { onSelectEditor(editor.bundleId) }
        } label: {
            HStack(spacing: 8) {
                if let icon = editor.icon {
                    Image(nsImage: icon).resizable().scaledToFit().frame(width: 22, height: 22)
                }
                // One truncating line, so the tile never folds or widens past its cell.
                Text(installed ? editor.name : "\(editor.name) — not installed")
                    .font(.system(size: 13, weight: installed ? .medium : .regular))
                    .foregroundStyle(palette.text.opacity(installed ? 0.85 : 0.4))
                    .lineLimit(1)
                // The tick reserves its box and appears by opacity, so selection never reflows the row.
                if installed {
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(accent)
                        .opacity(isSelected ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(palette.text.opacity(installed ? 0.05 : 0.02)))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(palette.text.opacity(0.09),
                                  style: StrokeStyle(lineWidth: 1, dash: installed ? [] : [4, 3]))
            )
            // The selection mark: a ring in a constant gutter.
            .padding(3)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(accent, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!installed)
    }
}

/// Grey diagonal stripes for a missing screenshot — visibly a placeholder.
struct CardStripePlaceholder: View {
    @Environment(\.palette) private var palette
    var body: some View {
        Canvas { context, size in
            let stripe: CGFloat = 14
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(palette.text.opacity(0.07)))
            var x: CGFloat = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height + stripe / 2, y: 0))
                path.addLine(to: CGPoint(x: x + stripe / 2, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(palette.text.opacity(0.12)))
                x += stripe * 2
            }
        }
    }
}
