//
//  AppearanceSwatch.swift
//  dialog
//
//  A drawn miniature desktop in light, dark or auto (diagonal split), used as picker tile content.
//

import SwiftUI

/// A miniature macOS window rendered in a given appearance; takes only a kind and a scale.
struct AppearanceSwatch: View {
    /// `light`, `dark` or `auto`.
    let kind: String
    var scaleFactor: CGFloat = 1.0

    /// The built-in vocabulary; a card naming anything else falls back to its icon.
    /// `nonisolated` because off-actor builders read it and a `Set<String>` is `Sendable`.
    nonisolated static let known: Set<String> = ["light", "dark", "auto"]

    var body: some View {
        ZStack {
            switch kind {
            case "dark":  window(dark: true)
            case "auto":
                // Light beneath, dark clipped to the leading triangle.
                window(dark: false)
                window(dark: true).clipShape(DiagonalSplit())
            default:      window(dark: false)
            }
        }
        .frame(width: 96 * scaleFactor, height: 64 * scaleFactor)
        .clipShape(.rect(cornerRadius: 7 * scaleFactor))
        .overlay(
            RoundedRectangle(cornerRadius: 7 * scaleFactor, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .accessibilityHidden(true)   // the card's label and subtitle already name the choice
    }

    /// One miniature desktop: a title bar with traffic lights, then two content lines.
    private func window(dark: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 3 * scaleFactor) {
                Circle().fill(Color(hex: "#FF5F57")).frame(width: 5 * scaleFactor, height: 5 * scaleFactor)
                Circle().fill(Color(hex: "#FEBC2E")).frame(width: 5 * scaleFactor, height: 5 * scaleFactor)
                Circle().fill(Color(hex: "#28C840")).frame(width: 5 * scaleFactor, height: 5 * scaleFactor)
                Spacer()
            }
            .padding(.horizontal, 6 * scaleFactor)
            .frame(height: 14 * scaleFactor)
            .background(dark ? Color(hex: "#3A3A3C") : Color(hex: "#ECECEE"))

            VStack(alignment: .leading, spacing: 5 * scaleFactor) {
                Capsule().fill(ink(dark).opacity(0.55))
                    .frame(width: 46 * scaleFactor, height: 4 * scaleFactor)
                Capsule().fill(ink(dark).opacity(0.3))
                    .frame(width: 62 * scaleFactor, height: 4 * scaleFactor)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8 * scaleFactor)
            .padding(.top, 8 * scaleFactor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(dark ? Color(hex: "#1E1E1F") : Color.white)
        }
    }

    private func ink(_ dark: Bool) -> Color { dark ? .white : .black }
}

/// Leading triangle for the `auto` split.
private struct DiagonalSplit: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
