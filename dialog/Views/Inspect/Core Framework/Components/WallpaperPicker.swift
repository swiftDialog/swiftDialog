//
//  WallpaperPicker.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/01/2026
//
//  Extracted from PresetCommonHelpers.swift
//  Wallpaper selection UI component
//

import SwiftUI

// MARK: - Wallpaper Picker View

/// Displays categorized wallpaper images for selection
/// Selection is stored in InspectState.wallpaperSelection and outputs full path to be used by tools like desktoppr CLI
struct WallpaperPickerView: View {
    /// Layout mode for wallpaper display
    enum WallpaperLayout {
        case categories  // Current: vertical stack of category rows
        case grid        // Flat grid of all images
        case row         // Single horizontal row
    }

    let categories: [InspectConfig.WallpaperCategory]
    let columns: Int  // Now used as a hint for tile width calculation
    let imageFit: String  // "fill" | "fit"
    let thumbnailHeight: Double
    let selectionKey: String
    let showPath: Bool
    let confirmButtonText: String?  // Optional confirm button text
    let multiSelectCount: Int  // Number of monitors (0 = single select)
    let scaleFactor: CGFloat
    var centered: Bool = false  // Center-align content (for Preset5)
    var layout: WallpaperLayout = .categories  // Layout mode (default: categories for backwards compatibility)
    @ObservedObject var inspectState: InspectState
    let itemId: String

    @State private var pendingSelections: [Int: String] = [:]  // Monitor index -> path
    @State private var currentMonitor: Int = 0  // Currently selecting for this monitor
    @State private var isConfirmed: Bool = false

    private var isMultiSelect: Bool { multiSelectCount > 1 }

    // Fixed tile width based on 16:10 aspect ratio (common wallpaper ratio)
    private var tileWidth: CGFloat {
        thumbnailHeight * 1.6 * scaleFactor
    }

    private var tileHeight: CGFloat {
        thumbnailHeight * scaleFactor
    }

    private var accentColor: Color {
        if let hex = inspectState.config?.highlightColor {
            return Color(hex: hex)
        }
        return .accentColor
    }

    /// Flattened list of all images across all categories (for grid/row layouts)
    private var allImages: [InspectConfig.WallpaperImage] {
        categories.flatMap { $0.images }
    }

    // Get all monitor indices for a selected path (supports same wallpaper on multiple monitors)
    private func monitorIndices(for path: String) -> [Int] {
        if isMultiSelect {
            return pendingSelections.filter { $0.value == path }.map { $0.key }.sorted()
        } else if pendingSelections[0] == path || inspectState.wallpaperSelection[selectionKey] == path {
            return [0]
        }
        return []
    }

