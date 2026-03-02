//
//  InspectSizes.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 22/09/2025
//
//  This file serves as the source for ech preset optimized window size
//

import Foundation
import CoreGraphics

/// Centralized sizing definitions for all Inspect Mode presets
public enum InspectSizes {

    /// Normalize preset name from short form to canonical form
    /// - Parameter preset: Preset name (e.g., "6" or "preset6")
    /// - Returns: Canonical preset name (e.g., "preset6")
    private static func normalizePreset(_ preset: String) -> String {
        if let number = Int(preset), number >= 1 && number <= 6 {
            return "preset\(number)"
        }
        // Handle named aliases
        let lowercased = preset.lowercased()
        switch lowercased {
        case "portal", "self-service", "webview-portal":
            return "preset5"
        case "toast", "compact-installer":
            return "preset4"
        case "guidance", "modern-sidebar":
            return "preset6"
        default:
            return lowercased
        }
    }

    /// Get the window size for a specific preset and size mode
    /// - Parameters:
    ///   - preset: In JSON fiel call the preset by name (e.g., "preset1", "preset2", etc.)
    ///   - mode: Set the size mode ("compact", "standard", or "large")
    ///  - Returns: A tuple of (width, height) as CGFloat values
    public static func getSize(preset: String, mode: String) -> (CGFloat, CGFloat) {
        // Normalize short forms to canonical preset names
        let normalizedPreset = normalizePreset(preset)

        switch normalizedPreset {
        case "preset1":
            switch mode {
            case "compact": return (800, 600)
            case "large": return (1024, 768)
            default: return (900, 650)  // standard
            }

        case "preset2":
            switch mode {
            case "compact": return (800, 580)
            case "large": return (1200, 700)
            default: return (1000, 550)  // standard
            }

        case "preset3":
            switch mode {
            case "compact": return (800, 480)  // We are very narrow - special as we'll show two columns
            case "large": return (900, 750)
            default: return (850, 650)  // standard
            }

        case "preset4":
            // Compact toast installer
            switch mode {
            case "compact": return (480, 100)
            case "large": return (600, 130)
            default: return (550, 110)  // standard
            }

        case "preset5":
            // Unified portal / self-service
            switch mode {
            case "compact": return (1024, 640)   // Portal / self-service
            case "large": return (1200, 800)     // Maximum
            case "assistant": return (1024, 700)  // Apple-size inspired
            case "portal": return (1100, 700)    // Wide portal layout
            default: return (800, 600)           // Apple Setup Assistant (default)
            }

        case "preset6":
            // Modern sidebar navigation — 220pt sidebar + content panel
            switch mode {
            case "large": return (1100, 700)
            default: return (860, 620)  // standard (sidebar 220 + content 640)
            }

        default:
            // Default fallback for unknown presets
            return (1000, 600)
        }
    }

    /// Get the default size for Inspect Mode when no preset is specified
    public static var defaultSize: (CGFloat, CGFloat) {
        return (1000, 600)
    }

    /// Canonical spacing values for setup-size (800×600) step layouts.
    /// All step types should use these instead of hardcoded values.
    public enum SetupSpacing {
        /// Horizontal padding on main content area (40pt)
        static let contentPadH: CGFloat = 40
        /// Max width for text-heavy content columns (480pt)
        static let contentMaxW: CGFloat = 480
        /// Minimum spacer height for breathing room (20pt)
        static let breathingRoom: CGFloat = 20
        /// Gap between title and subtitle — tight semantic pair (8pt)
        static let titleSubtitle: CGFloat = 8
        /// Gap between content blocks (12pt)
        static let blockGap: CGFloat = 12
        /// Gap between major sections (20pt)
        static let sectionGap: CGFloat = 20
        /// Top inset from container edge to first element (16pt)
        static let topInset: CGFloat = 16
    }
}
