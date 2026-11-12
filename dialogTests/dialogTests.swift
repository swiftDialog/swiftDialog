//
//  dialogTests.swift
//  dialogTests
//
//  Created by Bart Reardon on 9/3/21.
//

import AppKit
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
        XCTAssertEqual(json["ackChannel"] as? String, "com.swiftdialog.ack.\(pid)")
        XCTAssertEqual(json["commandChannel"] as? String, "com.swiftdialog.command.\(pid)")

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

    /// `loadPlistSource` end to end: a real plist with nested-dict values merged with the config.
    func testPlistAggregatorMergesPlistAndConfig() throws {
        let plistPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("compliance-\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(atPath: plistPath) }

        // macos_version: nested dict overrides explanation; config provides remediation
        // airdrop:       scalar bool; only config defaults are available
        // `expectedValue: "true"` selects swiftDialog's convention (`finding: false` fails); the default
        // is the mSCP/CIS one, where `finding: true` means a finding was raised.
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

        let configJSON = Data("""
        {
          "path": "\(plistPath)",
          "type": "compliance",
          "displayName": "Compliance",
          "expectedValue": "true",
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
        """.utf8)
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

        let configJSON = Data("""
        { "path": "\(plistPath)", "type": "compliance", "displayName": "Test" }
        """.utf8)
        let source = try JSONDecoder().decode(InspectConfig.PlistSourceConfig.self, from: configJSON)

        let items = try XCTUnwrap(PlistAggregator.loadPlistSource(source: source)?.items)
        XCTAssertEqual(items.first(where: { $0.id == "passing" })?.severity, .healthy)
        XCTAssertEqual(items.first(where: { $0.id == "failing" })?.severity, .failure)
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

    /// InspectState's `checkCommandFileForUpdates` polls the global `/var/tmp/dialog.log`, so at launch
    /// `CommandFileReplayGuard` adopts existing lines rather than replaying another session's commands.
    func testCommandFileFirstLookAdoptsExistingLinesWithoutReplaying() {
        let existing = ["item:slack:completed", "item:zoom:completed"]

        // First look: pre-existing content is adopted, never processed.
        XCTAssertEqual(
            CommandFileReplayGuard.linesToProcess(allLines: existing,
                                                  lastProcessedLineCount: 0, seeded: false),
            [],
            "stale content must not replay on the first look")

        // Once seeded at the adopted count, only appended lines are processed.
        let appended = existing + ["item:chrome:completed"]
        XCTAssertEqual(
            CommandFileReplayGuard.linesToProcess(allLines: appended,
                                                  lastProcessedLineCount: existing.count, seeded: true),
            ["item:chrome:completed"])
    }

    /// An empty command file at launch still seeds, so later content is processed in full.
    func testCommandFileEmptyAtLaunchStillProcessesLaterContent() {
        XCTAssertEqual(
            CommandFileReplayGuard.linesToProcess(allLines: [],
                                                  lastProcessedLineCount: 0, seeded: false),
            [])
        XCTAssertEqual(
            CommandFileReplayGuard.linesToProcess(allLines: ["success:step1"],
                                                  lastProcessedLineCount: 0, seeded: true),
            ["success:step1"])
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

    // "icon.png" → "icon-dark.png" in dark mode, only when the sibling exists; light mode never redirects.
    func testDarkVariantImagePathConvention() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("darkvar-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let base = dir.appendingPathComponent("icon.png").path
        let dark = dir.appendingPathComponent("icon-dark.png").path
        FileManager.default.createFile(atPath: base, contents: Data([0x1]))

        XCTAssertEqual(darkVariantImagePath(base, dark: true), base,
                       "no -dark sibling → original path")
        FileManager.default.createFile(atPath: dark, contents: Data([0x1]))
        XCTAssertEqual(darkVariantImagePath(base, dark: true), dark,
                       "-dark sibling exists → variant path")
        XCTAssertEqual(darkVariantImagePath(base, dark: false), base,
                       "light mode never redirects")
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

    // MARK: - Guided setup schema (option-picker + dock)

    func testOptionPickerStepSchemaDecodes() throws {
        let json = """
        { "id": "browser", "stepType": "options", "optionKey": "defaultBrowser",
          "optionCards": [
            { "id": "safari", "label": "Safari", "sfSymbol": "safari", "value": "com.apple.Safari" },
            { "id": "chrome", "label": "Chrome", "iconPath": "/Applications/Google Chrome.app" }
          ] }
        """
        let step = try JSONDecoder().decode(InspectConfig.IntroStep.self, from: Data(json.utf8))
        XCTAssertEqual(step.stepType, "options")
        XCTAssertEqual(step.optionKey, "defaultBrowser")
        XCTAssertEqual(step.optionCards?.count, 2)
        XCTAssertEqual(step.optionCards?.first?.id, "safari")           // id → cardId mapping
        XCTAssertEqual(step.optionCards?.first?.value, "com.apple.Safari")
    }

    func testDockStepSchemaDecodes() throws {
        let json = """
        { "id": "dock", "stepType": "dock", "dockMode": "flavors", "dockSelectionKey": "dock",
          "dockFlavors": [
            { "id": "essentials", "name": "Essentials", "sfSymbol": "star",
              "items": [ { "label": "Mail", "path": "/System/Applications/Mail.app" },
                         { "label": "Safari", "path": "/Applications/Safari.app", "sfSymbol": "safari" } ] }
          ] }
        """
        let step = try JSONDecoder().decode(InspectConfig.IntroStep.self, from: Data(json.utf8))
        XCTAssertEqual(step.stepType, "dock")
        XCTAssertEqual(step.dockMode, "flavors")
        XCTAssertEqual(step.dockFlavors?.count, 1)
        XCTAssertEqual(step.dockFlavors?.first?.id, "essentials")       // id → flavorId mapping
        XCTAssertEqual(step.dockFlavors?.first?.items.count, 2)
        XCTAssertEqual(step.dockFlavors?.first?.items.last?.sfSymbol, "safari")
    }

    /// The composed guided-setup config (mixed intro/dock/options/outro steps) decodes, including
    /// `optionCards`, which avoids IntroStep's existing `options: [String]?`.
    func testGuidedSetupConfigDecodes() throws {
        let json = """
        {
          "preset": "7",
          "size": "setup",
          "highlightColor": "#007AFF",
          "summaryScreen": { "title": "Done", "buttonText": "Close", "autoTransition": false },
          "introSteps": [
            { "id": "welcome", "stepType": "intro", "title": "Welcome" },
            { "id": "dock", "stepType": "dock", "dockMode": "flavors", "dockSelectionKey": "dock",
              "dockFlavors": [
                { "id": "essentials", "name": "Essentials", "sfSymbol": "star",
                  "items": [ { "label": "Safari", "path": "/Applications/Safari.app", "sfSymbol": "safari" } ] }
              ] },
            { "id": "browser", "stepType": "options", "optionKey": "browser",
              "optionCards": [
                { "id": "safari", "label": "Safari", "iconPath": "/Applications/Safari.app", "value": "com.apple.safari" }
              ] },
            { "id": "appearance", "stepType": "options", "optionKey": "appearance",
              "optionCards": [
                { "id": "dark", "label": "Dark", "sfSymbol": "moon.fill", "value": "dark" }
              ] },
            { "id": "finish", "stepType": "outro", "title": "Setup complete" }
          ]
        }
        """
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.preset, "7")
        XCTAssertEqual(config.introSteps?.count, 5)
        let steps = try XCTUnwrap(config.introSteps)
        XCTAssertEqual(steps[1].stepType, "dock")
        XCTAssertEqual(steps[1].dockFlavors?.first?.items.first?.path, "/Applications/Safari.app")
        XCTAssertEqual(steps[2].optionKey, "browser")
        XCTAssertEqual(steps[2].optionCards?.first?.value, "com.apple.safari")
        XCTAssertEqual(steps[3].optionCards?.first?.id, "dark")
        XCTAssertEqual(config.summaryScreen?.autoTransition, false)
    }

    func testCadenceSchemaDecodes() throws {
        let step = try decodeCadenceStep("""
        { "id": "deploy", "stepType": "cadence", "cadenceInterval": 2.0, "cadence": [
            { "id": "a", "message": "Task 1", "attribute": { "source": "native", "type": "app", "bundleId": "com.apple.finder" } },
            { "id": "b", "message": "Task 2", "attribute": { "type": "plist", "path": "/tmp/x.plist", "key": "Installed", "evaluation": "boolean", "expectedValue": "true" } }
        ] }
        """)
        XCTAssertEqual(step.cadenceEntries?.count, 2)
        XCTAssertEqual(step.cadenceInterval, 2.0)
        XCTAssertEqual(step.cadenceEntries?[0].id, "a")
        XCTAssertEqual(step.cadenceEntries?[1].attribute.evaluation, "boolean")
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
        // defaultMinDwell 0 isolates IPC advance from the replay dwell.
        svc.startWithEntries(entries: step.cadenceEntries ?? [], stepId: "deploy", interval: 60, defaultMinDwell: 0, onCompletion: nil)
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
        // Decode the step, then drive it with evaluateOnce; files gate each step.
        svc.startWithEntries(
            entries: [
                InspectConfig.CadenceEntry(id: "a", message: "A", attribute: fileAttr(p0), minDwell: nil, timeout: nil, sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil, subtitle: nil, timeEstimate: nil, size: nil),
                InspectConfig.CadenceEntry(id: "b", message: "B", attribute: fileAttr(p1), minDwell: nil, timeout: nil, sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil, subtitle: nil, timeEstimate: nil, size: nil)
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
            entries: [InspectConfig.CadenceEntry(id: "a", message: "A", attribute: attr, minDwell: 10, timeout: nil, sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil, subtitle: nil, timeEstimate: nil, size: nil)],
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
            entries: [InspectConfig.CadenceEntry(id: "a", message: "A", attribute: attr, minDwell: nil, timeout: 5, sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil, subtitle: nil, timeEstimate: nil, size: nil)],
            stepId: "s", interval: 60, onCompletion: nil)
        XCTAssertFalse(svc.isComplete, "before timeout, unsatisfied entry holds")
        clock = clock.addingTimeInterval(6)
        svc.evaluateOnce()
        XCTAssertTrue(svc.isComplete, "after timeout, force-advances past the never-satisfied entry")
    }

    @MainActor
    func testCadenceReplayDwellPacesAlreadySatisfied() {
        // All conditions already satisfied: with a 0.6s dwell, entries advance one per dwell.
        var clock = Date(timeIntervalSince1970: 1000)
        let svc = CadenceMonitorService(now: { clock })
        func ipc(_ id: String) -> InspectConfig.CadenceEntry {
            InspectConfig.CadenceEntry(
                id: id, message: id,
                attribute: InspectConfig.CadenceAttribute(source: "ipc", type: nil, bundleId: nil, path: nil,
                                                          key: nil, expectedValue: nil, evaluation: nil, useUserDefaults: nil, domain: nil, scope: nil),
                minDwell: nil, timeout: nil, sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil, subtitle: nil, timeEstimate: nil, size: nil)
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

    // MARK: - Measured cadence tokens

    private func decodeBlock(_ json: String) throws -> InspectConfig.GuidanceContent {
        try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(json.utf8))
    }

    @MainActor
    func testCadenceTokensResolveCountAndTimeouts() throws {
        var clock = Date(timeIntervalSince1970: 1000)
        let svc = CadenceMonitorService(now: { clock })
        let missing = InspectConfig.CadenceAttribute(source: nil, type: "file", bundleId: nil,
                                                     path: "/tmp/missing-\(UUID().uuidString)", key: nil,
                                                     expectedValue: nil, evaluation: nil, useUserDefaults: nil, domain: nil, scope: nil)
        func entry(_ id: String) -> InspectConfig.CadenceEntry {
            InspectConfig.CadenceEntry(id: id, message: id, attribute: missing, minDwell: nil, timeout: 5,
                                       sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil,
                                       subtitle: nil, timeEstimate: nil, size: nil)
        }
        svc.startWithEntries(entries: [entry("a"), entry("b")], stepId: "s", interval: 60, onCompletion: nil)
        clock = clock.addingTimeInterval(6)
        svc.evaluateOnce()
        clock = clock.addingTimeInterval(6)
        svc.evaluateOnce()

        let block = try decodeBlock("""
        { "type": "text", "content": "{cadenceCount} tasks, {cadenceTimeouts} timed out" }
        """)
        let resolved = CadenceTokens.resolve(block, monitor: svc, languageCode: nil)
        XCTAssertEqual(resolved.content, "2 tasks, 2 timed out",
                       "count and timeout tokens resolve from the measured run")
    }

    @MainActor
    func testCadenceTokensResolveInStatsAndChecklist() throws {
        let svc = CadenceMonitorService()
        let ipc = InspectConfig.CadenceAttribute(source: "ipc", type: nil, bundleId: nil, path: nil, key: nil,
                                                 expectedValue: nil, evaluation: nil, useUserDefaults: nil, domain: nil, scope: nil)
        svc.startWithEntries(
            entries: [InspectConfig.CadenceEntry(id: "a", message: "A", attribute: ipc, minDwell: nil, timeout: nil,
                                                 sfSymbol: nil, imagePath: nil, iconColor: nil, label: nil,
                                                 subtitle: nil, timeEstimate: nil, size: nil)],
            stepId: "s", interval: 60, onCompletion: nil)

        let block = try decodeBlock("""
        {
          "type": "stat-row",
          "stats": [{ "value": "{cadenceCount}", "label": "of {cadenceCount} steps" }],
          "checklist": [{ "text": "{cadenceCount} completed" }]
        }
        """)
        let resolved = CadenceTokens.resolve(block, monitor: svc, languageCode: nil)
        XCTAssertEqual(resolved.stats?.first?.value, "1", "stat VALUE resolves")
        XCTAssertEqual(resolved.stats?.first?.label, "of 1 steps", "stat LABEL resolves too")
        XCTAssertEqual(resolved.checklist?.first?.text, "1 completed", "checklist lines resolve")
    }

    @MainActor
    func testCadenceDurationIsDashUntilMeasured() throws {
        let svc = CadenceMonitorService()
        XCTAssertNil(CadenceTokens.duration(svc, languageCode: nil),
                     "no run measured → nil, so callers can drop the segment")
        let block = try decodeBlock("""
        { "type": "text", "content": "took {cadenceDuration}" }
        """)
        XCTAssertEqual(CadenceTokens.resolve(block, monitor: svc, languageCode: nil).content, "took –",
                       "unmeasured duration renders an em-dash, NEVER an estimate")
    }

    func testCadenceTokensMentionedGatesTheMap() throws {
        let plain = try decodeBlock("""
        { "type": "text", "content": "no tokens here" }
        """)
        XCTAssertFalse(CadenceTokens.mentioned(in: plain), "plain block short-circuits the resolver")
        let checklistOnly = try decodeBlock("""
        { "type": "checklist", "checklist": [{ "text": "{cadenceTimeouts} skipped" }] }
        """)
        XCTAssertTrue(CadenceTokens.mentioned(in: checklistOnly),
                      "a token buried in a checklist line still counts — the gate must not miss it")
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

    /// swiftDialog#699: a `sideMessage` written as one string refused to launch. It is read as a
    /// one-item list; a list is untouched.
    func testASingleStringSideMessageIsReadAsAOneItemList() {
        let one = validateInspectSchema(data(
            #"{"preset":"1","message":"m","sideMessage":"Only one","items":[{"id":"a","displayName":"A","guiIndex":0}]}"#))
        guard case .valid(let config) = one else { return XCTFail("expected .valid, got \(one)") }
        XCTAssertEqual(config.sideMessage, ["Only one"])

        let list = validateInspectSchema(data(
            #"{"preset":"1","sideMessage":["x","y"],"items":[{"id":"a","displayName":"A","guiIndex":0}]}"#))
        guard case .valid(let listed) = list else { return XCTFail("expected .valid, got \(list)") }
        XCTAssertEqual(listed.sideMessage, ["x", "y"])
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

    // MARK: - Option card availability

    /// An option card states its real availability per card.
    func testOptionCardStateDecodes() throws {
        let json = Data("""
        [{"id":"safari","label":"Safari","subtitle":"Already installed","state":"installed"},
         {"id":"chrome","label":"Chrome","subtitle":"Installs in step 6","state":"pending"},
         {"id":"edge","label":"Edge","subtitle":"Not in your catalogue","state":"unavailable"},
         {"id":"plain","label":"Plain"}]
        """.utf8)
        let cards = try JSONDecoder().decode([InspectConfig.OptionCard].self, from: json)
        XCTAssertEqual(cards.map(\.state), ["installed", "pending", "unavailable", nil])
    }

    /// Only `unavailable` blocks selection; `installed` and `pending` are informational.
    func testOnlyUnavailableBlocksSelection() throws {
        let json = Data("""
        [{"id":"a","label":"A","state":"installed"},
         {"id":"b","label":"B","state":"pending"},
         {"id":"c","label":"C","state":"unavailable"},
         {"id":"d","label":"D"}]
        """.utf8)
        let cards = try JSONDecoder().decode([InspectConfig.OptionCard].self, from: json)
        XCTAssertEqual(cards.map(\.isSelectable), [true, true, false, true])
    }

    /// Omitting `state` changes nothing.
    func testOptionCardWithoutStateIsUnchanged() throws {
        let json = Data(#"[{"id":"x","label":"X","subtitle":"desc","sfSymbol":"globe"}]"#.utf8)
        let card = try JSONDecoder().decode([InspectConfig.OptionCard].self, from: json)[0]
        XCTAssertNil(card.state)
        XCTAssertTrue(card.isSelectable)
        XCTAssertEqual(card.label, "X")
        XCTAssertEqual(card.subtitle, "desc")
    }

    /// Built-in tile artwork; `auto` shows the light/dark split no single image can.
    func testOptionCardPreviewDecodes() throws {
        let json = Data("""
        [{"id":"light","label":"Light","subtitle":"Always light","preview":"light"},
         {"id":"dark","label":"Dark","subtitle":"Always dark","preview":"dark"},
         {"id":"auto","label":"Auto","subtitle":"Dark from 18:04 to 07:12","preview":"auto"}]
        """.utf8)
        let cards = try JSONDecoder().decode([InspectConfig.OptionCard].self, from: json)
        XCTAssertEqual(cards.map(\.preview), ["light", "dark", "auto"])
        XCTAssertTrue(cards.allSatisfy { AppearanceSwatch.known.contains($0.preview ?? "") })
    }

    /// An unknown preview name falls through to the icon tile.
    func testUnknownPreviewFallsThrough() throws {
        let json = Data(#"[{"id":"x","label":"X","preview":"sepia","sfSymbol":"globe"}]"#.utf8)
        let card = try JSONDecoder().decode([InspectConfig.OptionCard].self, from: json)[0]
        XCTAssertEqual(card.preview, "sepia")
        XCTAssertFalse(AppearanceSwatch.known.contains(card.preview ?? ""))
        XCTAssertEqual(card.sfSymbol, "globe")   // the fallback is still there to use
    }
}
