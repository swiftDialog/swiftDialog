//
//  SidebarNavigationModule.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 25/01/2026
//
//  Reusable sidebar navigation module for step-based workflows.
//  Provides a modern vertical stepper with clean Preset5-style aesthetics.
//
//  Used by: Preset6 (modern sidebar variant)
//

import SwiftUI

// MARK: - Sidebar Navigation Module

/// A reusable sidebar navigation component for step-based workflows.
/// Displays a vertical list of steps with progress indicators and selection support.
struct SidebarNavigationModule: View {
    let items: [InspectConfig.ItemConfig]
    let currentStep: Int
    let completedSteps: Set<String>
    let downloadingSteps: Set<String>
    let accentColor: Color
    let logoPath: String?
    let title: String?
    let subtitle: String?
    let iconPath: String?
    let iconBasePath: String?
    let showStepNumbers: Bool
    let showCompletionMarks: Bool
    let width: CGFloat
    let scaleFactor: CGFloat
    let onStepSelected: (Int) -> Void
    let isNavigationBlocked: Bool

    init(
        items: [InspectConfig.ItemConfig],
        currentStep: Int,
        completedSteps: Set<String>,
        downloadingSteps: Set<String> = [],
        accentColor: Color = .blue,
        logoPath: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        iconPath: String? = nil,
        iconBasePath: String? = nil,
        showStepNumbers: Bool = true,
        showCompletionMarks: Bool = true,
        width: CGFloat = 220,
        scaleFactor: CGFloat = 1.0,
        onStepSelected: @escaping (Int) -> Void,
        isNavigationBlocked: Bool = false
    ) {
        self.items = items
        self.currentStep = currentStep
        self.completedSteps = completedSteps
        self.downloadingSteps = downloadingSteps
        self.accentColor = accentColor
        self.logoPath = logoPath
        self.title = title
        self.subtitle = subtitle
        self.iconPath = iconPath
        self.iconBasePath = iconBasePath
        self.showStepNumbers = showStepNumbers
        self.showCompletionMarks = showCompletionMarks
        self.width = width
        self.scaleFactor = scaleFactor
        self.onStepSelected = onStepSelected
        self.isNavigationBlocked = isNavigationBlocked
    }

    /// Filter to display only non-intro/outro steps in sidebar
    private var displayItems: [(index: Int, item: InspectConfig.ItemConfig)] {
        items.enumerated().filter { _, item in
            item.stepType != "intro" && item.stepType != "outro"
        }.map { ($0.offset, $0.element) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with logo and title
            headerSection
                .padding(.top, 16 * scaleFactor)
                .padding(.bottom, 12 * scaleFactor)

            Divider()
                .padding(.horizontal, 16 * scaleFactor)

            // Step list
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4 * scaleFactor) {
                        ForEach(displayItems, id: \.index) { displayIndex, item in
                            let actualIndex = displayIndex
                            ModernStepRow(
                                index: displayIndex,
                                item: item,
                                isActive: actualIndex == currentStep,
                                isCompleted: completedSteps.contains(item.id),
                                isDownloading: downloadingSteps.contains(item.id),
                                accentColor: accentColor,
                                showStepNumber: showStepNumbers,
                                showCompletionMark: showCompletionMarks,
                                scaleFactor: scaleFactor,
                                isNavigationBlocked: isNavigationBlocked
                            )
                            .id("step_\(actualIndex)")
                            .onTapGesture {
                                if !isNavigationBlocked {
                                    onStepSelected(actualIndex)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8 * scaleFactor)
                    .padding(.horizontal, 12 * scaleFactor)
                }
                .onChange(of: currentStep) { _, newStep in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("step_\(newStep)", anchor: .center)
                    }
                }
            }

            Spacer(minLength: 0)

            // Bottom logo section (optional)
            if let logoPath = logoPath {
                bottomLogoSection(logoPath: logoPath)
            }
        }
        .frame(width: width * scaleFactor)
        .background(
            Color(NSColor.controlBackgroundColor)
                .opacity(0.5)
        )
    }

    // MARK: - Header Section

    /// Resolved icon: static `iconPath` from config, or dynamic from the current step's icon.
    private var resolvedHeaderIcon: String? {
        if let iconPath = iconPath { return iconPath }
        return items[safe: currentStep]?.icon
    }

    /// Whether the header icon is present (static or dynamic).
    private var hasHeaderIcon: Bool { resolvedHeaderIcon != nil }

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8 * scaleFactor) {
            // Prominent icon — static (config-level) or dynamic (current step's icon)
            if let icon = resolvedHeaderIcon {
                AsyncImageView(
                    iconPath: icon,
                    basePath: iconBasePath,
                    maxWidth: 64 * scaleFactor,
                    maxHeight: 64 * scaleFactor,
                    imageFit: .fit
                ) {
                    EmptyView()
                }
                .frame(width: 64 * scaleFactor, height: 64 * scaleFactor)
                .id(icon) // crossfade when the icon changes between steps
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: icon)
            }

            // Title
            if let title = title, !title.isEmpty {
                Text(title)
                    .font(hasHeaderIcon ? .title3.bold() : .headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            // Subtitle
            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            // Progress indicator
            progressIndicator
        }
        .padding(.horizontal, 16 * scaleFactor)
    }

    @ViewBuilder
    private var progressIndicator: some View {
        let totalRealSteps = displayItems.count
        let completedCount = displayItems.filter { completedSteps.contains($0.item.id) }.count
        let progress = totalRealSteps > 0 ? Double(completedCount) / Double(totalRealSteps) : 0

        VStack(spacing: 4 * scaleFactor) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor.opacity(0.2))
                        .frame(height: 4 * scaleFactor)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: geometry.size.width * progress, height: 4 * scaleFactor)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4 * scaleFactor)

            // Step counter text
            Text("\(completedCount) of \(totalRealSteps) completed")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Bottom Logo Section

    @ViewBuilder
    private func bottomLogoSection(logoPath: String) -> some View {
        Divider()
            .padding(.horizontal, 16 * scaleFactor)

        if let nsImage = NSImage(contentsOfFile: logoPath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 100 * scaleFactor, maxHeight: 32 * scaleFactor)
                .padding(.vertical, 12 * scaleFactor)
                .padding(.horizontal, 16 * scaleFactor)
        }
    }
}

