//
//  SidebarNavigationModule.swift
//  dialog
//
//  Sidebar step navigation for preset 6: header, grouped step list with progress marks, and an
//  optional bottom logo.
//

import SwiftUI

// MARK: - Sidebar Navigation Module

/// A vertical list of the flow's main-phase steps with progress indicators and selection.
struct SidebarNavigationModule: View {
    let items: [InspectConfig.IntroStep]
    let currentStep: Int
    let completedSteps: Set<String>
    let downloadingSteps: Set<String>
    let accentColor: Color
    let logoPath: String?
    let title: String?
    let subtitle: String?
    let iconPath: String?
    let iconBasePath: String?
    /// The `--overlayicon` mark blended into the header icon's corner.
    var overlayIconPath: String?
    let showStepNumbers: Bool
    let showCompletionMarks: Bool
    let width: CGFloat
    let scaleFactor: CGFloat
    let onStepSelected: (Int) -> Void
    let isNavigationBlocked: Bool

    init(
        items: [InspectConfig.IntroStep],
        currentStep: Int,
        completedSteps: Set<String>,
        downloadingSteps: Set<String> = [],
        accentColor: Color = .accentColor,
        logoPath: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        iconPath: String? = nil,
        iconBasePath: String? = nil,
        overlayIconPath: String? = nil,
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
        self.overlayIconPath = overlayIconPath
        self.showStepNumbers = showStepNumbers
        self.showCompletionMarks = showCompletionMarks
        self.width = width
        self.scaleFactor = scaleFactor
        self.onStepSelected = onStepSelected
        self.isNavigationBlocked = isNavigationBlocked
    }

    @Environment(\.palette) private var palette

    /// Main-phase steps only; intro and outro steps stay off the rail.
    private var displayItems: [(index: Int, item: InspectConfig.IntroStep)] {
        items.enumerated().filter { _, item in
            item.resolvedPhase == "main"
        }.map { ($0.offset, $0.element) }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.top, 16 * scaleFactor)
                .padding(.bottom, 12 * scaleFactor)

