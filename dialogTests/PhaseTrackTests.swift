//
//  PhaseTrackTests.swift
//  dialogTests
//
//  The phase track: its state, segment widths, covered fraction and bar.
//

import XCTest
@testable import Dialog

// MARK: - Mark per phase
// Done is filled, pending outlined, the covered track accent; an authored state stays in step with `currentPhase`.

final class PhaseTrackStateTests: XCTestCase {

    private func spec(_ label: String, state: String? = nil) throws -> InspectConfig.GuidanceContent.PhaseSpec {
        let json = state.map { #"{"label":"\#(label)","state":"\#($0)"}"# } ?? #"{"label":"\#(label)"}"#
        return try JSONDecoder().decode(InspectConfig.GuidanceContent.PhaseSpec.self,
                                         from: Data(json.utf8))
    }

    func testPositionDerivesTheThreeOrdinaryStates() throws {
        let phases = [try spec("A"), try spec("B"), try spec("C")]
        XCTAssertEqual(PhaseTrack.state(at: 0, in: phases, currentPhase: 2), .done)
        XCTAssertEqual(PhaseTrack.state(at: 1, in: phases, currentPhase: 2), .current)
        XCTAssertEqual(PhaseTrack.state(at: 2, in: phases, currentPhase: 2), .pending)
    }

    /// An authored state (blocked, failed) overrides position.
    func testAnAuthoredStateOverridesPosition() throws {
        let phases = [try spec("A"), try spec("B", state: "failed"), try spec("C")]
        XCTAssertEqual(PhaseTrack.state(at: 1, in: phases, currentPhase: 2), .failed)
        XCTAssertEqual(PhaseTrack.state(at: 1, in: phases, currentPhase: 3), .failed,
                       "a failed phase keeps its state even once the track has moved past it")
    }

    /// An out-of-range `currentPhase` (1-based, hand-written) neither crashes nor invents state.
    func testAnOutOfRangeCurrentPhaseDoesNotCrashOrInventState() throws {
        let phases = [try spec("A"), try spec("B")]
        XCTAssertEqual(PhaseTrack.state(at: 0, in: phases, currentPhase: 99), .done)
        XCTAssertEqual(PhaseTrack.state(at: 0, in: phases, currentPhase: 0), .pending)
    }

    /// The connector is accent only behind the current phase.
    func testTheConnectorIsCoveredOnlyBehindTheCurrentPhase() {
        XCTAssertTrue(PhaseTrack.isCovered(segmentBefore: 1, currentPhase: 2))
        XCTAssertFalse(PhaseTrack.isCovered(segmentBefore: 2, currentPhase: 2))
        XCTAssertFalse(PhaseTrack.isCovered(segmentBefore: 3, currentPhase: 2))
    }
}

// MARK: - Horizontal holds a word, vertical a sentence

extension PhaseTrackStateTests {

    private func detailed(_ label: String, _ detail: String?) -> InspectConfig.GuidanceContent.PhaseSpec {
        .init(label: label, detail: detail)
    }

    func testBareLabelsStayHorizontal() {
        XCTAssertFalse(PhaseTrack.prefersVertical([detailed("A", nil), detailed("B", nil)]))
    }

    /// One phase with detail turns the whole track vertical.
    func testOneDetailedPhaseTurnsTheWholeTrackVertical() {
        XCTAssertTrue(PhaseTrack.prefersVertical([detailed("A", nil),
                                                  detailed("B", "Starts at 21:00 tonight."),
                                                  detailed("C", nil)]))
    }

    /// An empty detail does not flip the layout.
    func testAnEmptyDetailIsNotASentence() {
        XCTAssertFalse(PhaseTrack.prefersVertical([detailed("A", "")]))
    }
}

// MARK: - Chunk sizes

final class PhaseSegmentWidthTests: XCTestCase {

    private func p(_ label: String, _ size: String? = nil) -> InspectConfig.GuidanceContent.PhaseSpec {
        .init(label: label,
              chunkSize: size.flatMap(InspectConfig.PhaseSpec.ChunkSize.init(rawValue:)))
    }

    /// No chunkSize anywhere gives exactly equal widths.
    /// 100 / 3 does not divide evenly, so bit-exact equality only holds through the equal-width path.
    func testNoAuthoredSizeGivesExactlyEqualWidths() {
        let w = PhaseTrack.segmentWidths(for: [p("A"), p("B"), p("C")], total: 100, minimum: 20)
        XCTAssertEqual(w, [100.0 / 3, 100.0 / 3, 100.0 / 3])
    }