// MARK: - Modern Step Row

/// A single step row in the sidebar navigation.
/// Clean, minimal design matching Preset5's aesthetics.
struct ModernStepRow: View {
    let index: Int
    let item: InspectConfig.ItemConfig
    let isActive: Bool
    let isCompleted: Bool
    let isDownloading: Bool
    let accentColor: Color
    let showStepNumber: Bool
    let showCompletionMark: Bool
    let scaleFactor: CGFloat
    let isNavigationBlocked: Bool

    /// Get step number for display (1-indexed, excluding intro steps)
    private var displayStepNumber: Int {
        // The index is already filtered to exclude intro/outro, so just add 1 for 1-indexed display
        return index + 1
    }

    var body: some View {
        HStack(spacing: 12 * scaleFactor) {
            // Step indicator (number, checkmark, or spinner)
            stepIndicator
                .frame(width: 28 * scaleFactor, height: 28 * scaleFactor)

            // Step content
            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                Text(item.displayName)
                    .font(.subheadline.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .lineLimit(1)

                // Optional subtitle (status or description)
                if let subtitle = stepSubtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12 * scaleFactor)
        .padding(.vertical, 8 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .fill(isActive ? accentColor.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .strokeBorder(isActive ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .opacity(isNavigationBlocked && !isActive ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    // MARK: - Step Indicator

    @ViewBuilder
    private var stepIndicator: some View {
        ZStack {
            if isCompleted && showCompletionMark {
                // Completed state - checkmark
                Circle()
                    .fill(Color.green)
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            } else if isDownloading {
                // Downloading/processing state - spinner
                Circle()
                    .fill(accentColor.opacity(0.15))
                ProgressView()
                    .scaleEffect(0.6 * scaleFactor)
            } else if isActive {
                // Active state - filled circle with number
                Circle()
                    .fill(accentColor)
                if showStepNumber {
                    Text("\(displayStepNumber)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            } else {
                // Pending state - outlined circle with number
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1.5)
                if showStepNumber {
                    Text("\(displayStepNumber)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Step Subtitle

    private var stepSubtitle: String? {
        if isCompleted {
            return "Completed"
        } else if isDownloading {
            return "In progress..."
        } else if isActive {
            return "Current step"
        }
        return nil
    }

    private var subtitleColor: Color {
        if isCompleted {
            return .green
        } else if isDownloading {
            return accentColor
        }
        return .secondary
    }
}

// MARK: - Preview

#if DEBUG
struct SidebarNavigationModule_Previews: PreviewProvider {
    static var previews: some View {
        SidebarNavigationModule(
            items: [
                InspectConfig.ItemConfig(id: "step1", displayName: "Welcome"),
                InspectConfig.ItemConfig(id: "step2", displayName: "Configure Settings"),
                InspectConfig.ItemConfig(id: "step3", displayName: "Install Software"),
                InspectConfig.ItemConfig(id: "step4", displayName: "Complete Setup")
            ],
            currentStep: 1,
            completedSteps: ["step1"],
            accentColor: .blue,
            title: "Setup Assistant",
            subtitle: "Configure your new Mac!",
            iconPath: "sf=checklist",
            onStepSelected: { _ in }
        )
        .frame(height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
#endif
