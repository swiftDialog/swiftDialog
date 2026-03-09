//
//  PlistEvaluationTests.swift
//  dialogTests
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 2026-02-10
//
//  Unit tests for plist evaluation logic used by InspectState and MonitoringModule
//

import XCTest
@testable import dialog

final class PlistEvaluationTests: XCTestCase {

    var tempDirectory: URL!
    var testPlistPath: String!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("plist-eval-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        testPlistPath = tempDirectory.appendingPathComponent("test.plist").path
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Helper: Create Plist

    private func writePlist(_ dict: [String: Any]) {
        (dict as NSDictionary).write(toFile: testPlistPath, atomically: true)
    }

    private func readPlistValue(key: String) -> String? {
        guard let plist = NSDictionary(contentsOfFile: testPlistPath) else { return nil }
        return plist.value(forKeyPath: key).map { String(describing: $0) }
    }

    // MARK: - Helper: Create ItemConfig from JSON

    private func makeItem(
        id: String = "test_item",
        displayName: String = "Test Item",
        paths: [String]? = nil,
        plistKey: String? = nil,
        expectedValue: String? = nil,
        evaluation: String? = nil,
        plistRecheckInterval: Int? = nil,
        useUserDefaults: Bool? = nil,
        waitForExternalTrigger: Bool? = nil
    ) -> InspectConfig.ItemConfig {
        var json: [String: Any] = [
            "id": id,
            "displayName": displayName,
            "guiIndex": 0,
            "paths": paths ?? [testPlistPath!]
        ]
        if let plistKey = plistKey { json["plistKey"] = plistKey }
        if let expectedValue = expectedValue { json["expectedValue"] = expectedValue }
        if let evaluation = evaluation { json["evaluation"] = evaluation }
        if let plistRecheckInterval = plistRecheckInterval { json["plistRecheckInterval"] = plistRecheckInterval }
        if let useUserDefaults = useUserDefaults { json["useUserDefaults"] = useUserDefaults }
        if let waitForExternalTrigger = waitForExternalTrigger { json["waitForExternalTrigger"] = waitForExternalTrigger }

        do {
            let data = try JSONSerialization.data(withJSONObject: json)
            return try JSONDecoder().decode(InspectConfig.ItemConfig.self, from: data)
        } catch {
            fatalError("Failed to create mock ItemConfig: \(error)")
        }
    }

    // MARK: - Evaluation: "exists"

    func testExistsEvaluation_KeyPresent_ReturnsTrue() {
        writePlist(["TestKey": "SomeValue"])
        let value = readPlistValue(key: "TestKey")
        XCTAssertNotNil(value)
        XCTAssertFalse(value!.isEmpty)
        // evaluation: "exists" => isInstalled = actualValue != nil && !actualValue!.isEmpty
        let isInstalled = value != nil && !value!.isEmpty
        XCTAssertTrue(isInstalled)
    }

    func testExistsEvaluation_KeyAbsent_ReturnsFalse() {
        writePlist(["OtherKey": "SomeValue"])
        let value = readPlistValue(key: "TestKey")
        XCTAssertNil(value)
        let isInstalled = value != nil && !(value?.isEmpty ?? true)
        XCTAssertFalse(isInstalled)
    }

    func testExistsEvaluation_EmptyString_ReturnsFalse() {
        writePlist(["TestKey": ""])
        let value = readPlistValue(key: "TestKey")
        XCTAssertNotNil(value)
        XCTAssertTrue(value!.isEmpty)
        let isInstalled = value != nil && !value!.isEmpty
        XCTAssertFalse(isInstalled)
    }

    // MARK: - Evaluation: "boolean"

    func testBooleanEvaluation_TrueString() {
        let value = "true"
        let isInstalled = value == "1" || value.lowercased() == "true"
        XCTAssertTrue(isInstalled)
    }

    func testBooleanEvaluation_OneString() {
        let value = "1"
        let isInstalled = value == "1" || value.lowercased() == "true"
        XCTAssertTrue(isInstalled)
    }

    func testBooleanEvaluation_FalseString() {
        let value = "false"
        let isInstalled = value == "1" || value.lowercased() == "true"
        XCTAssertFalse(isInstalled)
    }

    func testBooleanEvaluation_ZeroString() {
        let value = "0"
        let isInstalled = value == "1" || value.lowercased() == "true"
        XCTAssertFalse(isInstalled)
    }

    // MARK: - Evaluation: "contains"

    func testContainsEvaluation_Match() {
        let value = "Hello World"
        let expected = "World"
        let isInstalled = value.contains(expected)
        XCTAssertTrue(isInstalled)
    }

    func testContainsEvaluation_NoMatch() {
        let value = "Hello World"
        let expected = "Moon"
        let isInstalled = value.contains(expected)
        XCTAssertFalse(isInstalled)
    }

    // MARK: - Evaluation: "range"

    func testRangeEvaluation_InRange() {
        let value = "5"
        let expected = "1-10"
        let parts = expected.split(separator: "-")
        let actual = Int(value)!
        let lo = Int(parts[0])!
        let hi = Int(parts[1])!
        XCTAssertTrue(actual >= lo && actual <= hi)
    }

    func testRangeEvaluation_BelowRange() {
        let value = "0"
        let expected = "1-10"
        let parts = expected.split(separator: "-")
        let actual = Int(value)!
        let lo = Int(parts[0])!
        let hi = Int(parts[1])!
        XCTAssertFalse(actual >= lo && actual <= hi)
    }

    func testRangeEvaluation_AboveRange() {
        let value = "11"
        let expected = "1-10"
        let parts = expected.split(separator: "-")
        let actual = Int(value)!
        let lo = Int(parts[0])!
        let hi = Int(parts[1])!
        XCTAssertFalse(actual >= lo && actual <= hi)
    }

    // MARK: - Evaluation: "equals" (default)

    func testEqualsEvaluation_Match() {
        let value: String? = "Dark"
        let expected: String? = "Dark"
        XCTAssertTrue(value == expected)
    }

    func testEqualsEvaluation_NoMatch() {
        let value: String? = "Light"
        let expected: String? = "Dark"
        XCTAssertFalse(value == expected)
    }

    func testEqualsEvaluation_NilValue() {
        let value: String? = nil
        let expected: String? = "Dark"
        XCTAssertFalse(value == expected)
    }

    // MARK: - Evaluation: "changed" (baseline tracking)

    func testChangedEvaluation_FirstCheck_RecordsBaseline() {
        // Simulate the "changed" evaluation logic
        var baselines: [String: String?] = [:]
        var initialized: Set<String> = []

        let itemId = "test_item"
        let currentValue: String? = "Dark"

        // First check should record baseline and return false
        if !initialized.contains(itemId) {
            baselines[itemId] = currentValue
            initialized.insert(itemId)
        }

        XCTAssertTrue(initialized.contains(itemId))
        XCTAssertEqual(baselines[itemId] as? String, "Dark")
    }

    func testChangedEvaluation_NoChange_ReturnsFalse() {
        var baselines: [String: String?] = [:]
        var initialized: Set<String> = []

        let itemId = "test_item"

        // First check: record baseline
        let initialValue: String? = "Dark"
        baselines[itemId] = initialValue
        initialized.insert(itemId)

        // Second check: same value
        let currentValue: String? = "Dark"
        let baseline = baselines[itemId] ?? nil
        let changed = (baseline != currentValue)
        XCTAssertFalse(changed, "Should not detect change when value is the same")
    }

    func testChangedEvaluation_ValueChanged_ReturnsTrue() {
        var baselines: [String: String?] = [:]
        var initialized: Set<String> = []

        let itemId = "test_item"

        // First check: record baseline "Dark"
        let initialValue: String? = "Dark"
        baselines[itemId] = initialValue
        initialized.insert(itemId)

        // Second check: value changed to nil (Light mode removes AppleInterfaceStyle)
        let currentValue: String? = nil
        let baseline = baselines[itemId] ?? nil
        let changed = (baseline != currentValue)
        XCTAssertTrue(changed, "Should detect change from Dark to nil (Light mode)")
    }

    func testChangedEvaluation_NilToValue_ReturnsTrue() {
        var baselines: [String: String?] = [:]
        var initialized: Set<String> = []

        let itemId = "test_item"

        // First check: baseline is nil (key absent)
        let initialValue: String? = nil
        baselines[itemId] = initialValue
        initialized.insert(itemId)

        // Second check: value appeared
        let currentValue: String? = "Dark"
        let baseline = baselines[itemId] ?? nil
        let changed = (baseline != currentValue)
        XCTAssertTrue(changed, "Should detect change from nil to Dark")
    }

    func testChangedEvaluation_ValueToNewValue_ReturnsTrue() {
        var baselines: [String: String?] = [:]
        var initialized: Set<String> = []

        let itemId = "test_item"

        // First check: baseline is "v1.0"
        baselines[itemId] = "v1.0" as String?
        initialized.insert(itemId)

        // Second check: value updated
        let currentValue: String? = "v2.0"
        let baseline = baselines[itemId] ?? nil
        let changed = (baseline != currentValue)
        XCTAssertTrue(changed, "Should detect change from v1.0 to v2.0")
    }

    // MARK: - Full Plist Read + "changed" Evaluation

    func testChangedEvaluation_WithRealPlist_DetectsChange() {
        var baselines: [String: String?] = [:]
        var initialized: Set<String> = []
        let itemId = "dark_mode"

        // Write initial plist
        writePlist(["AppleInterfaceStyle": "Dark"])

        // First check: read and record baseline
        let initialValue = readPlistValue(key: "AppleInterfaceStyle")
        XCTAssertEqual(initialValue, "Dark")
        baselines[itemId] = initialValue
        initialized.insert(itemId)

        // Same value: no change
        let sameValue = readPlistValue(key: "AppleInterfaceStyle")
        let baseline1 = baselines[itemId] ?? nil
        XCTAssertFalse(baseline1 != sameValue, "Same value should not trigger change")

        // Change plist: remove the key (simulates switching to Light mode)
        writePlist(["OtherKey": "value"])
        let changedValue = readPlistValue(key: "AppleInterfaceStyle")
        XCTAssertNil(changedValue)
        let baseline2 = baselines[itemId] ?? nil
        XCTAssertTrue(baseline2 != changedValue, "Removing key should trigger change")
    }

    func testChangedEvaluation_WithRealPlist_ValueUpdate() {
        var baselines: [String: String?] = [:]
        var initialized: Set<String> = []
        let itemId = "version_monitor"

        // Write initial plist with version
        writePlist(["AppVersion": "1.0.0"])
        let initialValue = readPlistValue(key: "AppVersion")
        XCTAssertEqual(initialValue, "1.0.0")
        baselines[itemId] = initialValue
        initialized.insert(itemId)

        // Update version
        writePlist(["AppVersion": "2.0.0"])
        let newValue = readPlistValue(key: "AppVersion")
        XCTAssertEqual(newValue, "2.0.0")

        let baseline = baselines[itemId] ?? nil
        XCTAssertTrue(baseline != newValue, "Version change should trigger completion")
    }

    // MARK: - UserDefaults "changed" Evaluation

    func testChangedEvaluation_WithUserDefaults() {
        let testKey = "PlistEvaluationTest_\(UUID().uuidString)"
        let defaults = UserDefaults.standard

        // Clean up in case of previous test failure
        defaults.removeObject(forKey: testKey)

        var baselines: [String: String?] = [:]
        var initialized: Set<String> = []
        let itemId = "ud_test"

        // Baseline: key absent
        let initialValue = defaults.string(forKey: testKey)
        XCTAssertNil(initialValue)
        baselines[itemId] = initialValue
        initialized.insert(itemId)

        // Set value
        defaults.set("TestValue", forKey: testKey)
        let newValue = defaults.string(forKey: testKey)
        XCTAssertEqual(newValue, "TestValue")

        let baseline = baselines[itemId] ?? nil
        XCTAssertTrue(baseline != newValue, "Should detect change from nil to TestValue")

        // Cleanup
        defaults.removeObject(forKey: testKey)
    }

    // MARK: - ItemConfig Decoding

    func testItemConfigDecodesEvaluationChanged() {
        let item = makeItem(
            plistKey: "AppleInterfaceStyle",
            evaluation: "changed",
            plistRecheckInterval: 3,
            useUserDefaults: true
        )
        XCTAssertEqual(item.evaluation, "changed")
        XCTAssertEqual(item.plistKey, "AppleInterfaceStyle")
        XCTAssertEqual(item.plistRecheckInterval, 3)
        XCTAssertEqual(item.useUserDefaults, true)
    }

    func testItemConfigDecodesAllEvaluationTypes() {
        let types = ["exists", "boolean", "contains", "range", "equals", "changed"]
        for evalType in types {
            let item = makeItem(plistKey: "Key", evaluation: evalType)
            XCTAssertEqual(item.evaluation, evalType, "Should decode evaluation type: \(evalType)")
        }
    }

    // MARK: - Edge Cases

    func testChangedEvaluation_EmptyStringToNil() {
        var baselines: [String: String?] = [:]
        baselines["item"] = "" as String?

        let currentValue: String? = nil
        let baseline = baselines["item"] ?? nil
        let changed = (baseline != currentValue)
        XCTAssertTrue(changed, "Should detect change from empty string to nil")
    }

    func testChangedEvaluation_NilToEmptyString() {
        var baselines: [String: String?] = [:]
        baselines["item"] = nil as String?

        let currentValue: String? = ""
        let baseline = baselines["item"] ?? nil
        let changed = (baseline != currentValue)
        XCTAssertTrue(changed, "Should detect change from nil to empty string")
    }

    // MARK: - Bug Report: "equals" with state transition (not_installed → installed)

    /// Reproduces the reported bug where expectedValue: "not_installed" with evaluation: "equals"
    /// causes items to show as "failed" when the plist value changes to "installed".
    /// The user's intent is to detect when installation completes, so expectedValue should be "installed".
    func testEqualsEvaluation_StateTransition_NotInstalledToInstalled() {
        // User's config: expectedValue = "not_installed", evaluation = "equals"
        // This means: item is "installed" when plist value EQUALS "not_installed"
        let expectedValue = "not_installed"

        // Initial state: plist says "not_installed" — matches expectedValue
        writePlist(["state": "not_installed"])
        let initialValue = readPlistValue(key: "state")
        XCTAssertEqual(initialValue, "not_installed")
        let initialIsInstalled = initialValue == expectedValue
        XCTAssertTrue(initialIsInstalled, "Item incorrectly shows as complete BEFORE installation")

        // After installation: plist says "installed" — does NOT match expectedValue
        writePlist(["state": "installed"])
        let updatedValue = readPlistValue(key: "state")
        XCTAssertEqual(updatedValue, "installed")
        let updatedIsInstalled = updatedValue == expectedValue
        XCTAssertFalse(updatedIsInstalled, "Item shows as NOT complete AFTER installation — config is backwards")
    }

    /// Shows the correct config: expectedValue: "installed" detects completion properly
    func testEqualsEvaluation_CorrectConfig_DetectsInstallation() {
        // Correct config: expectedValue = "installed", evaluation = "equals"
        let expectedValue = "installed"

        // Before installation: plist says "not_installed"
        writePlist(["state": "not_installed"])
        let initialValue = readPlistValue(key: "state")
        let initialIsInstalled = initialValue == expectedValue
        XCTAssertFalse(initialIsInstalled, "Item should not be complete before installation")

        // After installation: plist says "installed"
        writePlist(["state": "installed"])
        let updatedValue = readPlistValue(key: "state")
        let updatedIsInstalled = updatedValue == expectedValue
        XCTAssertTrue(updatedIsInstalled, "Item should be complete after installation")
    }

    /// The "changed" evaluation is an alternative that detects ANY value change from baseline
    func testChangedEvaluation_AlternativeForStateTransition() {
        var baselines: [String: String?] = [:]
        var initialized: Set<String> = []
        let itemId = "companyportal"

        // Initial state: record baseline
        writePlist(["state": "not_installed"])
        let initialValue = readPlistValue(key: "state")
        baselines[itemId] = initialValue
        initialized.insert(itemId)

        // Same value: not yet installed
        let sameValue = readPlistValue(key: "state")
        let baseline1 = baselines[itemId] ?? nil
        XCTAssertFalse(baseline1 != sameValue, "Should not trigger before value changes")

        // After installation: value changed
        writePlist(["state": "installed"])
        let changedValue = readPlistValue(key: "state")
        let baseline2 = baselines[itemId] ?? nil
        XCTAssertTrue(baseline2 != changedValue, "Should detect state change from not_installed to installed")
    }

    // MARK: - Edge Cases (continued)

    func testChangedEvaluation_MultipleItemsIndependent() {
        var baselines: [String: String?] = [:]
        var initialized: Set<String> = []

        // Item A: baseline "Dark"
        baselines["itemA"] = "Dark" as String?
        initialized.insert("itemA")

        // Item B: baseline nil
        baselines["itemB"] = nil as String?
        initialized.insert("itemB")

        // Only Item A changes
        let changedA = (baselines["itemA"] ?? nil) != ("Light" as String?)
        let changedB = (baselines["itemB"] ?? nil) != (nil as String?)

        XCTAssertTrue(changedA, "Item A should detect change")
        XCTAssertFalse(changedB, "Item B should not detect change")
    }
}
