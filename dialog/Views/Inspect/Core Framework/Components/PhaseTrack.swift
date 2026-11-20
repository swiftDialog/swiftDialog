//
//  PhaseTrack.swift
//  Dialog
//
//  The phase track's layout and state rules, kept pure over the phase list so views only draw.
//

import SwiftUI

/// What each mark on the phase track means and how wide each segment is. One accent at three
/// weights (filled, ringed, hairline); red appears only for failure.
enum PhaseTrack {

    /// Failure is a state of a real phase, not an extra phase appended to the track.
    enum MarkState: Equatable {
        case done, current, pending, blocked, failed
    }

    /// An authored state wins over position, so a failed phase keeps saying so after the track
    /// moves past it.
    static func state(at index: Int,
                      in phases: [InspectConfig.GuidanceContent.PhaseSpec],
                      currentPhase: Int) -> MarkState {
        if let authored = phases[safe: index]?.state {
            switch authored {
            case .done:    return .done
            case .current: return .current
            case .pending: return .pending
            case .blocked: return .blocked
            case .failed:  return .failed
            }
        }
        // `currentPhase` is 1-based and hand-authored; comparing, not indexing, tolerates out-of-range.
        let position = index + 1
        if position < currentPhase { return .done }
        if position == currentPhase { return .current }
        return .pending
    }

    /// Vertical when any phase carries a `detail` sentence; there is no style key for this.
    static func prefersVertical(_ phases: [InspectConfig.GuidanceContent.PhaseSpec]) -> Bool {
        phases.contains { ($0.detail?.isEmpty == false) }
    }

    /// Drawn to scale (segmented bar) when any phase authors a `chunkSize`; `prefersVertical` wins
    /// where both apply.
    static func prefersProportional(_ phases: [InspectConfig.GuidanceContent.PhaseSpec]) -> Bool {
        phases.contains { $0.chunkSize != nil }
    }

    /// What a segment of the proportional bar is filled with.
    enum SegmentFill: Equatable {
        case full                 // done: solid accent
        case partial(Double)      // running, progress known
        case inFlight             // running, progress unknown; never a made-up number
        case blocked              // accent outline, no fill
        case failed               // the one place red appears
        case empty
    }

    /// `progress` is the live 0…1 value and applies only to the phase in flight.
    static func fill(at index: Int,
                     in phases: [InspectConfig.GuidanceContent.PhaseSpec],
                     currentPhase: Int,
                     progress: Double?) -> SegmentFill {
        switch state(at: index, in: phases, currentPhase: currentPhase) {
        case .done:    return .full
        case .failed:  return .failed
        case .blocked: return .blocked
        case .pending: return .empty
        case .current:
            guard let progress else { return .inFlight }
            return .partial(min(1, max(0, progress)))
        }
    }

    /// Segment widths for the proportional track. Equal widths when no phase authors a
    /// `chunkSize`; otherwise each takes its weight's share, segments under `minimum` (or
    /// `spacerMinimum` when unlabelled) are raised to it at the expense of those with slack, and
    /// equal widths are returned if the floors cannot all fit.
    static func segmentWidths(for phases: [InspectConfig.GuidanceContent.PhaseSpec],
                              total: CGFloat,
                              minimum: CGFloat,
                              spacerMinimum: CGFloat = 0) -> [CGFloat] {
        let count = phases.count
        guard count > 0, total > 0 else { return [] }
        let equal = Array(repeating: total / CGFloat(count), count: count)

        guard phases.contains(where: { $0.chunkSize != nil }) else { return equal }

        let floors = phases.map { $0.label.isEmpty ? spacerMinimum : minimum }
        guard floors.reduce(0, +) <= total else { return equal }

        let weights = phases.map { ($0.chunkSize ?? .regular).weight }
        let sum = weights.reduce(0, +)
        guard sum > 0 else { return equal }

        var widths = weights.map { total * CGFloat($0 / sum) }

        // Take the deficit back from each wide segment in proportion to its slack.
        let deficit = zip(widths, floors).reduce(CGFloat(0)) { $0 + max(0, $1.1 - $1.0) }
        if deficit > 0 {
            let slack = zip(widths, floors).reduce(CGFloat(0)) { $0 + max(0, $1.0 - $1.1) }
            guard slack > 0 else { return equal }
            widths = zip(widths, floors).map { w, floor in
                if w < floor { return floor }
                return w - (w - floor) / slack * deficit
            }
        }
        return widths
    }

    /// The fraction the `progress` style's bar fills to: the weight of `done` phases over the
    /// total. A phase in flight or failed does not count; the result saturates at 0…1.
    static func coveredFraction(for phases: [InspectConfig.GuidanceContent.PhaseSpec],
                                currentPhase: Int) -> Double {
        guard !phases.isEmpty else { return 0 }
        let weights = phases.map { ($0.chunkSize ?? .regular).weight }
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }
        let covered = phases.indices.reduce(Double(0)) { sum, index in
            state(at: index, in: phases, currentPhase: currentPhase) == .done
                ? sum + weights[index]
                : sum
        }
        return min(1, max(0, covered / total))
    }

    /// The phase number a counter may print; `currentPhase` is authored by hand.
    static func clamped(phaseNumber: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(phaseNumber, 1), count)
    }

    /// Whether the connector entering phase `segmentBefore` (1-based) draws in accent (covered)
    /// or as a hairline.
    static func isCovered(segmentBefore position: Int, currentPhase: Int) -> Bool {
        position < currentPhase
    }
}