            // The header divider fades at both ends, the same 26pt fade the vertical rule uses.
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
                .mask(
                    HStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: 26 * scaleFactor)
                        Rectangle()
                        LinearGradient(colors: [.black, .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: 26 * scaleFactor)
                    }
                )
                .padding(.horizontal, 16 * scaleFactor)

            // Step list: centred inside the scroll view when the items fit (minHeight plus the
            // spacers), top-anchored and scrolling when they do not.
            ScrollViewReader { proxy in
              GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                  VStack(spacing: 0) {
                    // The top gap is capped so the list stays near its header; slack pools below.
                    Spacer(minLength: 0)
                        .frame(maxHeight: 24 * scaleFactor)
                    // Not a LazyVStack: rows outside the viewport must still exist for VoiceOver.
                    VStack(alignment: .leading, spacing: 4 * scaleFactor) {
                        ForEach(displayItems, id: \.index) { displayIndex, item in
                            let actualIndex = displayIndex
                            // A heading whenever the group changes.
                            if let group = item.group, group != groupOfItem(before: displayIndex) {
                                Text(group.uppercased())
                                    .font(.system(size: 11 * scaleFactor, weight: .semibold, design: .monospaced))
                                    .tracking(0.6)
                                    .foregroundStyle(palette.textFaint)
                                    .padding(.horizontal, 12 * scaleFactor)
                                    .padding(.top, displayIndex == 0 ? 2 * scaleFactor : 12 * scaleFactor)
                                    .padding(.bottom, 2 * scaleFactor)
                            }
                            ModernStepRow(
                                index: displayIndex,
                                item: item,
                                isActive: actualIndex == currentStep,
                                isCompleted: completedSteps.contains(item.id),
                                isDownloading: downloadingSteps.contains(item.id),
                                accentColor: accentColor,
                                showStepNumber: showStepNumbers && !isCatalogue,
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
                    Spacer(minLength: 0)
                  }
                  .frame(minHeight: geo.size.height)
                }
                // Rows fade at both edges; the fade is the scroll affordance in place of indicators.
                .mask(
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 16 * scaleFactor)
                        Rectangle()
                        LinearGradient(colors: [.black, .clear],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 20 * scaleFactor)
                    }
                )
                .onChange(of: currentStep) { _, newStep in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("step_\(newStep)", anchor: .center)
                    }
                }
              }
            }

            Spacer(minLength: 0)

            if let logoPath = logoPath {
                bottomLogoSection(logoPath: logoPath)
            }
        }
        .frame(width: width * scaleFactor)
        // No background: the host paints the column's ground behind the whole window, since only
        // it knows the column's full extent.
    }

    // MARK: - Header Section

    /// Static `iconPath` from config, else the current step's icon.
    private var resolvedHeaderIcon: String? {
        if let iconPath = iconPath { return iconPath }
        return items[safe: currentStep]?.heroImage
    }

    private var hasHeaderIcon: Bool { resolvedHeaderIcon != nil }

    /// Icon and title on one leading-aligned row. Text sizes are explicit so they scale with
    /// `scaleFactor` like the rows.
    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 8 * scaleFactor) {
            headerIcon
            VStack(alignment: .leading, spacing: 3 * scaleFactor) {
                if let title = title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 15 * scaleFactor, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // No progress indicator here; the footer cluster is the one place that states progress.
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 24pt, where the section headings and row labels begin (12pt list + 12pt row padding).
        .padding(.horizontal, 24 * scaleFactor)
    }

    /// The header icon with the `--overlayicon` mark in its bottom-trailing corner. Badge size
    /// and offset match `AppIconView.badgeSize` (`max(12, size * 0.36)`, offset 0.28).
    @ViewBuilder
    private var headerIcon: some View {
        if let icon = resolvedHeaderIcon {
            iconImage(icon, size: headerIconSize)
                .overlay(alignment: .bottomTrailing) {
                    if let overlay = overlayIconPath, !overlay.isEmpty {
                        iconImage(overlay, size: headerOverlaySize)
                            // The ring makes the badge read as blended into the mark.
                            .background(Circle().fill(Color(NSColor.windowBackgroundColor)))
                            .offset(x: headerOverlaySize * 0.28, y: headerOverlaySize * 0.28)
                    }
                }
                .id(icon)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: icon)
        }
    }

    /// 32pt plus the 8pt gap puts the title at 64pt, where the row labels begin
    /// (12 + 12 padding + 28 glyph + 12 gap), so header and rows share one grid.
    private var headerIconSize: CGFloat { 32 * scaleFactor }
    private var headerOverlaySize: CGFloat { max(12, headerIconSize * 0.36) }

    /// Renders the icon or its overlay: an SF Symbol when the reference names one, else a file path.
    @ViewBuilder
    private func iconImage(_ icon: String, size: CGFloat) -> some View {
        if let symbolRef = IconRef.symbol(icon) {
            // "SF=a,b" names alternates; the first wins.
            let symbolName = symbolRef.components(separatedBy: ",").first ?? ""
            Image(systemName: symbolName)
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(accentColor)
                .frame(width: size, height: size)
                .background(accentColor.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        } else {
            AsyncImageView(
                iconPath: icon,
                basePath: iconBasePath,
                maxWidth: size,
                maxHeight: size,
                imageFit: .fit
            ) {
                EmptyView()
            }
            .frame(width: size, height: size)
        }
    }

    /// The group of the item before `index`, so a heading is drawn only when the group changes.
    private func groupOfItem(before index: Int) -> String? {
        guard index > 0, index - 1 < displayItems.count else { return nil }
        return displayItems[index - 1].item.group
    }

    /// A grouped rail is a catalogue of kinds, not a queue of work, so it shows no step numbers.
    private var isCatalogue: Bool {
        displayItems.contains { $0.item.group?.isEmpty == false }
    }

    // MARK: - Bottom Logo Section

    @ViewBuilder
    private func bottomLogoSection(logoPath: String) -> some View {
        Divider()
            .padding(.horizontal, 16 * scaleFactor)

        if let nsImage = InspectImageCache.shared.image(atPath: logoPath) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 100 * scaleFactor, maxHeight: 32 * scaleFactor)
                .padding(.vertical, 12 * scaleFactor)
                .padding(.horizontal, 16 * scaleFactor)
        }
    }
}

// MARK: - Modern Step Row

/// One step row in the sidebar.
struct ModernStepRow: View {
    let index: Int
    let item: InspectConfig.IntroStep
    let isActive: Bool
    let isCompleted: Bool
    let isDownloading: Bool
    let accentColor: Color
    let showStepNumber: Bool
    let showCompletionMark: Bool
    let scaleFactor: CGFloat
    let isNavigationBlocked: Bool

