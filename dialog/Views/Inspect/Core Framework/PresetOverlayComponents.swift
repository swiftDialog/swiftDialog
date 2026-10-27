//
//  PresetOverlayComponents.swift
//  dialog
//
//  Help buttons and detail-overlay modifiers shared across presets.
//

import SwiftUI

// MARK: - Help glyph

/// The help control's one look: a bare 15pt glyph in the tint at a 14pt line height, so it can
/// join a row of small type without making it taller.
struct HelpGlyphButton: View {
    let icon: String
    let tooltip: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            Self.logPress(tooltip)
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(height: 14)
                .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }
}

extension HelpGlyphButton {
    /// What pressed the control: a mouse click, a key, or neither (accessibility or code).
    @MainActor static func logPress(_ tooltip: String) {
        let event = NSApp.currentEvent
        let source: String
        switch event?.type {
        case .leftMouseUp, .leftMouseDown: source = "mouse"
        case .keyDown, .keyUp: source = "key (\(event?.charactersIgnoringModifiers ?? "?"))"
        case .none: source = "no event (accessibility or code)"
        case .some(let other): source = "event \(other.rawValue)"
        }
        writeLog("HelpGlyph: '\(tooltip)' pressed by \(source)", logLevel: .info)
    }
}

// MARK: - Detail Overlay Help Button

/// A configurable help button that triggers the detail overlay
struct DetailOverlayHelpButton: View {
    let config: InspectConfig.HelpButtonConfig
    let action: () -> Void

    /// Icon to display (SF Symbol name)
    private var iconName: String {
        config.icon ?? "questionmark.circle"
    }

    /// Button style
    private var buttonStyle: String {
        config.style ?? "floating"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: buttonStyle == "floating" ? 15 : 14))

                if let label = config.label {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .foregroundStyle(Color.accentColor)
            .padding(6)
            .background(
                // `floating` is the bare glyph; `toolbar` keeps its capsule because it was asked for.
                Group {
                    if buttonStyle == "toolbar" {
                        Capsule()
                            .fill(Color(NSColor.controlBackgroundColor))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .help(config.tooltip ?? "Get Help")
        .accessibilityLabel(config.tooltip ?? "Get Help")
    }
}


// MARK: - Detail Overlay View Modifier

/// Adds the detail overlay sheet to a preset. `presentationMode: "gallery"` shows the carousel.
struct DetailOverlayModifier: ViewModifier {
    @ObservedObject var inspectState: InspectState
    @Binding var showOverlay: Bool
    let config: InspectConfig.DetailOverlayConfig?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showOverlay) {
                if let config = config {
                    if config.presentationMode == "gallery" {
                        GalleryCarouselView(
                            config: config,
                            onClose: { showOverlay = false }
                        )
                    } else {
                        DetailOverlayView(
                            inspectState: inspectState,
                            config: config,
                            onClose: { showOverlay = false }
                        )
                    }
                }
            }
    }
}

extension View {
    /// Adds detail overlay support to a view
    func detailOverlay(
        inspectState: InspectState,
        isPresented: Binding<Bool>,
        config: InspectConfig.DetailOverlayConfig?
    ) -> some View {
        modifier(DetailOverlayModifier(
            inspectState: inspectState,
            showOverlay: isPresented,
            config: config
        ))
    }
}


// MARK: - Item Info Button

/// A small (i) button beside an install item that shows its details.
struct ItemInfoButton: View {
    let item: InspectConfig.ItemConfig
    let action: () -> Void
    let size: CGFloat
    let tint: Color

    init(item: InspectConfig.ItemConfig, action: @escaping () -> Void, size: CGFloat = 18, tint: Color = .accentColor) {
        self.item = item
        self.action = action
        self.size = size
        self.tint = tint
    }

