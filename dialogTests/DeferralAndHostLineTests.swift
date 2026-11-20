//
//  DeferralAndHostLineTests.swift
//  dialogTests
//
//  The deferral menu offer and the host line.
//

import XCTest
import SwiftUI
import Synchronization
@testable import Dialog

/// `HostLine` decides which host facts a device-identity line states and how they are joined.
/// Gathering reads the real machine; joining is pure and tested here.
final class HostLineTests: XCTestCase {

    /// Preset 3's line: "name · OS · user".
    func testTheLineItReplaced() {
        XCTAssertEqual(HostLine.text(name: "Robin's MacBook Pro",
                                     os: "Version 26.0 (Build 25A5295e)",
                                     user: "robin"),
                       "Robin's MacBook Pro · Version 26.0 (Build 25A5295e) · robin")
    }

    /// The separator is the seat's choice.
    func testSeparatorIsTheSeatsChoice() {
        XCTAssertEqual(HostLine.text(name: "a", os: "b", user: "c", separator: " — "), "a — b — c")
    }

    /// An empty fact is dropped, not left as a dangling separator.
    func testEmptyFactsAreDroppedNotPadded() {
        XCTAssertEqual(HostLine.text(name: "mac", os: "", user: "robin"), "mac · robin")
        XCTAssertEqual(HostLine.text(name: "", os: "", user: ""), "")
    }
}

// MARK: - When a deferral menu is offered

/// `DeferralMenu.isOffered` is the entry rule Preset 5 and Preset 6 share. Most deferral seats have
/// no captured screen, so these tests are their coverage.
final class DeferralMenuOfferedTests: XCTestCase {

    private func steps(_ types: [String?]) throws -> [InspectConfig.IntroStep] {
        try types.enumerated().map { index, type in
            let stepType = type.map { "\"stepType\": \"\($0)\"," } ?? ""
            let json = "{\(stepType) \"id\": \"s\(index)\", \"title\": \"S\(index)\"}"
            return try JSONDecoder().decode(InspectConfig.IntroStep.self, from: Data(json.utf8))
        }
    }

    /// The menu is offered before work starts and never once it has.
    func testTheMenuDisappearsFromTheFirstProcessingStepOnward() throws {
        let flow = try steps(["intro", "intro", "processing", "outro"])
        XCTAssertTrue(DeferralMenu.isOffered(steps: flow, currentIndex: 0))
        XCTAssertTrue(DeferralMenu.isOffered(steps: flow, currentIndex: 1))
        XCTAssertFalse(DeferralMenu.isOffered(steps: flow, currentIndex: 2))
        XCTAssertFalse(DeferralMenu.isOffered(steps: flow, currentIndex: 3))
    }

    /// A flow with no processing step defers from anywhere.
    func testAFlowWithNoProcessingStepDefersFromAnywhere() throws {
        let flow = try steps(["intro", "intro", "outro"])
        for index in flow.indices {
            XCTAssertTrue(DeferralMenu.isOffered(steps: flow, currentIndex: index))
        }
    }

    /// An unauthored stepType is not "processing" whether read raw or through `resolvedStepType`.
    func testAnUnauthoredStepTypeIsNotProcessingUnderEitherSpelling() throws {
        let flow = try steps([nil, nil, "processing"])
        XCTAssertEqual(flow[0].resolvedStepType, "standard")
        XCTAssertTrue(DeferralMenu.isOffered(steps: flow, currentIndex: 0))
        XCTAssertTrue(DeferralMenu.isOffered(steps: flow, currentIndex: 1))
        XCTAssertFalse(DeferralMenu.isOffered(steps: flow, currentIndex: 2))
    }

    /// Only the first processing step matters; returning to an intro-shaped step does not re-offer it.
    func testOnlyTheFirstProcessingStepMatters() throws {
        let flow = try steps(["intro", "processing", "intro", "processing"])
        XCTAssertTrue(DeferralMenu.isOffered(steps: flow, currentIndex: 0))
        XCTAssertFalse(DeferralMenu.isOffered(steps: flow, currentIndex: 2))
    }

    /// An empty flow is safe: the menu is offered, and `isDeferralEnabled` keeps it off screen.
    func testAnEmptyFlowIsSafe() {
        XCTAssertTrue(DeferralMenu.isOffered(steps: [], currentIndex: 0))
    }
}