    @Environment(\.palette) private var palette

    /// 1-based; `index` already excludes intro and outro steps.
    private var displayStepNumber: Int {
        return index + 1
    }

    /// SF Symbol name when the step's icon is authored as `SF=name`; nil keeps the numbered circle.
    private var leadingSymbol: String? {
        guard let icon = item.heroImage, let symbolRef = IconRef.symbol(icon) else { return nil }
        let name = symbolRef.components(separatedBy: ",").first ?? ""
        return name.isEmpty ? nil : name
    }

    /// The leading bar carries the accent, so the label stays plain text on the 8% tint.
    private var contentColor: Color {
        if isActive { return .primary }
        return isCompleted ? .primary : .secondary
    }

    var body: some View {
        HStack(spacing: 12 * scaleFactor) {
            leadingGlyph
                .frame(width: 28 * scaleFactor, height: 28 * scaleFactor)

            // No subtitle, so every row has the same height. Explicit size so the label scales
            // with the glyph; semantic styles ignore `scaleFactor`.
            Text(item.displayName ?? item.title ?? item.id)
                .font(.system(size: 14 * scaleFactor, weight: isActive ? .semibold : .regular))
                .foregroundStyle(contentColor)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12 * scaleFactor)
        .padding(.vertical, 8 * scaleFactor)
        .background(
            // An 8% tint plus the 3pt leading bar marks the active row without a saturated fill.
            RoundedRectangle(cornerRadius: 8 * scaleFactor, style: .continuous)
                .fill(isActive ? accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(alignment: .leading) {
            if isActive {
                RoundedRectangle(cornerRadius: 1.5 * scaleFactor, style: .continuous)
                    .fill(accentColor)
                    .frame(width: 3 * scaleFactor)
                    .padding(.vertical, 4 * scaleFactor)
            }
        }
        .contentShape(Rectangle())
        .opacity(isNavigationBlocked && !isActive ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    // MARK: - Leading Glyph

    @ViewBuilder
    private var leadingGlyph: some View {
        if let symbol = leadingSymbol {
            // A completed, non-active step gets a small check badge so progress stays legible.
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: 17 * scaleFactor, weight: .medium))
                    .foregroundStyle(isActive || isCompleted ? accentColor : Color.secondary)
                    .symbolEffect(.pulse, options: .repeating, isActive: isDownloading)
                if isCompleted && showCompletionMark && !isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11 * scaleFactor, weight: .bold))
                        .foregroundStyle(palette.success)
                        .background(Circle().fill(.background))
                        .offset(x: 3 * scaleFactor, y: 3 * scaleFactor)
                }
            }
        } else {
            stepIndicator
        }
    }

    // MARK: - Step Indicator

    @ViewBuilder
    private var stepIndicator: some View {
        ZStack {
            if isCompleted && showCompletionMark && !isActive {
                Circle()
                    .fill(palette.success)
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            } else if isDownloading {
                Circle()
                    .fill(accentColor.opacity(isActive ? 0.18 : 0.10))
                Image(systemName: "ellipsis")
                    .font(.system(size: 10 * scaleFactor, weight: .bold))
                    .foregroundStyle(accentColor)
                    .symbolEffect(.pulse, options: .repeating)
            } else if isActive {
                // Accent ring and number; white would vanish on the row's tint in light mode.
                Circle()
                    .strokeBorder(accentColor, lineWidth: 1.5)
                if showStepNumber {
                    Text("\(displayStepNumber)")
                        .font(.caption.bold())
                        .foregroundStyle(accentColor)
                }
            } else {
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
            return palette.success
        } else if isDownloading {
            return accentColor
        }
        return .secondary
    }
}

// MARK: - Preview

#if DEBUG
struct SidebarNavigationModule_Previews: PreviewProvider {
    /// Decoded from JSON because `IntroStep` has no usable memberwise initializer.
    static let sampleSteps: [InspectConfig.IntroStep] = {
        let json = """
        [{"id": "step1", "title": "Welcome"},
         {"id": "step2", "title": "Configure Settings"},
         {"id": "step3", "title": "Install Software"},
         {"id": "step4", "title": "Complete Setup"}]
        """
        return (try? JSONDecoder().decode([InspectConfig.IntroStep].self,
                                          from: Data(json.utf8))) ?? []
    }()

    static var previews: some View {
        SidebarNavigationModule(
            items: SidebarNavigationModule_Previews.sampleSteps,
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
