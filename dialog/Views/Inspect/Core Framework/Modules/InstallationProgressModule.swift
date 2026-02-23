//
//  InstallationProgressModule.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 22/01/2026
//
//  Installation progress UI components for Inspect presets
//
//  This module provides reusable views for displaying software installation progress:
//  - Item cards with icon, name, status, and progress bar
//  - List and grid layouts for multiple items
//  - Summary view for overall progress
//  - Frameless overlay variants for Preset5
//
//  Used by: Preset6, Preset5 (and future presets)
//

import SwiftUI

// MARK: - Installation Layout Style

/// Layout style for installation progress display
enum InstallationLayout: String, CaseIterable {
    case list       // Vertical list of items (compact)
    case grid       // Grid of item cards
    case cards      // Large cards with more detail
}

// MARK: - Installation Progress Configuration

/// Configuration for installation progress display
struct InstallationProgressConfiguration {
    let layout: InstallationLayout
    let highlightColor: Color
    let scaleFactor: CGFloat
    let showSummary: Bool
    let showIcons: Bool
    let showProgressBars: Bool
    let columns: Int

    init(
        layout: InstallationLayout = .list,
        highlightColor: Color = .accentColor,
        scaleFactor: CGFloat = 1.0,
        showSummary: Bool = true,
        showIcons: Bool = true,
        showProgressBars: Bool = true,
        columns: Int = 2
    ) {
        self.layout = layout
        self.highlightColor = highlightColor
        self.scaleFactor = scaleFactor
        self.showSummary = showSummary
        self.showIcons = showIcons
        self.showProgressBars = showProgressBars
        self.columns = columns
    }
}

// MARK: - Installation Item Data

/// Data model for an installation item
struct InstallationItemData: Identifiable {
    let id: String
    let displayName: String
    let icon: String?
    let iconPath: String?
    let status: MonitoringItemStatus
    let progress: Double?
    let statusMessage: String?

    init(
        id: String,
        displayName: String,
        icon: String? = nil,
        iconPath: String? = nil,
        status: MonitoringItemStatus = .pending,
        progress: Double? = nil,
        statusMessage: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.icon = icon
        self.iconPath = iconPath
        self.status = status
        self.progress = progress
        self.statusMessage = statusMessage
    }

    /// Create from InspectConfig.ItemConfig
    init(from item: InspectConfig.ItemConfig, status: MonitoringItemStatus = .pending, progress: Double? = nil, statusMessage: String? = nil) {
        self.id = item.id
        self.displayName = item.displayName
        self.icon = item.icon
        self.iconPath = item.icon
        self.status = status
        self.progress = progress
        self.statusMessage = statusMessage
    }
}

// MARK: - Installation Progress View

/// Main view for displaying installation progress for multiple items
///
/// Supports multiple layouts (list, grid, cards) and integrates with
/// UnifiedMonitoringService for real-time status updates.
///
/// ## Usage Example
/// ```swift
/// InstallationProgressView(
///     items: installationItems,
///     configuration: .init(layout: .cards)
/// )
/// ```
struct InstallationProgressView: View {
    let items: [InstallationItemData]
    let configuration: InstallationProgressConfiguration
    let onItemTapped: ((InstallationItemData) -> Void)?

    init(
        items: [InstallationItemData],
        configuration: InstallationProgressConfiguration = InstallationProgressConfiguration(),
        onItemTapped: ((InstallationItemData) -> Void)? = nil
    ) {
        self.items = items
        self.configuration = configuration
        self.onItemTapped = onItemTapped
    }

    private var scaleFactor: CGFloat { configuration.scaleFactor }

    var body: some View {
        VStack(spacing: 16 * scaleFactor) {
            // Summary header
            if configuration.showSummary {
                InstallationSummaryView(
                    items: items,
                    highlightColor: configuration.highlightColor,
                    scaleFactor: scaleFactor
                )
            }

            // Items display
            switch configuration.layout {
            case .list:
                InstallationItemList(
                    items: items,
                    configuration: configuration,
                    onItemTapped: onItemTapped
                )
            case .grid:
                InstallationItemGrid(
                    items: items,
                    configuration: configuration,
                    onItemTapped: onItemTapped
                )
            case .cards:
                InstallationItemCards(
                    items: items,
                    configuration: configuration,
                    onItemTapped: onItemTapped
                )
            }
        }
    }
}

// MARK: - Installation Summary View

