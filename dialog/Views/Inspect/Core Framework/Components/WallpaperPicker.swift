//
//  WallpaperPicker.swift
//  dialog
//
//  The wallpaper picker: categorised tiles, optional multi-display assignment, and the
//  `wallpaper:<key>:<monitor>:<path>` interaction-log line scripts apply.
//

import SwiftUI

// MARK: - Wallpaper Picker View

/// Layout mode; file-scope because the picker is generic.
enum WallpaperLayout {
    case categories  // Vertical stack of categories, each a wrapped grid
    case grid        // Flat grid of all images
    case row         // Single horizontal row
}

/// Categorised wallpaper selection. The chosen path is stored in the context's
/// `wallpaperSelection` under `selectionKey` (suffixed `_<monitor>` for multi-display).
struct WallpaperPickerView<Context: UserInputContext & ObservableObject>: View {
    @Environment(\.palette) private var palette
    let categories: [InspectConfig.WallpaperCategory]
    let columns: Int  // for the grid and category layouts; tiles cap to the cell
    let imageFit: String  // "fill" | "fit"
    let thumbnailHeight: Double
    let selectionKey: String
    let showPath: Bool
    let confirmButtonText: String?
    let multiSelectCount: Int  // number of monitors (0 = single select)
    let scaleFactor: CGFloat
    var centered: Bool = false
    var layout: WallpaperLayout = .categories
    @ObservedObject var inspectState: Context
    let itemId: String

    @State private var pendingSelections: [Int: String] = [:]  // monitor index -> path
    /// Path whose display chooser is open.
    @State private var assigningPath: String?
    @State private var isConfirmed: Bool = false
    @State private var expandedCategories: Set<String> = []

    /// Categories above this image count collapse behind a "See more" toggle.
    private let categoryCollapseThreshold = 6

    /// Featured categories first, order preserved within each group.
    private var orderedCategories: [InspectConfig.WallpaperCategory] {
        let featured = categories.filter { $0.featured == true }
        let rest = categories.filter { $0.featured != true }
        return featured + rest
    }

    private var isMultiSelect: Bool { multiSelectCount > 1 }

    // 16:10, the common wallpaper ratio.
    private var tileWidth: CGFloat {
        thumbnailHeight * 1.6 * scaleFactor
    }

    /// Height the flat grid needs, so its width-reading `GeometryReader` can be given one.
    private var gridHeight: CGFloat {
        let rows = max(Int(ceil(Double(allImages.count) / Double(max(columns, 1)))), 1)
        let gap = InspectConstants.spacingInner * scaleFactor
        // The label is about 18pt at this size.
        return CGFloat(rows) * (tileHeight + 18 * scaleFactor) + CGFloat(rows - 1) * gap
    }

    private var tileHeight: CGFloat {
        thumbnailHeight * scaleFactor
    }

    /// `gridHeight`'s arithmetic for one category.
    private func categoryHeight(count: Int) -> CGFloat {
        let rows = max(Int(ceil(Double(count) / Double(max(columns, 1)))), 1)
        let gap = InspectConstants.spacingInner * scaleFactor
        return CGFloat(rows) * (tileHeight + 18 * scaleFactor) + CGFloat(rows - 1) * gap
    }

    /// One category's images, wrapped; each tile is capped to its cell with the aspect kept.
    @ViewBuilder
    private func categoryGrid(_ images: [InspectConfig.WallpaperImage]) -> some View {
        let gap = InspectConstants.spacingInner * scaleFactor
        GeometryReader { geo in
            let cell = max((geo.size.width - gap * CGFloat(max(columns - 1, 0))) / CGFloat(max(columns, 1)), 1)
            let drawnWidth = min(tileWidth, cell)
            let drawnHeight = drawnWidth / 1.6
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: max(columns, 1)),
                      alignment: .leading, spacing: gap) {
                ForEach(images, id: \.path) { image in
                    wallpaperTile(image, width: drawnWidth, height: drawnHeight)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: categoryHeight(count: images.count))
    }

    private var accentColor: Color {
        if let hex = inspectState.config?.highlightColor {
            return Color(hex: hex)
        }
        return .accentColor
    }

    private var allImages: [InspectConfig.WallpaperImage] {
        categories.flatMap { $0.images }
    }

    /// Monitors showing `path`; one wallpaper may be on several.
    private func monitorIndices(for path: String) -> [Int] {
        if isMultiSelect {
            return pendingSelections.filter { $0.value == path }.map { $0.key }.sorted()
        } else if pendingSelections[0] == path || inspectState.wallpaperSelection[selectionKey] == path {
            return [0]
        }
        return []
    }