    // Check if a path is currently selected
    private func isSelected(_ path: String) -> Bool {
        if confirmButtonText != nil || isMultiSelect {
            return pendingSelections.values.contains(path)
        } else {
            return inspectState.wallpaperSelection[selectionKey] == path
        }
    }

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 20 * scaleFactor) {
            // Multi-select monitor picker
            if isMultiSelect {
                HStack(spacing: 8 * scaleFactor) {
                    Text("Select for:")
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(.secondary)

                    ForEach(0..<multiSelectCount, id: \.self) { index in
                        Button(action: { currentMonitor = index }) {
                            HStack(spacing: 4 * scaleFactor) {
                                Image(systemName: "display")
                                    .font(.system(size: 10 * scaleFactor))
                                Text("Monitor \(index + 1)")
                                    .font(.system(size: 11 * scaleFactor, weight: .medium))
                                if pendingSelections[index] != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10 * scaleFactor))
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(.horizontal, 10 * scaleFactor)
                            .padding(.vertical, 6 * scaleFactor)
                            .background(currentMonitor == index ? accentColor : Color.gray.opacity(0.2))
                            .foregroundStyle(currentMonitor == index ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6 * scaleFactor))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 4 * scaleFactor)
            }

            // Layout modes
            switch layout {
            case .grid:
                // Flat grid - all images in specified number of columns
                let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12 * scaleFactor), count: columns)
                LazyVGrid(columns: gridColumns, spacing: 12 * scaleFactor) {
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

            case .row:
                // Single horizontal row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12 * scaleFactor) {
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
                // Existing category-based layout
                ForEach(categories, id: \.title) { category in
                    VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                        // Category title
                        Text(category.title)
                            .font(.system(size: 13 * scaleFactor, weight: .semibold))
                            .foregroundStyle(.secondary)

                        // Horizontal scrolling row for this category
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12 * scaleFactor) {
                                ForEach(category.images, id: \.path) { image in
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
                            .padding(.horizontal, 2)  // Small padding for shadow visibility
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            // Bottom section: selections and/or confirm button
            if showPath || confirmButtonText != nil || isMultiSelect {
                VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                    // Show selections
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

                    // Confirm button
                    if let buttonText = confirmButtonText, !pendingSelections.isEmpty {
                        HStack {
                            Spacer()
                            Button(action: confirmSelection) {
                                Text(buttonText)
                                    .font(.system(size: 12 * scaleFactor, weight: .medium))
                                    .padding(.horizontal, 16 * scaleFactor)
                                    .padding(.vertical, 8 * scaleFactor)
                                    .background(isConfirmed ? Color.gray : accentColor)
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
        .onDisappear {
            // Auto-commit any pending selections when the step transitions away
            if !isConfirmed && !pendingSelections.isEmpty {
                confirmSelection()
            }
        }
    }

    private func handleTileSelection(_ path: String) {
        writeLog("WallpaperPicker: handleTileSelection '\(path)' confirmButton=\(confirmButtonText ?? "nil") multiSelect=\(isMultiSelect)", logLevel: .debug)
        if isMultiSelect {
            // Multi-select: assign to current monitor
            // Same wallpaper can be assigned to multiple monitors
            pendingSelections[currentMonitor] = path
            isConfirmed = false

            // Auto-advance to next unselected monitor
            if let nextEmpty = (0..<multiSelectCount).first(where: { pendingSelections[$0] == nil }) {
                currentMonitor = nextEmpty
            }
        } else if confirmButtonText != nil {
            // Single select with confirm: set as pending
            pendingSelections[0] = path
            isConfirmed = false
        } else {
            // Single select without confirm: immediate
            selectWallpaper(0, path: path)
        }
    }

    private func confirmSelection() {
        isConfirmed = true

        if isMultiSelect {
            // Output all monitor selections
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

        // Write to interaction log for external script to monitor and apply immediately
        // Format: wallpaper:<key>:<monitor>:<path>
        inspectState.writeToInteractionLog("wallpaper:\(selectionKey):\(monitor):\(path)")
    }
}

/// Individual wallpaper tile in the picker - fixed size for consistent layout
struct WallpaperTileView: View {
    let image: InspectConfig.WallpaperImage
    let isSelected: Bool
    let monitorIndices: [Int]  // Monitor indices if selected (supports same wallpaper on multiple monitors)
    let imageFit: String
    let tileWidth: CGFloat
    let tileHeight: CGFloat
    let scaleFactor: CGFloat
    let accentColor: Color
    let onTap: () -> Void

    private var imagePath: String {
        image.thumbnail ?? image.path
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6 * scaleFactor) {
                // Image content with fixed dimensions
                imageContent
                    .frame(width: tileWidth, height: tileHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8 * scaleFactor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8 * scaleFactor)
                            .stroke(isSelected ? accentColor : Color.clear, lineWidth: 3)
                    )
                    .overlay(
                        // Show monitor badge(s) or checkmark
                        Group {
                            if isSelected {
                                if !monitorIndices.isEmpty {
                                    // Multi-select: show monitor number(s)
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
                                    // Single select: show checkmark
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
                    .shadow(color: isSelected ? accentColor.opacity(0.3) : .black.opacity(0.1),
                            radius: isSelected ? 8 : 4,
                            y: 2)

                // Optional title - fixed width to match tile
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
        if let nsImage = NSImage(contentsOfFile: imagePath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)  // Always fill to ensure consistent sizing
                .frame(width: tileWidth, height: tileHeight)
                .clipped()
        } else {
            // Placeholder for missing image
            Rectangle()
                .fill(Color.gray.opacity(0.2))
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
