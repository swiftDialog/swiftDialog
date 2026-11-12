//
//  InstallationInfoPopoverView.swift
//  dialog
//
//  Installation info popover with device, user and progress summary, shared by the inspect presets.
//

import SwiftUI
import Foundation

struct InstallationInfoPopoverView: View {
    @ObservedObject var inspectState: InspectState

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            VStack(spacing: 8) {
                Image(nsImage: NSImage(named: NSImage.computerName) ?? NSImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)

                if inspectState.config?.hideSystemDetails != true {
                    Text(getSystemInfo("computermodel"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(getSystemInfo("serialnumber"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    Text("System Information Hidden")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                Text("\(getOSDisplayName()) (\(getBuildNumber()))")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .padding(.bottom, 8)

            Divider()

            VStack(alignment: .center, spacing: 4) {
                if inspectState.config?.hideSystemDetails != true {
                    Text(getSystemInfo("userfullname"))
                        .font(.headline)
                        .fontWeight(.semibold)

                    HStack(spacing: 4) {
                        Text(getSystemInfo("username"))
                        Text("(UID: \(getUserID()))")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                    Text("User Details Hidden")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 8)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Progress Overview")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 6) {
                    EnhancedInfoRow(label: "Total Items", value: "\(inspectState.items.count)")
                    EnhancedInfoRow(label: "Completed", value: "\(inspectState.completedItems.count)",
                                  valueColor: !inspectState.completedItems.isEmpty ? palette.success : palette.text)
                    EnhancedInfoRow(label: "Installing", value: "\(inspectState.downloadingItems.count)",
                                  valueColor: !inspectState.downloadingItems.isEmpty ? palette.info : palette.text)
                    EnhancedInfoRow(label: "Pending", value: "\(inspectState.items.count - inspectState.completedItems.count - inspectState.downloadingItems.count)",
                                  valueColor: .secondary)

                    let progress = inspectState.items.isEmpty ? 0.0 : Double(inspectState.completedItems.count) / Double(inspectState.items.count)
                    EnhancedInfoRow(label: "Progress", value: "\(Int(progress * 100))%",
                                  valueColor: progress == 1.0 ? palette.success : palette.info)
                }
            }

            if !inspectState.downloadingItems.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Currently Installing")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(palette.info)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(inspectState.items.filter { inspectState.downloadingItems.contains($0.id) }, id: \.id) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(palette.info)
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

    /// A value from swiftDialog's built-in variables.
    private func getSystemInfo(_ key: String) -> String {
        let systemInfo = getEnvironmentVars()
        return systemInfo[key] ?? "Unknown"
    }

    private func getOSDisplayName() -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osName = getSystemInfo("osname")
        return "\(osName) \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }

    /// kern.osversion, the same value as `sw_vers -buildVersion`.
    private func getBuildNumber() -> String {
        return osBuildVersion
    }

    private func getUserID() -> String {
        let uid = getuid()
        return String(uid)
    }

}

/// Label and value row with a tinted value.
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