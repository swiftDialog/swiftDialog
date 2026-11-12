//
//  CatalogueStatusRuleTests.swift
//  dialogTests
//
//  What a detection pass may do to a status it did not produce: absence on disk cannot refute a
//  reported failure or a skip decision; only progress or the app itself can.
//

import XCTest
@testable import Dialog

final class CatalogueStatusRuleTests: XCTestCase {

    // MARK: - What detection may assert

    func testSatisfiedRequirementsCompleteTheItem() {
        XCTAssertEqual(CatalogueStatusRule.resolve(previous: .pending, done: true, satisfied: 2,
                                                   reflectsCurrentState: true), .completed)
    }

    /// No churn: re-asserting a status the item already has publishes nothing.
    func testAlreadyCompletedPublishesNoChange() {
        XCTAssertNil(CatalogueStatusRule.resolve(previous: .completed, done: true, satisfied: 2,
                                                 reflectsCurrentState: true))
    }

    func testPartialSatisfactionReadsAsWorkInProgress() {
        XCTAssertEqual(CatalogueStatusRule.resolve(previous: .pending, done: false, satisfied: 1,
                                                   reflectsCurrentState: true), .active)
    }

    func testNothingSatisfiedReadsAsPending() {
        XCTAssertEqual(CatalogueStatusRule.resolve(previous: .active, done: false, satisfied: 0,
                                                   reflectsCurrentState: true), .pending)
    }

    // MARK: - Completion latch

    /// Outside catalogue mode a completed item never falls back: a signal that flickers mid-install
    /// must not un-complete a step the user already watched finish.
    func testInstallRunLatchesCompletionAgainstAFlickeringSignal() {
        XCTAssertNil(CatalogueStatusRule.resolve(previous: .completed, done: false, satisfied: 0,
                                                 reflectsCurrentState: false))
    }

    /// In a catalogue a deleted app falls back out of completed, so the row stops offering to open it.
    func testCatalogueLetsADeletedAppFallBackOutOfCompleted() {
        XCTAssertEqual(CatalogueStatusRule.resolve(previous: .completed, done: false, satisfied: 0,
                                                   reflectsCurrentState: true), .pending)
    }

    // MARK: - Absence cannot refute a reported failure

    func testAReportedFailureSurvivesAPassThatMerelyFindsNothing() {
        XCTAssertNil(CatalogueStatusRule.resolve(previous: .failed, done: false, satisfied: 0,
                                                 reflectsCurrentState: true))
    }

    /// Same in an install run: the modes differ about completion, never about failure.
    func testAReportedFailureSurvivesInAnInstallRunToo() {
        XCTAssertNil(CatalogueStatusRule.resolve(previous: .failed, done: false, satisfied: 0,
                                                 reflectsCurrentState: false))
    }

    /// Progress contradicts the failure and wins, so Retry clears the row.
    func testProgressRefutesTheFailure() {
        XCTAssertEqual(CatalogueStatusRule.resolve(previous: .failed, done: false, satisfied: 1,
                                                   reflectsCurrentState: true), .active)
    }

    /// The app appearing clears the failure.
    func testTheAppAppearingClearsTheFailure() {
        XCTAssertEqual(CatalogueStatusRule.resolve(previous: .failed, done: true, satisfied: 2,
                                                   reflectsCurrentState: true), .completed)
    }

    /// A failure reported for an item already on the Mac is overruled by the disk.
    func testFailureDoesNotSurviveWhenTheRequirementsAreMet() {
        XCTAssertEqual(CatalogueStatusRule.resolve(previous: .failed, done: true, satisfied: 1,
                                                   reflectsCurrentState: false), .completed)
    }

    // MARK: - Decisions

    /// A `skipped` decision is not reopened by a pass that finds nothing.
    func testASkippedItemIsNotQuietlyReopenedByAPassThatFindsNothing() {
        XCTAssertNil(CatalogueStatusRule.resolve(previous: .skipped, done: false, satisfied: 0,
                                                 reflectsCurrentState: true))
    }
}