    func testSegmentsTakeTheirShareAndFillTheTotal() {
        // nano 1 : long 7 → 30 : 210 of 240
        let w = PhaseTrack.segmentWidths(for: [p("A", "nano"), p("B", "long")], total: 240, minimum: 10)
        XCTAssertEqual(w[0], 30, accuracy: 0.001)
        XCTAssertEqual(w[1], 210, accuracy: 0.001)
        XCTAssertEqual(w.reduce(0, +), 240, accuracy: 0.001, "segments must stretch to the total")
    }

    /// An unsized phase among sized ones counts as `regular`.
    func testAnUnsizedPhaseCountsAsRegular() {
        let w = PhaseTrack.segmentWidths(for: [p("A", "nano"), p("B")], total: 250, minimum: 10)
        XCTAssertEqual(w[0], 50, accuracy: 0.001)   // 1 of (1+4)
        XCTAssertEqual(w[1], 200, accuracy: 0.001)  // 4 of (1+4)
    }

    /// A starved segment is raised to the floor, paid back from slack; the total stays exact.
    func testAStarvedSegmentIsRaisedToTheFloor() {
        let w = PhaseTrack.segmentWidths(for: [p("A", "nano"), p("B", "long")], total: 240, minimum: 60)
        XCTAssertEqual(w[0], 60, accuracy: 0.001)
        XCTAssertEqual(w.reduce(0, +), 240, accuracy: 0.001)
        XCTAssertGreaterThan(w[1], w[0], "long must still read as longer than nano")
    }

    /// When the floors cannot all fit, widths fall back to equal.
    func testWidthsFallBackToEqualWhenTheFloorsCannotFit() {
        let w = PhaseTrack.segmentWidths(for: [p("A", "nano"), p("B", "long"), p("C", "mini")],
                                         total: 100, minimum: 60)
        XCTAssertEqual(w, [100.0 / 3, 100.0 / 3, 100.0 / 3])
    }

    func testAnEmptyTrackHasNoSegments() {
        XCTAssertEqual(PhaseTrack.segmentWidths(for: [], total: 300, minimum: 40), [])
    }
}

// MARK: - Progress bar

final class PhaseCoveredFractionTests: XCTestCase {

    private func p(_ label: String, _ size: String? = nil, _ state: String? = nil)
        -> InspectConfig.GuidanceContent.PhaseSpec {
        .init(label: label,
              state: state.flatMap(InspectConfig.PhaseSpec.PhaseState.init(rawValue:)),
              chunkSize: size.flatMap(InspectConfig.PhaseSpec.ChunkSize.init(rawValue:)))
    }

    private let five = ["A", "B", "C", "D", "E"]

    /// The phase in flight is not finished: on phase 3 of 5, two are covered.
    func testTheBarCountsFinishedPhasesNotTheOneInFlight() {
        let w = PhaseTrack.coveredFraction(for: five.map { p($0) }, currentPhase: 3)
        XCTAssertEqual(w, 0.4, accuracy: 0.0001)
    }

    /// Coverage is weighted by chunk size, like the marks.
    func testCoverageIsWeightedByChunkSize() {
        let phases = [p("A", "long"), p("B", "nano"), p("C", "nano")]
        // 7 of 7 + 1 + 1
        XCTAssertEqual(PhaseTrack.coveredFraction(for: phases, currentPhase: 2),
                       7.0 / 9.0, accuracy: 0.0001)
    }

    /// A failed phase is not covered track.
    func testAFailedPhaseIsNotCoveredTrack() {
        let phases = [p("A", nil, "failed"), p("B"), p("C"), p("D"), p("E")]
        XCTAssertEqual(PhaseTrack.coveredFraction(for: phases, currentPhase: 3),
                       0.2, accuracy: 0.0001, "only B is behind us AND done")
    }

    /// An out-of-range `currentPhase` saturates the bar.
    func testAnOutOfRangePhaseSaturatesTheBar() {
        XCTAssertEqual(PhaseTrack.coveredFraction(for: five.map { p($0) }, currentPhase: 99), 1.0)
        XCTAssertEqual(PhaseTrack.coveredFraction(for: five.map { p($0) }, currentPhase: 0), 0.0)
        XCTAssertEqual(PhaseTrack.coveredFraction(for: five.map { p($0) }, currentPhase: -4), 0.0)
    }

    func testAnEmptyTrackIsNotDividedBy() {
        XCTAssertEqual(PhaseTrack.coveredFraction(for: [], currentPhase: 2), 0.0)
    }