/// Displays summary statistics for installation progress
struct InstallationSummaryView: View {
    let items: [InstallationItemData]
    let highlightColor: Color
    let scaleFactor: CGFloat

    init(
        items: [InstallationItemData],
        highlightColor: Color = .accentColor,
        scaleFactor: CGFloat = 1.0
    ) {
        self.items = items
        self.highlightColor = highlightColor
        self.scaleFactor = scaleFactor
    }

    private var completedCount: Int {
        items.filter { $0.status == .completed }.count
    }

    private var failedCount: Int {
        items.filter {
            if case .failed = $0.status { return true }
            return false
        }.count
    }

    private var inProgressCount: Int {
        items.filter { $0.status.isActive }.count
    }

    private var progressPercentage: Double {
        guard !items.isEmpty else { return 0 }
        return Double(completedCount) / Double(items.count) * 100
    }

    var body: some View {
        VStack(spacing: 12 * scaleFactor) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8 * scaleFactor)

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(failedCount > 0 ? Color.orange : highlightColor)
                        .frame(width: geometry.size.width * CGFloat(progressPercentage / 100), height: 8 * scaleFactor)
                        .animation(.easeInOut(duration: 0.3), value: progressPercentage)
                }
            }
            .frame(height: 8 * scaleFactor)

            // Stats row
            HStack {
                Label("\(completedCount) of \(items.count)", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if inProgressCount > 0 {
                    Label("\(inProgressCount) in progress", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(.blue)
                }

                if failedCount > 0 {
                    Label("\(failedCount) failed", systemImage: "xmark.circle.fill")
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, 16 * scaleFactor)
        .padding(.vertical, 12 * scaleFactor)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 10))
    }
}

// MARK: - Installation Item List

/// Vertical list of installation items (compact view)
struct InstallationItemList: View {
    let items: [InstallationItemData]
    let configuration: InstallationProgressConfiguration
    let onItemTapped: ((InstallationItemData) -> Void)?

    private var scaleFactor: CGFloat { configuration.scaleFactor }

    var body: some View {
        VStack(spacing: 8 * scaleFactor) {
            ForEach(items) { item in
                InstallationItemRow(
                    item: item,
                    configuration: configuration
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onItemTapped?(item)
                }
            }
        }
    }
}

// MARK: - Installation Item Row

/// Single row in installation list
struct InstallationItemRow: View {
    let item: InstallationItemData
    let configuration: InstallationProgressConfiguration

    private var scaleFactor: CGFloat { configuration.scaleFactor }
    private var highlightColor: Color { configuration.highlightColor }

    var body: some View {
        HStack(spacing: 12 * scaleFactor) {
            // Icon
            if configuration.showIcons {
                itemIcon
            }

            // Name and status
            VStack(alignment: .leading, spacing: 4 * scaleFactor) {
                Text(item.displayName)
                    .font(.system(size: 14 * scaleFactor, weight: .medium))
                    .foregroundStyle(.primary)

                if let message = item.statusMessage {
                    Text(message)
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Status indicator
            statusIndicator
        }
        .padding(.horizontal, 12 * scaleFactor)
        .padding(.vertical, 10 * scaleFactor)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    @ViewBuilder
    private var itemIcon: some View {
        Group {
            if let iconPath = item.iconPath {
                if iconPath.hasPrefix("SF=") {
                    let symbolName = String(iconPath.dropFirst(3))
                    Image(systemName: symbolName)
                        .font(.system(size: 20 * scaleFactor))
                        .foregroundStyle(highlightColor)
                } else if let nsImage = NSImage(contentsOfFile: iconPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 20 * scaleFactor))
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 20 * scaleFactor))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 32 * scaleFactor, height: 32 * scaleFactor)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch item.status {
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 16 * scaleFactor))
                .foregroundStyle(.secondary)

        case .downloading:
            ProgressView()
                .controlSize(.small)
                .tint(.blue)

        case .installing:
            if let progress = item.progress {
                CircularProgressIndicator(progress: progress, size: 20 * scaleFactor, color: highlightColor)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(highlightColor)
            }

        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16 * scaleFactor))
                .foregroundStyle(.green)

        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16 * scaleFactor))
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Installation Item Grid

/// Grid layout for installation items
struct InstallationItemGrid: View {
    let items: [InstallationItemData]
    let configuration: InstallationProgressConfiguration
    let onItemTapped: ((InstallationItemData) -> Void)?

