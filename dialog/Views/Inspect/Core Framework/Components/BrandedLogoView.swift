//
//  BrandedLogoView.swift
//  dialog
//
// Created by Henry Stamerjohann, Declarative IT GmbH, 25/01/2026
//
//  Unified logo component for consistent rendering across all step types.
//  Handles dark mode switching, wide-logo sizing, positioning, and opacity.
//  Rendered once at the Preset5 root level — persists across step transitions.
//
//

import SwiftUI

/// Persistent branded logo overlay. Renders once and stays across step transitions.
/// Position, opacity, and sizing are driven entirely by LogoConfig.
struct BrandedLogoView: View {
    let logoConfig: InspectConfig.LogoConfig
    let basePath: String?

    @Environment(\.colorScheme) private var colorScheme

    init(logoConfig: InspectConfig.LogoConfig, basePath: String? = nil) {
        self.logoConfig = logoConfig
        self.basePath = basePath
    }

    // MARK: - Resolved Properties

    private var effectiveLogoPath: String {
        if colorScheme == .dark, let darkPath = logoConfig.imagePathDark {
            return darkPath
        }
        return logoConfig.imagePath
    }

    private var effectiveWidth: CGFloat {
        CGFloat(logoConfig.maxWidth ?? 120)
    }

    private var effectiveHeight: CGFloat {
        CGFloat(logoConfig.maxHeight ?? 40)
    }

    private var pos: String {
        logoConfig.position?.lowercased() ?? "topright"
    }

    private var isBottom: Bool { pos.contains("bottom") }
    private var isLeft: Bool { pos.contains("left") }

    /// Config opacity, or position-based default: bottom = 0.6, top = 1.0
    private var effectiveOpacity: Double {
        logoConfig.opacity ?? (isBottom ? 0.6 : 1.0)
    }

    private var edgePaddingH: CGFloat {
        CGFloat(logoConfig.padding ?? 20)
    }

    private var edgePaddingV: CGFloat {
        if let padding = logoConfig.padding {
            return CGFloat(padding)
        }
        // Bottom logos need more clearance to sit above the footer bar (~60pt)
        return isBottom ? 64 : 16
    }

    // MARK: - Body

    var body: some View {
        VStack {
            if isBottom { Spacer() }
            HStack {
                if !isLeft { Spacer() }
                AsyncImageView(
                    iconPath: effectiveLogoPath,
                    basePath: basePath,
                    maxWidth: effectiveWidth,
                    maxHeight: effectiveHeight,
                    imageFit: .fit,
                    fallback: { EmptyView() }
                )
                .opacity(effectiveOpacity)
                .padding(isLeft ? .leading : .trailing, edgePaddingH)
                .padding(isBottom ? .bottom : .top, edgePaddingV)
                if isLeft { Spacer() }
            }
            if !isBottom { Spacer() }
        }
    }
}
