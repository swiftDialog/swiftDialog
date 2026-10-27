//
//  PlistEvaluationTests.swift
//  dialogTests
//
//  Plist evaluation: operators, value stringification, step canonicalization, operator defaults
//  shared across engines, and the advisories for silent defaults.
//

import XCTest
@testable import Dialog

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

        writePlist(["AppVersion": "1.0.0"])
        let initialValue = readPlistValue(key: "AppVersion")
        XCTAssertEqual(initialValue, "1.0.0")
        baselines[itemId] = initialValue
        initialized.insert(itemId)

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

        defaults.set("TestValue", forKey: testKey)
        let newValue = defaults.string(forKey: testKey)
        XCTAssertEqual(newValue, "TestValue")

        let baseline = baselines[itemId] ?? nil
        XCTAssertTrue(baseline != newValue, "Should detect change from nil to TestValue")

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

    // MARK: - equals across a state transition

    /// With `expectedValue: "not_installed"` and `equals`, an item reads complete before installation, not after.
    func testEqualsEvaluation_StateTransition_NotInstalledToInstalled() {
        // The item counts as installed when the value equals "not_installed".
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

    /// `expectedValue: "installed"` detects completion.
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

    /// `changed` detects any change from the baseline.
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

// MARK: - Stringification Contract

/// How plist/JSON-decoded values become display strings. Fixtures round-trip through real
/// serialization: a `__NSCFBoolean` casts to `Int` and a `__NSCFNumber` 1 casts to `Bool`, which Swift literals do not reproduce.
final class ValueStringificationContractTests: XCTestCase {

    /// Round-trips through a real plist so values arrive as the CF types the app sees.
    private func plistDecoded(_ dict: [String: Any]) throws -> [String: Any] {
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        return try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String: Any]
    }

    private var fixture: [String: Any] { get throws {
        try plistDecoded([
            "boolTrue": true,
            "boolFalse": false,
            "intZero": 0,
            "intOne": 1,
            "intFive": 5,
            "double": 3.5,
            "string": "hello",
            "array": [1, 2, 3],
            "dict": ["a": 1]
        ])
    } }

    // MARK: Bridging premise

    func testPlistRoundTripProducesBridgedCFTypes() throws {
        let f = try fixture
        XCTAssertEqual(CFGetTypeID(f["boolTrue"]! as CFTypeRef), CFBooleanGetTypeID(),
                       "plist bool must arrive as CFBoolean or the rest of this suite proves nothing")
        XCTAssertNotEqual(CFGetTypeID(f["intOne"]! as CFTypeRef), CFBooleanGetTypeID(),
                          "plist integer 1 must NOT be a CFBoolean")
    }

    func testBridgingLeniencyIsSymmetric() throws {
        let f = try fixture
        // A CFBoolean answers to `as? Int` ...
        XCTAssertEqual(f["boolTrue"] as? Int, 1)
        XCTAssertEqual(f["boolFalse"] as? Int, 0)
        // ... and a CFNumber holding 0/1 answers to `as? Bool`.
        XCTAssertEqual(f["intOne"] as? Bool, true)
        XCTAssertEqual(f["intZero"] as? Bool, false)
        // So only the CFTypeID discriminates; integers outside 0/1 are unambiguous.
        XCTAssertNil(f["intFive"] as? Bool)
    }

    // MARK: readKeyPath (item-level plistMonitors)

    private func readKeyPath(_ key: String) throws -> String? {
        IntroStepMonitorService().readKeyPath(from: try fixture, keyPath: key)
    }

    func testReadKeyPathStringifiesBooleans() {
        XCTAssertEqual(try readKeyPath("boolTrue"), "true")
        XCTAssertEqual(try readKeyPath("boolFalse"), "false")
    }

    func testReadKeyPathStringifiesIntegers() {
        XCTAssertEqual(try readKeyPath("intZero"), "0")
        XCTAssertEqual(try readKeyPath("intOne"), "1")
        XCTAssertEqual(try readKeyPath("intFive"), "5")
    }

    func testReadKeyPathStringifiesScalars() {
        XCTAssertEqual(try readKeyPath("double"), "3.5")
        XCTAssertEqual(try readKeyPath("string"), "hello")
    }

    func testReadKeyPathReturnsNilForContainers() {
        XCTAssertNil(try readKeyPath("array"))
        XCTAssertNil(try readKeyPath("dict"))
    }

    func testReadKeyPathReturnsNilForMissingKey() {
        XCTAssertNil(try readKeyPath("nope"))
    }

    func testReadKeyPathTraversesNestedKeyPaths() throws {
        let nested = try plistDecoded(["outer": ["inner": true]])
        XCTAssertEqual(IntroStepMonitorService().readKeyPath(from: nested, keyPath: "outer.inner"), "true")
    }

    // MARK: formatValueForDisplay

    @MainActor
    private func formatted(_ key: String) throws -> String {
        Validation.shared.formatValueForDisplay(try fixture[key]!)
    }

    @MainActor
    func testFormatValueForDisplayStringifiesBooleans() {
        XCTAssertEqual(try formatted("boolTrue"), "true")
        XCTAssertEqual(try formatted("boolFalse"), "false")
    }

    @MainActor
    func testFormatValueForDisplayStringifiesIntegers() {
        XCTAssertEqual(try formatted("intZero"), "0")
        XCTAssertEqual(try formatted("intOne"), "1")
        XCTAssertEqual(try formatted("intFive"), "5")
    }

    @MainActor
    func testFormatValueForDisplayStringifiesScalars() {
        XCTAssertEqual(try formatted("double"), "3.5")
        XCTAssertEqual(try formatted("string"), "hello")
    }

    @MainActor
    func testFormatValueForDisplaySummarizesContainers() {
        XCTAssertEqual(try formatted("array"), "[3 items]")
        XCTAssertEqual(try formatted("dict"), "{1 keys}")
    }

    @MainActor
    func testFormatValueForDisplayHandlesNSNull() {
        XCTAssertEqual(Validation.shared.formatValueForDisplay(NSNull()), "null")
    }

    // MARK: Both paths agree

    @MainActor
    func testBothPathsStringifyScalarsIdentically() {
        for key in ["boolTrue", "boolFalse", "intZero", "intOne", "intFive", "double", "string"] {
            XCTAssertEqual(try readKeyPath(key), try formatted(key),
                           "monitor path and display path disagree on '\(key)'")
        }
    }

    // MARK: equals comparison

    /// `equals` (the default when expectedValue is authored) compares the display reading, so a plist
    /// integer never answers as a Bool.
    @MainActor
    private func equalsCheck(_ key: String, _ expected: String) throws -> Bool {
        Validation.shared.performSmartEvaluation(
            value: try fixture[key]!, evaluationType: "equals", expectedValue: expected, key: key)
    }

    @MainActor
    func testEqualsMatchesAnIntegerAgainstItsOwnDigits() {
        // A plist integer 1 satisfies "1".
        XCTAssertTrue(try equalsCheck("intOne", "1"))
        XCTAssertTrue(try equalsCheck("intZero", "0"))
        XCTAssertTrue(try equalsCheck("intFive", "5"))
    }

    @MainActor
    func testEqualsDoesNotTreatAnIntegerAsABoolean() {
        // 1 does not match "true"; boolean semantics are `evaluation: "boolean"`.
        XCTAssertFalse(try equalsCheck("intOne", "true"))
        XCTAssertFalse(try equalsCheck("intZero", "false"))
    }

    @MainActor
    func testEqualsStillMatchesRealBooleans() {
        // A genuine CFBoolean still reads, and compares, as "true"/"false".
        XCTAssertTrue(try equalsCheck("boolTrue", "true"))
        XCTAssertTrue(try equalsCheck("boolFalse", "false"))
        XCTAssertFalse(try equalsCheck("boolTrue", "false"))
    }

    @MainActor
    func testEqualsMatchesStringsAndDoubles() {
        XCTAssertTrue(try equalsCheck("string", "hello"))
        XCTAssertTrue(try equalsCheck("double", "3.5"))
        XCTAssertFalse(try equalsCheck("string", "goodbye"))
    }

    /// The verdict and the value shown for it must come from the same reading.
    @MainActor
    func testEqualsAgreesWithWhatTheDisplayPathWouldShow() throws {
        for key in ["boolTrue", "boolFalse", "intZero", "intOne", "intFive", "double", "string"] {
            let shown = Validation.shared.formatValueForDisplay(try fixture[key]!)
            XCTAssertTrue(try equalsCheck(key, shown),
                          "'\(key)' displays as '\(shown)' but does not compare equal to it")
        }
    }

    // MARK: valueMap boolean-alias retry

    func testValueMapResolvesExactKeyFirst() {
        let map = ["true": "success", "1": "wrong"]
        XCTAssertEqual(mapMonitorValue("true", through: map), "success",
                       "an exact hit must never be overridden by the alias")
    }

    func testValueMapRetriesBooleanAliasForConfigsAuthoredAgainstTheOldReads() {
        // A config authored against a boolean key read back as "1"/"0".
        let legacyMap = ["1": "enabled", "0": "disabled"]
        XCTAssertEqual(mapMonitorValue("true", through: legacyMap), "enabled")
        XCTAssertEqual(mapMonitorValue("false", through: legacyMap), "disabled")
    }

    func testValueMapRetriesInTheOtherDirectionToo() {
        let currentMap = ["true": "success", "false": "warning"]
        XCTAssertEqual(mapMonitorValue("1", through: currentMap), "success")
        XCTAssertEqual(mapMonitorValue("0", through: currentMap), "warning")
    }

    func testValueMapReturnsNilWhenNeitherFormIsPresent() {
        XCTAssertNil(mapMonitorValue("5", through: ["true": "success"]))
        XCTAssertNil(mapMonitorValue("true", through: ["running": "up"]))
        XCTAssertNil(mapMonitorValue("true", through: nil))
    }

    func testValueMapDoesNotAliasNonBooleanValues() {
        // Only true/false/1/0 are retried as boolean aliases, not "yes"/"on".
        XCTAssertNil(mapMonitorValue("yes", through: ["true": "success"]))
    }

    /// A CFBoolean key with a valueMap authored on "true", end to end.
    @MainActor
    func testFleetDemoScreensaverBadgeResolvesThroughTheMap() throws {
        let plist = try plistDecoded(["askForPassword": true])
        let raw = IntroStepMonitorService().readKeyPath(from: plist, keyPath: "askForPassword")
        XCTAssertEqual(raw, "true")
        XCTAssertEqual(mapMonitorValue(raw!, through: ["true": "success", "false": "warning"]), "success",
                       "the screensaver badge must map to a state, not fall through to a raw value")
        XCTAssertEqual(mapMonitorValue(raw!, through: ["true": "true (locked)", "false": "false"]), "true (locked)")
    }
}

