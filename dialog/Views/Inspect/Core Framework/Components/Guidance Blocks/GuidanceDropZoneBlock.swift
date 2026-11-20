//
//  GuidanceDropZoneBlock.swift
//  dialog
//
//  `type: "drop-zone"`: drop (or choose) an app or image. Paths are stored where a text field's value is
//  (`guidanceFormInputs[step].textfields[id]`, one per line). `fileType` uses the text field grammar plus
//  `app`; `multiple: true` collects several. `style: "logo"` draws light and dark tiles, stored "light\ndark".

import SwiftUI
import UniformTypeIdentifiers

struct GuidanceDropZoneBlock<Context: UserInputContext & ObservableObject>: View {
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    let scaleFactor: CGFloat

    @Environment(\.palette) private var palette
    @State private var targeted = false

    private var accepted: [String] {
        (block.fileType ?? "app image").lowercased().split(separator: " ").map(String.init)
    }

    private var paths: [String] {
        guard let id = block.id, let stored = inspectState.guidanceFormInputs[itemId]?.textfields[id] else { return [] }
        return stored.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            if let label = block.content, !label.isEmpty {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(palette.text)
            }
            if block.style?.lowercased() == "logo" { logoSlots } else { zone }
        }
    }

    // MARK: - Logo: two slots

    /// The two slots, by position; either may be empty.
    private var slots: [String] {
        guard let id = block.id, let stored = inspectState.guidanceFormInputs[itemId]?.textfields[id] else { return ["", ""] }
        let parts = stored.components(separatedBy: "\n")
        return [parts.first ?? "", parts.dropFirst().first ?? ""]
    }

    private func setSlot(_ index: Int, _ path: String) {
        var next = slots
        next[index] = path
        guard let id = block.id else { return }
        if inspectState.guidanceFormInputs[itemId] == nil { inspectState.initializeGuidanceFormState(for: itemId) }
        inspectState.guidanceFormInputs[itemId]?.textfields[id] = next.joined(separator: "\n")
        inspectState.writeToInteractionLog("dropzone:\(id)[\(index)]:\(path)")
    }

    private var logoSlots: some View {
        HStack(alignment: .top, spacing: 16 * scaleFactor) {
            logoSlot(0, title: "Logo", caption: "Light appearance", dark: false)
            logoSlot(1, title: "Dark version", caption: "Optional — for dark mode", dark: true)
        }
    }

    private func logoSlot(_ index: Int, title: String, caption: String, dark: Bool) -> some View {
        let path = slots[index]
        return VStack(alignment: .leading, spacing: 4 * scaleFactor) {
            ZStack {
                // The tile is the ground the logo will sit on: the dark slot always draws in dark appearance.
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.cardSurface)
                    .environment(\.colorScheme, dark ? .dark : .light)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(palette.text.opacity(path.isEmpty ? 0.25 : 0.12),
                                  style: StrokeStyle(lineWidth: 1, dash: path.isEmpty ? [5, 4] : []))
                if path.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 20 * scaleFactor))
                        Text("Drop or click")
                            .font(.system(size: 11 * scaleFactor))
                    }
                    .foregroundStyle(palette.textMuted)
                    .environment(\.colorScheme, dark ? .dark : .light)
                } else {
                    Image(nsImage: Self.thumbnail(path))
                        .resizable().interpolation(.high).scaledToFit()
                        .padding(14 * scaleFactor)
                }
            }
            .frame(width: 168 * scaleFactor, height: 96 * scaleFactor)
            .contentShape(Rectangle())
            .onTapGesture { chooseSlot(index) }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                guard let provider = providers.first else { return false }
                let kinds = accepted
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, dropZoneAccepts(url, accepted: kinds) else { return }
                    let path = url.path
                    DispatchQueue.main.async { setSlot(index, path) }
                }
                return true
            }
            .overlay(alignment: .topTrailing) {
                if !path.isEmpty {
                    Button { setSlot(index, "") } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(palette.textMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(title)")
                    .offset(x: 6, y: -6)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(path.isEmpty ? "\(title): empty" : "\(title): \((path as NSString).lastPathComponent)")
            .accessibilityHint("Drop an image or app, or activate to choose one")
            .accessibilityAddTraits(.isButton)
            Text(title)
                .font(.system(size: 12 * scaleFactor, weight: .semibold))
                .foregroundStyle(palette.text)
            Text(caption)
                .font(.system(size: 11 * scaleFactor))
                .foregroundStyle(palette.textMuted)
        }
    }

    private func chooseSlot(_ index: Int) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Self.contentTypes(for: accepted)
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url, Self.accepts(url, accepted: accepted) else { return }
            setSlot(index, url.path)
        }
    }

    private var zone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(targeted ? palette.accent.opacity(0.08) : palette.text.opacity(0.03))
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(targeted ? palette.accent : palette.text.opacity(0.25),
                              style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            if paths.isEmpty {
                VStack(spacing: 6 * scaleFactor) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 20 * scaleFactor))
                        .foregroundStyle(palette.textMuted)
                    Text(block.placeholder ?? Self.hint(for: accepted))
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(palette.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14 * scaleFactor) {
                        ForEach(paths, id: \.self) { path in chip(path) }
                    }
                    .padding(12)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 84 * scaleFactor)
        .contentShape(Rectangle())
        .onTapGesture { choose() }
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            // Collect every file of the drop, then merge once, so several apps land together in order.
            let group = DispatchGroup()
            let lock = NSLock()
            let kinds = accepted
            nonisolated(unsafe) var dropped: [(Int, String)] = []   // every access holds `lock`
            for (index, provider) in providers.enumerated() {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url, dropZoneAccepts(url, accepted: kinds) {
                        lock.lock(); dropped.append((index, url.path)); lock.unlock()
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                add(dropped.sorted { $0.0 < $1.0 }.map(\.1))
            }
            return true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(block.content ?? "Drop zone")
        .accessibilityHint("Drop a file here, or activate to choose one")
        .accessibilityAddTraits(.isButton)
    }

    private func chip(_ path: String) -> some View {
        VStack(spacing: 4) {
            Image(nsImage: Self.thumbnail(path))
                .resizable().interpolation(.high).scaledToFit()
                .frame(width: 40 * scaleFactor, height: 40 * scaleFactor)
            Text(((path as NSString).lastPathComponent as NSString).deletingPathExtension)
                .font(.system(size: 11 * scaleFactor))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .frame(maxWidth: 120 * scaleFactor)
            // The bundle id is what the flow will detect by.
            if let info = AppBundleInfo.read(path), !info.summary.isEmpty {
                Text(info.summary)
                    .font(.system(size: 9.5 * scaleFactor, design: .monospaced))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 120 * scaleFactor)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { remove(path) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(palette.textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \((path as NSString).lastPathComponent)")
            .offset(x: 6, y: -6)
        }
    }

    // MARK: - Storing

    private func store(_ list: [String]) {
        guard let id = block.id else { return }
        if inspectState.guidanceFormInputs[itemId] == nil { inspectState.initializeGuidanceFormState(for: itemId) }
        inspectState.guidanceFormInputs[itemId]?.textfields[id] = list.joined(separator: "\n")
        inspectState.writeToInteractionLog("dropzone:\(id):\(list.joined(separator: ","))")
    }

    private func add(_ dropped: [String]) {
        guard !dropped.isEmpty else { return }
        store(Self.merged(existing: paths, dropped: dropped, multiple: block.multiple == true, limit: block.limit))
    }

    /// A multiple zone adds new files (no duplicates, drop order kept) up to `limit`, earliest kept;
    /// a single zone holds the last file dropped.
    static func merged(existing: [String], dropped: [String], multiple: Bool, limit: Int? = nil) -> [String] {
        guard multiple else { return dropped.last.map { [$0] } ?? existing }
        var out = existing
        for path in dropped where !out.contains(path) { out.append(path) }
        if let limit, limit > 0, out.count > limit { out = Array(out.prefix(limit)) }
        return out
    }

    private func remove(_ path: String) { store(paths.filter { $0 != path }) }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = block.multiple == true
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.allowedContentTypes = Self.contentTypes(for: accepted)
        if accepted.contains("app") { panel.directoryURL = URL(fileURLWithPath: "/Applications") }
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK else { return }
            add(panel.urls.filter { Self.accepts($0, accepted: accepted) }.map(\.path))
        }
    }

    // MARK: - Pure helpers

    static func contentTypes(for accepted: [String]) -> [UTType] {
        accepted.compactMap { token in
            switch token {
            case "app": return .application
            case "image": return .image
            default: return UTType(filenameExtension: token)
            }
        }
    }

    /// Whether a dropped file is one of the accepted kinds.
    nonisolated static func accepts(_ url: URL, accepted: [String]) -> Bool {
        dropZoneAccepts(url, accepted: accepted)
    }

    static func hint(for accepted: [String]) -> String {
        switch (accepted.contains("app"), accepted.contains("image")) {
        case (true, true): return "Drop an app or an image here, or click to choose"
        case (true, false): return "Drop apps here, or click to choose"
        case (false, true): return "Drop an image here, or click to choose"
        default: return "Drop a file here, or click to choose"
        }
    }

    /// An app's own icon, an image's own picture, else the file's Finder icon.
    static func thumbnail(_ path: String) -> NSImage {
        if !path.lowercased().hasSuffix(".app"), let image = InspectImageCache.shared.image(atPath: path) { return image }
        return NSWorkspace.shared.icon(forFile: path)
    }
}

/// `GuidanceDropZoneBlock.accepts` at file scope, so off-main item-provider callbacks need not capture
/// the view's generic metatype.
private func dropZoneAccepts(_ url: URL, accepted: [String]) -> Bool {
    let type = UTType(filenameExtension: url.pathExtension)
    for token in accepted {
        switch token {
        case "app": if url.pathExtension.lowercased() == "app" { return true }
        case "image": if type?.conforms(to: .image) == true { return true }
        default: if url.pathExtension.lowercased() == token { return true }
        }
    }
    return false
}
