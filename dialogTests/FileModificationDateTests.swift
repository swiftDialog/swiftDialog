//
//  FileModificationDateTests.swift
//  dialogTests
//
//  Regression tests for getModificationDateOf (backlog A1). The original bug
//  passed fileURL.absoluteString ("file:///…") to attributesOfItem(atPath:),
//  which always threw, so the function silently returned Date.now and the
//  launch-time command-file guard never fired.
//

import XCTest
@testable import Dialog

final class FileModificationDateTests: XCTestCase {

    private func makeTempFile() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gmd-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
        return url
    }

    func testReturnsActualModificationDate() throws {
        let url = makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        // A known date well in the past — clearly distinct from the Date.now fallback.
        let past = Date(timeIntervalSince1970: 1_000_000_000) // 2001-09-09
        try FileManager.default.setAttributes([.modificationDate: past],
                                              ofItemAtPath: url.path)

        let result = getModificationDateOf(url)
        XCTAssertEqual(result.timeIntervalSince1970, past.timeIntervalSince1970, accuracy: 1.0,
                       "Should return the file's actual modification date, not the current time")
    }

    func testRecentFileReportsRecentDate() throws {
        // A file created 'now' must not read as older than a moment ago — the
        // property the launch-time guard depends on.
        let before = Date().addingTimeInterval(-2)
        let url = makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertGreaterThanOrEqual(getModificationDateOf(url), before)
    }

    func testMissingFileFallsBackToApproximatelyNow() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).log")
        let before = Date().addingTimeInterval(-2)
        let result = getModificationDateOf(url)
        let after = Date().addingTimeInterval(2)
        XCTAssertTrue(result >= before && result <= after,
                      "A missing file should fall back to approximately the current time")
    }
}
