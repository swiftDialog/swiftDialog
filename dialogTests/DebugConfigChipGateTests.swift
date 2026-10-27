//
//  DebugConfigChipGateTests.swift
//  dialogTests
//
//  The provenance chip in InspectView.swift is gated on `appvars.debugMode` (the `--debug` flag),
//  the same switch as the DEBUG prints beside it, never on a per-config key. The chip is a private
//  view, so these tests read the source and check which expression guards it.
//

import XCTest
@testable import Dialog

final class DebugConfigChipGateTests: XCTestCase {

    // MARK: - Source access

    private func inspectViewSource() throws -> String {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Core Framework/InspectView.swift")
        return try String(contentsOf: path, encoding: .utf8)
    }

    /// The `if` condition immediately guarding `DebugConfigChip(path:`, trimmed.
    /// Skips full-line comments, so a comment between the guard and the call cannot be matched.
    private func chipGateCondition(in source: String) throws -> String {
        guard let chipRange = source.range(of: "DebugConfigChip(path:") else {
            XCTFail("DebugConfigChip(path: call site not found — has it moved or been renamed?")
            return ""
        }
        let before = source[..<chipRange.lowerBound]
        let lines = before.split(separator: "\n", omittingEmptySubsequences: false)
        guard let guardLine = lines.reversed().first(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && !trimmed.hasPrefix("//") && trimmed.contains("if ")
        }) else {
            XCTFail("No non-comment `if` line found guarding the DebugConfigChip call site")
            return ""
        }
        guard let ifRange = guardLine.range(of: "if ") else {
            XCTFail("Guard line did not contain `if `")
            return ""
        }
        let conditionPart = guardLine[ifRange.upperBound...]
        guard let braceIndex = conditionPart.firstIndex(of: "{") else {
            XCTFail("No opening brace found on the DebugConfigChip guard line")
            return ""
        }
        return String(conditionPart[..<braceIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Gate

    /// The chip is gated on `appvars.debugMode`, the `--debug` switch.
    func testChipIsGatedOnAppvarsDebugMode() throws {
        let source = try inspectViewSource()
        let condition = try chipGateCondition(in: source)
        XCTAssertEqual(
            condition, "appvars.debugMode",
            "DebugConfigChip must be gated on appvars.debugMode (the --debug flag), " +
            "the same switch as the DEBUG prints beside it — not a per-config key."
        )
    }

    /// The chip's condition never references the config's own `debugMode` key.
    func testChipGateDoesNotReferenceConfigDebugModeKey() throws {
        let source = try inspectViewSource()
        let condition = try chipGateCondition(in: source)
        XCTAssertFalse(
            condition.contains("config?.debugMode") || condition.contains("config.debugMode"),
            "DebugConfigChip's gate must not depend on the config's debugMode root key — " +
            "found: \"\(condition)\""
        )
    }

    /// The DEBUG prints beside the chip still use `appvars.debugMode`.
    /// The chip's own guard is excluded before counting, since it would always match.
    func testNeighbouringDebugPrintsShareTheSameSwitch() throws {
        let source = try inspectViewSource()
        guard let chipRange = source.range(of: "DebugConfigChip(path:") else {
            XCTFail("DebugConfigChip(path: call site not found — has it moved or been renamed?")
            return
        }
        let before = source[..<chipRange.lowerBound]
        guard let chipGuardRange = before.range(of: "if appvars.debugMode {", options: .backwards) else {
            XCTFail("Expected the chip's own guard to read `if appvars.debugMode {` immediately " +
                     "before the call site — testChipIsGatedOnAppvarsDebugMode should also be failing.")
            return
        }
        let outsideChipGuard = source.replacingCharacters(in: chipGuardRange, with: "")
        let printGateCount = outsideChipGuard.components(separatedBy: "if appvars.debugMode {").count - 1
        XCTAssertGreaterThan(
            printGateCount, 0,
            "Expected at least one `if appvars.debugMode {` gated DEBUG print OUTSIDE the chip's " +
            "own guard in InspectView.swift — if this fails, the neighbouring DEBUG prints no " +
            "longer share the chip's switch, and the \"same switch as its neighbours\" comment " +
            "above the chip is now false."
        )
    }
}
