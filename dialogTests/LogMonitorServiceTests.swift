//
//  LogMonitorServiceTests.swift
//  dialogTests
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 2026-01-21
//
//  Unit tests for LogMonitorService and related components
//

import XCTest
@testable import dialog

final class LogMonitorServiceTests: XCTestCase {

    var tempDirectory: URL!
    var testLogPath: String!

    override func setUp() {
        super.setUp()
        // Create temp directory for test log files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        testLogPath = tempDirectory.appendingPathComponent("test.log").path
    }

    override func tearDown() {
        // Clean up temp files
        try? FileManager.default.removeItem(at: tempDirectory)
        LogMonitorService.shared.stop()
        super.tearDown()
    }

    // MARK: - LogPatternPreset Tests (Installomator)
    // Installomator log format: [YYYY-MM-DD HH:MM:SS] LEVEL: message
    
    func regexForPreset(forPreset preset: LogPatternPreset, options: NSRegularExpression.MatchingOptions = []) -> String {
        guard let regex = try? NSRegularExpression(pattern: preset.pattern, options: options) else {
            fputs("Invalid regex pattern: \(preset.pattern)", stderr)
            return
        }
    }

    func testInstallomatorPresetMatchesDownloading() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines)

        let testLine = "[2023-10-05 14:32:45] INFO: Downloading https://dl.google.com/chrome/mac/stable/CHFA/googlechrome.dmg"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Installomator preset should match downloading line")

        if let match = match {
            let captureRange = Range(match.range(at: preset.captureGroup), in: testLine)!
            let captured = String(testLine[captureRange])
            XCTAssertTrue(captured.hasPrefix("Downloading"))
            XCTAssertTrue(captured.contains("googlechrome.dmg"))
        }
    }

    func testInstallomatorPresetMatchesMounting() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines)

        let testLine = "[2023-10-05 14:33:12] INFO: Mounting /var/folders/abc/googlechrome.dmg"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
        if let match = match {
            let captureRange = Range(match.range(at: preset.captureGroup), in: testLine)!
            XCTAssertTrue(String(testLine[captureRange]).hasPrefix("Mounting"))
        }
    }

    func testInstallomatorPresetMatchesAppIdentification() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines)

        let testLine = "[2023-10-05 14:32:21] INFO: ################## App: googlechrome"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
        if let match = match {
            let captureRange = Range(match.range(at: preset.captureGroup), in: testLine)!
            XCTAssertTrue(String(testLine[captureRange]).contains("googlechrome"))
        }
    }

    func testInstallomatorPresetMatchesInstalledVersion() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines)

        let testLine = "[2023-10-05 14:33:15] INFO: Installed version: 117.0.5938.132"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
        if let match = match {
            let captureRange = Range(match.range(at: preset.captureGroup), in: testLine)!
            XCTAssertEqual(String(testLine[captureRange]), "Installed version: 117.0.5938.132")
        }
    }

    func testInstallomatorPresetMatchesCopying() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines)

        let testLine = "[2023-10-05 14:34:00] INFO: Copying Google Chrome.app to /Applications"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
        if let match = match {
            let captureRange = Range(match.range(at: preset.captureGroup), in: testLine)!
            XCTAssertTrue(String(testLine[captureRange]).contains("Google Chrome.app"))
        }
    }

    func testInstallomatorPresetMatchesVerifying() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines)

        let testLine = "[2023-10-05 14:34:05] INFO: Verifying signature"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
    }

    func testInstallomatorPresetDoesNotMatchStartEnd() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines)

        // Should NOT match the start/end banners (no useful status info)
        let startLine = "[2023-10-05 14:32:21] INFO: ################## Start Installomator v.10.6beta"
        let endLine = "[2023-10-05 14:33:16] INFO: ################## End Installomator, exit code 0"

        XCTAssertNil(regex.firstMatch(in: startLine, range: NSRange(startLine.startIndex..., in: startLine)))
        XCTAssertNil(regex.firstMatch(in: endLine, range: NSRange(endLine.startIndex..., in: endLine)))
    }

    func testShellPresetMatchesStatusFormat() {
        let preset = LogPatternPreset.presets["shell"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines)

        let testLine = "[STATUS] Installing dependencies"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
        if let match = match {
            let captureRange = Range(match.range(at: preset.captureGroup), in: testLine)!
            XCTAssertEqual(String(testLine[captureRange]), "Installing dependencies")
        }
    }

    func testJamfPresetMatchesInfoLines() {
        let preset = LogPatternPreset.presets["jamf"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines)

        let testLine = "[2024-01-20 10:30:45] INFO - Running policy: Install Firefox"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
    }

    func testJamfPresetMatchesDebugLines() {
        let preset = LogPatternPreset.presets["jamf"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines)

        let testLine = "[2024-01-20 10:30:45] DEBUG - Checking policy scope"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
    }

    func testMunkiPresetMatchesInfoLines() {
        let preset = LogPatternPreset.presets["munki"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines)

        let testLine = "INFO: Installing Firefox-123.0.pkg"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
        if let match = match {
            let captureRange = Range(match.range(at: preset.captureGroup), in: testLine)!
            XCTAssertEqual(String(testLine[captureRange]), "Installing Firefox-123.0.pkg")
        }
    }

    // MARK: - Custom Pattern Tests

    func testCustomPatternExtraction() {
        let pattern = #"^>>> (.+)$"#
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines)
        
        let testLine = ">>> Custom status message"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
        if let match = match {
            let captureRange = Range(match.range(at: 1), in: testLine)!
            XCTAssertEqual(String(testLine[captureRange]), "Custom status message")
        }
    }

    func testCustomPatternWithMultipleCaptureGroups() {
        let pattern = #"^\[(\w+)\]\s+(.+)$"#
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines)

        let testLine = "[INFO] Application started successfully"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
        if let match = match {
            // First capture group (level)
            let levelRange = Range(match.range(at: 1), in: testLine)!
            XCTAssertEqual(String(testLine[levelRange]), "INFO")

            // Second capture group (message)
            let messageRange = Range(match.range(at: 2), in: testLine)!
            XCTAssertEqual(String(testLine[messageRange]), "Application started successfully")
        }
    }

    // MARK: - Pattern Edge Cases

    func testInstallomatorPresetDoesNotMatchUnrelatedLines() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines))

        let testLines = [
            "2024-01-20 10:30:45: Starting script",
            "DEBUG: Checking permissions",
            "Completed successfully",
            "Some random log line"
        ]

        for testLine in testLines {
            let range = NSRange(testLine.startIndex..., in: testLine)
            let match = regex.firstMatch(in: testLine, range: range)
            XCTAssertNil(match, "Should not match: \(testLine)")
        }
    }

    func testShellPresetDoesNotMatchMalformedLines() {
        let preset = LogPatternPreset.presets["shell"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines))

        let testLines = [
            "STATUS Installing dependencies",  // Missing brackets
            "[STATUS]Installing",               // Missing space
            "[ STATUS ] message",               // Extra spaces in tag
            "status message"                    // No tag at all
        ]

        for testLine in testLines {
            let range = NSRange(testLine.startIndex..., in: testLine)
            let match = regex.firstMatch(in: testLine, range: range)
            XCTAssertNil(match, "Should not match malformed: \(testLine)")
        }
    }

    // MARK: - File Monitoring Tests

    func testFileMonitorStartsFromEnd() async throws {
        // Create log file with existing content
        let existingContent = "Old log line 1\nOld log line 2\n"
        try existingContent.write(toFile: testLogPath, atomically: true, encoding: .utf8)

        let expectation = XCTestExpectation(description: "Status extracted")
        expectation.isInverted = true // We expect NO callback for old content

        let config = createMockLogMonitorConfig(
            path: testLogPath,
            preset: "shell",
            startFromEnd: true
        )

        // Monitor should start from end, not trigger for existing content
        let monitor = LogFileMonitor(config: config, path: testLogPath)
        monitor.onStatusExtracted = { _, _ in
            expectation.fulfill()
        }
        monitor.start()

        // Wait briefly - should NOT receive callback
        await fulfillment(of: [expectation], timeout: 0.5)

        monitor.stop()
    }

    func testFileMonitorDetectsNewContent() async throws {
        // Create empty log file
        try "".write(toFile: testLogPath, atomically: true, encoding: .utf8)

        let expectation = XCTestExpectation(description: "Status extracted")
        var extractedStatus: String?

        let config = createMockLogMonitorConfig(
            path: testLogPath,
            preset: "shell",
            startFromEnd: true
        )

        let monitor = LogFileMonitor(config: config, path: testLogPath)
        monitor.onStatusExtracted = { status, _ in
            extractedStatus = status
            expectation.fulfill()
        }
        monitor.start()

        // Give monitor time to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Append new content
        try "[STATUS] New status message\n".appendToFile(at: testLogPath)

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertEqual(extractedStatus, "New status message")
        monitor.stop()
    }

    func testFileMonitorReadsFromBeginning() async throws {
        // Create log file with existing content
        let existingContent = "[STATUS] Existing message\n"
        try existingContent.write(toFile: testLogPath, atomically: true, encoding: .utf8)

        let expectation = XCTestExpectation(description: "Status extracted")
        var extractedStatus: String?

        let config = createMockLogMonitorConfig(
            path: testLogPath,
            preset: "shell",
            startFromEnd: false  // Read from beginning
        )

        let monitor = LogFileMonitor(config: config, path: testLogPath)
        monitor.onStatusExtracted = { status, _ in
            extractedStatus = status
            expectation.fulfill()
        }
        monitor.start()

        // The monitor should process existing content immediately
        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(extractedStatus, "Existing message")
        monitor.stop()
    }

    // MARK: - Helper Methods

    private func createMockLogMonitorConfig(
        path: String = "/tmp/test.log",
        preset: String? = nil,
        pattern: String? = nil,
        captureGroup: Int? = nil,
        itemId: String? = nil,
        itemMapping: [String: String]? = nil,
        autoMatch: Bool? = nil,
        startFromEnd: Bool? = nil,
        format: String? = nil,
        statusKey: String? = nil,
        itemKey: String? = nil
    ) -> InspectConfig.LogMonitorConfig {
        // Create a JSON representation and decode it
        var json: [String: Any] = ["path": path]
        if let preset = preset { json["preset"] = preset }
        if let pattern = pattern { json["pattern"] = pattern }
        if let captureGroup = captureGroup { json["captureGroup"] = captureGroup }
        if let itemId = itemId { json["itemId"] = itemId }
        if let itemMapping = itemMapping { json["itemMapping"] = itemMapping }
        if let autoMatch = autoMatch { json["autoMatch"] = autoMatch }
        if let startFromEnd = startFromEnd { json["startFromEnd"] = startFromEnd }
        if let format = format { json["format"] = format }
        if let statusKey = statusKey { json["statusKey"] = statusKey }
        if let itemKey = itemKey { json["itemKey"] = itemKey }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: json),
              let config = try? JSONDecoder().decode(InspectConfig.LogMonitorConfig.self, from: jsonData) else {
            fputs("Failed to parse log monitor config\n", stderr)
            return nil
        }
        return config
    }

    // MARK: - macOS Installer Preset Tests

    func testMacOSInstallerPresetMatchesExtractingPKG() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines))

        let testLine = "2026-01-21 02:37:33+01 dev-mini installd[74805]: PackageKit: Extracting file://localhost/Users/henry/Downloads/Microsoft_365.pkg#Microsoft_Word_Internal.pkg (destination=/Applications)"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match PKG extraction line")
    }

    func testMacOSInstallerPresetMatchesTouchedBundle() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines))

        let testLine = "2026-01-21 02:00:08+01 dev-mini installd[1068]: PackageKit: Touched bundle /Applications/Microsoft Word.app"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match touched bundle line")
    }

    func testMacOSInstallerPresetMatchesInstalled() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines))

        let testLine = "2026-01-21 02:37:35+01 dev-mini installd[74805]: Installed \"Stream Deck\" ()"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match Installed line")
    }

    // MARK: - Status Transform Tests

    func testMacOSInstallerTransformPKGToInstalling() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let transform = preset.statusTransform!

        let raw = "Microsoft_365_and_Office_16.105.26011018_Installer.pkg#Microsoft_Word_Internal.pkg"
        let result = transform(raw)

        XCTAssertEqual(result, "Installing Microsoft Word...")
    }

    func testMacOSInstallerTransformAppToCompleted() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let transform = preset.statusTransform!

        let raw = "Microsoft Word.app"
        let result = transform(raw)

        XCTAssertEqual(result, "Completed")
    }

    func testMacOSInstallerTransformSimplePKG() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let transform = preset.statusTransform!

        let raw = "StreamDeck.pkg"
        let result = transform(raw)

        XCTAssertEqual(result, "Installing StreamDeck...")
    }

    // MARK: - macOS Installer Failure Tests

    func testMacOSInstallerPresetMatchesInstallFailed() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines))

        let testLine = "2026-01-21 02:37:35+01 dev-mini installd[74805]: Install failed: Package requires restart"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match Install failed line")
    }

    func testMacOSInstallerPresetMatchesPackageKitInstallFailed() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines))

        let testLine = "2026-01-21 02:37:35+01 dev-mini installd[74805]: PackageKit: Install Failed: Error Domain=PKInstallErrorDomain Code=102"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match PackageKit Install Failed line")
    }

    func testMacOSInstallerPresetMatchesInstallerError() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let regex = regexForPreset(preset: preset, options: .anchorsMatchLines))

        let testLine = "2026-01-21 02:37:35+01 dev-mini installer[74805]: installer: Error: Unable to verify package signature"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match installer Error line")
    }

    func testMacOSInstallerTransformFailedWithMessage() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let transform = preset.statusTransform!

        let raw = "Package requires restart"
        let result = transform(raw)

        // Since this doesn't contain "fail" or "error", it should return raw
        // But if we pass an actual error message containing those words:
        let errorRaw = "Error Domain=PKInstallErrorDomain Code=102"
        let errorResult = transform(errorRaw)

        XCTAssertTrue(errorResult.hasPrefix("Failed:"), "Should transform error message to Failed status")
    }

    func testMacOSInstallerTransformFailedEmpty() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let transform = preset.statusTransform!

        // Test with just "failed" indicator
        let raw = "Install failed"
        let result = transform(raw)

        XCTAssertTrue(result.hasPrefix("Failed"), "Should show Failed status")
    }

    func testMacOSInstallerTransformFailedTruncatesLongMessage() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let transform = preset.statusTransform!

        let longError = "Error: This is a very long error message that should be truncated because it exceeds fifty characters"
        let result = transform(longError)

        XCTAssertTrue(result.hasPrefix("Failed:"), "Should show Failed prefix")
        XCTAssertTrue(result.hasSuffix("..."), "Should truncate with ellipsis")
        XCTAssertLessThan(result.count, longError.count, "Result should be shorter than original")
    }

    // MARK: - JSON Format Tests

    func testJSONFormatExtractsStatus() async throws {
        let jsonPath = tempDirectory.appendingPathComponent("status.json").path

        // Write initial JSON
        let json: [String: Any] = ["status": "Downloading", "app": "Firefox"]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: URL(fileURLWithPath: jsonPath))

        let expectation = XCTestExpectation(description: "Status extracted")
        var extractedStatus: String?
        var extractedItemId: String?

        let config = createMockLogMonitorConfig(
            path: jsonPath,
            format: "json",
            statusKey: "status",
            itemKey: "app"
        )

        let monitor = LogFileMonitor(config: config, path: jsonPath)
        monitor.onStatusExtracted = { status, itemId in
            extractedStatus = status
            extractedItemId = itemId
            expectation.fulfill()
        }
        monitor.start()

        // Update JSON to trigger change
        try await Task.sleep(nanoseconds: 100_000_000)
        let newJson: [String: Any] = ["status": "Installing", "app": "Firefox"]
        let newData = try JSONSerialization.data(withJSONObject: newJson)
        try newData.write(to: URL(fileURLWithPath: jsonPath))

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertEqual(extractedStatus, "Installing")
        XCTAssertEqual(extractedItemId, "Firefox")
        monitor.stop()
    }

    func testJSONFormatWithoutItemKey() async throws {
        let jsonPath = tempDirectory.appendingPathComponent("status2.json").path

        let json: [String: Any] = ["message": "Processing..."]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: URL(fileURLWithPath: jsonPath))

        let expectation = XCTestExpectation(description: "Status extracted")
        var extractedStatus: String?
        var extractedItemId: String?

        let config = createMockLogMonitorConfig(
            path: jsonPath,
            format: "json",
            statusKey: "message"
        )

        let monitor = LogFileMonitor(config: config, path: jsonPath)
        monitor.onStatusExtracted = { status, itemId in
            extractedStatus = status
            extractedItemId = itemId
            expectation.fulfill()
        }
        monitor.start()

        // Trigger re-read by modifying file
        try await Task.sleep(nanoseconds: 100_000_000)
        try data.write(to: URL(fileURLWithPath: jsonPath))

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertEqual(extractedStatus, "Processing...")
        XCTAssertNil(extractedItemId)
        monitor.stop()
    }

    func testJSONFormatWithDefaultStatusKey() async throws {
        let jsonPath = tempDirectory.appendingPathComponent("status3.json").path

        // Use default "status" key
        let json: [String: Any] = ["status": "Complete"]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: URL(fileURLWithPath: jsonPath))

        let expectation = XCTestExpectation(description: "Status extracted")
        var extractedStatus: String?

        let config = createMockLogMonitorConfig(
            path: jsonPath,
            format: "json"
            // No statusKey specified - should use default "status"
        )

        let monitor = LogFileMonitor(config: config, path: jsonPath)
        monitor.onStatusExtracted = { status, _ in
            extractedStatus = status
            expectation.fulfill()
        }
        monitor.start()

        // Trigger re-read
        try await Task.sleep(nanoseconds: 100_000_000)
        try data.write(to: URL(fileURLWithPath: jsonPath))

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertEqual(extractedStatus, "Complete")
        monitor.stop()
    }
}

// MARK: - String Extension for Tests

private extension String {
    func appendToFile(at path: String) throws {
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
        handle.seekToEndOfFile()
        if let data = self.data(using: .utf8) {
            handle.write(data)
        }
        try handle.close()
    }
}
