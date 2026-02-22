//
// ContentBlockRenderer.swift
//  Dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Shared content block renderer for Preset6 and Preset5
//  Provides consistent rendering of GuidanceContent blocks across presets
//

import SwiftUI

// MARK: - Content Block Renderer

/// Main dispatcher for rendering GuidanceContent blocks
/// Used by Preset6 and Preset5 for consistent content rendering
struct ContentBlockRenderer {
    let accentColor: Color
    let maxWidth: CGFloat
    let formValues: Binding<[String: String]>?
    let preferencesService: PreferencesService?

    init(
        accentColor: Color,
        maxWidth: CGFloat = 420,
        formValues: Binding<[String: String]>? = nil,
        preferencesService: PreferencesService? = nil
    ) {
        self.accentColor = accentColor
        self.maxWidth = maxWidth
        self.formValues = formValues
        self.preferencesService = preferencesService
    }

    // MARK: - Centered Container

    /// Wraps content in a centered container with max width
    @ViewBuilder
    func centeredContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Main Render Dispatcher

    /// Renders a GuidanceContent block based on its type
    @ViewBuilder
    func render(_ block: InspectConfig.GuidanceContent) -> some View {
        switch block.type {
        // Tables
        case "feature-table":
            FeatureTableBlock(block: block, accentColor: accentColor, maxWidth: maxWidth)

        case "comparison-table":
            ComparisonTableBlock(block: block, accentColor: accentColor, maxWidth: maxWidth)

        // Status Components
        case "compliance-card":
            ComplianceCardBlock(block: block, accentColor: accentColor, maxWidth: maxWidth)

        case "progress-bar":
            ProgressBarBlock(block: block, accentColor: accentColor, maxWidth: maxWidth)

        // Media
        case "image-carousel":
            ImageCarouselBlock(block: block, accentColor: accentColor, maxWidth: maxWidth)

        default:
            EmptyView()
        }
    }

    /// Check if this renderer handles a given block type
    static func handles(_ type: String) -> Bool {
        let handledTypes = [
            "feature-table",
            "comparison-table",
            "compliance-card",
            "progress-bar",
            "image-carousel"
        ]
        return handledTypes.contains(type)
    }
}

// MARK: - Shared Styling Helpers

extension ContentBlockRenderer {
    /// Standard card background style
    static func cardBackground(color: Color = Color(NSColor.controlBackgroundColor)) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(color.opacity(0.5))
    }

    /// Standard section header style
    static func sectionHeaderStyle(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
    }
}