    private func isSelected(_ path: String) -> Bool {
        if confirmButtonText != nil || isMultiSelect {
            return pendingSelections.values.contains(path)
        } else {
            return inspectState.wallpaperSelection[selectionKey] == path
        }
    }

    /// One selectable wallpaper tile.
    @ViewBuilder
    private func wallpaperTile(_ image: InspectConfig.WallpaperImage,
                               width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        WallpaperTileView(
            image: image,
            isSelected: isSelected(image.path),
            monitorIndices: monitorIndices(for: image.path),
            imageFit: imageFit,
            tileWidth: width ?? tileWidth,
            tileHeight: height ?? tileHeight,
            scaleFactor: scaleFactor,
            accentColor: accentColor
        ) {
            handleTileSelection(image.path)
        }
        // Multi-display assignment is asked on the tile, never implied by a mode.
        .popover(isPresented: Binding(
            get: { assigningPath == image.path },
            set: { if !$0 { assigningPath = nil } }
        ), arrowEdge: .bottom) {
            assignmentChooser(for: image)
        }
    }

    /// One row per display, each naming what it currently shows, plus a both-displays action.
    @ViewBuilder
    private func assignmentChooser(for image: InspectConfig.WallpaperImage) -> some View {
        let name = image.title ?? (image.path as NSString).lastPathComponent
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            Text("\(name) · set on")
                .font(.system(size: 12 * scaleFactor, weight: .semibold))

            ForEach(0..<multiSelectCount, id: \.self) { index in
                Button {
                    assign(image.path, to: [index])
                } label: {
                    HStack(spacing: 8 * scaleFactor) {
                        Image(systemName: "display").font(.system(size: 11 * scaleFactor))
                        Text("Display \(index + 1)").font(.system(size: 12 * scaleFactor))
                        Spacer(minLength: 12 * scaleFactor)
                        Text(currentName(forMonitor: index))
                            .font(.system(size: 11 * scaleFactor))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if multiSelectCount > 1 {
                Divider()
                Button {
                    assign(image.path, to: Array(0..<multiSelectCount))
                } label: {
                    HStack(spacing: 8 * scaleFactor) {
                        Image(systemName: "rectangle.on.rectangle").font(.system(size: 11 * scaleFactor))
                        Text("Both displays").font(.system(size: 12 * scaleFactor))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14 * scaleFactor)
        .frame(width: 260 * scaleFactor)
    }

    /// The wallpaper a display currently shows.
    private func currentName(forMonitor index: Int) -> String {
        // Committed multi-display picks are keyed per display.
        let committedKey = isMultiSelect ? "\(selectionKey)_\(index)" : selectionKey
        guard let path = pendingSelections[index] ?? inspectState.wallpaperSelection[committedKey] else {
            return "not set"
        }
        let match = categories.flatMap(\.images).first { $0.path == path }
        return "currently " + (match?.title ?? (path as NSString).lastPathComponent)
    }

    /// Apply one wallpaper to the named displays; the badge moves with the display.
    private func assign(_ path: String, to monitors: [Int]) {
        for m in monitors { pendingSelections[m] = path }
        isConfirmed = false
        assigningPath = nil
        if confirmButtonText == nil { confirmSelection() }
    }

    var body: some View {
        // Outer spacing separates category groups; the inner spacing below binds a title to its row.
        VStack(alignment: centered ? .center : .leading, spacing: InspectConstants.spacingOuter * scaleFactor) {
            if isMultiSelect {
                HStack(spacing: 8 * scaleFactor) {
                    Text("Select for:")
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(.secondary)

                    ForEach(0..<multiSelectCount, id: \.self) { index in
                        // Indicator, not a control: it reports what each display has.
                        Group {
                            HStack(spacing: 4 * scaleFactor) {
                                Image(systemName: "display")
                                    .font(.system(size: 10 * scaleFactor))
                                Text("Monitor \(index + 1)")
                                    .font(.system(size: 11 * scaleFactor, weight: .medium))
                                if pendingSelections[index] != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10 * scaleFactor))
                                        .foregroundStyle(accentColor)
                                }
                            }
                            .padding(.horizontal, 10 * scaleFactor)
                            .padding(.vertical, 6 * scaleFactor)
                            .background(pendingSelections[index] != nil ? accentColor : palette.text.opacity(0.2))
                            .foregroundStyle(pendingSelections[index] != nil ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6 * scaleFactor))
                        }
                    }
                }
                .padding(.bottom, 4 * scaleFactor)
            }

            switch layout {
            case .grid:
                // The tile is capped to its flexible cell, height derived through the same 1.6,
                // so a large `thumbnailHeight` cannot overflow the gutters.
                GeometryReader { gridGeo in
                let gap = InspectConstants.spacingInner * scaleFactor
                let cell = max((gridGeo.size.width - gap * CGFloat(columns - 1)) / CGFloat(columns), 1)
                let drawnWidth = min(tileWidth, cell)
                let drawnHeight = drawnWidth / 1.6
                let gridColumns = Array(repeating: GridItem(.flexible(), spacing: gap), count: columns)
                LazyVGrid(columns: gridColumns, spacing: gap) {
                    ForEach(allImages, id: \.path) { image in
                        WallpaperTileView(
                            image: image,
                            isSelected: isSelected(image.path),
                            monitorIndices: monitorIndices(for: image.path),
                            imageFit: imageFit,
                            tileWidth: drawnWidth,
                            tileHeight: drawnHeight,
                            scaleFactor: scaleFactor,
                            accentColor: accentColor
                        ) {
                            handleTileSelection(image.path)
                        }
                    }
                }
                .padding(.horizontal, 2)
                }
                // The GeometryReader only reads the width; the height comes from the rows.
                .frame(height: gridHeight)

            case .row:
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: InspectConstants.spacingInner * scaleFactor) {
                        ForEach(allImages, id: \.path) { image in
                            WallpaperTileView(
                                image: image,
                                isSelected: isSelected(image.path),
                                monitorIndices: monitorIndices(for: image.path),
                                imageFit: imageFit,
                                tileWidth: tileWidth,
                                tileHeight: tileHeight,
                                scaleFactor: scaleFactor,
                                accentColor: accentColor
                            ) {
                                handleTileSelection(image.path)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }

            case .categories:
                ForEach(Array(orderedCategories.enumerated()), id: \.element.title) { index, category in
                    let isFeatured = category.featured == true
                    let canExpand = category.images.count > categoryCollapseThreshold
                    let isExpanded = expandedCategories.contains(category.title)

                    VStack(alignment: .leading, spacing: InspectConstants.spacingInner * scaleFactor) {
                        HStack {
                            HStack(spacing: 4 * scaleFactor) {
                                if isFeatured {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11 * scaleFactor))
                                        .foregroundStyle(accentColor)
                                }
                                Text(category.title)
                                    .font(.system(size: 13 * scaleFactor, weight: isFeatured ? .bold : .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            if canExpand {
                                Spacer()
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if isExpanded { expandedCategories.remove(category.title) } else { expandedCategories.insert(category.title) }
                                    }
                                } label: {
                                    Text(isExpanded ? "See less" : "See more")
                                        .font(.system(size: 12 * scaleFactor, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                            }
                        }

                        categoryGrid(isExpanded ? category.images
                                                : Array(category.images.prefix(categoryCollapseThreshold)))
                    }
                    // The first title must clear the scroll region's top edge to be readable.
                    .padding(.top, index == 0 ? 6 * scaleFactor : 0)
                }
            }

            if showPath || confirmButtonText != nil || isMultiSelect {
                VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                    if showPath || isMultiSelect {
                        if isMultiSelect {
                            ForEach(0..<multiSelectCount, id: \.self) { index in
                                if let path = pendingSelections[index] {
                                    HStack(spacing: 8 * scaleFactor) {
                                        Image(systemName: "display")
                                            .font(.system(size: 10 * scaleFactor))
                                            .foregroundStyle(.secondary)
                                        Text("Monitor \(index + 1):")
                                            .font(.system(size: 11 * scaleFactor, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        Text(URL(fileURLWithPath: path).lastPathComponent)
                                            .font(.system(size: 11 * scaleFactor))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        } else if let path = pendingSelections[0] ?? inspectState.wallpaperSelection[selectionKey] {
                            HStack(spacing: 8 * scaleFactor) {
                                Image(systemName: isConfirmed ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isConfirmed ? accentColor : .secondary)
                                Text(path)
                                    .font(.system(size: 11 * scaleFactor))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }

                    if let buttonText = confirmButtonText, !pendingSelections.isEmpty {
                        HStack {
                            Spacer()
                            Button(action: confirmSelection) {
                                Text(buttonText)
                                    .font(.system(size: 12 * scaleFactor, weight: .medium))
                                    .padding(.horizontal, 16 * scaleFactor)
                                    .padding(.vertical, 8 * scaleFactor)
                                    .background(isConfirmed ? palette.textMuted : accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6 * scaleFactor))
                            }
                            .buttonStyle(.plain)
                            .disabled(isConfirmed)
                        }
                    }
                }
                .padding(.top, 8 * scaleFactor)
            }
        }
        .onAppear {
            ThumbnailService.shared.preloadThumbnails(for: allImages.map { $0.thumbnail ?? $0.path })
        }
        .onDisappear {
            ThumbnailService.shared.releaseThumbnails()
            // Pending selections commit when the step transitions away.
            if !isConfirmed && !pendingSelections.isEmpty {
                confirmSelection()
            }
        }
    }

    private func handleTileSelection(_ path: String) {
        writeLog("WallpaperPicker: handleTileSelection '\(path)' confirmButton=\(confirmButtonText ?? "nil") multiSelect=\(isMultiSelect)", logLevel: .debug)
        if isMultiSelect {
            // The tile asks which display, so nothing is overwritten unseen.
            assigningPath = path
        } else if confirmButtonText != nil {
            pendingSelections[0] = path
            isConfirmed = false
        } else {
            selectWallpaper(0, path: path)
        }
    }

    private func confirmSelection() {
        isConfirmed = true

        if isMultiSelect {
            for (monitor, path) in pendingSelections.sorted(by: { $0.key < $1.key }) {
                selectWallpaper(monitor, path: path)
            }
        } else if let path = pendingSelections[0] {
            selectWallpaper(0, path: path)
        }
    }

    private func selectWallpaper(_ monitor: Int, path: String) {
        let key = isMultiSelect ? "\(selectionKey)_\(monitor)" : selectionKey
        inspectState.wallpaperSelection[key] = path
        writeLog("WallpaperPicker: Selected wallpaper '\(path)' for monitor \(monitor)", logLevel: .info)

        // The line scripts watch for: wallpaper:<key>:<monitor>:<path>
        inspectState.writeToInteractionLog("wallpaper:\(selectionKey):\(monitor):\(path)")
    }
}

/// One fixed-size wallpaper tile.
struct WallpaperTileView: View {
    @Environment(\.palette) private var palette
    let image: InspectConfig.WallpaperImage
    let isSelected: Bool
    let monitorIndices: [Int]  // monitors showing this wallpaper, when selected
    let imageFit: String
    let tileWidth: CGFloat
    let tileHeight: CGFloat
    let scaleFactor: CGFloat
    let accentColor: Color
    let onTap: () -> Void

    @ObservedObject private var thumbnailService = ThumbnailService.shared

    private var imagePath: String {
        image.thumbnail ?? image.path
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6 * scaleFactor) {
                imageContent
                    .frame(width: tileWidth, height: tileHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8 * scaleFactor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8 * scaleFactor)
                            .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2.5)
                    )
                    .overlay(
                        Group {
                            if isSelected {
                                if !monitorIndices.isEmpty {
                                    HStack(spacing: 2 * scaleFactor) {
                                        Image(systemName: "display")
                                            .font(.system(size: 10 * scaleFactor))
                                        Text(monitorIndices.map { "\($0 + 1)" }.joined(separator: ","))
                                            .font(.system(size: 11 * scaleFactor, weight: .bold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6 * scaleFactor)
                                    .padding(.vertical, 4 * scaleFactor)
                                    .background(accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 4 * scaleFactor))
                                    .padding(6 * scaleFactor)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(accentColor))
                                        .font(.system(size: 18 * scaleFactor))
                                        .padding(6 * scaleFactor)
                                }
                            }
                        },
                        alignment: .topTrailing
                    )
                    // Neutral shadow; selection reads via the ring.
                    .shadow(color: .black.opacity(isSelected ? 0.16 : 0.1),
                            radius: isSelected ? 5 : 4,
                            y: 2)

                if let title = image.title {
                    Text(title)
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: tileWidth)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var imageContent: some View {
        // `tile:` and `gradient:` sources are drawn, not loaded, so they are checked before the
        // file system.
        if let generated = GeneratedImageRef.parse(imagePath) {
            GeneratedImageView(ref: generated)
                .frame(width: tileWidth, height: tileHeight)
        } else if let nsImage = thumbnailService.thumbnail(for: imagePath) {
            Image(nsImage: nsImage)
                .resizable().scaledToFill()
                .frame(width: tileWidth, height: tileHeight)
                .clipped()
        } else if FileManager.default.fileExists(atPath: imagePath) {
            // Thumbnail still loading.
            Rectangle()
                .fill(palette.text.opacity(0.1))
                .overlay(
                    ProgressView()
                        .scaleEffect(0.6)
                )
                .task {
                    await thumbnailService.loadThumbnail(for: imagePath)
                }
        } else {
            Rectangle()
                .fill(palette.text.opacity(0.2))
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.system(size: 24 * scaleFactor))
                            .foregroundStyle(.secondary)
                        Text("Not found")
                            .font(.system(size: 9 * scaleFactor))
                            .foregroundStyle(.secondary)
                    }
                )
        }
    }
}
