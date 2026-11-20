//
//  GuidanceInlineIcon.swift
//  dialog
//
//  A small row icon resolved via `IconRef` from "SF=globe", a bare symbol name, an absolute file,
//  or a path relative to iconBasePath.

import SwiftUI

/// A small leading icon for a row: SF Symbol or image file, sized to a square slot.
struct GuidanceInlineIcon: View {
    let icon: String
    let size: CGFloat
    var basePath: String?
    var tint: Color?

    /// The option-row slot only holds a mark, so a bare `globe` is a symbol; file-shaped names go to the loader.
    private var symbolName: String? { IconRef.symbolOrBareName(icon) }

    var body: some View {
        if let symbolName {
            Image(systemName: symbolName)
                .font(.system(size: size * 0.62))
                .foregroundStyle(tint ?? .secondary)
                .frame(width: size, height: size)
        } else {
            AsyncImageView(
                iconPath: icon,
                basePath: basePath,
                maxWidth: size,
                maxHeight: size,
                imageFit: .fit,
                showLoadingState: false,
                fallback: {
                    // An unloadable file draws nothing, keeping the slot so titles stay aligned.
                    Color.clear
                }
            )
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
