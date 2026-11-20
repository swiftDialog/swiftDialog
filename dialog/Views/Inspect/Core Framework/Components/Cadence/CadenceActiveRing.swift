//
//  CadenceActiveRing.swift
//  dialog
//
//  An accent highlight travelling a rounded outline, so a tile reads as the thing in progress.
//  Seated on the running card of the journey grid.
//

import SwiftUI

extension CadenceM {
    /// One lap of the sweep, in seconds.
    static let ringRevolution: Double = 1.8
}

struct CadenceActiveRing: View {
    /// nil fills the container instead of taking a fixed square.
    var side: CGFloat?
    let cornerRadius: CGFloat
    let color: Color

    private let lineWidth: CGFloat = 2.5

    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                AngularGradient(
                    colors: [color, color.opacity(0.15), color],
                    center: .center,
                    startAngle: .degrees(Double(phase) * 360),
                    endAngle: .degrees(Double(phase) * 360 + 360)
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: side, height: side)
            // Decoration: the seat names the entry and its state in words.
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.linear(duration: CadenceM.ringRevolution).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
