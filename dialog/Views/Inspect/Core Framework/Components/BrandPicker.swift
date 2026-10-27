//
//  BrandPicker.swift
//  dialog
//
//  A dropdown whose closed state is drawn from the palette; AppKit's pop-up chrome ignores
//  `.tint()`. The open menu stays the system's. Assistive technology sees a standard `Picker`.
//

import SwiftUI

/// A dropdown whose closed state is drawn from the palette rather than by AppKit. The
/// `.accessibilityRepresentation` must stay: VoiceOver reads the `Picker`, not the drawn label.
struct BrandPicker: View {
    let options: [String]
    @Binding var selection: String
    /// Shown when `selection` is empty; the caller decides the wording.
    let placeholder: String
    /// The flow's accent, or nil to take the palette's.
    var accentColor: Color?
    var scaleFactor: CGFloat = 1

    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    private var tint: Color { accentColor ?? palette.accent }
    private var isPlaceholder: Bool { selection.isEmpty }

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    // A `Menu` of buttons draws no checkmark of its own.
                    if option == selection {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        } label: {
            HStack(spacing: 8 * scaleFactor) {
                Text(isPlaceholder ? placeholder : selection)
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(isPlaceholder ? palette.textMuted : palette.text)
                    .lineLimit(1)
                    // Fill the offered width so the control does not resize with the selection.
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                // The accent sits in a filled trailing square, as a macOS pop-up button draws it.
                ZStack {
                    RoundedRectangle(cornerRadius: 5 * scaleFactor, style: .continuous)
                        .fill(tint)
                        .frame(width: 19 * scaleFactor, height: 19 * scaleFactor)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9 * scaleFactor, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.leading, 10 * scaleFactor)
            .padding(.trailing, 4 * scaleFactor)
            .padding(.vertical, 4 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 7 * scaleFactor, style: .continuous)
                    .fill(palette.cardSurface)
                    .shadow(color: palette.text.opacity(0.14), radius: 0.5, x: 0, y: 0.5)
            )
            .contentShape(Rectangle())
        }
        // `.borderlessButton` draws its own chrome over the label; `.button` + `.plain` hands the
        // whole surface to it.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityRepresentation {
            Picker(placeholder, selection: $selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
        }
    }
}