    private var scaleFactor: CGFloat { configuration.scaleFactor }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12 * scaleFactor), count: configuration.columns)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12 * scaleFactor) {
            ForEach(items) { item in
                InstallationItemGridCell(
                    item: item,
                    configuration: configuration
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onItemTapped?(item)
                }
            }
        }
    }
}

// MARK: - Installation Item Grid Cell

/// Single cell in installation grid
struct InstallationItemGridCell: View {
    let item: InstallationItemData
    let configuration: InstallationProgressConfiguration

    private var scaleFactor: CGFloat { configuration.scaleFactor }
    private var highlightColor: Color { configuration.highlightColor }

    var body: some View {
        VStack(spacing: 8 * scaleFactor) {
            // Icon with status overlay
            ZStack(alignment: .bottomTrailing) {
                itemIcon
                    .frame(width: 48 * scaleFactor, height: 48 * scaleFactor)

                statusBadge
                    .offset(x: 4 * scaleFactor, y: 4 * scaleFactor)
            }

            // Name
            Text(item.displayName)
                .font(.system(size: 12 * scaleFactor, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Progress bar (if applicable)
            if configuration.showProgressBars, item.status.isActive {
                if let progress = item.progress {
                    ProgressView(value: progress, total: 100)
                        .tint(highlightColor)
                        .frame(width: 60 * scaleFactor)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .tint(highlightColor)
                }
            }
        }
        .padding(12 * scaleFactor)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(.rect(cornerRadius: 12))
    }

    @ViewBuilder
    private var itemIcon: some View {
        Group {
            if let iconPath = item.iconPath {
                if iconPath.hasPrefix("SF=") {
                    let symbolName = String(iconPath.dropFirst(3))
                    Image(systemName: symbolName)
                        .font(.system(size: 28 * scaleFactor))
                        .foregroundStyle(highlightColor)
                } else if let nsImage = NSImage(contentsOfFile: iconPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 28 * scaleFactor))
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 28 * scaleFactor))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14 * scaleFactor))
                .foregroundStyle(.green)
                .background(Circle().fill(.white).padding(-2))

        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14 * scaleFactor))
                .foregroundStyle(.red)
                .background(Circle().fill(.white).padding(-2))

        case .downloading, .installing:
            Circle()
                .fill(.blue)
                .frame(width: 12 * scaleFactor, height: 12 * scaleFactor)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: 2)
                )

        case .pending:
            EmptyView()
        }
    }
}

// MARK: - Installation Item Cards

/// Large card layout for installation items
struct InstallationItemCards: View {
    let items: [InstallationItemData]
    let configuration: InstallationProgressConfiguration
    let onItemTapped: ((InstallationItemData) -> Void)?

    private var scaleFactor: CGFloat { configuration.scaleFactor }

    var body: some View {
        VStack(spacing: 12 * scaleFactor) {
            ForEach(items) { item in
                InstallationItemCard(
                    item: item,
                    configuration: configuration
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onItemTapped?(item)
                }
            }
        }
    }
}

// MARK: - Installation Item Card

/// Large card for single installation item
struct InstallationItemCard: View {
    let item: InstallationItemData
    let configuration: InstallationProgressConfiguration

    private var scaleFactor: CGFloat { configuration.scaleFactor }
    private var highlightColor: Color { configuration.highlightColor }

