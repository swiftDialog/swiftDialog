//
//  BrandTrackControls.swift
//  dialog
//
//  `BrandSegmented` and `BrandSlider`: branded replacements for the native segmented control and
//  slider, which lose the accent colour in dark mode. Neither accepts text input.
//

import SwiftUI

// MARK: - Segmented

/// A segmented control drawn from the palette: a capsule track with one filled selection,
/// at the platform's own geometry.
struct BrandSegmented: View {
    let options: [String]
    @Binding var selection: String
    /// Announced by VoiceOver as the control's name; the visible label is drawn by the caller.
    let accessibilityLabel: String
    var accentColor: Color?
    var scaleFactor: CGFloat = 1

    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    private var tint: Color { accentColor ?? palette.accent }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(option)
                        .font(.system(size: 12.5 * scaleFactor,
                                      weight: isSelected ? .semibold : .regular))
                        // On-accent ink stays white in both appearances, like the toggle's thumb.
                        .foregroundStyle(isSelected ? .white : palette.text)
                        .lineLimit(1)
                        .padding(.horizontal, 12 * scaleFactor)
                        .padding(.vertical, 5 * scaleFactor)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(isSelected ? tint : Color.clear)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2 * scaleFactor)
        .background(
            // `surfaceRaised` is relative to the text colour, so the well survives both appearances.
            Capsule().fill(palette.surfaceRaised)
        )
        .animation(.easeInOut(duration: 0.14), value: selection)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityRepresentation {
            Picker(accessibilityLabel, selection: $selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - Slider

/// A slider drawn from the palette: a thin track, an accent fill to the thumb, and a white knob.
/// Drag maps across the track width minus one thumb, values snap to `step`, arrow keys nudge by
/// one step, and VoiceOver adjusts through `accessibilityAdjustableAction`.
struct BrandSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let accessibilityLabel: String
    var accentColor: Color?
    var scaleFactor: CGFloat = 1

    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var focused: Bool

    private var tint: Color { accentColor ?? palette.accent }
    private var thumb: CGFloat { 18 * scaleFactor }
    private var trackHeight: CGFloat { 4 * scaleFactor }

    private var span: Double { max(range.upperBound - range.lowerBound, .ulpOfOne) }
    private var fraction: Double {
        min(max((value - range.lowerBound) / span, 0), 1)
    }

    /// One tick per step, as fractions of the track; none past 20 steps, where they would merge.
    private var tickFractions: [Double] {
        guard step > 0 else { return [] }
        let count = (span / step).rounded()
        guard count >= 1, count <= 20 else { return [] }
        return (0...Int(count)).map { Double($0) / count }
    }

    /// Snap to `step`, then clamp, so a step that does not divide the range stays inside it.
    private func normalise(_ raw: Double) -> Double {
        guard step > 0 else { return min(max(raw, range.lowerBound), range.upperBound) }
        let steps = ((raw - range.lowerBound) / step).rounded()
        return min(max(range.lowerBound + steps * step, range.lowerBound), range.upperBound)
    }

    private func nudge(_ direction: Double) {
        value = normalise(value + direction * (step > 0 ? step : span / 20))
    }

    var body: some View {
        GeometryReader { geo in
            let usable = max(geo.size.width - thumb, 1)
            let x = thumb / 2 + usable * fraction

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.text.opacity(0.12))
                    .frame(height: trackHeight)
                Capsule()
                    .fill(tint)
                    .frame(width: x, height: trackHeight)
                // Ticks sit below the track, where AppKit puts them.
                ForEach(Array(tickFractions.enumerated()), id: \.offset) { _, f in
                    Circle()
                        .fill(palette.text.opacity(0.22))
                        .frame(width: 2 * scaleFactor, height: 2 * scaleFactor)
                        .offset(x: thumb / 2 + usable * f - 1 * scaleFactor,
                                y: trackHeight / 2 + 5 * scaleFactor)
                }
                Circle()
                    .fill(.white)
                    .shadow(color: palette.text.opacity(0.28), radius: 1, x: 0, y: 0.5)
                    .overlay(
                        // Stands in for the focus ring.
                        Circle().strokeBorder(focused ? tint : .clear, lineWidth: 2 * scaleFactor)
                    )
                    .frame(width: thumb, height: thumb)
                    .offset(x: x - thumb / 2)
            }
            .frame(height: geo.size.height, alignment: .center)
            // The drag target is the thumb-height band, not the 4pt line.
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let clamped = min(max(g.location.x - thumb / 2, 0), usable)
                        value = normalise(range.lowerBound + span * (clamped / usable))
                    }
            )
        }
        .frame(height: thumb)
        .focusable(isEnabled)
        .focused($focused)
        .onMoveCommand { direction in
            switch direction {
            case .left:  nudge(-1)
            case .right: nudge(1)
            default:     break
            }
        }
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(Text("\(Int(value.rounded()))"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: nudge(1)
            case .decrement: nudge(-1)
            @unknown default: break
            }
        }
    }
}
