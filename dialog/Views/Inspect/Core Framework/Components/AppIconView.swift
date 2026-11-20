//
//  AppIconView.swift
//  dialog
//
//  An app's icon with its install state badged on it. Icon ladder: the config's icon, else the
//  installed app's own icon, else a placeholder that reads as absent.
//

import AppKit
import SwiftUI

struct AppIconView: View {
    /// Config-supplied icon: a file path, or `SF=symbol`. Wins when present.
    let iconPath: String?
    /// Bundle identifier, resolved through LaunchServices wherever the app landed.
    let bundleId: String?
    /// Filesystem paths, the fallback when there is no bundle id.
    let paths: [String]
    let size: CGFloat
    /// nil draws no badge.
    let status: StepStatus?
    let accent: Color
    var basePath: String?

    private var cornerRadius: CGFloat { size * 0.24 }

    /// A missing app is dimmed, never hidden.
    private var isMissing: Bool {
        if case .some(.pending) = status { return true }
        return false
    }

    var body: some View {
        iconImage
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .opacity(isMissing ? 0.42 : 1)
            .overlay(alignment: .bottomTrailing) { badge }
            .accessibilityLabel(accessibilityText)
    }

    // MARK: - The ladder

    @ViewBuilder
    private var iconImage: some View {
        if let iconPath, !iconPath.isEmpty {
            AsyncImageView(iconPath: iconPath, basePath: basePath,
                           maxWidth: size, maxHeight: size,
                           fallback: { installedOrPlaceholder })
        } else {
            installedOrPlaceholder
        }
    }

    @ViewBuilder
    private var installedOrPlaceholder: some View {
        if let icon = installedAppIcon {
            Image(nsImage: icon).resizable().interpolation(.high)
        } else {
            placeholder
        }
    }

    /// The installed app's own icon; nil when it is not on this Mac.
    private var installedAppIcon: NSImage? {
        if let bundleId, !bundleId.isEmpty,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let existing = paths.first(where: {
            FileManager.default.fileExists(atPath: ($0 as NSString).expandingTildeInPath)
        }) {
            return NSWorkspace.shared.icon(forFile: (existing as NSString).expandingTildeInPath)
        }
        return nil
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.primary.opacity(0.06))
            .overlay(
                Image(systemName: "app.dashed")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.46, height: size * 0.46)
                    .foregroundStyle(.secondary)
            )
    }

    // MARK: - State on the tile

    @ViewBuilder
    private var badge: some View {
        if let status {
            // An explicit size is what lets the badge scale with the tile.
            StatusIndicatorCircle(
                status: status,
                accent: accent,
                size: badgeSize,
                activeStyle: .spinner,
                showPending: false          // dimming already says "missing"
            )
                .background(Circle().fill(Color(NSColor.windowBackgroundColor)))
                .offset(x: badgeSize * 0.28, y: badgeSize * 0.28)
        }
    }

    private var badgeSize: CGFloat { max(12, size * 0.36) }

    private var accessibilityText: String {
        guard let status else { return "" }
        switch status {
        case .completed:   return "installed"
        case .failed:      return "failed"
        case .active:      return "installing"
        case .pending:     return "not installed"
        case .skipped:     return "skipped"
        }
    }
}
