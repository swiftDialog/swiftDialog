//
//  DetailOverlayView.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Configurable detail flyout overlay for Inspect mode
//  Supports rich content, system info, and customizable sizing
//

import SwiftUI
import Foundation

// MARK: - Size Configuration

/// Defines the available sizes for the detail overlay
enum DetailOverlaySize: String {
    case small
    case medium
    case large
    case full

    /// Width for the overlay
    var width: CGFloat {
        switch self {
        case .small: return 320
        case .medium: return 450
        case .large: return 600
        case .full: return 800
        }
    }

    /// Height for the overlay
    var height: CGFloat {
        switch self {
        case .small: return 400
        case .medium: return 550
        case .large: return 700
        case .full: return 900
        }
    }

    /// Whether to use sheet presentation (large/full) or popover (small/medium)
    var usesSheet: Bool {
        switch self {
        case .small, .medium: return false
        case .large, .full: return true
        }
    }
}

// MARK: - Detail Overlay View

struct DetailOverlayView: View {
    @ObservedObject var inspectState: InspectState
    let config: InspectConfig.DetailOverlayConfig
    let onClose: () -> Void

    /// Computed size from config
    private var overlaySize: DetailOverlaySize {
        DetailOverlaySize(rawValue: config.size ?? "medium") ?? .medium
    }

    /// Background color from config or default
    private var backgroundColor: Color {
        if let hexColor = config.backgroundColor {
            return Color(hex: hexColor)
        }
        return Color(NSColor.windowBackgroundColor)
    }

