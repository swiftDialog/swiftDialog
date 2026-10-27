//
//  CadenceTests.swift
//  dialogTests
//
//  The cadence cards: the minimal fit and the rollup bound.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog

// The minimal sheet fits the height the provisioning shell hands it — 348 at a 600 window
// matched to the splash, 388 at the native 640 — rather than the canvas's one sheet.
final class CadenceMinimalFitTests: XCTestCase {

    private let payloads: [CGFloat] = Array(stride(from: 300, through: 620, by: 4))

    func testTheSheetNeverOverrunsItsPayloadOnceTheFloorIsReachable() {
        for kind in [CadenceMinimalKind.manifest, .spotlight] {
            for h in payloads {
                let fit = CadenceMinimalFit.resolve(height: h, kind: kind)
                if fit.rows > 0 || fit.machineImage > CadenceMinimalFit.machineImageFloor {
                    XCTAssertLessThanOrEqual(fit.height(kind), h, "\(kind) overruns a \(h)pt payload")
                }
                XCTAssertGreaterThanOrEqual(fit.machineImage, CadenceMinimalFit.machineImageFloor)
                XCTAssertLessThanOrEqual(fit.machineImage, CadenceMinimalM.machineImage)
            }
        }
    }

    func testRowsNeverShrinkAsTheWindowGrows() {
        for kind in [CadenceMinimalKind.manifest, .spotlight] {
            let rows = payloads.map { CadenceMinimalFit.resolve(height: $0, kind: kind).rows }
            XCTAssertEqual(rows, rows.sorted(), "\(kind): a taller window named fewer rows")
            XCTAssertLessThanOrEqual(rows.max() ?? 0, CadenceMinimalFit.maxRows(kind))
        }
    }

    func testTheTwoWindowsThisFlowUses() {
        // 600: the splash-matched window. One queued row; the picture takes the rest, 115.
        XCTAssertEqual(CadenceMinimalFit.resolve(height: 348, kind: .manifest),
                       CadenceMinimalFit(machineImage: 115, rows: 1))
        // 640: the native window keeps both queued rows; the picture gets 105.
        XCTAssertEqual(CadenceMinimalFit.resolve(height: 388, kind: .manifest),
                       CadenceMinimalFit(machineImage: 105, rows: 2))
        // Room for the full read: the picture at its 128 ceiling.
        XCTAssertEqual(CadenceMinimalFit.resolve(height: 420, kind: .manifest),
                       CadenceMinimalFit(machineImage: 128, rows: 2))
    }
}

/// `CadenceRollup` bounds the named rows whatever the run's length.
final class CadenceRollupBoundTests: XCTestCase {
    private func entries(_ n: Int) -> [InspectConfig.CadenceEntry] {
        let attr = (try? JSONDecoder().decode(InspectConfig.CadenceAttribute.self,
                                              from: Data(#"{"source": "ipc"}"#.utf8)))!
        return (0..<n).map { i in
            InspectConfig.CadenceEntry(id: "e\(i)", message: "m\(i)", attribute: attr, minDwell: 0,
                timeout: 60, sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil,
                subtitle: nil, timeEstimate: nil, size: nil)
        }
    }

    func testFinishedNamesAtMostThreeWhateverTheRunDoes() {
        for count in 1...24 {
            for position in 0...count {
                let done = CadenceRollup.finished(entries(count), position: position)
                XCTAssertLessThanOrEqual(done.shown.count, 3, "count \(count), position \(position)")
                XCTAssertEqual(done.total, position, "the COUNT is the truth, the rows are the window")
            }
        }
    }

    func testWaitingNamesAtMostItsQuotaAndCountsTheRest() {
        for count in 1...24 {
            for position in 0..<count {
                let ahead = CadenceRollup.waiting(entries(count), position: position, queued: 2)
                XCTAssertLessThanOrEqual(ahead.shown.count, 2)
                XCTAssertEqual(ahead.shown.count + ahead.beyond, max(0, count - position - 1),
                               "every waiting step is either named or counted, never dropped")
            }
        }
    }

    /// A twelve-step run draws as many rows as a four-step one.
    func testTwelveStepsDrawTheSameRowsAsFour() {
        let four = CadenceRollup.finished(entries(4), position: 4).shown.count
            + CadenceRollup.waiting(entries(4), position: 1, queued: 2).shown.count
        let twelve = CadenceRollup.finished(entries(12), position: 12).shown.count
            + CadenceRollup.waiting(entries(12), position: 1, queued: 2).shown.count
        XCTAssertEqual(four, twelve)
    }
}
