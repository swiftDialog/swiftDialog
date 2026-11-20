//
//  BrandSwitches.swift
//  dialog
//
//  `BrandToggle`, `BrandCheckbox` and `BrandRadioGroup`: controls drawn from the brand palette,
//  because `.tint()` leaves the off track, thumb, border and focus ring in system colours.
//  Each exposes a native control through `.accessibilityRepresentation`.

import SwiftUI

/// A switch drawn from the palette: capsule track, circular thumb, accent when on.
/// Uses AppKit's switch geometry (38×22 track, 18pt thumb, 2pt inset).
struct BrandToggle: View {
    @Binding var isOn: Bool
    /// The label VoiceOver announces; not rendered, the caller draws its own row text.
    let accessibilityLabel: String
    var accentColor: Color?
    var scaleFactor: CGFloat = 1

    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    private var tint: Color { accentColor ?? palette.accent }
    private var trackWidth: CGFloat { 38 * scaleFactor }
    private var trackHeight: CGFloat { 22 * scaleFactor }
    private var thumb: CGFloat { 18 * scaleFactor }

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    // `surfaceRaised`, not a grey literal, so the off track reads on light and dark grounds.
                    .fill(isOn ? tint : palette.surfaceRaised)
                    .overlay(
                        Capsule().strokeBorder(palette.hairline, lineWidth: isOn ? 0 : 1)
                    )
                    .frame(width: trackWidth, height: trackHeight)
                Circle()
                    .fill(.white)
                    .shadow(color: palette.text.opacity(0.22), radius: 0.5, x: 0, y: 0.5)
                    .frame(width: thumb, height: thumb)
                    .padding(2 * scaleFactor)
            }
            .frame(width: trackWidth, height: trackHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.16), value: isOn)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityRepresentation {
            Toggle(accessibilityLabel, isOn: $isOn)
        }
    }
}

/// A checkbox drawn from the palette: rounded square, accent fill and a white mark when on.
/// 14pt at scale 1, matching AppKit's checkbox.
struct BrandCheckbox: View {
    @Binding var isOn: Bool
    let accessibilityLabel: String
    var accentColor: Color?
    var scaleFactor: CGFloat = 1

    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    private var tint: Color { accentColor ?? palette.accent }
    private var side: CGFloat { 14 * scaleFactor }

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            RoundedRectangle(cornerRadius: 3 * scaleFactor, style: .continuous)
                .fill(isOn ? tint : palette.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 3 * scaleFactor, style: .continuous)
                        // A visible edge when unchecked; `hairline` is too faint at this size.
                        .strokeBorder(isOn ? .clear : palette.text.opacity(0.18), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 9 * scaleFactor, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(isOn ? 1 : 0)
                )
                .frame(width: side, height: side)
                // Pads the hit target to the platform minimum without changing what is drawn.
                .padding(4 * scaleFactor)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: isOn)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityRepresentation {
            Toggle(accessibilityLabel, isOn: $isOn)
        }
    }
}

// MARK: - Checkbox as a ToggleStyle

/// `BrandCheckbox` as a `ToggleStyle`, so an existing `Toggle` keeps its binding, label and layout.
struct BrandCheckboxToggleStyle: ToggleStyle {
    var accentColor: Color?
    var scaleFactor: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6 * scaleFactor) {
            BrandCheckbox(isOn: configuration.$isOn,
                          accessibilityLabel: "",
                          accentColor: accentColor,
                          scaleFactor: scaleFactor)
            configuration.label
        }
        // Clicking the label toggles it, as on a native checkbox.
        .contentShape(Rectangle())
        .onTapGesture { configuration.isOn.toggle() }
    }
}

/// Type-erased `ToggleStyle`, so a call site can choose between two styles in one expression.
/// SwiftUI has no built-in eraser for this protocol.
struct AnyToggleStyle: ToggleStyle {
    private let makeBodyClosure: (Configuration) -> AnyView

    init<S: ToggleStyle>(_ style: S) {
        makeBodyClosure = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        makeBodyClosure(configuration)
    }
}

// MARK: - Radio

/// A radio group drawn from the palette: concentric circles, accent fill and a white centre.
/// Exposed to VoiceOver as a `Picker`, and drawn at the checkbox's geometry so both match on one form.
struct BrandRadioGroup: View {
    let options: [String]
    @Binding var selection: String
    /// The group's VoiceOver name; the visible label is drawn by the caller.
    let accessibilityLabel: String
    var accentColor: Color?
    var scaleFactor: CGFloat = 1

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    HStack(spacing: 8 * scaleFactor) {
                        BrandRadioDot(isSelected: option == selection,
                                      accentColor: accentColor,
                                      scaleFactor: scaleFactor)
                        Text(option)
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundStyle(palette.text)
                    }
                    // The whole row is the target; a radio label is clickable.
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityRepresentation {
            Picker(accessibilityLabel, selection: $selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
        }
    }
}

/// One radio dot at the checkbox's geometry: 14pt outer, 1pt border at 0.18, accent fill.
struct BrandRadioDot: View {
    let isSelected: Bool
    var accentColor: Color?
    var scaleFactor: CGFloat = 1

    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    private var tint: Color { accentColor ?? palette.accent }
    private var side: CGFloat { 14 * scaleFactor }

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? tint : palette.cardSurface)
                .overlay(
                    Circle().strokeBorder(isSelected ? .clear : palette.text.opacity(0.18),
                                          lineWidth: 1)
                )
            // White on the non-adapting accent fill, like the toggle's thumb, to keep contrast.
            Circle()
                .fill(.white)
                .frame(width: 5 * scaleFactor, height: 5 * scaleFactor)
                .opacity(isSelected ? 1 : 0)
        }
        .frame(width: side, height: side)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .opacity(isEnabled ? 1 : 0.4)
    }
}
