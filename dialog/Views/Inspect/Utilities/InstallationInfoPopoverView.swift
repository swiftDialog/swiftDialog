//
//  InstallationInfoPopoverView.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Enhanced installation info popover with system information
//  Shared component for all Inspect presets
//

import SwiftUI
import Foundation

struct InstallationInfoPopoverView: View {
    @ObservedObject var inspectState: InspectState

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            // Computer Model Header with Icon
            VStack(spacing: 8) {
                // Computer Icon (using actual device-specific icon like dialog --icon computer)
                Image(nsImage: NSImage(named: NSImage.computerName) ?? NSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)

                if inspectState.config?.hideSystemDetails != true {
                    // Computer Model
                    Text(getSystemInfo("computermodel"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    // Serial Number
                    Text(getSystemInfo("serialnumber"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    // Generic system info when details are hidden
                    Text("System Information Hidden")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                // OS Name + Version with Build Number
                Text("\(getOSDisplayName()) (\(getBuildNumber()))")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .padding(.bottom, 8)

            Divider()

            // User Information
            VStack(alignment: .center, spacing: 4) {
                if inspectState.config?.hideSystemDetails != true {
                    // Full Name
                    Text(getSystemInfo("userfullname"))
                        .font(.headline)
                        .fontWeight(.semibold)

                    // Unix Username with UID
                    HStack(spacing: 4) {
                        Text(getSystemInfo("username"))
                        Text("(UID: \(getUserID()))")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                    // Generic user info when details are hidden
                    Text("User Details Hidden")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 8)

            Divider()

            // Progress Overview
            VStack(alignment: .leading, spacing: 8) {
                Text("Progress Overview")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 6) {
                    EnhancedInfoRow(label: "Total Items", value: "\(inspectState.items.count)")
                    EnhancedInfoRow(label: "Completed", value: "\(inspectState.completedItems.count)",
                                  valueColor: !inspectState.completedItems.isEmpty ? .green : .primary)
                    EnhancedInfoRow(label: "Installing", value: "\(inspectState.downloadingItems.count)",
                                  valueColor: !inspectState.downloadingItems.isEmpty ? .blue : .primary)
                    EnhancedInfoRow(label: "Pending", value: "\(inspectState.items.count - inspectState.completedItems.count - inspectState.downloadingItems.count)",
                                  valueColor: .secondary)

                    let progress = inspectState.items.isEmpty ? 0.0 : Double(inspectState.completedItems.count) / Double(inspectState.items.count)
                    EnhancedInfoRow(label: "Progress", value: "\(Int(progress * 100))%",
                                  valueColor: progress == 1.0 ? .green : .blue)
                }
            }

            // Current Activity (if any items are installing)
            if !inspectState.downloadingItems.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Currently Installing")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(inspectState.items.filter { inspectState.downloadingItems.contains($0.id) }, id: \.id) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                            Text(item.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 340)
        .frame(maxHeight: 500)
    }

    /// Get system information using swiftDialog's built-in variables
    private func getSystemInfo(_ key: String) -> String {
        let systemInfo = getEnvironmentVars()
        return systemInfo[key] ?? "Unknown"
    }

    /// Get OS display name with version using native Foundation APIs
    private func getOSDisplayName() -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        // Use the system-provided OS name from environment variables
        let osName = getSystemInfo("osname")
        return "\(osName) \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }

    /// Get macOS build number
    private func getBuildNumber() -> String {
        // Still use sw_vers for build number as ProcessInfo doesn't provide it
        return shell("sw_vers -buildVersion").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get current user's UID using native Foundation API
    private func getUserID() -> String {
        // Using POSIX getuid() for the actual Unix UID
        let uid = getuid()
        return String(uid)
    }

    /// Get current user's effective GID
    private func getUserGID() -> String {
        let gid = getgid()
        return String(gid)
    }
}

/// Enhanced info row component with better styling and color support
struct EnhancedInfoRow: View {
    let label: String
    let value: String
    let valueColor: Color

    init(label: String, value: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(valueColor)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}