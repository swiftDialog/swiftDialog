import XCTest
@testable import Dialog

class dialogTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    // MARK: - #667: rich remediation content (KeyMapping + PlistAggregator)

    func testKeyMappingDecodesNewFields() throws {
        let json = Data("""
        {
          "key": "macos_version",
          "displayName": "macOS Version",
          "category": "Maintenance",
          "isCritical": true,
          "severity": "failure",
          "explanation": "Your macOS is unsupported.",
          "remediation": "Update to the latest supported macOS.",
          "actionButtonText": "Open Software Update",
          "actionURL": "x-apple.systempreferences:com.apple.Software-Update-Settings.extension"
        }
        """.utf8)

        let mapping = try JSONDecoder().decode(InspectConfig.KeyMapping.self, from: json)
        XCTAssertEqual(mapping.key, "macos_version")
        XCTAssertEqual(mapping.severity, "failure")
        XCTAssertEqual(mapping.explanation, "Your macOS is unsupported.")
        XCTAssertEqual(mapping.remediation, "Update to the latest supported macOS.")
        XCTAssertEqual(mapping.actionButtonText, "Open Software Update")
        XCTAssertEqual(mapping.actionURL,
                       "x-apple.systempreferences:com.apple.Software-Update-Settings.extension")
    }

    func testKeyMappingDecodesBackwardsCompat() throws {
        // A config with only `key` still decodes, with every newer field nil.
        let json = Data(#"{ "key": "battery_health" }"#.utf8)
        let mapping = try JSONDecoder().decode(InspectConfig.KeyMapping.self, from: json)
        XCTAssertEqual(mapping.key, "battery_health")
        XCTAssertNil(mapping.severity)
        XCTAssertNil(mapping.explanation)
        XCTAssertNil(mapping.remediation)
        XCTAssertNil(mapping.actionButtonText)
        XCTAssertNil(mapping.actionURL)
    }

    // MARK: - Trigger-file replay guard

    /// Content written to the trigger file before `startMonitoring` is not delivered; content appended
    /// after it is. The guard is `TriggerCursor.seekToEnd(of:)`.
    @MainActor
    func testTriggerFileReplayGuard_preExistingContentIgnored() {
        let tmpFile = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("test-trigger-replay-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }

        // Pre-existing content, written before monitoring starts
        let preExisting = "success:preexisting\n"
        try? preExisting.write(toFile: tmpFile, atomically: true, encoding: .utf8)

        let router = CommandRouter()
        var deliveredStepIds: [String] = []

        let appendedExpectation = expectation(description: "appended line delivered")
        router.onSuccess = { stepId, _ in
            deliveredStepIds.append(stepId)
            if stepId == "appended" {
                appendedExpectation.fulfill()
            }
        }

        router.startMonitoring(triggerFilePath: tmpFile)
        defer { router.stopMonitoring() }

        // Appended after monitoring has started
        if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: tmpFile)) {
            _ = try? fileHandle.seekToEnd()
            try? fileHandle.write(contentsOf: Data("success:appended\n".utf8))
            try? fileHandle.close()
        }

        wait(for: [appendedExpectation], timeout: 3)

        XCTAssertTrue(deliveredStepIds.contains("appended"),
                      "Appended line must be delivered to onSuccess")
        XCTAssertFalse(deliveredStepIds.contains("preexisting"),
                       "Pre-existing content must NOT be replayed after startMonitoring")
    }

    // MARK: - EventType wire format

    /// External consumers parse `userInfo["event"]` as a string, so the raw values are a contract.
    func testEventTypeRawValues() {
        XCTAssertEqual(DialogNotifications.EventType.ready.rawValue, "ready")
        XCTAssertEqual(DialogNotifications.EventType.exit.rawValue, "exit")
        XCTAssertEqual(DialogNotifications.EventType.deferred.rawValue, "defer")
        XCTAssertEqual(DialogNotifications.EventType.button.rawValue, "button")
        XCTAssertEqual(DialogNotifications.EventType.step.rawValue, "step")
        XCTAssertEqual(DialogNotifications.EventType.selection.rawValue, "selection")
    }

    // MARK: - Gated cadence (CadenceMonitorService)

    /// Decodes an IntroStep carrying a cadence array from JSON.
    private func decodeCadenceStep(_ json: String) throws -> InspectConfig.IntroStep {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(InspectConfig.IntroStep.self, from: data)
    }

    private func cadenceTempDir() -> String {
        let dir = (NSTemporaryDirectory() as NSString).appendingPathComponent("cadence-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    @MainActor
    func testCadenceManagedPrefAttribute() throws {
        // A managed preference landing satisfies a managedpref entry; the base points at a temp dir
        // standing in for /Library/Managed Preferences.
        let dir = cadenceTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let originalBase = CadenceMonitorService.managedPreferencesBase
        CadenceMonitorService.managedPreferencesBase = dir
        defer { CadenceMonitorService.managedPreferencesBase = originalBase }

        let domain = "com.test.security"
        let plistPath = (dir as NSString).appendingPathComponent("\(domain).plist")
        let svc = CadenceMonitorService()
        func attr(_ eval: String, _ expected: String?) -> InspectConfig.CadenceAttribute {
            InspectConfig.CadenceAttribute(source: nil, type: "managedpref", bundleId: nil, path: nil,
                                           key: "MDMProfileInstalled", expectedValue: expected, evaluation: eval,
                                           useUserDefaults: nil, domain: domain, scope: "device")
        }

        // Before the profile lands → unsatisfied.
        XCTAssertFalse(svc.isAttributeSatisfied(attr("exists", nil), entryId: "p"),
                       "no managed-pref file yet → unsatisfied")

        // Profile lands with the enforced value.
        let dict: [String: Any] = ["MDMProfileInstalled": "yes"]
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: URL(fileURLWithPath: plistPath))

        XCTAssertTrue(svc.isAttributeSatisfied(attr("exists", nil), entryId: "p"),
                      "key present after profile lands → satisfied")
        XCTAssertTrue(svc.isAttributeSatisfied(attr("equals", "yes"), entryId: "p"),
                      "enforced value matches → satisfied")
        XCTAssertFalse(svc.isAttributeSatisfied(attr("equals", "no"), entryId: "p"),
                       "different expected value → unsatisfied")
    }

    @MainActor
    func testCadenceClaimsFromManagedPref() throws {
        // A profile supplies the claims array (CadenceEntry dicts) via cadenceRef.
        let dir = cadenceTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let origBase = CadenceMonitorService.managedPreferencesBase
        CadenceMonitorService.managedPreferencesBase = dir
        defer { CadenceMonitorService.managedPreferencesBase = origBase }

        let domain = "com.tenant.deploy"
        let claims: [[String: Any]] = [
            ["id": "a", "message": "Task 1", "attribute": ["source": "ipc"]],
            ["id": "b", "message": "Task 2", "attribute": ["source": "ipc"]]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: ["Claims": claims], format: .xml, options: 0)
        try data.write(to: URL(fileURLWithPath: (dir as NSString).appendingPathComponent("\(domain).plist")))

        let step = try decodeCadenceStep("""
        { "id": "deploy", "stepType": "cadence", "cadenceRef": { "domain": "\(domain)", "key": "Claims" } }
        """)
        let svc = CadenceMonitorService()
        svc.start(step: step)
        XCTAssertEqual(svc.entries.count, 2, "claims loaded from the managed-pref array")
        XCTAssertEqual(svc.currentMessage, "Task 1")
    }

    @MainActor
    func testManagedPrefBrandColorLightDark() throws {
        // Brand colour read from a managed pref, with a dark-mode variant.
        let dir = cadenceTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let origBase = CadenceMonitorService.managedPreferencesBase
        CadenceMonitorService.managedPreferencesBase = dir
        defer { CadenceMonitorService.managedPreferencesBase = origBase }

        let domain = "nl.root3.support"
        let data = try PropertyListSerialization.data(
            fromPropertyList: ["CustomColor": "#732D3C", "CustomColorDarkMode": "#ada29a"],
            format: .xml, options: 0)
        try data.write(to: URL(fileURLWithPath: (dir as NSString).appendingPathComponent("\(domain).plist")))

        let ref = InspectConfig.ManagedValueRef(domain: domain, key: "CustomColor", darkKey: "CustomColorDarkMode")
        XCTAssertEqual(CadenceMonitorService.resolveColor(from: ref, dark: false), "#732D3C", "light")
        XCTAssertEqual(CadenceMonitorService.resolveColor(from: ref, dark: true), "#ada29a", "dark variant")

        let refNoDark = InspectConfig.ManagedValueRef(domain: domain, key: "CustomColor", darkKey: nil)
        XCTAssertEqual(CadenceMonitorService.resolveColor(from: refNoDark, dark: true), "#732D3C",
                       "no darkKey → falls back to the light value")
    }

}

