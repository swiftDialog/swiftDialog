//
//  FractionBar.swift
//  dialog
//
//  The linear fraction bar (rounded track + leading fill) shared by compliance, guidance status blocks and
//  Preset 3. Indeterminate progress uses `IndeterminateProgressView` instead.

import SwiftUI

struct FractionBar: View {
    /// Filled portion, 0–1; callers clamp.
    let fraction: Double
    var height: CGFloat = 8
    var cornerRadius: CGFloat = 4
    let fill: Color
    var track: Color = Color.secondary.opacity(0.2)
    /// Animates fill-width changes (easeInOut 0.3).
    var animateChanges: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(track)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fill)
                    .frame(width: geometry.size.width * fraction, height: height)
                    .animation(animateChanges ? .easeInOut(duration: 0.3) : nil, value: fraction)
            }
        }
        .frame(height: height)
    }
}
