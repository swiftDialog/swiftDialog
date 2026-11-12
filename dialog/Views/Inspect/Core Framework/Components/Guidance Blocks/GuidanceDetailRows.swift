//
//  GuidanceDetailRows.swift
//  dialog
//
//  Catalog rows with icon, title, action and description (type: "detail-rows").
//

import SwiftUI

// MARK: - Detail Rows Block

/// Stacks `DetailRowView`s with hairline dividers. Its own view so GuidanceContentView's `detail-rows`
/// dispatch stays a single expression (type-check budget).
struct DetailRowsBlock<Context: UserInputContext & ObservableObject>: View {
    let rows: [InspectConfig.GuidanceContent.InstallItem]
    let scaleFactor: CGFloat
    let iconBasePath: String?
    let accentColor: Color
    let itemId: String
    @ObservedObject var inspectState: Context

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows.indices, id: \.self) { i in
                DetailRowView(
                    item: rows[i],
                    isLast: i == rows.count - 1,
                    scaleFactor: scaleFactor,
                    iconBasePath: iconBasePath,
                    accentColor: accentColor,
                    itemId: itemId,
                    inspectState: inspectState
                )
            }
        }
    }
}

// MARK: - Detail Row

/// A catalog row: 60pt app icon, bold title, subtitle with an optional trailing SF glyph, a trailing action
/// button and a description paragraph. Rendered by the `detail-rows` block in Presets 5 and 6.
struct DetailRowView<Context: UserInputContext & ObservableObject>: View {
    @Environment(\.palette) private var palette
    let item: InspectConfig.GuidanceContent.InstallItem
    let isLast: Bool
    let scaleFactor: CGFloat
    let iconBasePath: String?
    let accentColor: Color
    let itemId: String
    @ObservedObject var inspectState: Context

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16 * scaleFactor) {
                iconView
                    .frame(width: 60 * scaleFactor, height: 60 * scaleFactor)

                VStack(alignment: .leading, spacing: 3 * scaleFactor) {
                    Text(item.title)
                        .font(.system(size: 20 * scaleFactor, weight: .bold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)

                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        HStack(spacing: 4 * scaleFactor) {
                            Text(subtitle)
                                .font(.system(size: 13 * scaleFactor))
                                .foregroundStyle(palette.textMuted)
                            if let sym = item.subtitleSymbol, !sym.isEmpty {
                                Image(systemName: sym)
                                    .font(.system(size: 11 * scaleFactor))
                                    .foregroundStyle(palette.textMuted)
                            }
                        }
                    }
                }

                Spacer(minLength: 8 * scaleFactor)

                if let label = item.actionLabel, !label.isEmpty {
                    Button(action: {
                        handleRowAction(action: item.action, url: item.url, requestId: item.requestId,
                                        label: label, itemId: itemId, inspectState: inspectState)
                    }) {
                        Text(label)
                            .frame(minWidth: 48 * scaleFactor)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(accentColor)
                }
            }

            if let desc = item.detail, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10 * scaleFactor)
            }

            if !isLast {
                Divider()
                    .padding(.top, 18 * scaleFactor)
            }
        }
        .padding(.vertical, 10 * scaleFactor)
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconPath = item.icon, !iconPath.isEmpty {
            if let symbolName = IconRef.symbol(iconPath) {
                symbolIcon(symbolName)
            } else if iconPath.hasPrefix("/") || iconPath.contains(".") {
                if let nsImage = loadRowIcon(iconPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 13 * scaleFactor, style: .continuous))
                } else {
                    defaultIcon
                }
            } else {
                symbolIcon(iconPath)
            }
        } else {
            defaultIcon
        }
    }

    private func symbolIcon(_ name: String) -> some View {
        RoundedRectangle(cornerRadius: 13 * scaleFactor, style: .continuous)
            .fill(accentColor.opacity(0.12))
            .overlay(
                Image(systemName: name.components(separatedBy: ",").first ?? name)
                    .font(.system(size: 26 * scaleFactor, weight: .medium))
                    .foregroundStyle(accentColor)
            )
    }

    private var defaultIcon: some View {
        RoundedRectangle(cornerRadius: 13 * scaleFactor, style: .continuous)
            .fill(palette.text.opacity(0.15))
            .overlay(
                Image(systemName: "app.fill")
                    .font(.system(size: 24 * scaleFactor))
                    .foregroundStyle(palette.textMuted)
            )
    }

    /// Loads a row icon: the Finder/app icon for bundles and files, a direct load for image files.
    private func loadRowIcon(_ path: String) -> NSImage? {
        let full = path.hasPrefix("/") ? path
            : (iconBasePath.map { ($0 as NSString).appendingPathComponent(path) } ?? path)
        let ext = (full as NSString).pathExtension.lowercased()
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "gif", "tiff", "bmp", "icns", "pdf", "svg"]
        if imageExts.contains(ext) { return InspectImageCache.shared.image(atPath: full) }
        if FileManager.default.fileExists(atPath: full) { return NSWorkspace.shared.icon(forFile: full) }
        return InspectImageCache.shared.image(atPath: full)
    }
}
