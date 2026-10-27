//
//  DetailOverlayView.swift
//  dialog
//
//  The configurable detail sheet (`detailOverlay` in the config): authored content blocks plus
//  optional generated system-info and progress sections.
//

import SwiftUI
import Foundation

// MARK: - Size Configuration

/// The `size` values of the detail overlay.
enum DetailOverlaySize: String {
    case small
    case medium
    case large
    case full

    var width: CGFloat {
        switch self {
        case .small: return 320
        case .medium: return 450
        case .large: return 600
        case .full: return 800
        }
    }

    /// A height cap: the sheet hugs its content up to this, except that generated sections take
    /// the full height and scroll.
    var height: CGFloat {
        switch self {
        case .small: return 400
        case .medium: return 550
        case .large: return 700
        case .full: return 900
        }
    }

    /// Sheet presentation for large and full, popover for small and medium.
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
    @Environment(\.inspectLocalization) private var l10n
    @Environment(\.palette) private var palette

    private var overlaySize: DetailOverlaySize {
        DetailOverlaySize(rawValue: config.size ?? "medium") ?? .medium
    }

    private var backgroundColor: Color {
        if let hexColor = config.backgroundColor {
            return Color(hex: hexColor)
        }
        return Color(NSColor.windowBackgroundColor)
    }

    private var showDividers: Bool {
        config.showDividers ?? true
    }

    /// Generated sections have no authored length, so the sheet scrolls at full height instead of clipping.
    private var hasGeneratedSections: Bool {
        (config.showSystemInfo ?? true) || (config.showProgressInfo ?? false)
    }

    var body: some View {
        DetailSheetShell(
            backLabel: config.closeButtonText ?? l10n("ui.detailSheetBack", "Back"),
            accentColor: inspectState.config?.highlightColor.map { Color(hex: $0) } ?? .accentColor,
            width: overlaySize.width,
            minHeight: min(DetailSheetMetrics.minHeight, overlaySize.height),
            maxHeight: overlaySize.height,
            background: config.backgroundColor.map { Color(hex: $0) },
            scrolls: hasGeneratedSections,
            onClose: onClose
        ) {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock

                if let content = config.content, !content.isEmpty {
                    customContentSection(content)
                }

                if config.showSystemInfo ?? true {
                    if showDividers && config.content != nil {
                        Divider()
                            .padding(.vertical, 8)
                    }
                    systemInfoSection
                }

                if config.showProgressInfo ?? false {
                    if showDividers {
                        Divider()
                            .padding(.vertical, 8)
                    }
                    progressInfoSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Title

    /// Title and subtitle inside the content, without an icon; `config.icon` is drawn by the opener.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(config.title ?? l10n("ui.detailOverlayTitle", "Help"))
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.3)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle = config.subtitle {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Custom Content Section

    @ViewBuilder
    private func customContentSection(_ content: [InspectConfig.GuidanceContent]) -> some View {
        // GuidanceContentView resolves template variables itself.
        GuidanceContentView(
            contentBlocks: content,
            scaleFactor: 1.0,
            iconBasePath: inspectState.config?.iconBasePath,
            inspectState: inspectState,
            itemId: "__detail_overlay__",
            accentColor: inspectState.config?.highlightColor.map { Color(hex: $0) }
        )
    }

    // MARK: - System Info Section

    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n("ui.detailOverlaySystemInfo", "System Information"))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(nsImage: NSImage(named: NSImage.computerName) ?? NSImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(getSystemInfo("computermodel"))
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(l10n("ui.detailOverlaySerial", "Serial: {serial}")
                        .replacingOccurrences(of: "{serial}", with: getSystemInfo("serialnumber")))
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
            Text(l10n("ui.detailOverlayInstallProgress", "Installation Progress"))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                progressRow(label: "Total Items", value: "\(inspectState.items.count)")
                progressRow(label: "Completed", value: "\(inspectState.completedItems.count)",
                           valueColor: !inspectState.completedItems.isEmpty ? palette.success : palette.text)
                progressRow(label: "Installing", value: "\(inspectState.downloadingItems.count)",
                           valueColor: !inspectState.downloadingItems.isEmpty ? palette.info : palette.text)

                let pending = inspectState.items.count - inspectState.completedItems.count - inspectState.downloadingItems.count
                progressRow(label: "Pending", value: "\(pending)", valueColor: .secondary)

                let progress = inspectState.items.isEmpty ? 0.0 : Double(inspectState.completedItems.count) / Double(inspectState.items.count)
                progressRow(label: "Progress", value: "\(Int(progress * 100))%",
                           valueColor: progress == 1.0 ? palette.success : palette.info)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )

            if !inspectState.downloadingItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    // The header owns the only spinner; rows get a static dot.
                    HStack(spacing: 8) {
                        Text(l10n("ui.detailOverlayCurrentlyInstalling", "Currently Installing"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(palette.info)
                        ProgressView()
                            .controlSize(.small)
                        Spacer()
                    }

                    ForEach(inspectState.items.filter { inspectState.downloadingItems.contains($0.id) }, id: \.id) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(palette.info)
                                .frame(width: 8, height: 8)
                                .padding(3)
                                .background(Circle().fill(palette.info.opacity(0.18)))
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
                        .fill(palette.info.opacity(0.1))
                )
            }
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

    /// User-facing fallback for a missing system value, so it is localized.
    private var unknownValue: String { l10n("ui.detailOverlayUnknown", "Unknown") }

    private func getSystemInfo(_ key: String) -> String {
        let systemInfo = getEnvironmentVars()
        return systemInfo[key] ?? unknownValue
    }

    private func getOSDisplayName() -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osName = getSystemInfo("osname")
        return "\(osName) \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
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