// MARK: - Operator defaults
// Per engine, over (evaluation nil/authored × expectedValue nil/authored); every engine fails
// closed on an unknown operator and folds case. Operator semantics per engine are a separate contract.
@MainActor
final class OperatorDefaultContractTests: XCTestCase {

    // MARK: Derived default

    func testAbsentEvaluationWithAnExpectedValueComparesWithEquals() {
        XCTAssertEqual(EvaluationOperator.resolve(evaluation: nil, expectedValue: "1"), .equals,
                       "an author who wrote an expectedValue wrote something to compare against")
    }

    func testAbsentEvaluationWithoutAnExpectedValueChecksExistence() {
        XCTAssertEqual(EvaluationOperator.resolve(evaluation: nil, expectedValue: nil), .exists,
                       "a bare domain/key requirement means 'key present', not equals-nil")
    }

    func testAnEmptyEvaluationStringIsTreatedAsAbsent() {
        XCTAssertEqual(EvaluationOperator.resolve(evaluation: "   ", expectedValue: nil), .exists)
    }

    func testAuthoredEvaluationAlwaysWinsOverTheDerivedDefault() {
        XCTAssertEqual(EvaluationOperator.resolve(evaluation: "exists", expectedValue: "1"), .exists,
                       "the derived default must never override what the author wrote")
    }

