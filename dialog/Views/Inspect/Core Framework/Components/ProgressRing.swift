//
//  ProgressRing.swift
//  dialog
//
//  The countdown/percentage ring the processing screens draw: a faint track, a trimmed arc
//  starting at 12 o'clock, and a bold center label.
//

import SwiftUI

struct ProgressRing: View {
    let fraction: CGFloat            // 0…1 arc fill
    let label: String                // center text (seconds remaining / "NN%")
    let color: Color
    var diameter: CGFloat = 100
    var lineWidth: CGFloat = 4
    var labelSize: CGFloat = 48
    var animation: Animation?        // nil = static arc
    var animationValue: Int = 0      // value driving the arc animation
    /// Shown under the number so "18" reads as seconds, items or percent.
    var unit: String?

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: lineWidth)
                .frame(width: diameter, height: diameter)

            arc

            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: labelSize, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                if let unit, !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: max(10, labelSize * 0.30)))
                        .foregroundStyle(.secondary)
                }
            }
        }
        // Read as one element, "seconds left, 18"; the arc only draws the same value.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unit?.isEmpty == false ? unit! : ChromeCopy.inProgress)
        .accessibilityValue(label)
    }

    @ViewBuilder
    private var arc: some View {
        let ring = Circle()
            .trim(from: 0, to: fraction)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: diameter, height: diameter)
            .rotationEffect(.degrees(-90))
        if let animation {
            ring.animation(animation, value: animationValue)
        } else {
            ring
        }
    }
}