    /// Show dividers between sections
    private var showDividers: Bool {
        config.showDividers ?? true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            if showDividers {
                Divider()
            }

            // Scrollable content area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Custom content blocks
                    if let content = config.content, !content.isEmpty {
                        customContentSection(content)
                    }

                    // System info section (optional)
                    if config.showSystemInfo ?? true {
                        if showDividers && config.content != nil {
                            Divider()
                                .padding(.vertical, 8)
                        }
                        systemInfoSection
                    }

                    // Progress info section (optional)
                    if config.showProgressInfo ?? false {
                        if showDividers {
                            Divider()
                                .padding(.vertical, 8)
                        }
                        progressInfoSection
                    }
                }
                .padding(20)
            }

            if showDividers {
                Divider()
            }

            // Footer with close button
            footerView
        }
        .frame(width: overlaySize.width, height: overlaySize.height)
        .background(backgroundColor)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 12) {
            // Icon (if provided)
            if let iconString = config.icon {
                iconView(for: iconString, size: 32)
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(config.title ?? "Help")
                    .font(.title2)
                    .fontWeight(.bold)

                if let subtitle = config.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Close button (X)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Custom Content Section

    @ViewBuilder
    private func customContentSection(_ content: [InspectConfig.GuidanceContent]) -> some View {
        // Pass content blocks directly to GuidanceContentView
        // Template variable resolution happens via resolveTemplateVariables() in GuidanceContentView
        // which already calls through to the system template resolution
        GuidanceContentView(
            contentBlocks: content,
            scaleFactor: 1.0,
            iconBasePath: inspectState.config?.iconBasePath,
            inspectState: inspectState,
            itemId: "__detail_overlay__"
        )
    }

    // MARK: - System Info Section

    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Information")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            // Computer info with icon
            HStack(spacing: 12) {
                Image(nsImage: NSImage(named: NSImage.computerName) ?? NSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(getSystemInfo("computermodel"))
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Serial: \(getSystemInfo("serialnumber"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Text("\(getOSDisplayName())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )

            // User info
            if inspectState.config?.hideSystemDetails != true {
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(getSystemInfo("userfullname"))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(getSystemInfo("username"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
            }
        }
    }

    // MARK: - Progress Info Section

    private var progressInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Installation Progress")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                progressRow(label: "Total Items", value: "\(inspectState.items.count)")
                progressRow(label: "Completed", value: "\(inspectState.completedItems.count)",
                           valueColor: !inspectState.completedItems.isEmpty ? .green : .primary)
                progressRow(label: "Installing", value: "\(inspectState.downloadingItems.count)",
                           valueColor: !inspectState.downloadingItems.isEmpty ? .blue : .primary)

                let pending = inspectState.items.count - inspectState.completedItems.count - inspectState.downloadingItems.count
                progressRow(label: "Pending", value: "\(pending)", valueColor: .secondary)

                let progress = inspectState.items.isEmpty ? 0.0 : Double(inspectState.completedItems.count) / Double(inspectState.items.count)
                progressRow(label: "Progress", value: "\(Int(progress * 100))%",
                           valueColor: progress == 1.0 ? .green : .blue)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )

            // Currently installing items
            if !inspectState.downloadingItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Currently Installing")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)

                    ForEach(inspectState.items.filter { inspectState.downloadingItems.contains($0.id) }, id: \.id) { item in
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text(item.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
    }

    // MARK: - Footer View

    private var footerView: some View {
        HStack {
            Spacer()
            Button(action: onClose) {
                Text(config.closeButtonText ?? "Close")
                    .fontWeight(.medium)
            }
            .keyboardShortcut(.escape, modifiers: [])
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func iconView(for iconString: String, size: CGFloat) -> some View {
        if iconString.hasPrefix("sf=") {
            // SF Symbol with optional color: sf=icon.name,color=#hex
            let parts = iconString.dropFirst(3).components(separatedBy: ",")
            let symbolName = parts[0]
            let iconColor: Color = {
                if parts.count > 1, let colorPart = parts.first(where: { $0.hasPrefix("color=") }) {
                    let hex = String(colorPart.dropFirst(6))
                    return Color(hex: hex)
                }
                return .accentColor
            }()

            Image(systemName: symbolName)
                .font(.system(size: size))
                .foregroundStyle(iconColor)
        } else if iconString.contains("/") || iconString.contains(".") {
            // File path
            let expandedPath = (iconString as NSString).expandingTildeInPath
            if let nsImage = NSImage(contentsOfFile: expandedPath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                // Fallback to SF Symbol
                Image(systemName: "questionmark.circle")
                    .font(.system(size: size))
                    .foregroundStyle(.secondary)
            }
        } else {
            // Assume SF Symbol name
            Image(systemName: iconString)
                .font(.system(size: size))
                .foregroundStyle(Color.accentColor)
        }
    }

    private func progressRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(valueColor)
        }
    }

    // MARK: - System Info Helpers

    private func getSystemInfo(_ key: String) -> String {
        let systemInfo = getEnvironmentVars()
        return systemInfo[key] ?? "Unknown"
    }

    private func getOSDisplayName() -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osName = getSystemInfo("osname")
        return "\(osName) \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }

    /// Resolve template variables in content strings
    /// Supports: {{serialNumber}}, {{computerModel}}, {{computerName}}, {{userName}}, {{userFullName}}, {{osVersion}}, {{osName}}
    private func resolveSystemTemplateVariables(_ text: String) -> String {
        let systemInfo = getEnvironmentVars()
        var result = text

        // Map template variables to system info keys
        let templateMap: [String: String] = [
            "{{serialNumber}}": systemInfo["serialnumber"] ?? "Unknown",
            "{{computerModel}}": systemInfo["computermodel"] ?? "Unknown",
            "{{computerName}}": systemInfo["computername"] ?? "Unknown",
            "{{userName}}": systemInfo["username"] ?? "Unknown",
            "{{userFullName}}": systemInfo["userfullname"] ?? "Unknown",
            "{{osVersion}}": {
                let v = ProcessInfo.processInfo.operatingSystemVersion
                return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
            }(),
            "{{osName}}": systemInfo["osname"] ?? "macOS",
            "{{progress}}": {
                let progress = inspectState.items.isEmpty ? 0.0 : Double(inspectState.completedItems.count) / Double(inspectState.items.count)
                return "\(Int(progress * 100))%"
            }()
        ]

        for (template, value) in templateMap {
            result = result.replacingOccurrences(of: template, with: value)
        }

        return result
    }
}

// MARK: - Preview

#if DEBUG
struct DetailOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        let config = InspectConfig.DetailOverlayConfig(
            enabled: true,
            size: "medium",
            title: "Need Help?",
            subtitle: "Contact IT Support",
            icon: "questionmark.circle.fill",
            overlayIcon: nil,
            content: nil,
            showSystemInfo: true,
            showProgressInfo: true,
            closeButtonText: "Got it",
            backgroundColor: nil,
            showDividers: true
        )

        DetailOverlayView(
            inspectState: InspectState(),
            config: config,
            onClose: {}
        )
    }
}
#endif