    func testUnknownAuthoredOperatorResolvesToNilSoCallersCanFailClosed() {
        XCTAssertNil(EvaluationOperator.resolve(evaluation: "eqauls", expectedValue: "1"),
                     "a typo must be visible as a failure, not silently become a comparison")
    }

    func testOperatorNamesAreCaseAndWhitespaceInsensitive() {
        XCTAssertEqual(EvaluationOperator(authored: "Exists"), .exists)
        XCTAssertEqual(EvaluationOperator(authored: " BOOLEAN "), .boolean)
        XCTAssertEqual(EvaluationOperator(authored: "Range"), .range)
    }

    func testDerivationNoteNamesTheOperatorAppliedOnlyWhenOneWasDerived() {
        XCTAssertNotNil(EvaluationOperator.derivationNote(evaluation: nil, expectedValue: "1"))
        XCTAssertNotNil(EvaluationOperator.derivationNote(evaluation: nil, expectedValue: nil))
        XCTAssertNil(EvaluationOperator.derivationNote(evaluation: "equals", expectedValue: "1"),
                     "nothing was derived, so there is nothing to advise about")
    }

    // MARK: Fail closed: an unknown operator never completes an item

    func testUnknownOperatorDoesNotMarkAnItemComplete() {
        XCTAssertFalse(PlistStatusPoller.evaluate("no", expected: "yes", evaluation: "bogus"),
                       "a typo'd operator marking the item complete is the worst outcome available")
    }

