//
//  StepDotIndicator.swift
//  dialog
//
//  The footer's wayfinding dots: one dot per step with the current step as a pill, or one filled
//  measure for long flows. Decorative; the "4 of 6" counter beside it carries the exact position.
//  Drawn by `StepCounter`, the card action bar and the plain shells.
//

import SwiftUI

struct StepDotIndicator: View {
    let current: Int          // 1-based
    let total: Int
    let accentColor: Color
    /// Tap on dot n (1-based). Only the `.dots` form wires it.
    var onSelect: ((Int) -> Void)?

    /// A passed dot is the accent at `passedOpacity`, a future one `.quaternary`.
    enum DotState: Equatable { case passed, current, future }

    static func state(ofDot index: Int, current: Int) -> DotState {
        if index == current { return .current }
        return index < current ? .passed : .future
    }

    static let passedOpacity: Double = 0.45

    /// Past this many steps the slot draws one measure instead of dots. Capped, never windowed.
    static let maximumDots = 8

    /// What the progress slot draws for a flow of this length.
    enum Form: Equatable {
        case none       // fewer than two steps
        case dots       // one mark per step
        case measure    // a single filled track
    }

    static func form(total: Int) -> Form {
        guard total > 1 else { return .none }
        return total <= maximumDots ? .dots : .measure
    }

    /// Whether dots (not the measure) are drawn.
    static func drawsDots(total: Int) -> Bool {
        form(total: total) == .dots
    }

    /// Fill of the measure: `current / total`, clamped to 0…1. Step 1 is not zero progress and the
    /// last step is not a finished flow.
    static func measureFraction(current: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return min(max(Double(current) / Double(total), 0), 1)
    }

    /// The measure's track width equals eight dots and their gaps (8 × 7 + 7 × 5), so nothing
    /// beside the slot shifts when a flow crosses the cap.
    static let measureWidth: CGFloat = 91

    var body: some View {
        Group {
            switch Self.form(total: total) {
            case .none:
                EmptyView()
            case .dots:
                HStack(spacing: 5) {
                    ForEach(0..<max(0, total), id: \.self) { index in
                        let state = Self.state(ofDot: index + 1, current: current)
                        let isCurrent = state == .current
                        Capsule()
                            .fill(Self.fill(for: state, accent: accentColor))
                            .frame(width: isCurrent ? 18 : 7, height: 7)
                            .contentShape(Capsule())
                            .onTapGesture { onSelect?(index + 1) }
                    }
                }
            case .measure:
                StepMeasureBar(current: current, total: total, accentColor: accentColor)
            }
        }
        .accessibilityElement(children: .ignore)
        // Decorative: the counter beside the dots is the accessible statement.
        .accessibilityHidden(true)
    }

    private static func fill(for state: DotState, accent: Color) -> AnyShapeStyle {
        switch state {
        case .current: AnyShapeStyle(accent)
        case .passed:  AnyShapeStyle(accent.opacity(passedOpacity))
        case .future:  AnyShapeStyle(.quaternary)
        }
    }
}

/// The long-flow form of the progress slot: one filled track with the footprint of eight dots.
/// Drawn by `StepDotIndicator` in its `.measure` form and directly by the card action bar.
struct StepMeasureBar: View {
    let current: Int          // 1-based, like StepDotIndicator
    let total: Int
    let accentColor: Color

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.quaternary)
            Capsule().fill(accentColor)
                .frame(width: StepDotIndicator.measureWidth
                       * StepDotIndicator.measureFraction(current: current, total: total))
        }
        .frame(width: StepDotIndicator.measureWidth, height: 7)
        .accessibilityHidden(true)
    }
}
