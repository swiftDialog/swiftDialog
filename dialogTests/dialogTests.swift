//
//  dialogTests.swift
//  dialogTests
//
//  Created by Bart Reardon on 9/3/21.
//

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

    // MARK: - Published Sessions Directory (per-PID discovery file)

    func testPublishedSessionWriteAndCleanup() throws {
        let originalValue = appArguments.publishedSessionsDir.value
        let tmpDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("swiftdialog-test-\(UUID().uuidString)")
        appArguments.publishedSessionsDir.value = tmpDir
        defer {
            appArguments.publishedSessionsDir.value = originalValue
            try? FileManager.default.removeItem(atPath: tmpDir)
        }

        let triggerFile = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("test-trigger-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(atPath: "\(triggerFile).ready") }

        writeReadinessFile(config: nil, triggerFilePath: triggerFile,
                           preset: "test", itemCount: 3)

        let pid = ProcessInfo.processInfo.processIdentifier
        let publishedPath = (tmpDir as NSString).appendingPathComponent("\(pid).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: publishedPath),
                      "Expected published session file at \(publishedPath)")

        let data = try XCTUnwrap(FileManager.default.contents(atPath: publishedPath))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["pid"] as? Int, Int(pid))
        XCTAssertEqual(json["triggerFile"] as? String, triggerFile)
        XCTAssertEqual(json["preset"] as? String, "test")
        XCTAssertEqual(json["itemCount"] as? Int, 3)
        XCTAssertEqual(json["ackChannel"] as? String, "com.swiftdialog.ack")

        cleanupReadinessFile(config: nil, triggerFilePath: triggerFile)
        XCTAssertFalse(FileManager.default.fileExists(atPath: publishedPath),
                       "Expected published session file removed after cleanup")
    }

    func testPublishedSessionDisabledWhenEmpty() {
        let originalValue = appArguments.publishedSessionsDir.value
        appArguments.publishedSessionsDir.value = ""
        defer { appArguments.publishedSessionsDir.value = originalValue }

        XCTAssertNil(resolvePublishedSessionsDir())
        XCTAssertNil(resolvePublishedSessionPath())
    }

    func testPublishedSessionDisabledWhenNone() {
        let originalValue = appArguments.publishedSessionsDir.value
        appArguments.publishedSessionsDir.value = "none"
        defer { appArguments.publishedSessionsDir.value = originalValue }

        XCTAssertNil(resolvePublishedSessionsDir())
        XCTAssertNil(resolvePublishedSessionPath())
    }

    // MARK: - FR #667: Rich Remediation Content (KeyMapping + PlistAggregator)

    func testKeyMappingDecodesNewFields() throws {
        let json = """
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
        """.data(using: .utf8)!

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
        // A pre-FR-#667 config with only `key` must still decode and yield nil for
        // every new field.
        let json = #"{ "key": "battery_health" }"#.data(using: .utf8)!
        let mapping = try JSONDecoder().decode(InspectConfig.KeyMapping.self, from: json)
        XCTAssertEqual(mapping.key, "battery_health")
        XCTAssertNil(mapping.severity)
        XCTAssertNil(mapping.explanation)
        XCTAssertNil(mapping.remediation)
        XCTAssertNil(mapping.actionButtonText)
        XCTAssertNil(mapping.actionURL)
    }

    /// End-to-end integration through `loadPlistSource`: writes a real plist with
    /// nested-dict values, builds a `PlistSourceConfig` via Codable, and asserts the
    /// resulting `ComplianceItem`s have the expected merge of plist + config.
    func testPlistAggregatorMergesPlistAndConfig() throws {
        let plistPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("compliance-\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(atPath: plistPath) }

        // macos_version: nested dict overrides explanation; config provides remediation
        // airdrop:       scalar bool; only config defaults are available
        let plist: [String: Any] = [
            "macos_version": [
                "finding": false,
                "explanation": "Plist override: macOS 12 is too old"
            ],
            "airdrop": false,
            "lastComplianceCheck": "2026-05-09T12:00:00Z"
        ]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        )
        try plistData.write(to: URL(fileURLWithPath: plistPath))

        let configJSON = """
        {
          "path": "\(plistPath)",
          "type": "compliance",
          "displayName": "Compliance",
          "keyMappings": [
            {
              "key": "macos_version",
              "displayName": "macOS Version",
              "category": "Maintenance",
              "severity": "failure",
              "explanation": "Config default: macOS unsupported",
              "remediation": "Update macOS to the latest version.",
              "actionButtonText": "Open Software Update",
              "actionURL": "x-apple.systempreferences:com.apple.Software-Update-Settings.extension"
            },
            {
              "key": "airdrop",
              "displayName": "AirDrop",
              "category": "Privacy",
              "severity": "warning",
              "explanation": "AirDrop is enabled.",
              "remediation": "Disable AirDrop in Control Center."
            }
          ]
        }
        """.data(using: .utf8)!
        let source = try JSONDecoder().decode(InspectConfig.PlistSourceConfig.self, from: configJSON)

        let result = PlistAggregator.loadPlistSource(source: source)
        let items = try XCTUnwrap(result?.items)
        let macos = try XCTUnwrap(items.first(where: { $0.id == "macos_version" }))
        let airdrop = try XCTUnwrap(items.first(where: { $0.id == "airdrop" }))

        // Plist-overrides-config: macos_version's explanation comes from the plist
        XCTAssertEqual(macos.explanation, "Plist override: macOS 12 is too old")
        // Config default flows through when plist lacks the field
        XCTAssertEqual(macos.remediation, "Update macOS to the latest version.")
        XCTAssertEqual(macos.actionButtonText, "Open Software Update")
        XCTAssertEqual(macos.actionURL,
                       "x-apple.systempreferences:com.apple.Software-Update-Settings.extension")
        XCTAssertEqual(macos.severity, .failure)
        XCTAssertFalse(macos.finding)

        // Scalar plist value: all rich fields come from the config
        XCTAssertEqual(airdrop.explanation, "AirDrop is enabled.")
        XCTAssertEqual(airdrop.remediation, "Disable AirDrop in Control Center.")
        XCTAssertEqual(airdrop.severity, .warning)
        XCTAssertFalse(airdrop.finding)
    }

    /// Severity derives from `finding` when no keyMapping severity is set.
    func testPlistAggregatorSeverityDerivedFromFinding() throws {
        let plistPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("compliance-\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(atPath: plistPath) }

        try PropertyListSerialization.data(
            fromPropertyList: ["passing": true, "failing": false], format: .xml, options: 0
        ).write(to: URL(fileURLWithPath: plistPath))

        let configJSON = """
        { "path": "\(plistPath)", "type": "compliance", "displayName": "Test" }
        """.data(using: .utf8)!
        let source = try JSONDecoder().decode(InspectConfig.PlistSourceConfig.self, from: configJSON)

        let items = try XCTUnwrap(PlistAggregator.loadPlistSource(source: source)?.items)
        XCTAssertEqual(items.first(where: { $0.id == "passing" })?.severity, .healthy)
        XCTAssertEqual(items.first(where: { $0.id == "failing" })?.severity, .failure)
    }

    // MARK: - CommandRouter trigger-file replay guard (IPC Gap 5)

    /// Pins the byte-offset skip guarantee in `CommandRouter.startMonitoring`.
    ///
    /// Content written to the trigger file BEFORE `startMonitoring` is called must
    /// NOT be delivered to handlers; content appended AFTER monitoring starts MUST
    /// be delivered. The guard is implemented via `lastProcessedByteOffset` being
    /// set to `data.count` at the moment monitoring begins — this test proves it holds.
    @MainActor
    func testTriggerFileReplayGuard_preExistingContentIgnored() {
        let tmpFile = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("test-trigger-replay-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }

        // Write pre-existing content BEFORE monitoring starts
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

        // Append new content AFTER monitoring has started
        if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: tmpFile)) {
            try? fileHandle.seekToEnd()
            try? fileHandle.write(contentsOf: Data("success:appended\n".utf8))
            try? fileHandle.close()
        }

        wait(for: [appendedExpectation], timeout: 3)

        XCTAssertTrue(deliveredStepIds.contains("appended"),
                      "Appended line must be delivered to onSuccess")
        XCTAssertFalse(deliveredStepIds.contains("preexisting"),
                       "Pre-existing content must NOT be replayed after startMonitoring")
    }

    // MARK: - DistributedNotifications EventType wire-format contract

    /// External consumers (ignitecli, Fleet Desktop, custom scripts) parse
    /// `userInfo["event"]` as a string. A rename of any enum case that changes
    /// its rawValue would silently break those consumers. This test pins the
    /// wire format so the contract has to be changed deliberately.
    func testEventTypeRawValues() {
        XCTAssertEqual(DialogNotifications.EventType.ready.rawValue, "ready")
        XCTAssertEqual(DialogNotifications.EventType.exit.rawValue, "exit")
        XCTAssertEqual(DialogNotifications.EventType.deferred.rawValue, "defer")
        XCTAssertEqual(DialogNotifications.EventType.button.rawValue, "button")
        XCTAssertEqual(DialogNotifications.EventType.step.rawValue, "step")
        XCTAssertEqual(DialogNotifications.EventType.selection.rawValue, "selection")
    }

    // MARK: - Gated Cadence (CadenceMonitorService)

    /// Decode an IntroStep carrying a cadence array from JSON (proves the schema decodes).
    private func decodeCadenceStep(_ json: String) throws -> InspectConfig.IntroStep {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(InspectConfig.IntroStep.self, from: data)
    }

    private func cadenceTempDir() -> String {
        let dir = (NSTemporaryDirectory() as NSString).appendingPathComponent("cadence-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    func testCadenceSchemaDecodes() throws {
        let step = try decodeCadenceStep("""
        { "id": "deploy", "stepType": "cadence", "cadenceInterval": 2.0, "cadence": [
            { "id": "a", "message": "Task 1", "attribute": { "source": "native", "type": "app", "bundleId": "com.apple.finder" } },
            { "id": "b", "message": "Task 2", "attribute": { "type": "plist", "path": "/tmp/x.plist", "key": "Installed", "evaluation": "boolean", "expectedValue": "true" } }
        ] }
        """)
        XCTAssertEqual(step.cadence?.count, 2)
        XCTAssertEqual(step.cadenceInterval, 2.0)
        XCTAssertEqual(step.cadence?[0].id, "a")
        XCTAssertEqual(step.cadence?[1].attribute.evaluation, "boolean")
    }

    @MainActor
    func testCadenceFileAttributeSatisfaction() {
        let dir = cadenceTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let path = (dir as NSString).appendingPathComponent("receipt.bom")
        let svc = CadenceMonitorService()
        let attr = InspectConfig.CadenceAttribute(source: nil, type: "file", bundleId: nil, path: path,
                                                  key: nil, expectedValue: nil, evaluation: nil, useUserDefaults: nil, domain: nil, scope: nil)
        XCTAssertFalse(svc.isAttributeSatisfied(attr, entryId: "f"), "missing file → unsatisfied")
        FileManager.default.createFile(atPath: path, contents: Data("x".utf8))
        XCTAssertTrue(svc.isAttributeSatisfied(attr, entryId: "f"), "present file → satisfied")
    }

    @MainActor
    func testCadenceAppByBundleId() {
        let svc = CadenceMonitorService()
        let finder = InspectConfig.CadenceAttribute(source: nil, type: "app", bundleId: "com.apple.finder",
                                                    path: nil, key: nil, expectedValue: nil, evaluation: nil, useUserDefaults: nil, domain: nil, scope: nil)
        let bogus = InspectConfig.CadenceAttribute(source: nil, type: "app", bundleId: "com.nonexistent.zzz123",
                                                   path: nil, key: nil, expectedValue: nil, evaluation: nil, useUserDefaults: nil, domain: nil, scope: nil)
        XCTAssertTrue(svc.isAttributeSatisfied(finder, entryId: "x"), "Finder is always installed on the test host")
        XCTAssertFalse(svc.isAttributeSatisfied(bogus, entryId: "y"))
    }

    @MainActor
    func testCadenceIpcDriveAdvances() throws {
        let step = try decodeCadenceStep("""
        { "id": "deploy", "stepType": "cadence", "cadence": [
            { "id": "step1", "message": "Task 1", "attribute": { "source": "ipc" } },
            { "id": "step2", "message": "Task 2", "attribute": { "source": "ipc" } }
        ] }
        """)
        let svc = CadenceMonitorService()
        // defaultMinDwell 0 isolates the IPC-advance logic from the replay dwell (covered separately).
        svc.startWithEntries(entries: step.cadence ?? [], stepId: "deploy", interval: 60, defaultMinDwell: 0, onCompletion: nil)
        XCTAssertEqual(svc.currentIndex, 0, "ipc entry must not auto-advance")
        svc.satisfyExternally(id: "step1")
        XCTAssertEqual(svc.currentIndex, 1, "external satisfy advances the active ipc entry")
    }

    @MainActor
    func testCadenceGatedAdvanceInOrderAndCompletes() {
        let dir = cadenceTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let p0 = (dir as NSString).appendingPathComponent("0")
        let p1 = (dir as NSString).appendingPathComponent("1")
        func fileAttr(_ p: String) -> InspectConfig.CadenceAttribute {
            InspectConfig.CadenceAttribute(source: nil, type: "file", bundleId: nil, path: p, key: nil,
                                           expectedValue: nil, evaluation: nil, useUserDefaults: nil, domain: nil, scope: nil)
        }
        var completed = 0
        let svc = CadenceMonitorService()
        // Build a step by decoding (schema) then driving via evaluateOnce — files gate each step.
        svc.startWithEntries(
            entries: [
                InspectConfig.CadenceEntry(id: "a", message: "A", attribute: fileAttr(p0), minDwell: nil, timeout: nil, sfSymbol: nil, imagePath: nil, iconColor: nil),
                InspectConfig.CadenceEntry(id: "b", message: "B", attribute: fileAttr(p1), minDwell: nil, timeout: nil, sfSymbol: nil, imagePath: nil, iconColor: nil)
            ],
            stepId: "deploy",
            interval: 60,
            onCompletion: { _, _ in completed += 1 })

        XCTAssertEqual(svc.currentIndex, 0)
        FileManager.default.createFile(atPath: p0, contents: Data())
        svc.evaluateOnce()
        XCTAssertEqual(svc.currentIndex, 1, "advances only after entry 0's file appears")
        XCTAssertFalse(svc.isComplete)
        FileManager.default.createFile(atPath: p1, contents: Data())
        svc.evaluateOnce()
        XCTAssertTrue(svc.isComplete, "last file present → complete")
        XCTAssertEqual(completed, 1, "completion fires exactly once")
        svc.evaluateOnce()
        XCTAssertEqual(completed, 1, "no double-fire")
    }

    @MainActor
    func testCadenceMinDwellHolds() {
        let dir = cadenceTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let p0 = (dir as NSString).appendingPathComponent("0")
        FileManager.default.createFile(atPath: p0, contents: Data())  // already satisfied
        var clock = Date(timeIntervalSince1970: 1000)
        let svc = CadenceMonitorService(now: { clock })
        let attr = InspectConfig.CadenceAttribute(source: nil, type: "file", bundleId: nil, path: p0, key: nil,
                                                  expectedValue: nil, evaluation: nil, useUserDefaults: nil, domain: nil, scope: nil)
        svc.startWithEntries(
            entries: [InspectConfig.CadenceEntry(id: "a", message: "A", attribute: attr, minDwell: 10, timeout: nil, sfSymbol: nil, imagePath: nil, iconColor: nil)],
            stepId: "s", interval: 60, onCompletion: nil)
        XCTAssertFalse(svc.isComplete, "minDwell not elapsed → holds even though satisfied")
        clock = clock.addingTimeInterval(11)
        svc.evaluateOnce()
        XCTAssertTrue(svc.isComplete, "after minDwell, satisfied entry completes")
    }

    @MainActor
    func testCadenceTimeoutForceAdvances() {
        var clock = Date(timeIntervalSince1970: 1000)
        let svc = CadenceMonitorService(now: { clock })
        // Never-satisfied native file (missing) with a 5s timeout.
        let attr = InspectConfig.CadenceAttribute(source: nil, type: "file", bundleId: nil,
                                                  path: "/tmp/definitely-missing-\(UUID().uuidString)", key: nil,
                                                  expectedValue: nil, evaluation: nil, useUserDefaults: nil, domain: nil, scope: nil)
        svc.startWithEntries(
            entries: [InspectConfig.CadenceEntry(id: "a", message: "A", attribute: attr, minDwell: nil, timeout: 5, sfSymbol: nil, imagePath: nil, iconColor: nil)],
            stepId: "s", interval: 60, onCompletion: nil)
        XCTAssertFalse(svc.isComplete, "before timeout, unsatisfied entry holds")
        clock = clock.addingTimeInterval(6)
        svc.evaluateOnce()
        XCTAssertTrue(svc.isComplete, "after timeout, force-advances past the never-satisfied entry")
    }

    @MainActor
    func testCadenceReplayDwellPacesAlreadySatisfied() {
        // Replay scenario: all conditions already satisfied. With a 0.6s default dwell the
        // entries must advance ONE PER DWELL (a smooth replay), not collapse instantly.
        var clock = Date(timeIntervalSince1970: 1000)
        let svc = CadenceMonitorService(now: { clock })
        func ipc(_ id: String) -> InspectConfig.CadenceEntry {
            InspectConfig.CadenceEntry(
                id: id, message: id,
                attribute: InspectConfig.CadenceAttribute(source: "ipc", type: nil, bundleId: nil, path: nil,
                                                          key: nil, expectedValue: nil, evaluation: nil, useUserDefaults: nil, domain: nil, scope: nil),
                minDwell: nil, timeout: nil, sfSymbol: nil, imagePath: nil, iconColor: nil)
        }
        svc.startWithEntries(entries: [ipc("a"), ipc("b"), ipc("c")],
                             stepId: "s", interval: 60, defaultMinDwell: 0.6, onCompletion: nil)
        // Pre-satisfy everything (as if returning to an already-complete step).
        svc.satisfyExternally(id: "a"); svc.satisfyExternally(id: "b"); svc.satisfyExternally(id: "c")
        XCTAssertEqual(svc.currentIndex, 0, "dwell holds entry 0 even though all conditions are met")
        clock = clock.addingTimeInterval(0.7); svc.evaluateOnce()
        XCTAssertEqual(svc.currentIndex, 1, "advances exactly one step per dwell")
        clock = clock.addingTimeInterval(0.7); svc.evaluateOnce()
        XCTAssertEqual(svc.currentIndex, 2, "still one per dwell — not collapsed")
        clock = clock.addingTimeInterval(0.7); svc.evaluateOnce()
        XCTAssertTrue(svc.isComplete, "reaches completion after pacing through all entries")
    }

    @MainActor
    func testCadenceManagedPrefAttribute() throws {
        // A mobileconfig managed preference landing (any MDM: Fleet, Jamf, Intune, …) satisfies a
        // managedpref entry. Point the base at a temp dir standing in for /Library/Managed Preferences.
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
        // A tenant profile supplies the claims array (structured CadenceEntry dicts) via cadenceRef.
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
        // Brand colour read per-tenant from a managed pref (e.g. nl.root3.support CustomColor),
        // with a dark-mode variant.
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
