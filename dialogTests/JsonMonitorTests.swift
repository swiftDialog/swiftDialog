//
//  JsonMonitorTests.swift
//  dialogTests
//
//  The JSON-monitor path (item.jsonMonitors → UnifiedMonitoringService.checkJsonValue), against
//  real temp JSON files. A JSON `true` reads back as "1" through String(describing:).
//

import XCTest
@testable import Dialog

/// Main-actor because `UnifiedMonitoringService` is.
@MainActor
final class JsonMonitorTests: XCTestCase {

    private var tempDir: URL!
    private var service: UnifiedMonitoringService!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("json-monitor-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = UnifiedMonitoringService()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func writeJson(_ object: [String: Any], name: String = "status.json") throws -> String {
        let url = tempDir.appendingPathComponent(name)
        try JSONSerialization.data(withJSONObject: object).write(to: url)
        return url.path
    }

    private func monitor(key: String, evaluation: String? = nil) -> InspectConfig.JsonMonitor {
        InspectConfig.JsonMonitor(path: "", key: key, guidanceBlockIndex: 0,
                                  targetProperty: "state", valueMap: nil,
                                  recheckInterval: 1, evaluation: evaluation,
                                  completionTrigger: nil)
    }

    /// Spins the run loop until checkJsonValue's main-actor publish lands. Call it after
    /// checkJsonValue, so the production job is ahead of the fulfill in the main queue.
    private func drainMain() {
        let exp = expectation(description: "main queue drained")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 2)
    }

    func testStatusMessageReflectsJsonValueWithoutEvaluation() throws {
        let path = try writeJson(["phase": "syncing"])
        service.checkJsonValue(for: "it", at: path, config: monitor(key: "phase"))
        drainMain()
        XCTAssertEqual(service.statusMessages["it"], "syncing")
        XCTAssertNil(service.itemStatuses["it"], "no evaluation → status untouched")
    }

    func testBooleanEvaluationCompletesOnRealJsonTrue() throws {
        // A real JSON `true` renders as "1", so the check accepts both spellings.
        let path = try writeJson(["done": true])
        service.checkJsonValue(for: "it", at: path, config: monitor(key: "done", evaluation: "boolean"))
        drainMain()
        XCTAssertEqual(service.statusMessages["it"], "1")
        XCTAssertEqual(service.itemStatuses["it"], .completed)
    }

    func testBooleanEvaluationCompletesOnStringTrueAndCaseFoldedAuthoring() throws {
        let path = try writeJson(["done": "true"])
        service.checkJsonValue(for: "it", at: path, config: monitor(key: "done", evaluation: "Boolean"))
        drainMain()
        XCTAssertEqual(service.itemStatuses["it"], .completed)
    }

    func testBooleanEvaluationFalseLeavesPending() throws {
        let path = try writeJson(["done": false])
        service.checkJsonValue(for: "it", at: path, config: monitor(key: "done", evaluation: "boolean"))
        drainMain()
        XCTAssertEqual(service.statusMessages["it"], "0")
        XCTAssertNil(service.itemStatuses["it"], "a false boolean must leave the item pending")
    }

    func testExistsEvaluationCompletesOnAnyValue() throws {
        let path = try writeJson(["marker": "whatever"])
        service.checkJsonValue(for: "it", at: path, config: monitor(key: "marker", evaluation: "exists"))
        drainMain()
        XCTAssertEqual(service.itemStatuses["it"], .completed)
    }

    func testUnknownEvaluationLeavesPendingButStillReportsValue() throws {
        let path = try writeJson(["k": "v"])
        service.checkJsonValue(for: "it", at: path, config: monitor(key: "k", evaluation: "frobnicate"))
        drainMain()
        XCTAssertEqual(service.statusMessages["it"], "v")
        XCTAssertNil(service.itemStatuses["it"], "unknown evaluation is the closed answer: pending")
    }

    func testUnwiredOperatorsLeavePending() throws {
        // equals/contains/range/changed/withinSeconds are not wired for JSON monitors.
        let path = try writeJson(["k": "v"])
        service.checkJsonValue(for: "it", at: path, config: monitor(key: "k", evaluation: "equals"))
        drainMain()
        XCTAssertNil(service.itemStatuses["it"], "an unwired operator must leave the item pending")
    }

    func testMissingKeyAndMissingFileAreNoOps() throws {
        let path = try writeJson(["other": "v"])
        service.checkJsonValue(for: "it", at: path, config: monitor(key: "absent"))
        service.checkJsonValue(for: "it2", at: tempDir.appendingPathComponent("nope.json").path,
                               config: monitor(key: "k"))
        drainMain()
        XCTAssertNil(service.statusMessages["it"])
        XCTAssertNil(service.statusMessages["it2"])
    }
}
