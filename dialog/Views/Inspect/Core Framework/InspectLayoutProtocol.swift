//
//  InspectLayoutProtocol.swift
//  dialog
//
//  Layout defaults every preset root view conforms to (scales, metrics, window size), plus the
//  narrow context protocols shared components render from instead of the whole `InspectState`.
//

import SwiftUI

// MARK: - Protocol Definition

/// Main-actor because every conformer is a SwiftUI `View` and the protocol re-declares `body`,
/// which is main-actor-isolated.
@MainActor
protocol InspectLayoutProtocol {
    associatedtype Body: View

    var inspectState: InspectState { get }

    @ViewBuilder var body: Body { get }
}

// MARK: - Protocol Extension

extension InspectLayoutProtocol {

    // MARK: Properties

    /// Scale-resolved layout tokens; every value is post-scale, never multiply it by scale again.
    var metrics: InspectMetrics {
        InspectMetrics(typeScale: typeScale, measureScale: measureScale)
    }

    /// The resolved reading-comfort tier, a pure function of the authored value and the preset.
    var density: InspectDensity {
        InspectDensity.resolve(authored: inspectState.uiConfiguration.density,
                               preset: inspectState.uiConfiguration.preset).tier
    }

    /// Fonts and icon point sizes. The only place an authored `density` tier is multiplied in.
    var typeScale: CGFloat { scaleFactor * density.typeScale }

    /// Columns, padding, spacing. Pinned to the window; must not follow density.
    var measureScale: CGFloat { scaleFactor }

    /// The one-knob value still fed to components that take a raw `scaleFactor:`. Equals `measureScale`.
    var scaleFactor: CGFloat {
        InspectSizes.scale(mode: inspectState.uiConfiguration.size)
    }

    // MARK: Window Size Management

    /// The window size from the one ladder in `InspectSizes`, shared with launch-time sizing.
    var windowSize: CGSize {
        InspectSizes.windowSize(
            width: inspectState.uiConfiguration.width,
            height: inspectState.uiConfiguration.height,
            preset: inspectState.uiConfiguration.preset,
            mode: inspectState.uiConfiguration.size,
            itemCount: inspectState.items.count,
            chrome: inspectState.uiConfiguration.chrome,
            bandGrowth: InspectSizes.cardBandGrowth(config: inspectState.config)
        ).size
    }

    /// The current size mode.
    var sizeMode: String {
        return inspectState.uiConfiguration.size ?? "standard"
    }

    // MARK: Common UI Dimensions

    var iconSize: CGFloat {
        return CGFloat(inspectState.uiConfiguration.iconSize) * scaleFactor
    }

    /// Display text for an item's status: item-specific text, then global labels, then the default.
    /// The body lives in `ItemSetModel.displayStatusText(for:state:)`.
    func getItemStatus(for item: InspectConfig.ItemConfig) -> String {
        ItemSetModel.displayStatusText(for: item, state: inspectState)
    }

    // MARK: UI Components
}

// MARK: - Supporting Types
// Item status is the shared StepStatus from StepModel.swift.

// MARK: - Component Context Protocols

// The explicit surface shared components depend on. `InspectState` conforms; classic dialog's
// state object can conform too, so components typed against these are the classic ↔ inspect bridge.

/// Read-only configuration surface components render from.
protocol ContentContext: AnyObject {
    var config: InspectConfig? { get }
    var items: [InspectConfig.ItemConfig] { get }
    var uiConfiguration: UIConfiguration { get }
    var colorThresholds: InspectConfig.ColorThresholds { get }
    var itemIconOverrides: [String: String] { get }
}

extension ContentContext {
    /// Contexts with no running overrides (classic dialog's content) have none.
    var itemIconOverrides: [String: String] { [:] }
}

/// Live install/progress surface (completion sets driven by monitors/IPC).
protocol ProgressContext: AnyObject {
    var completedItems: Set<String> { get }
    var downloadingItems: Set<String> { get }
    var failedItems: Set<String> { get }
}

/// Live cadence surface for the gated run a `cadence` step drives. Read-only: a block may ask
/// what the run has measured; starting and advancing it stay with the preset.
protocol CadenceContext: AnyObject {
    var cadenceMonitor: CadenceMonitorService { get }
}

/// User-input sink: selection stores + the interaction log components emit choices into.
protocol UserInputContext: ContentContext {
    var userValues: [String: String] { get set }
    var wallpaperSelection: [String: String] { get set }
    var dockSelection: [String: String] { get set }
    var guidanceFormInputs: [String: GuidanceFormInputState] { get set }
    func writeToInteractionLog(_ message: String)
    func initializeGuidanceFormState(for itemId: String)
    func resolveInheritValue(_ inheritSpec: String, basePath: String?) -> String?
}

// Defaults so a conformer only implements the guidance-form machinery if it renders form blocks.
extension UserInputContext {
    func initializeGuidanceFormState(for itemId: String) {}
    func resolveInheritValue(_ inheritSpec: String, basePath: String?) -> String? { nil }
}

// InspectState is @MainActor, so each conformance is main-actor-isolated (SE-0470); the protocols
// themselves stay nonisolated so DialogUpdatableContent's conformances can too.
extension InspectState: @MainActor ContentContext, @MainActor ProgressContext, @MainActor UserInputContext {}
