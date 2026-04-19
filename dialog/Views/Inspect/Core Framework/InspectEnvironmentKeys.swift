//
//  InspectEnvironmentKeys.swift
//  Dialog
//
//  Shared SwiftUI `EnvironmentKey`s used by Inspect-mode views to reach services
//  that are owned by preset root views (Preset5View, Preset6View) without passing
//  them through every render-layer initializer.
//

import SwiftUI

// MARK: - Compliance Aggregator

/// Environment key exposing the preset's `ComplianceAggregatorService` to shared
/// renderers (`GuidanceContentView`, `BentoGridView`, compliance content blocks).
/// Each preset root injects it via `.environment(\.complianceAggregator, complianceService)`;
/// child views read `@Environment(\.complianceAggregator)`. Falls back to `nil` when
/// a preset does not own an aggregator (e.g. Preset 1–4), in which case plist-driven
/// blocks short-circuit their rendering and bento cells skip the auto-binding.
private struct ComplianceAggregatorKey: EnvironmentKey {
    static let defaultValue: ComplianceAggregatorService? = nil
}

extension EnvironmentValues {
    var complianceAggregator: ComplianceAggregatorService? {
        get { self[ComplianceAggregatorKey.self] }
        set { self[ComplianceAggregatorKey.self] = newValue }
    }
}
