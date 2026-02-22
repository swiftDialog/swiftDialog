// DeploymentStepViews.swift
//
// Created by Henry Stamerjohann, Declarative IT GmbH, 26/01/2026
//
// Components for the "deployment" step type (Preset1-style sidebar + item list layout)
// Used by Preset5's deploymentStepView()

import SwiftUI

// MARK: - Sidebar

/// Left sidebar: hero icon, progress bar, and optional popup button
struct DeploymentSidebarView: View {
    let heroImage: String?
    let items: [InstallationItemData]
    let popupButtonText: String?
    let accentColor: Color
    let onPopupButton: (() -> Void)?

    private var completedCount: Int {
        items.filter { $0.status == .completed }.count
    }

    private var totalCount: Int {
        items.count
    }

    private var progressFraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        VStack {
            Spacer()
                .frame(height: 20)

            // Hero icon
            if let heroImage = heroImage {
                IconView(image: heroImage, defaultImage: "arrow.down.circle", defaultColour: "accent")
                    .frame(width: 180, height: 180)
            }

            // Progress bar
            if totalCount > 0 {
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(accentColor)
                                .frame(width: geo.size.width * progressFraction, height: 8)
                                .animation(.easeInOut(duration: 0.4), value: progressFraction)
                        }
                    }
                    .frame(width: 200, height: 8)

                    Text("\(completedCount) of \(totalCount) completed")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
            }

            Spacer()

            // Popup button (e.g., "Install Details...")
            if let buttonText = popupButtonText, let action = onPopupButton {
                Button(buttonText, action: action)
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .font(.body)
                    .padding(.bottom, 20)
            }
        }
        .frame(width: 260)
        .padding(.vertical)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Item Row

/// Single item row: icon + name + status text + status indicator
struct DeploymentItemRow: View {
    let item: InstallationItemData
    let accentColor: Color
    var basePath: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Item icon (uses AsyncImageView for basePath resolution)
            if let icon = item.icon ?? item.iconPath {
                AsyncImageView(
                    iconPath: icon,
                    basePath: basePath,
                    maxWidth: 40,
                    maxHeight: 40,
                    imageFit: .fit
                ) {
                    Image(systemName: "app.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Name + status text
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)

                Text(deploymentStatusText(for: item))
                    .font(.system(size: 12))
                    .foregroundStyle(deploymentStatusColor(for: item))
            }

            Spacer()

            // Status indicator circle
            DeploymentStatusIndicator(status: item.status, accentColor: accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

// MARK: - Status Indicator

/// Circle indicator: checkmark (completed), spinner (active), empty circle (pending), X (failed)
struct DeploymentStatusIndicator: View {
    let status: MonitoringItemStatus
    let accentColor: Color
    private let size: CGFloat = 20

    var body: some View {
        switch status {
        case .failed:
            Circle()
                .fill(Color.red)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "xmark")
                        .font(.system(size: size * 0.6, weight: .bold))
                        .foregroundStyle(.white)
                )
        case .completed:
            Circle()
                .fill(Color.green)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.6, weight: .bold))
                        .foregroundStyle(.white)
                )
        case .downloading, .installing:
            ProgressView()
                .scaleEffect(0.8)
                .tint(.blue)
                .frame(width: size, height: size)
        case .pending:
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Side Message View

/// Rotating messages with self-contained timer — starts/stops with view lifecycle
struct DeploymentSideMessageView: View {
    let messages: [String]
    let interval: Int

    @State private var currentIndex: Int = 0

    var body: some View {
        if !messages.isEmpty {
            let safeIndex = min(currentIndex, messages.count - 1)
            Text(messages[safeIndex])
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 40, alignment: .leading)
                .animation(.easeInOut(duration: 0.5), value: currentIndex)
                .onAppear {
                    startRotation()
                }
        }
    }

    private func startRotation() {
        guard messages.count > 1, interval > 0 else { return }
        Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { timer in
            DispatchQueue.main.async {
                // Invalidate if view is gone (timer won't fire after view disappears since @State resets)
                currentIndex = (currentIndex + 1) % messages.count
            }
        }
    }
}

// MARK: - Group Header

/// Section header for item status groups ("Completed", "Currently Installing", "Pending Installation")
struct DeploymentItemGroupHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
            .tracking(0.5)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Helpers

/// Sort items by status group: completed → active (downloading/installing) → pending → failed
func deploymentSortedItems(_ items: [InstallationItemData]) -> [InstallationItemData] {
    items.sorted { a, b in
        statusSortOrder(a.status) < statusSortOrder(b.status)
    }
}

private func statusSortOrder(_ status: MonitoringItemStatus) -> Int {
    switch status {
    case .completed: return 0
    case .downloading, .installing: return 1
    case .pending: return 2
    case .failed: return 3
    }
}

/// Returns a group index for the status (used for separator detection in the item list)
func deploymentStatusGroupIndex(_ status: MonitoringItemStatus) -> Int {
    statusSortOrder(status)
}

/// Human-readable status text for a deployment item
func deploymentStatusText(for item: InstallationItemData) -> String {
    if let message = item.statusMessage, !message.isEmpty {
        return message
    }
    switch item.status {
    case .pending: return "Pending"
    case .downloading: return "Downloading..."
    case .installing(_, let message): return message ?? "Installing..."
    case .completed: return "Completed"
    case .failed(let reason): return reason ?? "Failed"
    }
}

/// Color for item status text
func deploymentStatusColor(for item: InstallationItemData) -> Color {
    switch item.status {
    case .failed: return .red
    case .completed: return .green
    case .downloading, .installing: return .blue
    case .pending: return .secondary
    }
}

/// Group header text for a given status
func deploymentGroupHeader(for status: MonitoringItemStatus) -> String {
    switch status {
    case .completed: return "Completed"
    case .downloading, .installing: return "Currently Installing"
    case .pending: return "Pending Installation"
    case .failed: return "Installation Failed"
    }
}