    func testUnknownOperatorFailsClosedEvenWhenValuesHappenToMatch() {
        XCTAssertFalse(PlistStatusPoller.evaluate("yes", expected: "yes", evaluation: "bogus"),
                       "matching by accident is not the same as being asked to compare")
    }

    // MARK: Case folding
    // The probes use an operator whose correct answer is false, so a fail-open default cannot mask a missing fold.

    func testCapitalisedEqualsIsHonouredRatherThanFallingToTheDefault() {
        XCTAssertFalse(PlistStatusPoller.evaluate("no", expected: "yes", evaluation: "Equals"),
                       "'Equals' must compare, and 'no' does not equal 'yes'")
    }

    func testCapitalisedContainsIsHonouredRatherThanFallingToTheDefault() {
        XCTAssertFalse(PlistStatusPoller.evaluate("alpha", expected: "beta", evaluation: "CONTAINS"),
                       "'alpha' does not contain 'beta'")
    }

    /// `Exists` folds to `exists`; this alone cannot tell folding from fail-open, hence the tests above.
    func testCapitalisedExistsIsTrueBeforeAndAfterTheFix() {
        XCTAssertTrue(PlistStatusPoller.evaluate("anything", expected: nil, evaluation: "Exists"))
    }

    func testValidationAlreadyFoldsCaseAndMustKeepDoingSo() {
        // Validation folds case through `EvaluationOperator(authored:)`.
        XCTAssertTrue(Validation.shared.performSmartEvaluation(
            value: "hello", evaluationType: "EXISTS", expectedValue: nil, key: "k"))
    }

    // MARK: Cross-engine agreement

    /// Both engines fail closed on an unknown operator.
    func testEnginesAgreeOnAnUnknownOperator() {
        let poller = PlistStatusPoller.evaluate("no", expected: "yes", evaluation: "bogus")
        let validation = Validation.shared.performSmartEvaluation(value: "no",
                                                                  evaluationType: "bogus",
                                                                  expectedValue: "yes",
                                                                  key: "k")
        XCTAssertEqual(poller, validation,
                       "unknown operator: poller said \(poller), Validation said \(validation)")
    }

    /// `contains` means the same in both engines: substring on a string, membership on an array.
    func testEnginesAgreeOnWhatContainsMeans() {
        let poller = PlistStatusPoller.evaluate("alpha-beta", expected: "beta", evaluation: "contains")
        let validation = Validation.shared.performSmartEvaluation(value: "alpha-beta",
                                                                  evaluationType: "contains",
                                                                  expectedValue: "beta",
                                                                  key: "k")
        XCTAssertEqual(poller, validation,
                       "'contains' on a string: poller said \(poller), Validation said \(validation)")
    }

    // MARK: contains reads the value's shape

    /// The `contains` case table, on the operator so every engine shares it.

    func testContainsOnAStringIsCaseFoldedSubstring() {
        XCTAssertTrue(EvaluationOperator.containsMatch(value: "alpha-BETA", expected: "beta"))
        XCTAssertTrue(EvaluationOperator.containsMatch(value: "alpha-beta", expected: "BETA"))
        XCTAssertFalse(EvaluationOperator.containsMatch(value: "alpha-beta", expected: "gamma"))
    }

    /// Array membership is exact: "lph" is inside "alpha" but is not an element.
    func testContainsOnAnArrayIsMembershipAndNotSubstring() {
        XCTAssertTrue(EvaluationOperator.containsMatch(value: ["alpha", "beta"], expected: "beta"))
        XCTAssertFalse(EvaluationOperator.containsMatch(value: ["alpha", "beta"], expected: "lph"),
                       "array membership is exact; 'lph' is inside an element but is not one")
    }

    func testContainsOnAnArrayCoercesNonStringElements() {
        XCTAssertTrue(EvaluationOperator.containsMatch(value: [1, 2, 3], expected: "2"))
        XCTAssertFalse(EvaluationOperator.containsMatch(value: [1, 2, 3], expected: "4"))
    }

    /// An array is not stringified before evaluating, so "(alpha, beta)" punctuation cannot match.
    func testTheStringifiedArrayFalsePositiveIsGone() {
        XCTAssertFalse(PlistStatusPoller.evaluate(["alpha", "beta"], expected: "lph",
                                                  evaluation: "contains"),
                       "the poller must see the array, not its description")
        XCTAssertTrue(PlistStatusPoller.evaluate(["alpha", "beta"], expected: "beta",
                                                 evaluation: "contains"))
    }