final class InspectSchemaValidationTests: XCTestCase {
    private func data(_ s: String) -> Data { Data(s.utf8) }

    func testStandardDialogJSONIsNotInspect() {
        let r = validateInspectSchema(data(#"{"title":"Hi","message":"yo"}"#))
        if case .notInspect = r {} else { XCTFail("expected .notInspect, got \(r)") }
    }

    func testItemsOnlyConfigIsValid() {
        let r = validateInspectSchema(data(#"{"preset":"1","items":[{"id":"a","displayName":"A","guiIndex":0}]}"#))
        if case .valid = r {} else { XCTFail("expected .valid, got \(r)") }
    }

    func testEmptyObjectIsNotInspect() {
        let r = validateInspectSchema(data("{}"))
        if case .notInspect = r {} else { XCTFail("expected .notInspect, got \(r)") }
    }

    func testEmptyItemsArrayIsNotInspect() {
        // markers must be non-empty to count as intent
        let r = validateInspectSchema(data(#"{"items":[]}"#))
        if case .notInspect = r {} else { XCTFail("expected .notInspect, got \(r)") }
    }

    func testMarkerPresentButMalformedDecode() {
        // preset present (marker) but items has wrong type -> malformed, not notInspect
        let r = validateInspectSchema(data(#"{"preset":"1","items":"not-an-array"}"#))
        if case .malformed = r {} else { XCTFail("expected .malformed, got \(r)") }
    }

    func testQuotedScalarsCoerceAndValidate() {
        // guiIndex given as quoted string must coerce and still validate
        let r = validateInspectSchema(data(#"{"preset":"1","items":[{"id":"a","displayName":"A","guiIndex":"2"}]}"#))
        if case .valid = r {} else { XCTFail("expected .valid, got \(r)") }
    }
}

final class ConfigLoadFromDataTests: XCTestCase {
    func testValidInspectDataLoads() {
        let data = Data(#"{"preset":"1","items":[{"id":"a","displayName":"A","guiIndex":0}]}"#.utf8)
        let result = Config().loadConfiguration(fromData: data)
        switch result {
        case .success(let r): XCTAssertEqual(r.config.items.count, 1)
        case .failure(let e): XCTFail("expected success, got \(e)")
        }
    }

    func testStandardDataFails() {
        let data = Data(#"{"title":"Hi"}"#.utf8)
        if case .failure = Config().loadConfiguration(fromData: data) {} else {
            XCTFail("expected failure for non-inspect JSON")
        }
    }
}

final class InspectSourceResolverTests: XCTestCase {
    private let fakeRead: (String) -> Data? = { p in Data("FILE:\(p)".utf8) }

    func testJsonStringWins() {
        let r = resolveInspectConfigSource(jsonString: "{}", jsonFilePath: "/a.json",
            inspectConfigPath: nil, envPath: nil, standardLocationPath: nil, readFile: fakeRead)
        XCTAssertEqual(r?.origin, "--jsonstring")
        XCTAssertEqual(r?.data, Data("{}".utf8))
        XCTAssertNil(r?.path)
    }

    func testJsonFileBeatsEnvAndStandard() {
        let r = resolveInspectConfigSource(jsonString: nil, jsonFilePath: "/a.json",
            inspectConfigPath: nil, envPath: "/env.json", standardLocationPath: "/std.json", readFile: fakeRead)
        XCTAssertEqual(r?.path, "/a.json")
        XCTAssertEqual(r?.data, Data("FILE:/a.json".utf8))
    }

    func testEnvBeatsStandard() {
        let r = resolveInspectConfigSource(jsonString: nil, jsonFilePath: nil,
            inspectConfigPath: nil, envPath: "/env.json", standardLocationPath: "/std.json", readFile: fakeRead)
        XCTAssertEqual(r?.path, "/env.json")
    }

    func testNoSourceReturnsNil() {
        let r = resolveInspectConfigSource(jsonString: nil, jsonFilePath: nil,
            inspectConfigPath: nil, envPath: nil, standardLocationPath: nil, readFile: fakeRead)
        XCTAssertNil(r)
    }

    func testUnreadableFileFallsThrough() {
        let r = resolveInspectConfigSource(jsonString: nil, jsonFilePath: "/missing.json",
            inspectConfigPath: nil, envPath: "/env.json", standardLocationPath: nil,
            readFile: { $0 == "/env.json" ? Data("ok".utf8) : nil })
        XCTAssertEqual(r?.path, "/env.json")
    }
}

final class InspectIntakePipelineTests: XCTestCase {
    private let inspectJSON = #"{"preset":"1","items":[{"id":"a","displayName":"A","guiIndex":0},{"id":"b","displayName":"B","guiIndex":1}]}"#

    func testJsonStringPipelineProducesValidConfig() {
        let src = resolveInspectConfigSource(jsonString: inspectJSON, jsonFilePath: nil,
            inspectConfigPath: nil, envPath: nil, standardLocationPath: nil, readFile: { _ in nil })
        XCTAssertNotNil(src)
        guard case .valid = validateInspectSchema(src!.data) else { return XCTFail("string source failed validation") }
        switch Config().loadConfiguration(fromData: src!.data) {
        case .success(let r): XCTAssertEqual(r.config.items.count, 2)
        case .failure(let e): XCTFail("string pipeline load failed: \(e)")
        }
    }

    func testJsonFilePipelineMatchesString() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("intake-\(UUID().uuidString).json")
        try Data(inspectJSON.utf8).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let src = resolveInspectConfigSource(jsonString: nil, jsonFilePath: tmp.path,
            inspectConfigPath: nil, envPath: nil, standardLocationPath: nil,
            readFile: { FileManager.default.contents(atPath: $0) })
        XCTAssertEqual(src?.path, tmp.path)
        switch Config().loadConfiguration(fromData: src!.data) {
        case .success(let r): XCTAssertEqual(r.config.items.count, 2)
        case .failure(let e): XCTFail("file pipeline load failed: \(e)")
        }
    }

    func testStandardJSONViaPipelineIsRejected() {
        let src = resolveInspectConfigSource(jsonString: #"{"title":"Hi"}"#, jsonFilePath: nil,
            inspectConfigPath: nil, envPath: nil, standardLocationPath: nil, readFile: { _ in nil })
        if case .failure = Config().loadConfiguration(fromData: src!.data) {} else {
            XCTFail("standard JSON should be rejected by the pipeline")
        }
    }
}
