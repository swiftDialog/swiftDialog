//
//  GradientSwatch.swift
//  dialog
//
//  Large preview of a gradient preset beside an options list whose cards carry `preview: "gradient:gNN"`.
//  Light draws the preset's `colors`, dark its `darkColors`.
//

import SwiftUI

struct GradientSwatch: View {
    /// "gradient:g09" or "g09".
    let reference: String

    @Environment(\.colorScheme) private var scheme

    nonisolated static let prefix = "gradient:"

    private var id: String {
        reference.hasPrefix(Self.prefix) ? String(reference.dropFirst(Self.prefix.count)) : reference
    }

    @Environment(\.palette) private var palette

    var body: some View {
        if let hexes = GradientPresets.stops(GradientPresets.prefix + id, dark: scheme == .dark) {
            LinearGradient(colors: hexes.map { Color(hex: $0) },
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            // Not a preset: the "your own colour" choice, a quiet tile hinting that a picker follows.
            ZStack {
                palette.text.opacity(0.05)
                VStack(spacing: 6) {
                    Image(systemName: "paintpalette").font(.system(size: 28))
                    Text("Pick on the next screen").font(.system(size: 12))
                }
                .foregroundStyle(palette.textMuted)
            }
        }
    }
}