    /// The counter never prints "Phase 7 of 5".
    func testThePhaseCounterStaysInsideTheTrack() {
        XCTAssertEqual(PhaseTrack.clamped(phaseNumber: 7, count: 5), 5)
        XCTAssertEqual(PhaseTrack.clamped(phaseNumber: 0, count: 5), 1)
        XCTAssertEqual(PhaseTrack.clamped(phaseNumber: 3, count: 5), 3)
        XCTAssertEqual(PhaseTrack.clamped(phaseNumber: 3, count: 0), 0, "no track, no phase number")
    }
}

// MARK: - Segmented timeline bar

final class PhaseBarTests: XCTestCase {

    private func p(_ label: String, _ size: String? = nil, _ state: String? = nil)
        -> InspectConfig.GuidanceContent.PhaseSpec {
        .init(label: label,
              state: state.flatMap(InspectConfig.PhaseSpec.PhaseState.init(rawValue:)),
              chunkSize: size.flatMap(InspectConfig.PhaseSpec.ChunkSize.init(rawValue:)))
    }

    /// Authoring a chunk size selects the bar.
    func testAuthoringAChunkSizeAsksForTheBar() {
        XCTAssertFalse(PhaseTrack.prefersProportional([p("A"), p("B")]))
        XCTAssertTrue(PhaseTrack.prefersProportional([p("A"), p("B", "long")]))
    }

    /// The floor applies only to labelled segments, so an unlabelled spread stays to scale.
    func testTheFloorAppliesOnlyToSegmentsThatCarryALabel() {
        // The labelled segment is the smallest, so the floor must raise it (nano among long: 33 of 300).
        let phases = [p("", "nano"), p("Downloading", "nano"), p("", "long")]
        let w = PhaseTrack.segmentWidths(for: phases, total: 300, minimum: 120, spacerMinimum: 6)
        XCTAssertEqual(w[1], 120, accuracy: 0.001, "the labelled segment is raised to the floor")
        XCTAssertLessThan(w[0], 40, "an unlabelled spacer keeps its small share instead")
        XCTAssertEqual(w.reduce(0, +), 300, accuracy: 0.001)
    }

    /// A spacer never shrinks below its own floor.
    func testASpacerNeverShrinksBelowItsOwnFloor() {
        let phases = [p("", "nano"), p("Installing", "long"), p("", "nano")]
        let w = PhaseTrack.segmentWidths(for: phases, total: 400, minimum: 150, spacerMinimum: 10)
        XCTAssertGreaterThanOrEqual(w[0], 10)
        XCTAssertGreaterThanOrEqual(w[2], 10)
        XCTAssertEqual(w.reduce(0, +), 400, accuracy: 0.001)
    }

    // MARK: fills

    func testAFinishedSegmentIsSolidAndAPendingOneIsEmpty() {
        let phases = [p("A"), p("B"), p("C")]
        XCTAssertEqual(PhaseTrack.fill(at: 0, in: phases, currentPhase: 2, progress: nil), .full)
        XCTAssertEqual(PhaseTrack.fill(at: 2, in: phases, currentPhase: 2, progress: nil), .empty)
    }

    /// Only the segment in flight takes the live progress.
    func testTheSegmentInFlightTakesTheLiveProgress() {
        let phases = [p("A"), p("B"), p("C")]
        XCTAssertEqual(PhaseTrack.fill(at: 1, in: phases, currentPhase: 2, progress: 0.62),
                       .partial(0.62))
        XCTAssertEqual(PhaseTrack.fill(at: 1, in: phases, currentPhase: 2, progress: nil),
                       .inFlight, "no number to show is not the same as no progress")
    }

    /// Live progress is clamped to 0...1 here.
    func testALiveProgressOutsideZeroToOneIsClamped() {
        let phases = [p("A"), p("B")]
        XCTAssertEqual(PhaseTrack.fill(at: 1, in: phases, currentPhase: 2, progress: 4.2),
                       .partial(1))
        XCTAssertEqual(PhaseTrack.fill(at: 1, in: phases, currentPhase: 2, progress: -1),
                       .partial(0))
    }

    func testFailedAndBlockedKeepTheirOwnFills() {
        let phases = [p("A", nil, "failed"), p("B", nil, "blocked"), p("C")]
        XCTAssertEqual(PhaseTrack.fill(at: 0, in: phases, currentPhase: 3, progress: nil), .failed)
        XCTAssertEqual(PhaseTrack.fill(at: 1, in: phases, currentPhase: 3, progress: nil), .blocked)
    }
}