    var body: some View {
        HStack(spacing: 16 * scaleFactor) {
            // Large icon
            itemIcon
                .frame(width: 64 * scaleFactor, height: 64 * scaleFactor)

            // Content
            VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                Text(item.displayName)
                    .font(.system(size: 16 * scaleFactor, weight: .semibold))
                    .foregroundStyle(.primary)

                if let message = item.statusMessage {
                    Text(message)
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Progress bar
                if configuration.showProgressBars && item.status.isActive {
                    if let progress = item.progress {
                        VStack(alignment: .leading, spacing: 4 * scaleFactor) {
                            ProgressView(value: progress, total: 100)
                                .tint(highlightColor)

                            Text("\(Int(progress))%")
                                .font(.system(size: 11 * scaleFactor))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .tint(highlightColor)
                    }
                }
            }

            Spacer()

            // Status indicator
            statusIndicator
        }
        .padding(16 * scaleFactor)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    @ViewBuilder
    private var itemIcon: some View {
        Group {
            if let iconPath = item.iconPath {
                if iconPath.hasPrefix("SF=") {
                    let symbolName = String(iconPath.dropFirst(3))
                    Image(systemName: symbolName)
                        .font(.system(size: 36 * scaleFactor))
                        .foregroundStyle(highlightColor)
                } else if let nsImage = NSImage(contentsOfFile: iconPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 36 * scaleFactor))
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 36 * scaleFactor))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch item.status {
        case .pending:
            VStack(spacing: 4 * scaleFactor) {
                Image(systemName: "clock")
                    .font(.system(size: 24 * scaleFactor))
                    .foregroundStyle(.secondary)
                Text("Pending")
                    .font(.system(size: 10 * scaleFactor))
                    .foregroundStyle(.secondary)
            }

        case .downloading:
            VStack(spacing: 4 * scaleFactor) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(.blue)
                Text("Downloading")
                    .font(.system(size: 10 * scaleFactor))
                    .foregroundStyle(.blue)
            }

        case .installing:
            VStack(spacing: 4 * scaleFactor) {
                if let progress = item.progress {
                    CircularProgressIndicator(progress: progress, size: 28 * scaleFactor, color: highlightColor)
                } else {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(highlightColor)
                }
                Text("Installing")
                    .font(.system(size: 10 * scaleFactor))
                    .foregroundStyle(highlightColor)
            }

        case .completed:
            VStack(spacing: 4 * scaleFactor) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28 * scaleFactor))
                    .foregroundStyle(.green)
                Text("Complete")
                    .font(.system(size: 10 * scaleFactor))
                    .foregroundStyle(.green)
            }

        case .failed(let reason):
            VStack(spacing: 4 * scaleFactor) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28 * scaleFactor))
                    .foregroundStyle(.red)
                Text(reason ?? "Failed")
                    .font(.system(size: 10 * scaleFactor))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Circular Progress View

/// Small circular progress indicator
struct CircularProgressIndicator: View {
    let progress: Double
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 3)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: progress / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: progress)
        }
    }
}

// MARK: - Installation Overlay View

/// Full-screen installation progress overlay for frameless presets
///
/// Used by Preset5 and other frameless presets to display installation
/// progress as an overlay on top of existing content.
struct InstallationOverlayView: View {
    let items: [InstallationItemData]
    let title: String
    let subtitle: String?
    let configuration: InstallationProgressConfiguration
    let onComplete: (() -> Void)?
    let onCancel: (() -> Void)?

    @State private var showCancelButton = false

    init(
        items: [InstallationItemData],
        title: String = "Installing Your Apps",
        subtitle: String? = nil,
        configuration: InstallationProgressConfiguration = InstallationProgressConfiguration(layout: .cards),
        onComplete: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.items = items
        self.title = title
        self.subtitle = subtitle
        self.configuration = configuration
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    private var scaleFactor: CGFloat { configuration.scaleFactor }

    private var isComplete: Bool {
        items.allSatisfy { $0.status.isTerminal }
    }

    private var hasFailures: Bool {
        items.contains { if case .failed = $0.status { return true }; return false }
    }

    var body: some View {
        VStack(spacing: 24 * scaleFactor) {
            // Header
            VStack(spacing: 8 * scaleFactor) {
                Text(title)
                    .font(.system(size: 24 * scaleFactor, weight: .bold))
                    .foregroundStyle(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14 * scaleFactor))
                        .foregroundStyle(.secondary)
                }
            }

            // Progress content
            InstallationProgressView(
                items: items,
                configuration: configuration
            )

            // Footer buttons
            if isComplete || showCancelButton {
                HStack(spacing: 16 * scaleFactor) {
                    if !isComplete, let onCancel = onCancel {
                        Button("Cancel") {
                            onCancel()
                        }
                        .buttonStyle(.bordered)
                    }

                    if isComplete, let onComplete = onComplete {
                        Button(hasFailures ? "Continue Anyway" : "Continue") {
                            onComplete()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(hasFailures ? .orange : configuration.highlightColor)
                    }
                }
            }
        }
        .padding(32 * scaleFactor)
        .frame(maxWidth: 600 * scaleFactor)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .onAppear {
            // Show cancel button after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    showCancelButton = true
                }
            }
        }
    }
}

// MARK: - Extension for Status Comparison

extension MonitoringItemStatus {
    /// Check equality ignoring associated values
    static func == (lhs: MonitoringItemStatus, rhs: MonitoringItemStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending): return true
        case (.completed, .completed): return true
        case (.downloading, .downloading): return true
        case (.installing, .installing): return true
        case (.failed, .failed): return true
        default: return false
        }
    }
}
