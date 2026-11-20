//
//  Door.swift
//
//  The footer kit's way-out controls. `BackDoor` decides which words a back door carries; `Door`
//  decides what shape a control takes. Neither knows about a footer, a chrome or a preset.
//

import SwiftUI

enum BackDoor {
    /// The one precedence chain for a back door's words, shared by Presets 5 and 6: localized,
    /// then the per-step key, then the global, then the fallback. Empty strings fall through.
    static func label(localized: String?, step: String?, branding: String?,
                      fallback: String = "Back") -> String {
        for candidate in [localized, step, branding] {
            if let candidate, !candidate.isEmpty { return candidate }
        }
        return fallback
    }
}

/// A way out of the current screen that is not the primary action: back, skip, secondary, close.
/// Fixed numbers are constants here; only plate and ink vary per seat. These set no accessibility;
/// each seat keeps its own `.help` / `.accessibilityLabel`.
///
/// Main-actor because every member builds a `Button` with a `ButtonStyle` static.
@MainActor
enum Door {

    /// The back circle: 32pt, a 14pt semibold chevron, no border.
    static func back<P: ShapeStyle, I: ShapeStyle>(
        plate: P, ink: I, label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(plate))
        }
        .buttonStyle(.plain)
    }

    /// A bare word. `size` nil inherits the row's font.
    static func word<I: ShapeStyle>(
        ink: I, size: CGFloat? = nil, label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if let size { Text(label).font(.system(size: size)) } else { Text(label) }
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
    }

    /// A bordered button, for back and skip alike.
    static func pill(_ controlSize: ControlSize, label: String,
                     action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.bordered)
            .controlSize(controlSize)
    }

    /// A chevron beside a word; the detail sheet's dismissal.
    static func wordWithChevron<I: ShapeStyle>(
        ink: I, label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                Text(label).font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(ink)
        }
        .buttonStyle(.plain)
    }
}
