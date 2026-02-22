//
//  LogMonitorServiceTests.swift
//  dialogTests
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 2026-01-21
//
//  Unit tests for LogMonitorService and related components
//

import XCTest
@testable import Dialog

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
    // Real Installomator log format: "2026-02-22 15:23:13 : INFO  : microsoftword : Downloading https://..."
    // Format: timestamp : LEVEL : label : message (from Installomator's printlog function)

    func testInstallomatorPresetMatchesDownloading() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "2026-02-22 15:23:13 : REQ   : googlechrome : Downloading https://dl.google.com/chrome/mac/stable/CHFA/googlechrome.dmg"
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

    func testInstallomatorPresetMatchesDownloadingPKG() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "2026-02-22 15:36:22 : REQ   : microsoftoutlook : Downloading https://go.microsoft.com/fwlink/?linkid=525137 to Microsoft Outlook.pkg"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match downloading .pkg line")
        if let match = match {
            let captureRange = Range(match.range(at: preset.captureGroup), in: testLine)!
            let captured = String(testLine[captureRange])
            XCTAssertTrue(captured.contains("Microsoft Outlook.pkg"))
        }
    }

    func testInstallomatorPresetMatchesMounting() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "2026-02-22 15:33:12 : INFO  : googlechrome : Mounting /var/folders/abc/googlechrome.dmg"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
        if let match = match {
            let captureRange = Range(match.range(at: preset.captureGroup), in: testLine)!
            XCTAssertTrue(String(testLine[captureRange]).hasPrefix("Mounting"))
        }
    }

    func testInstallomatorPresetMatchesMounted() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "2026-02-22 15:33:12 : INFO  : googlechrome : Mounted /Volumes/Google Chrome.app"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match 'Mounted' line")
    }

    func testInstallomatorPresetMatchesInstalledVersion() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "2026-02-22 15:33:15 : INFO  : googlechrome : Installed version: 117.0.5938.132"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
        if let match = match {
            let captureRange = Range(match.range(at: preset.captureGroup), in: testLine)!
            XCTAssertEqual(String(testLine[captureRange]), "Installed version: 117.0.5938.132")
        }
    }

    func testInstallomatorPresetMatchesCopy() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        // Installomator uses "Copy" not "Copying": printlog "Copy $appPath to $targetDir"
        let testLine = "2026-02-22 15:34:00 : INFO  : googlechrome : Copy Google Chrome.app to /Applications"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match 'Copy' (Installomator's verb)")
        if let match = match {
            let captureRange = Range(match.range(at: preset.captureGroup), in: testLine)!
            XCTAssertTrue(String(testLine[captureRange]).contains("Google Chrome.app"))
        }
    }

    func testInstallomatorPresetMatchesVerifying() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "2026-02-22 15:34:05 : INFO  : microsoftoutlook : Verifying: Microsoft Outlook.pkg"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
    }

    func testInstallomatorPresetMatchesInstallingPKG() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "2026-02-22 15:38:41 : INFO  : microsoftoutlook : Installing Microsoft Outlook.pkg to /"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match 'Installing .pkg' line")
    }

    func testInstallomatorPresetMatchesRunningMsupdate() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "2026-02-22 15:36:10 : INFO  : microsoftoutlook : Running msupdate --list"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match 'Running' line")
    }

    func testInstallomatorPresetDoesNotMatchStartEnd() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        // Should NOT match the start/end banners (no useful status info)
        let startLine = "2026-02-22 15:23:00 : REQ   : microsoftword : ################## Start Installomator v. 10.9beta, date 2026-01-29"
        let endLine = "2026-02-22 15:39:33 : REQ   : microsoftoutlook : ################## End Installomator, exit code 0"

        XCTAssertNil(regex.firstMatch(in: startLine, range: NSRange(startLine.startIndex..., in: startLine)))
        XCTAssertNil(regex.firstMatch(in: endLine, range: NSRange(endLine.startIndex..., in: endLine)))
    }

    func testInstallomatorPresetDoesNotMatchInfoLines() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        // Should NOT match these non-actionable info lines
        let testLines = [
            "2026-02-22 15:23:13 : INFO  : microsoftword : Label type: pkg",
            "2026-02-22 15:23:13 : INFO  : microsoftword : archiveName: Microsoft Word.pkg",
            "2026-02-22 15:23:13 : INFO  : microsoftword : name: Microsoft Word, appName: Microsoft Word.app",
            "2026-02-22 15:23:13 : WARN  : microsoftword : No previous app found",
            "2026-02-22 15:23:13 : INFO  : microsoftword : Latest version of Microsoft Word is 16.106",
            "2026-02-22 15:39:33 : REQ   : microsoftoutlook : All done!",
        ]

        for testLine in testLines {
            let range = NSRange(testLine.startIndex..., in: testLine)
            let match = regex.firstMatch(in: testLine, range: range)
            XCTAssertNil(match, "Should not match: \(testLine)")
        }
    }

    func testInstallomatorPresetMatchesAllLogLevels() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        // REQ (3 chars, 2 spaces padding)
        let reqLine = "2026-02-22 15:23:13 : REQ   : microsoftword : Downloading https://example.com/word.pkg"
        XCTAssertNotNil(regex.firstMatch(in: reqLine, range: NSRange(reqLine.startIndex..., in: reqLine)), "Should match REQ level")

        // INFO (4 chars, 1 space padding)
        let infoLine = "2026-02-22 15:23:13 : INFO  : microsoftword : Mounting /var/folders/abc/word.dmg"
        XCTAssertNotNil(regex.firstMatch(in: infoLine, range: NSRange(infoLine.startIndex..., in: infoLine)), "Should match INFO level")

        // DEBUG (5 chars, no padding)
        let debugLine = "2026-02-22 15:23:13 : DEBUG : microsoftword : Extracting word.zip"
        XCTAssertNotNil(regex.firstMatch(in: debugLine, range: NSRange(debugLine.startIndex..., in: debugLine)), "Should match DEBUG level")

        // WARN (4 chars, 1 space padding)
        let warnLine = "2026-02-22 15:23:13 : WARN  : microsoftword : Removing /tmp/old.app"
        XCTAssertNotNil(regex.firstMatch(in: warnLine, range: NSRange(warnLine.startIndex..., in: warnLine)), "Should match WARN level")
    }

    func testShellPresetMatchesStatusFormat() {
        let preset = LogPatternPreset.presets["shell"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

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
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "[2024-01-20 10:30:45] INFO - Running policy: Install Firefox"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
    }

    func testJamfPresetMatchesDebugLines() {
        let preset = LogPatternPreset.presets["jamf"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "[2024-01-20 10:30:45] DEBUG - Checking policy scope"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
    }

    func testMunkiPresetMatchesInfoLines() {
        let preset = LogPatternPreset.presets["munki"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

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
        let regex = try! NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)

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
        let regex = try! NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)

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

    // MARK: - cleanupStatus Tests

    func testCleanupStatusDownloading() {
        XCTAssertEqual(LogPatternPreset.cleanupStatus("Downloading https://example.com/word.pkg"), "Downloading...")
    }

    func testCleanupStatusMounting() {
        XCTAssertEqual(LogPatternPreset.cleanupStatus("Mounting /var/folders/abc/word.dmg"), "Mounting...")
        XCTAssertEqual(LogPatternPreset.cleanupStatus("Mounted /Volumes/Word"), "Mounting...")
    }

    func testCleanupStatusCopy() {
        // Installomator uses "Copy" not "Copying"
        XCTAssertEqual(LogPatternPreset.cleanupStatus("Copy Microsoft Word.app to /Applications"), "Copying Microsoft Word.app...")
        XCTAssertEqual(LogPatternPreset.cleanupStatus("Copying Google Chrome.app to /Applications"), "Copying Google Chrome.app...")
    }

    func testCleanupStatusInstalled() {
        XCTAssertEqual(LogPatternPreset.cleanupStatus("Installed version: 16.106"), "Installed (v16.106)")
        XCTAssertEqual(LogPatternPreset.cleanupStatus("Downloaded version: 117.0"), "Installed (v117.0)")
    }

    func testCleanupStatusCompleted() {
        XCTAssertEqual(LogPatternPreset.cleanupStatus("installed successfully"), "Completed")
        XCTAssertEqual(LogPatternPreset.cleanupStatus("Installation completed"), "Completed")
        XCTAssertEqual(LogPatternPreset.cleanupStatus("Microsoft Word.app"), "Completed")
    }

    func testCleanupStatusVerifying() {
        XCTAssertEqual(LogPatternPreset.cleanupStatus("Verifying: Microsoft Outlook.pkg"), "Verifying Microsoft Outlook...")
    }

    func testCleanupStatusInstallingPKG() {
        XCTAssertEqual(LogPatternPreset.cleanupStatus("Installing Microsoft Outlook.pkg to /"), "Installing Microsoft Outlook...")
    }

    func testCleanupStatusRunning() {
        XCTAssertEqual(LogPatternPreset.cleanupStatus("Running msupdate --list"), "Running script...")
    }

    func testCleanupStatusFailure() {
        let result = LogPatternPreset.cleanupStatus("ERROR: not running as root, exiting")
        XCTAssertTrue(result.hasPrefix("Failed"), "Should detect failure: \(result)")
    }

    func testCleanupStatusBundleIDSkipped() {
        XCTAssertEqual(LogPatternPreset.cleanupStatus("com.microsoft.Word"), "")
    }

    // MARK: - Pattern Edge Cases

    func testInstallomatorPresetDoesNotMatchUnrelatedLines() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

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
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

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
        monitor.onStatusExtracted = { _ in
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
        monitor.onStatusExtracted = { status in
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
        var extractedStatuses: [String] = []

        let config = createMockLogMonitorConfig(
            path: testLogPath,
            preset: "shell",
            startFromEnd: false  // Read from beginning
        )

        let monitor = LogFileMonitor(config: config, path: testLogPath)
        monitor.onStatusExtracted = { status in
            extractedStatuses.append(status)
            expectation.fulfill()
        }
        monitor.start()

        // Monitor only processes on FS events, so trigger a write
        try await Task.sleep(nanoseconds: 100_000_000)
        try "[STATUS] New message\n".appendToFile(at: testLogPath)

        await fulfillment(of: [expectation], timeout: 2.0)

        // With startFromEnd=false, the existing content should be read first
        XCTAssertTrue(extractedStatuses.contains("Existing message"), "Should have processed existing content from beginning")
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

        let jsonData = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(InspectConfig.LogMonitorConfig.self, from: jsonData)
    }

    // MARK: - macOS Installer Preset Tests

    func testMacOSInstallerPresetMatchesExtractingPKG() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "2026-01-21 02:37:33+01 dev-mini installd[74805]: PackageKit: Extracting file://localhost/Users/admin/Downloads/Microsoft_365.pkg#Microsoft_Word_Internal.pkg (destination=/Applications)"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match PKG extraction line")
    }

    func testMacOSInstallerPresetMatchesTouchedBundle() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "2026-01-21 02:00:08+01 dev-mini installd[1068]: PackageKit: Touched bundle /Applications/Microsoft Word.app"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match touched bundle line")
    }

    func testMacOSInstallerPresetMatchesInstalled() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "2026-01-21 02:37:35+01 dev-mini installd[74805]: Installed \"Stream Deck\" ()"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match Installed line")
    }

    // MARK: - cleanupStatus Tests for macOS Installer Patterns

    func testCleanupStatusPKGInstalling() {
        // cleanupStatus handles .pkg patterns from macOS installer log
        let result = LogPatternPreset.cleanupStatus("Installing Microsoft Outlook.pkg to /")
        XCTAssertEqual(result, "Installing Microsoft Outlook...")
    }

    // MARK: - macOS Installer Failure Tests

    func testMacOSInstallerPresetMatchesInstallFailed() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "2026-01-21 02:37:35+01 dev-mini installd[74805]: Install failed: Package requires restart"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match Install failed line")
    }

    func testMacOSInstallerPresetMatchesPackageKitInstallFailed() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "2026-01-21 02:37:35+01 dev-mini installd[74805]: PackageKit: Install Failed: Error Domain=PKInstallErrorDomain Code=102"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match PackageKit Install Failed line")
    }

    func testMacOSInstallerPresetMatchesInstallerError() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        let testLine = "2026-01-21 02:37:35+01 dev-mini installer[74805]: installer: Error: Unable to verify package signature"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match installer Error line")
    }

    func testCleanupStatusFailedWithErrorMessage() {
        let result = LogPatternPreset.cleanupStatus("Error Domain=PKInstallErrorDomain Code=102")
        XCTAssertTrue(result.hasPrefix("Failed:"), "Should transform error message to Failed status")
    }

    func testCleanupStatusInstallFailed() {
        let result = LogPatternPreset.cleanupStatus("Install failed")
        XCTAssertTrue(result.hasPrefix("Failed"), "Should show Failed status")
    }

    func testCleanupStatusFailedTruncatesLongMessage() {
        let longError = "Error: This is a very long error message that should be truncated because it exceeds fifty characters"
        let result = LogPatternPreset.cleanupStatus(longError)

        XCTAssertTrue(result.hasPrefix("Failed:"), "Should show Failed prefix")
        XCTAssertTrue(result.hasSuffix("..."), "Should truncate with ellipsis")
        XCTAssertLessThan(result.count, longError.count, "Result should be shorter than original")
    }

    // MARK: - Real Installomator Session Tests
    // Validates regex + cleanupStatus against actual Installomator log output

    func testRealInstallomatorSessionFullFlow() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        // Real log lines from an actual microsoftonenote install session
        let logLines: [(line: String, shouldMatch: Bool, expectedCleanup: String?)] = [
            // Non-matching info lines
            ("2026-02-22 16:29:34 : INFO  : microsoftonenote : setting variable from argument DEBUG=0", false, nil),
            ("2026-02-22 16:29:34 : REQ   : microsoftonenote : ################## Start Installomator v. 10.9beta, date 2026-01-29", false, nil),
            ("2026-02-22 16:29:34 : INFO  : microsoftonenote : ################## microsoftonenote", false, nil),
            ("2026-02-22 16:29:47 : INFO  : microsoftonenote : Label type: pkg", false, nil),
            ("2026-02-22 16:29:47 : INFO  : microsoftonenote : archiveName: Microsoft OneNote.pkg", false, nil),
            ("2026-02-22 16:29:47 : INFO  : microsoftonenote : name: Microsoft OneNote, appName: Microsoft OneNote.app", false, nil),
            ("2026-02-22 16:29:47 : INFO  : microsoftonenote : Latest version of Microsoft OneNote is 16.106", false, nil),
            ("2026-02-22 16:30:01 : REQ   : microsoftonenote : All done!", false, nil),
            ("2026-02-22 16:30:01 : REQ   : microsoftonenote : ################## End Installomator, exit code 0", false, nil),

            // Matching action lines
            ("2026-02-22 16:29:35 : INFO  : microsoftonenote : Running msupdate --list", true, "Running script..."),
            ("2026-02-22 16:30:01 : REQ   : microsoftonenote : Installed Microsoft OneNote, version 16.106", false, nil),
            // Note: "Installed Microsoft OneNote, version 16.106" does NOT match the regex because
            // "Installed" is not in the action verbs list, and the version pattern expects "Installed version: X.Y"
        ]

        for (line, shouldMatch, expectedCleanup) in logLines {
            let range = NSRange(line.startIndex..., in: line)
            let match = regex.firstMatch(in: line, range: range)

            if shouldMatch {
                XCTAssertNotNil(match, "Should match: \(line)")
                if let match = match, let expectedCleanup = expectedCleanup {
                    let captureRange = Range(match.range(at: preset.captureGroup), in: line)!
                    let captured = String(line[captureRange])
                    let cleaned = LogPatternPreset.cleanupStatus(captured)
                    XCTAssertEqual(cleaned, expectedCleanup, "Cleanup mismatch for: \(captured)")
                }
            } else {
                XCTAssertNil(match, "Should NOT match: \(line)")
            }
        }
    }

    func testRealInstallomatorDownloadAndInstallFlow() {
        let preset = LogPatternPreset.presets["installomator"]!
        let regex = try! NSRegularExpression(pattern: preset.pattern, options: .anchorsMatchLines)

        // Real download+install flow from microsoftoutlook
        let actionLines: [(line: String, expectedCleanup: String)] = [
            ("2026-02-22 15:36:22 : REQ   : microsoftoutlook : Downloading https://go.microsoft.com/fwlink/?linkid=525137 to Microsoft Outlook.pkg", "Downloading..."),
            ("2026-02-22 15:38:41 : REQ   : microsoftoutlook : Installing Microsoft Outlook", "Installing Microsoft Outlook..."),
            ("2026-02-22 15:38:41 : INFO  : microsoftoutlook : Verifying: Microsoft Outlook.pkg", "Installing Microsoft Outlook..."),
            ("2026-02-22 15:38:41 : INFO  : microsoftoutlook : Installing Microsoft Outlook.pkg to /", "Installing Microsoft Outlook..."),
        ]

        for (line, expectedCleanup) in actionLines {
            let range = NSRange(line.startIndex..., in: line)
            let match = regex.firstMatch(in: line, range: range)

            XCTAssertNotNil(match, "Should match: \(line)")
            if let match = match {
                let captureRange = Range(match.range(at: preset.captureGroup), in: line)!
                let captured = String(line[captureRange])
                let cleaned = LogPatternPreset.cleanupStatus(captured)
                XCTAssertEqual(cleaned, expectedCleanup, "Cleanup mismatch for captured: '\(captured)'")
            }
        }
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

        let config = createMockLogMonitorConfig(
            path: jsonPath,
            format: "json",
            statusKey: "status",
            itemKey: "app"
        )

        let monitor = LogFileMonitor(config: config, path: jsonPath)
        monitor.onStatusExtracted = { status in
            extractedStatus = status
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
        monitor.stop()
    }

    func testJSONFormatWithoutItemKey() async throws {
        let jsonPath = tempDirectory.appendingPathComponent("status2.json").path

        let json: [String: Any] = ["message": "Processing..."]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: URL(fileURLWithPath: jsonPath))

        let expectation = XCTestExpectation(description: "Status extracted")
        var extractedStatus: String?

        let config = createMockLogMonitorConfig(
            path: jsonPath,
            format: "json",
            statusKey: "message"
        )

        let monitor = LogFileMonitor(config: config, path: jsonPath)
        monitor.onStatusExtracted = { status in
            extractedStatus = status
            expectation.fulfill()
        }
        monitor.start()

        // Trigger re-read by modifying file
        try await Task.sleep(nanoseconds: 100_000_000)
        try data.write(to: URL(fileURLWithPath: jsonPath))

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertEqual(extractedStatus, "Processing...")
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
        monitor.onStatusExtracted = { status in
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