    var body: some View {
        Button(action: action) {
            // Brand-tinted circle with a white glyph, the same badge on every preset.
            ZStack {
                Circle()
                    .fill(tint)
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
                Image(systemName: "info")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .help("More info about \(item.displayName)")
    }
}


// MARK: - Item Detail Overlay Modifier

/// View modifier for showing item-specific detail overlay
struct ItemDetailOverlayModifier: ViewModifier {
    @ObservedObject var inspectState: InspectState
    @Binding var showOverlay: Bool
    /// Resolved by the caller so a step (Preset 6) and a row (presets 1-2) share one modifier.
    let overlay: InspectConfig.DetailOverlayConfig?
    let label: String?
    let iconName: String?
    /// The row's claim or identifier when its own surface has no room for it. Becomes the sheet's
    /// subtitle; with no overlay authored the click still opens a small sheet carrying it.
    var detail: String?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showOverlay) {
                if let label {
                    let config = overlay ?? inspectState.config?.detailOverlay ?? detail.map { _ in
                        InspectConfig.DetailOverlayConfig(
                            enabled: true, size: "small", title: nil, subtitle: nil, icon: nil,
                            overlayIcon: nil, content: nil, showSystemInfo: false,
                            showProgressInfo: false, closeButtonText: nil, backgroundColor: nil,
                            showDividers: nil)
                    }
                    if let config = config {
                        if config.presentationMode == "gallery" {
                            GalleryCarouselView(
                                config: config,
                                onClose: { showOverlay = false }
                            )
                        } else {
                            // The item's label and detail fill in whatever the config leaves unset.
                            let itemConfig = InspectConfig.DetailOverlayConfig(
                                enabled: config.enabled,
                                size: config.size,
                                title: config.title ?? label,
                                subtitle: config.subtitle ?? detail,
                                icon: config.icon ?? iconName,
                                overlayIcon: config.overlayIcon,
                                content: config.content,
                                showSystemInfo: config.showSystemInfo,
                                showProgressInfo: false,  // Don't show progress for item-specific
                                closeButtonText: config.closeButtonText,
                                backgroundColor: config.backgroundColor,
                                showDividers: config.showDividers
                            )
                            DetailOverlayView(
                                inspectState: inspectState,
                                config: itemConfig,
                                onClose: { showOverlay = false }
                            )
                        }
                    }
                }
            }
    }
}

extension View {
    /// Adds item-specific detail overlay support to a view (presets 1-2: a ROW).
    func itemDetailOverlay(
        inspectState: InspectState,
        isPresented: Binding<Bool>,
        item: InspectConfig.ItemConfig?,
        showsDetail: Bool = false
    ) -> some View {
        let detail = showsDetail
            ? [item?.claim, item?.displayIdentifier].compactMap { $0?.nilIfEmpty }.joined(separator: "\n").nilIfEmpty
            : nil
        return modifier(ItemDetailOverlayModifier(
            inspectState: inspectState,
            showOverlay: isPresented,
            overlay: item?.itemOverlay,
            label: item?.displayName,
            iconName: item?.icon,
            detail: detail
        ))
    }

    /// The same overlay for a step (Preset 6): anchor `stepOverlay`, label the step's title.
    func itemDetailOverlay(
        inspectState: InspectState,
        isPresented: Binding<Bool>,
        item: InspectConfig.IntroStep?
    ) -> some View {
        modifier(ItemDetailOverlayModifier(
            inspectState: inspectState,
            showOverlay: isPresented,
            overlay: item?.stepOverlay,
            label: item.map { $0.title ?? $0.id },
            iconName: item?.heroImage
        ))
    }
}


// MARK: - Positioned Help Button Wrapper

/// Positions the help button: topRight, topLeft, bottomRight, bottomLeft, sidebar, buttonBar.
struct PositionedHelpButton: View {
    let config: InspectConfig.HelpButtonConfig
    let action: () -> Void
    let padding: CGFloat

    private var position: String {
        config.position ?? "bottomRight"
    }

    /// Whether this position uses floating overlay positioning
    var isFloatingPosition: Bool {
        !["sidebar", "buttonBar"].contains(position)
    }

    var body: some View {
        if isFloatingPosition {
            DetailOverlayHelpButton(config: config, action: action)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .padding(padding)
        } else {
            // sidebar and buttonBar render inline; the parent positions them.
            DetailOverlayHelpButton(config: config, action: action)
        }
    }

    /// A bottom request resolves to the top on the same side: the bottom belongs to the step's
    /// own actions. Wherever `ActionFooterRow` is drawn it seats the control itself instead.
    private var alignment: Alignment {
        position.lowercased().contains("left") ? .topLeading : .topTrailing
    }
}

