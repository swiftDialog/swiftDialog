//
//  ReadinessExitTests.swift
//  dialogTests
//
//  Every exit of an item preset (1–4) sends the exit code with the completed / failed / total
//  counts, so a `wait-exit` consumer sees the same event from every preset.
//

import XCTest

final class ReadinessExitTests: XCTestCase {

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("dialog/Views/Inspect/" + path), encoding: .utf8)
    }

    func testItemPresetExitsCarryTheResultCounts() throws {
        for path in ["Core Framework/PresetCommonViews.swift",
                     "Core Framework/Components/Chrome/PhaseContainer.swift",
                     "Preset Layouts/Preset1.swift"] {
            let text = try source(path)
            XCTAssertTrue(text.contains("cleanupReadinessFile(state:"), "\(path) must use the counted cleanup")
            XCTAssertFalse(text.contains("cleanupReadinessFile(config:"),
                           "\(path) sends the exit code alone — use cleanupReadinessFile(state:…)")
        }
    }
}
