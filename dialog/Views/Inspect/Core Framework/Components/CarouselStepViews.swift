//
// CarouselStepViews.swift
//
// Created by Henry Stamerjohann, Declarative IT GmbH, 26/01/2026
//
// Components for the "carousel" step type (Preset2-style horizontal card carousel)
// Used by Preset5's carouselStepView()

import SwiftUI

// MARK: - Carousel Card

/// Single item card: icon with status indicator overlay, name, and status text
struct CarouselCardView: View {
    let item: InstallationItemData
    let accentColor: Color

    private var isActive: Bool {
        if case .downloading = item.status { return true }
        if case .installing = item.status { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 4) {
            // Icon with status overlay
            ZStack {
                IconView(image: item.icon ?? item.iconPath ?? "SF=app.fill", defaultImage: "app.fill", defaultColour: "accent")
                    .frame(width: 90, height: 90)
                    .clipShape(.rect(cornerRadius: 16))

                // Status indicator overlay (top-right)
                VStack {
                    HStack {
                        Spacer()
                        CarouselStatusBadge(status: item.status, accentColor: accentColor)
                    }
                    Spacer()
                }
                .padding(2)
            }

            // Name and status text
            VStack(spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isActive ? accentColor : .primary)

                Text(carouselStatusText(for: item))
                    .font(.system(size: 9))
                    .foregroundStyle(carouselStatusColor(for: item))
            }
            .frame(width: 110, height: 35)
        }
        .frame(width: 130, height: 160)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isActive ? accentColor.opacity(0.5) : Color.gray.opacity(0.15),
                            lineWidth: isActive ? 1.5 : 1
                        )
                )
        )
        .opacity(item.status == .completed ? 1.0 : (isActive ? 1.0 : 0.75))
        .animation(.easeInOut(duration: 0.3), value: item.status == .completed)
    }
}

// MARK: - Status Badge

/// Circle badge overlay: checkmark (completed), spinner (active), X (failed)
struct CarouselStatusBadge: View {
    let status: MonitoringItemStatus
    let accentColor: Color
    private let size: CGFloat = 26

    var body: some View {
        switch status {
        case .failed:
            Circle()
                .fill(Color.red)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                )
        case .completed:
            Circle()
                .fill(Color.green)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                )
        case .downloading, .installing:
            ProgressView()
                .scaleEffect(0.7)
                .tint(accentColor)
                .frame(width: size, height: size)
        case .pending:
            EmptyView()
        }
    }
}

// MARK: - Placeholder Card

/// Empty card slot for when carousel doesn't fill all visible positions
struct CarouselPlaceholderCardView: View {
    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.05))
                .frame(width: 72, height: 72)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.05))
                .frame(width: 70, height: 10)
        }
        .frame(width: 110, height: 120)
        .padding(6)
    }
}

// MARK: - Progress Bar

/// Bottom progress bar with customizable format text
struct CarouselProgressBarView: View {
    let completed: Int
    let total: Int
    let accentColor: Color
    let progressFormat: String?

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: Double(completed), total: Double(total))
                .progressViewStyle(.linear)
                .frame(width: 600)
                .tint(accentColor)

            Text(formatProgressText())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
    }

    private func formatProgressText() -> String {
        if let template = progressFormat {
            return template
                .replacingOccurrences(of: "{completed}", with: "\(completed)")
                .replacingOccurrences(of: "{total}", with: "\(total)")
        }
        return "\(completed) of \(total) completed"
    }
}

// MARK: - Helpers

/// Human-readable status text for a carousel item
func carouselStatusText(for item: InstallationItemData) -> String {
    if let message = item.statusMessage, !message.isEmpty {
        return message
    }
    switch item.status {
    case .pending: return "Waiting"
    case .downloading: return "Installing..."
    case .installing(_, let message): return message ?? "Installing..."
    case .completed: return "Completed"
    case .failed(let reason): return reason ?? "Failed"
    }
}

/// Color for carousel item status text
func carouselStatusColor(for item: InstallationItemData) -> Color {
    switch item.status {
    case .failed: return .red
    case .completed: return .green
    case .downloading, .installing: return .blue
    case .pending: return .gray
    }
}

/// Number of visible cards based on window context (fixed for Preset5)
func carouselVisibleCardCount() -> Int {
    5
}