    /// No expected value means false.
    func testContainsWithNoExpectedValueIsFalse() {
        XCTAssertFalse(EvaluationOperator.containsMatch(value: "alpha", expected: nil))
        XCTAssertFalse(EvaluationOperator.containsMatch(value: ["alpha"], expected: nil))
    }

    func testContainsOnAScalarUsesItsStringForm() {
        XCTAssertTrue(EvaluationOperator.containsMatch(value: 1234, expected: "23"))
        XCTAssertFalse(EvaluationOperator.containsMatch(value: 1234, expected: "56"))
    }

    func testContainsOnNullIsFalse() {
        XCTAssertFalse(EvaluationOperator.containsMatch(value: NSNull(), expected: "anything"))
    }

    /// Same verdict for both shapes in both engines.
    func testBothEnginesAgreeOnContainsForBothShapes() {
        let probes: [(value: Any, expected: String, what: String)] = [
            ("alpha-beta", "beta", "substring hit"),
            ("alpha-beta", "gamma", "substring miss"),
            ("alpha-BETA", "beta", "case-folded hit"),
            (["alpha", "beta"], "beta", "membership hit"),
            (["alpha", "beta"], "lph", "membership miss on a substring of an element")
        ]
        for probe in probes {
            let poller = PlistStatusPoller.evaluate(probe.value, expected: probe.expected,
                                                    evaluation: "contains")
            let validation = Validation.shared.performSmartEvaluation(value: probe.value,
                                                                      evaluationType: "contains",
                                                                      expectedValue: probe.expected,
                                                                      key: "k")
            XCTAssertEqual(poller, validation,
                           "\(probe.what): poller said \(poller), Validation said \(validation)")
        }
    }

    /// `RequirementEvaluator.plistSatisfied` fails closed on an unknown operator. The stored value
    /// equals the expected one, so a `default: equals` would answer true.
    func testTheRequirementEvaluatorFailsClosedOnAnUnknownOperator() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("req-eval-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let plist = dir.appendingPathComponent("probe.plist")
        try (["state": "ready"] as NSDictionary).write(to: plist)

        func requirement(evaluation: String) throws -> InspectConfig.ItemConfig.Requirement {
            let json = """
            {"type":"plist","path":"\(plist.path)","key":"state",
             "evaluation":"\(evaluation)","expectedValue":"ready"}
            """
            return try JSONDecoder().decode(InspectConfig.ItemConfig.Requirement.self,
                                            from: Data(json.utf8))
        }

        XCTAssertTrue(RequirementEvaluator.isSatisfied(try requirement(evaluation: "equals"),
                                                       receiptsBasePath: "/var/db/receipts"),
                      "control: the probe really does satisfy 'equals'")
        XCTAssertFalse(RequirementEvaluator.isSatisfied(try requirement(evaluation: "bogus"),
                                                        receiptsBasePath: "/var/db/receipts"),
                       "an unrecognised operator must not silently become 'equals'")
    }

    // MARK: Compliance auto-discovery synthesises requirements

    // `Config+Helpers.swift` mints requirements from an mSCP-style findings plist, where
    // `finding == false` means compliant, so it stamps `boolean`/`"false"` rather than the derived default.

    private func findingsPlist() throws -> (dir: URL, path: String) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("synthesis-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("findings.plist").path
        let findings: NSDictionary = [
            "os_gatekeeper_enable": ["finding": false, "title": "Enable Gatekeeper"],
            "pwpolicy_account_lockout": ["finding": true, "title": "Account lockout"],
            "audit_folder_owner": ["finding": false, "title": "Audit folder owner"],
            // Excluded by the default excludeKeys set.
            "lastComplianceCheck": ["finding": false],
            // No finding subkey: skipped, not synthesised.
            "not_a_finding": ["title": "unrelated"]
        ]
        XCTAssertTrue(findings.write(toFile: path, atomically: true))
        return (dir, path)
    }

    private func plistSource(_ json: String) throws -> InspectConfig.PlistSourceConfig {
        try JSONDecoder().decode(InspectConfig.PlistSourceConfig.self, from: Data(json.utf8))
    }

    func testEverySynthesisedItemCarriesTheConventionExplicitly() throws {
        let fixture = try findingsPlist()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }

        let source = try plistSource(#"{"path": "\#(fixture.path)", "type": "compliance", "displayName": "Compliance"}"#)
        let items = Config().discoverItemsFromPlist(source: source, basePath: nil)

        XCTAssertEqual(items.count, 3, "one item per key carrying a finding, excludes filtered")
        for item in items {
            XCTAssertEqual(item.evaluation, "boolean",
                           "\(item.id): synthesised items must carry the operator EXPLICITLY, "
                           + "so no downstream engine has to derive one")
            XCTAssertEqual(item.expectedValue, "false",
                           "\(item.id): finding=false ⇒ compliant is the convention")
        }
    }

    /// A synthesised item carries its operator explicitly, so the derived default (`equals`) is never consulted.
    func testTheDerivedDefaultIsNeverConsultedForASynthesisedItem() throws {
        let fixture = try findingsPlist()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }

        let source = try plistSource(#"{"path": "\#(fixture.path)", "type": "compliance", "displayName": "Compliance"}"#)
        for item in Config().discoverItemsFromPlist(source: source, basePath: nil) {
            XCTAssertNil(EvaluationOperator.derivationNote(evaluation: item.evaluation,
                                                           expectedValue: item.expectedValue),
                         "\(item.id): a synthesised item must never look like an un-authored one")
            XCTAssertEqual(EvaluationOperator.resolve(evaluation: item.evaluation,
                                                      expectedValue: item.expectedValue),
                           .boolean)
        }
    }

    /// An authored source grammar wins over the convention.
    func testAnAuthoredSourceGrammarWinsOverTheConvention() throws {
        let fixture = try findingsPlist()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }

        let source = try plistSource(
            #"{"path": "\#(fixture.path)", "type": "compliance", "displayName": "Compliance", "evaluation": "equals", "expectedValue": "true"}"#)
        let items = Config().discoverItemsFromPlist(source: source, basePath: nil)

        XCTAssertFalse(items.isEmpty)
        for item in items {
            XCTAssertEqual(item.evaluation, "equals")
            XCTAssertEqual(item.expectedValue, "true")
        }
    }

    /// `boolean` reads every spelling of false (`false`, `0`, `"NO"`); `equals` matches only the literal "false".
    func testTheConventionsOperatorReadsEverySpellingOfFalseAndEqualsDoesNot() {
        for spelling in [false, 0, "NO", "no"] as [Any] {
            XCTAssertTrue(Validation.shared.performSmartEvaluation(
                value: spelling, evaluationType: "boolean", expectedValue: "false", key: "finding"),
                "finding=\(spelling) ⇒ compliant under the convention")
        }

        XCTAssertFalse(Validation.shared.performSmartEvaluation(
            value: 0, evaluationType: "equals", expectedValue: "false", key: "finding"),
            "a finding stored as 0 is compliant, but `equals` compares \"0\" to \"false\" "
            + "— the wrong answer the derived default would have produced")
        XCTAssertFalse(Validation.shared.performSmartEvaluation(
            value: "NO", evaluationType: "equals", expectedValue: "false", key: "finding"))

        // The operator the derived default would pick.
        XCTAssertEqual(EvaluationOperator.resolve(evaluation: nil, expectedValue: "false"), .equals)
    }

    /// Recognised operators give the same verdict in both engines.
    func testEnginesAgreeOnRecognisedOperators() {
        let probes: [(actual: String, expected: String?, op: String)] = [
            ("hello", nil, "exists"),
            ("yes", "yes", "equals"),
            ("no", "yes", "equals")
        ]
        for probe in probes {
            let poller = PlistStatusPoller.evaluate(probe.actual,
                                                    expected: probe.expected,
                                                    evaluation: probe.op)
            let validation = Validation.shared.performSmartEvaluation(value: probe.actual,
                                                                      evaluationType: probe.op,
                                                                      expectedValue: probe.expected,
                                                                      key: "k")
            XCTAssertEqual(poller, validation,
                           "'\(probe.op)' on '\(probe.actual)' vs \(probe.expected ?? "nil"): "
                           + "poller said \(poller), Validation said \(validation)")
        }
    }

    /// `RequirementEvaluator` derives its operator through `EvaluationOperator.resolve`.
    func testRequirementEvaluatorKeepsTheDerivationItAlreadyHad() {
        XCTAssertEqual(EvaluationOperator.resolve(evaluation: nil, expectedValue: "42"), .equals)
        XCTAssertEqual(EvaluationOperator.resolve(evaluation: nil, expectedValue: nil), .exists)
    }
}
