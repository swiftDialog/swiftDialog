//
//  CadenceCompletionCopyTests.swift
//  dialogTests
//
//  `completedTitle`/`completedMessage`: the swap rule, and a census that every cadence renderer routes through it.
//

import XCTest
import SwiftUI
@testable import Dialog

final class CadenceCompletionCopyTests: XCTestCase {

    // MARK: - Rule

    /// Completion copy replaces running copy only once complete and only when authored; absent or empty leaves the title as is.
    func testCompletionCopySwapsOnlyWhenCompleteAndAuthored() {
        // running: the completion copy is not shown even though it exists
        XCTAssertEqual(CadenceCopy.resolvedCopy(isComplete: false, running: "Checking markers",
                                                  completed: "All prerequisites met"),
                       "Checking markers")
        // complete + authored: swap
        XCTAssertEqual(CadenceCopy.resolvedCopy(isComplete: true, running: "Checking markers",
                                                  completed: "All prerequisites met"),
                       "All prerequisites met")
        // complete, nothing authored: the running copy stays
        XCTAssertEqual(CadenceCopy.resolvedCopy(isComplete: true, running: "Checking markers",
                                                  completed: nil),
                       "Checking markers")
        // authored-but-empty counts as absent, as `continueText` does
        XCTAssertEqual(CadenceCopy.resolvedCopy(isComplete: true, running: "Checking markers",
                                                  completed: ""),
                       "Checking markers")
        // no running copy either: nil in, nil out
        XCTAssertNil(CadenceCopy.resolvedCopy(isComplete: true, running: nil, completed: nil))
    }

    /// `resolvedTitle` and `resolvedSubtitle` behave exactly like `resolvedCopy`.
    func testTheThreeNamesAreOneRule() {
        for isComplete in [true, false] {
            for completed in ["Done", "", nil] as [String?] {
                XCTAssertEqual(
                    CadenceCopy.resolvedTitle(isComplete: isComplete, title: "Running",
                                                completedTitle: completed),
                    CadenceCopy.resolvedCopy(isComplete: isComplete, running: "Running",
                                               completed: completed) ?? "Running",
                    "resolvedTitle diverged from resolvedCopy (isComplete: \(isComplete), completed: \(String(describing: completed)))")
                XCTAssertEqual(
                    CadenceCopy.resolvedSubtitle(isComplete: isComplete, subtitle: "Running",
                                                   completedMessage: completed),
                    CadenceCopy.resolvedCopy(isComplete: isComplete, running: "Running",
                                               completed: completed),
                    "resolvedSubtitle diverged from resolvedCopy (isComplete: \(isComplete), completed: \(String(describing: completed)))")
            }
        }
    }

    /// The claim line blanks on completion (it narrates the active entry); the subtitle holds.
    func testTheClaimLineBlanksWhereTheSubtitleHolds() {
        XCTAssertEqual(CadenceCopy.resolvedClaim(isComplete: true, runningClaim: "Checking gate 3",
                                                   completedMessage: nil),
                       " ")
        XCTAssertEqual(CadenceCopy.resolvedSubtitle(isComplete: true, subtitle: "Checking gate 3",
                                                      completedMessage: nil),
                       "Checking gate 3")
    }

    // MARK: - Census

    /// Every renderer that draws a cadence step's title routes it through the swap.
    /// A pinned set, so a new renderer fails by name instead of passing unnoticed.
    func testEveryCadenceRendererHonoursTheCompletionCopy() throws {
        let expected = [
            "Preset5+Provisioning.swift"
        ]

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Preset Layouts")

        // Files that render a cadence step read the run's progress.
        var renderers: [String] = []
        let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        if let walker {
            for case let file as URL in walker where file.pathExtension == "swift" {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                guard text.contains("CadenceProgress(monitor:") else { continue }
                renderers.append(file.lastPathComponent)
            }
        }
        XCTAssertFalse(renderers.isEmpty, "found no cadence renderers — the walk is broken, not the tree")

        XCTAssertEqual(Set(renderers), Set(expected),
                       "the set of cadence renderers changed. A new one must honour "
                       + "completedTitle/completedMessage before it is added here — that is the "
                       + "whole point of this test. found: \(renderers.sorted())")

        for name in expected {
            let file = root.appendingPathComponent(name)
            let text = try String(contentsOf: file, encoding: .utf8)
            let honours = text.contains("resolvedTitle(") || text.contains("resolvedCopy(")
                || text.contains("resolvedSubtitle(")
            XCTAssertTrue(honours,
                          "\(name) renders a cadence step but never routes its copy through the "
                          + "completion swap — an authored completedTitle/completedMessage would "
                          + "be decoded and silently dropped, which is the bug this test exists for")
        }
    }
}
