//
//  LogMonitorServiceTests.swift
//  dialogTests
//
//  Log presets matched against real captured lines, scope lifetime across installs, the `fleet`
//  preset's snapshot and events files, and tailing a log while it is written.
//

import XCTest
@testable import Dialog

/// `@MainActor` because `LogMonitorService` is, and `tearDown` calls `stop()`.
@MainActor
final class LogMonitorServiceTests: XCTestCase {

    var tempDirectory: URL!
    var testLogPath: String!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        testLogPath = tempDirectory.appendingPathComponent("test.log").path
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        LogMonitorService.shared.stop()
        super.tearDown()
    }

    // MARK: - LogPatternPreset Tests (Installomator)
    // Installomator log format: [YYYY-MM-DD HH:MM:SS] LEVEL: message
    
    func regexForPreset(forPreset preset: LogPatternPreset, options: NSRegularExpression.Options = []) -> NSRegularExpression? {
        guard let regex = try? NSRegularExpression(pattern: preset.pattern, options: options) else {
            fputs("Invalid regex pattern: \(preset.pattern)", stderr)
            return nil
        }
        return regex
    }

    func testInstallomatorPresetMatchesDownloading() {
        let preset = LogPatternPreset.presets["installomator"]!
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

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
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

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
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

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
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

        let testLine = "2026-02-22 15:33:12 : INFO  : googlechrome : Mounted /Volumes/Google Chrome.app"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match 'Mounted' line")
    }

    func testInstallomatorPresetMatchesInstalledVersion() {
        let preset = LogPatternPreset.presets["installomator"]!
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

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
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
           return
       }

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
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

        let testLine = "2026-02-22 15:34:05 : INFO  : microsoftoutlook : Verifying: Microsoft Outlook.pkg"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
    }

    func testInstallomatorPresetMatchesUnzipping() {
        // Installomator logs "Unzipping <archive>" for zip payloads.
        let preset = LogPatternPreset.presets["installomator"]!
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

        let testLine = "2026-02-22 15:34:05 : INFO  : googlechrome : Unzipping googlechrome.zip"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match 'Unzipping .zip' line")
    }

    func testInstallomatorPresetMatchesInstallingPKG() {
        let preset = LogPatternPreset.presets["installomator"]!
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

        let testLine = "2026-02-22 15:38:41 : INFO  : microsoftoutlook : Installing Microsoft Outlook.pkg to /"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match 'Installing .pkg' line")
    }

    func testInstallomatorPresetMatchesRunningMsupdate() {
        let preset = LogPatternPreset.presets["installomator"]!
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

        let testLine = "2026-02-22 15:36:10 : INFO  : microsoftoutlook : Running msupdate --list"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "Should match 'Running' line")
    }

    func testInstallomatorPresetDoesNotMatchStartEnd() {
        let preset = LogPatternPreset.presets["installomator"]!
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

        // Start/end banners carry no status.
        let startLine = "2026-02-22 15:23:00 : REQ   : microsoftword : ################## Start Installomator v. 10.9beta, date 2026-01-29"
        let endLine = "2026-02-22 15:39:33 : REQ   : microsoftoutlook : ################## End Installomator, exit code 0"

        XCTAssertNil(regex.firstMatch(in: startLine, range: NSRange(startLine.startIndex..., in: startLine)))
        XCTAssertNil(regex.firstMatch(in: endLine, range: NSRange(endLine.startIndex..., in: endLine)))
    }

    func testInstallomatorPresetDoesNotMatchInfoLines() {
        let preset = LogPatternPreset.presets["installomator"]!
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

        // Non-actionable info lines do not match.
        let testLines = [
            "2026-02-22 15:23:13 : INFO  : microsoftword : Label type: pkg",
            "2026-02-22 15:23:13 : INFO  : microsoftword : archiveName: Microsoft Word.pkg",
            "2026-02-22 15:23:13 : INFO  : microsoftword : name: Microsoft Word, appName: Microsoft Word.app",
            "2026-02-22 15:23:13 : WARN  : microsoftword : No previous app found",
            "2026-02-22 15:23:13 : INFO  : microsoftword : Latest version of Microsoft Word is 16.106",
            "2026-02-22 15:39:33 : REQ   : microsoftoutlook : All done!"
        ]

        for testLine in testLines {
            let range = NSRange(testLine.startIndex..., in: testLine)
            let match = regex.firstMatch(in: testLine, range: range)
            XCTAssertNil(match, "Should not match: \(testLine)")
        }
    }

    func testInstallomatorPresetMatchesAllLogLevels() {
        let preset = LogPatternPreset.presets["installomator"]!
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

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
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

        let testLine = "[STATUS] Installing dependencies"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match)
        if let match = match {
            let captureRange = Range(match.range(at: preset.captureGroup), in: testLine)!
            XCTAssertEqual(String(testLine[captureRange]), "Installing dependencies")
        }
    }

    func testJamfPresetMatchesRealSyslogFormat() {
        let preset = LogPatternPreset.presets["jamf"]!
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

        // A real line from /var/log/jamf.log; fixtures are captured, never typed from the pattern's assumptions.
        let testLine = "Thu Aug 20 00:46:57 MAC-FRUIT-0042 jamf[22705]: Executing Policy Set Proxy on Network Change (proxy.pac)"
        let range = NSRange(testLine.startIndex..., in: testLine)
        let match = regex.firstMatch(in: testLine, range: range)

        XCTAssertNotNil(match, "the jamf pattern must match jamf's ACTUAL syslog output")
    }

    func testJamfPresetIgnoresRoutineCheckInChatter() {
        let preset = LogPatternPreset.presets["jamf"]!
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

        // Check-in noise must not land on an install row.
        let testLine = "Thu Aug 20 00:24:51 MAC-FRUIT-0042 jamf[21937]: Checking for policies triggered by \"recurring check-in\" for user \"U000042\"..."
        let range = NSRange(testLine.startIndex..., in: testLine)

        XCTAssertNil(regex.firstMatch(in: testLine, range: range))
    }

    func testMunkiPresetMatchesRealLogFormat() {
        // Real ManagedSoftwareUpdate.log format is "TIMESTAMP message" (no "INFO:" prefix).
        let preset = LogPatternPreset.presets["munki"]!
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

        // An install-phase line matches, capturing the message after the timestamp.
        let installLine = "2026-07-06 09:53:12.758+00:00 Installing Firefox"
        let installRange = NSRange(installLine.startIndex..., in: installLine)
        let installMatch = regex.firstMatch(in: installLine, range: installRange)
        XCTAssertNotNil(installMatch, "Should match a Munki install line")
        if let installMatch = installMatch {
            let captureRange = Range(installMatch.range(at: preset.captureGroup), in: installLine)!
            XCTAssertEqual(String(installLine[captureRange]), "Installing Firefox")
        }

        // Manifest/catalog/checking noise does not match.
        let noise = "2026-07-06 09:53:10.115+00:00 Requesting manifest Mac.localdomain..."
        XCTAssertNil(regex.firstMatch(in: noise, range: NSRange(noise.startIndex..., in: noise)),
                     "Manifest/noise lines should not surface as status")
    }

    // MARK: - Custom Pattern Tests

    func testCustomPatternExtraction() {
        let pattern = #"^>>> (.+)$"#
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
            let testLine = ">>> Custom status message"
            let range = NSRange(testLine.startIndex..., in: testLine)
            let match = regex.firstMatch(in: testLine, range: range)

            XCTAssertNotNil(match)
            if let match = match {
                let captureRange = Range(match.range(at: 1), in: testLine)!
                XCTAssertEqual(String(testLine[captureRange]), "Custom status message")
            }
        } catch {
            fputs("Invalid regex pattern: \(pattern) - \(error)", stderr)
        }
    }

    func testCustomPatternWithMultipleCaptureGroups() {
        let pattern = #"^\[(\w+)\]\s+(.+)$"#
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
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
        } catch {
            fputs("Invalid regex pattern: \(pattern) - \(error)", stderr)
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
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

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
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

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
        let existingContent = "Old log line 1\nOld log line 2\n"
        try existingContent.write(toFile: testLogPath, atomically: true, encoding: .utf8)

        let expectation = XCTestExpectation(description: "Status extracted")
        expectation.isInverted = true // no callback for existing content

        let config = createMockLogMonitorConfig(
            path: testLogPath,
            preset: "shell",
            startFromEnd: true
        )

        // The monitor starts from the end.
        let monitor = LogFileMonitor(config: config, path: testLogPath)
        monitor.onStatusExtracted = { _ in
            expectation.fulfill()
        }
        monitor.start()

        await fulfillment(of: [expectation], timeout: 0.5)

        monitor.stop()
    }

    func testFileMonitorDetectsNewContent() async throws {
        try "".write(toFile: testLogPath, atomically: true, encoding: .utf8)

        let expectation = XCTestExpectation(description: "Status extracted")
        var extractedStatus: String?

        let config = createMockLogMonitorConfig(
            path: testLogPath,
            preset: "shell",
            startFromEnd: true
        )

        let monitor = LogFileMonitor(config: config, path: testLogPath)
        monitor.onStatusExtracted = { event in
            let status = event.text
            extractedStatus = status
            expectation.fulfill()
        }
        monitor.start()

        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        try "[STATUS] New status message\n".appendToFile(at: testLogPath)

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertEqual(extractedStatus, "New status message")
        monitor.stop()
    }

    func testFileMonitorReadsFromBeginning() async throws {
        let existingContent = "[STATUS] Existing message\n"
        try existingContent.write(toFile: testLogPath, atomically: true, encoding: .utf8)

        let expectation = XCTestExpectation(description: "Status extracted")
        var extractedStatuses: [String] = []

        let config = createMockLogMonitorConfig(
            path: testLogPath,
            preset: "shell",
            startFromEnd: false
        )

        let monitor = LogFileMonitor(config: config, path: testLogPath)
        monitor.onStatusExtracted = { event in
            let status = event.text
            extractedStatuses.append(status)
            expectation.fulfill()
        }
        monitor.start()

        // The monitor only processes on FS events, so trigger a write.
        try await Task.sleep(nanoseconds: 100_000_000)
        try "[STATUS] New message\n".appendToFile(at: testLogPath)

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertTrue(extractedStatuses.contains("Existing message"), "Should have processed existing content from beginning")
        monitor.stop()
    }

    // MARK: - Helper Methods

    /// `addRows` is opt-in, and the row a log's scope names gets the id every source gives that app.
    func testAddRowsIsOptInAndNamesTheRowAsTheLogDoes() throws {
        XCTAssertNil(createMockLogMonitorConfig(preset: "munki").addRows)
        let on = try JSONDecoder().decode(InspectConfig.LogMonitorConfig.self,
                                          from: Data(#"{"path": "/tmp/x.log", "preset": "munki", "addRows": true}"#.utf8))
        XCTAssertEqual(on.addRows, true)
        XCTAssertEqual(LogMonitorService.addedRow(named: " Firefox ")?.id, "app-firefox")
        XCTAssertEqual(LogMonitorService.addedRow(named: "Firefox")?.title, "Firefox")
        XCTAssertEqual(LogMonitorService.addedRow(named: "Google_Chrome-120")?.title, "Google_Chrome", "jamf: the package, unversioned")
        XCTAssertEqual(LogMonitorService.addedRow(named: "googlechromepkg")?.title, "googlechromepkg", "installomator: the label")
        XCTAssertEqual(LogMonitorService.addedRow(named: "Widgets-3.0.3.pkg")?.title, "Widgets", "orbit: the installer")
        XCTAssertEqual(LogMonitorService.addedRow(named: "Office 2019")?.title, "Office 2019", "a title with spaces stays whole")
        XCTAssertNil(LogMonitorService.addedRow(named: nil), "a line with no scope names nothing to add")
        XCTAssertNil(LogMonitorService.addedRow(named: "  "))
    }

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
            fatalError("Failed to parse log monitor config")
        }
        return config
    }

    // MARK: - macOS Installer preset
    // Every fixture is a line captured verbatim from /private/var/log/install.log.

    func testMacOSInstallerSuccessTerminatesRowAndNamesItViaScope() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let line = "2026-08-12 14:25:33+00 Mac installd[3283]: Installed \"Microsoft Teams\" (26198.202.4929.7171)"
        XCTAssertEqual(LogPatternPreset.status(for: line, using: preset), "Completed")
        XCTAssertTrue(LogPatternPreset.isTerminal(line: line, preset: preset))
        // "Completed" names nothing, so the app name is lifted into the scope from the same line.
        XCTAssertEqual(LogPatternPreset.scopeName(for: line, using: preset), "Microsoft Teams")
    }

    func testMacOSInstallerSystemInstalldSuccessAlsoTerminates() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let line = "2026-08-19 15:28:46+00 dev1 system_installd[1041]: Installed \"XProtectPlistConfigData\" (5356)"
        XCTAssertEqual(LogPatternPreset.status(for: line, using: preset), "Completed")
    }

    func testMacOSInstallerEmptyNameSuccessOpensNoScope() {
        // A pkg with no title writes an empty name: the success still classifies but opens no scope,
        // so it cannot settle on whichever row is open.
        let preset = LogPatternPreset.presets["macos-installer"]!
        let line = "2026-08-19 22:43:37+00 dev1 installd[3283]: Installed \"\" (0.5-218)"
        XCTAssertEqual(LogPatternPreset.status(for: line, using: preset), "Completed")
        XCTAssertNil(LogPatternPreset.scopeName(for: line, using: preset))
    }

    func testMacOSInstallerExtractingIsProgressNotTerminal() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let line = "2026-08-19 21:32:53+00 dev1 installd[3283]: PackageKit: Extracting file:///Users/Shared/munkitools-7.3.0.5806.pkg#munkitools_app_usage.pkg (destination=/Library/InstallerSandboxes/.PKInstallSandboxManager/55D92998-7E8C-44CE-A90B-4CF310A53586.activeSandbox/Root, uid=0)"
        let status = LogPatternPreset.status(for: line, using: preset)
        XCTAssertNotNil(status)
        XCTAssertTrue(status!.hasPrefix("Extracting "), "capture keeps the path so routing can match a row by filename")
        XCTAssertFalse(LogPatternPreset.isTerminal(line: line, preset: preset))
        XCTAssertEqual(LogPatternPreset.cleanupStatus(status!), "Extracting...")
    }

    func testMacOSInstallerTouchedBundleIsProgressNotCompletion() {
        let preset = LogPatternPreset.presets["macos-installer"]!
        let line = "2026-08-19 21:32:55+00 dev1 installd[3283]: PackageKit: Touched bundle /Applications/Managed Software Center.app"
        let status = LogPatternPreset.status(for: line, using: preset)
        XCTAssertNotNil(status)
        XCTAssertFalse(LogPatternPreset.isTerminal(line: line, preset: preset))
        // A Touched bundle is mid-install; completion comes from the Installed line, never a `.app` suffix.
        XCTAssertEqual(LogPatternPreset.cleanupStatus(status!), "Installing...")
    }

    // MARK: - cleanupStatus for macOS installer lines

    func testCleanupStatusPKGInstalling() {
        let result = LogPatternPreset.cleanupStatus("Installing Microsoft Outlook.pkg to /")
        XCTAssertEqual(result, "Installing Microsoft Outlook...")
    }

    // MARK: - macOS installer failures
    // Real failure lines; each test asserts what the line classifies as.

    func testMacOSInstallerInstallFailedIsAFailureEvenWhenLocalized() {
        // Installer.app writes failure prose in the user's locale; only the "Install failed: " anchor is stable.
        let preset = LogPatternPreset.presets["macos-installer"]!
        let line = "2025-11-26 06:29:15+01 dev1 Installer[50962]: Install failed: Du hast nicht die notwendigen Rechte, um diese Software zu installieren. Vergewissere dich, dass du Administratorrechte besitzt, bevor du es erneut versuchst."
        let status = LogPatternPreset.status(for: line, using: preset)
        XCTAssertNotNil(status)
        XCTAssertTrue(LogPatternPreset.isTerminal(line: line, preset: preset))
        XCTAssertTrue(LogPatternPreset.cleanupStatus(status!, isFailure: true).hasPrefix("Failed: "))
    }

    func testMacOSInstallerCLIInstallFailedIsAFailure() {
        // The installer(8) CLI writes the same "Install failed: " anchor.
        let preset = LogPatternPreset.presets["macos-installer"]!
        let line = "2026-05-12 18:22:36+00 dev1 installer[84834]: Install failed: The Installer encountered an error that caused the installation to fail. Contact the software manufacturer for assistance."
        XCTAssertNotNil(LogPatternPreset.status(for: line, using: preset))
        XCTAssertTrue(LogPatternPreset.isTerminal(line: line, preset: preset))
    }

    func testMacOSInstallerPackageKitFailureNamesThePackage() {
        // The pkg name inside the error prose is routable only if it matches a displayName or logAliases entry.
        let preset = LogPatternPreset.presets["macos-installer"]!
        let line = "2026-05-12 18:22:35+00 dev1 installd[1438]: PackageKit: Install Failed: Error Domain=PKInstallErrorDomain Code=112 \"An error occurred while running scripts from the package “MicrosoftTeams.pkg”.\" UserInfo={NSFilePath=./postinstall, NSURL=file:///Library/Caches/com.microsoft.autoupdate.helper/MicrosoftTeams.pkg#MicrosoftTeams_app.pkg, PKInstallPackageIdentifier=com.microsoft.teams2, NSLocalizedDescription=An error occurred while running scripts from the package “MicrosoftTeams.pkg”.} {"
        let status = LogPatternPreset.status(for: line, using: preset)
        XCTAssertNotNil(status)
        XCTAssertTrue(status!.contains("MicrosoftTeams.pkg"))
        XCTAssertTrue(LogPatternPreset.isTerminal(line: line, preset: preset))
    }

    func testMacOSInstallerFailureUIChatterDoesNotReadAsAFailure() {
        // Installer.app's lines about the failure UI are not failures; the colon in the anchor excludes them.
        let preset = LogPatternPreset.presets["macos-installer"]!
        let chatter = [
            "2025-11-26 06:29:15+01 dev1 Installer[50962]: Displaying 'Install Failed' UI.",
            "2025-11-26 06:29:15+01 dev1 Installer[50962]: 'Install Failed' UI displayed message:'Du benötigst Administratorzugriffsrechte, um diese Software installieren zu können."
        ]
        for line in chatter {
            XCTAssertNil(LogPatternPreset.status(for: line, using: preset), "chatter matched: \(line)")
            XCTAssertFalse(LogPatternPreset.isTerminal(line: line, preset: preset))
        }
    }

    func testTheOldInstallerErrorArmIsGoneBecauseItWasNeverObserved() {
        // No "installer: Error" alternation: no captured line uses it. Add one only with a captured fixture.
        let preset = LogPatternPreset.presets["macos-installer"]!
        XCTAssertFalse(preset.pattern.contains("installer: Error"))
        XCTAssertFalse(preset.failurePattern?.contains("installer: Error") ?? false)
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

    // MARK: - Real Installomator sessions

    func testRealInstallomatorSessionFullFlow() {
        let preset = LogPatternPreset.presets["installomator"]!
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

        // A real microsoftonenote install session
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
            ("2026-02-22 16:30:01 : REQ   : microsoftonenote : Installed Microsoft OneNote, version 16.106", false, nil)
            // "Installed Microsoft OneNote, version 16.106" does not match: "Installed" is not an action verb,
            // and the version pattern expects "Installed version: X.Y".
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
        guard let regex = regexForPreset(forPreset: preset, options: .anchorsMatchLines) else {
            return
        }

        // A real microsoftoutlook download and install
        let actionLines: [(line: String, expectedCleanup: String)] = [
            ("2026-02-22 15:36:22 : REQ   : microsoftoutlook : Downloading https://go.microsoft.com/fwlink/?linkid=525137 to Microsoft Outlook.pkg", "Downloading..."),
            ("2026-02-22 15:38:41 : REQ   : microsoftoutlook : Installing Microsoft Outlook", "Installing Microsoft Outlook..."),
            ("2026-02-22 15:38:41 : INFO  : microsoftoutlook : Verifying: Microsoft Outlook.pkg", "Verifying Microsoft Outlook..."),
            ("2026-02-22 15:38:41 : INFO  : microsoftoutlook : Installing Microsoft Outlook.pkg to /", "Installing Microsoft Outlook...")
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
        monitor.onStatusExtracted = { event in
            let status = event.text
            extractedStatus = status
            expectation.fulfill()
        }
        monitor.start()

        // Update the JSON to trigger a change.
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
        monitor.onStatusExtracted = { event in
            let status = event.text
            extractedStatus = status
            expectation.fulfill()
        }
        monitor.start()

        // Modify the file to trigger a re-read.
        try await Task.sleep(nanoseconds: 100_000_000)
        try data.write(to: URL(fileURLWithPath: jsonPath))

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertEqual(extractedStatus, "Processing...")
        monitor.stop()
    }

    func testJSONFormatWithDefaultStatusKey() async throws {
        let jsonPath = tempDirectory.appendingPathComponent("status3.json").path

        let json: [String: Any] = ["status": "Complete"]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: URL(fileURLWithPath: jsonPath))

        let expectation = XCTestExpectation(description: "Status extracted")
        var extractedStatus: String?

        let config = createMockLogMonitorConfig(
            path: jsonPath,
            format: "json"
            // No statusKey: the default "status" is used.
        )

        let monitor = LogFileMonitor(config: config, path: jsonPath)
        monitor.onStatusExtracted = { event in
            let status = event.text
            extractedStatus = status
            expectation.fulfill()
        }
        monitor.start()

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

// MARK: - Scope lifetime
// A scope names one install. It stays open across that install's lines and is spent by its
// terminal line, so an anonymous line that follows (the next install's first line) inherits nothing.
final class LogFileMonitorScopeLifetimeTests: XCTestCase {

    private var tempDirectory: URL!
    private var logPath: String!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        logPath = tempDirectory.appendingPathComponent("scope.log").path
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    /// Feeds `lines` to a live `LogFileMonitor` and returns its events in order.
    private func replay(_ lines: [String], preset: String,
                        expecting expectedEvents: Int) async throws -> [LogStatusEvent] {
        try "".write(toFile: logPath, atomically: true, encoding: .utf8)

        let config = Self.logMonitorConfig(path: logPath, preset: preset)
        let monitor = LogFileMonitor(config: config, path: logPath)

        let lock = NSLock()
        var events: [LogStatusEvent] = []
        let expectation = XCTestExpectation(description: "\(expectedEvents) statuses extracted")
        expectation.expectedFulfillmentCount = expectedEvents

        monitor.onStatusExtracted = { event in
            lock.withLock { events.append(event) }
            expectation.fulfill()
        }
        monitor.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        try (lines.joined(separator: "\n") + "\n").appendToFile(at: logPath)
        await fulfillment(of: [expectation], timeout: 5.0)
        monitor.stop()

        return lock.withLock { events }
    }

    private static func logMonitorConfig(path: String, preset: String) -> InspectConfig.LogMonitorConfig {
        let json: [String: Any] = ["path": path, "preset": preset, "startFromEnd": true]
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let config = try? JSONDecoder().decode(InspectConfig.LogMonitorConfig.self, from: data) else {
            fatalError("Failed to parse log monitor config")
        }
        return config
    }

    /// The service's routing: raw text routes (`handleStatus`), cleaned text is what a row shows.
    private func latestStatuses(from events: [LogStatusEvent],
                                items: [LogRouteCandidate]) -> [String: String] {
        var statuses: [String: String] = [:]
        for event in events {
            let cleaned = LogPatternPreset.cleanupStatus(event.text, isFailure: event.isFailure)
            guard !cleaned.isEmpty else { continue }
            for id in LogPatternPreset.routeTargets(status: event.text, scope: event.scope, items: items) {
                statuses[id] = cleaned
            }
        }
        return statuses
    }

    // MARK: orbit: two installs back to back

    /// Shapes from orbit.stderr.log, two consecutive installs; each filename appears once.
    private let orbitTwoInstalls = [
        "2026-01-15T09:03:26+00:00 INF about to download software installer from Fleet installerID=11111111-2222-4333-8444-555555555555 runner=installer",
        "2026-01-15T09:03:28+00:00 INF software installer downloaded installerID=11111111-2222-4333-8444-555555555555 installerPath=/tmp/1000000001/MicrosoftTeams.pkg runner=installer",
        "2026-01-15T09:03:28+00:00 INF about to run install script installerID=11111111-2222-4333-8444-555555555555 runner=installer",
        "2026-01-15T09:03:51+00:00 INF install script exitCode=0 installerID=11111111-2222-4333-8444-555555555555 runner=installer",
        "2026-01-15T09:03:52+00:00 INF about to download software installer from Fleet installerID=aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee runner=installer",
        "2026-01-15T09:03:55+00:00 INF software installer downloaded installerID=aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee installerPath=/tmp/1000000002/Slack-4.39.90.pkg runner=installer",
        "2026-01-15T09:03:55+00:00 INF about to run install script installerID=aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee runner=installer",
        "2026-01-15T09:04:14+00:00 INF install script exitCode=0 installerID=aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee runner=installer"
    ]

    /// Rows with no `paths`, aliased by installer filename, the only name the log gives.
    private let orbitItems = [
        LogRouteCandidate(id: "teams", displayName: "Microsoft Teams", aliases: ["MicrosoftTeams.pkg"]),
        LogRouteCandidate(id: "slack", displayName: "Slack", aliases: ["Slack-4.39.90.pkg"])
    ]

    func testATerminalLineSpendsTheScopeSoTheNextInstallCannotInheritIt() async throws {
        let events = try await replay(orbitTwoInstalls, preset: "orbit", expecting: 8)
        XCTAssertEqual(events.count, 8, "four lines per install, two installs")

        // Install one: the scope opens on the download line and carries the verdict.
        XCTAssertNil(events[0].scope, "nothing is open before the first installerPath line")
        XCTAssertEqual(events[1].scope, "MicrosoftTeams.pkg")
        XCTAssertEqual(events[3].text, "Completed")
        XCTAssertEqual(events[3].scope, "MicrosoftTeams.pkg", "the verdict still gets its scope")

        // Install two's first line is anonymous and precedes the line naming Slack; it inherits nothing.
        XCTAssertEqual(events[4].text, "about to download software installer")
        XCTAssertNil(events[4].scope,
                     "the scope was spent by install one's verdict — inheriting it re-opens Teams")

        XCTAssertEqual(events[5].scope, "Slack-4.39.90.pkg")
        XCTAssertEqual(events[7].text, "Completed")
        XCTAssertEqual(events[7].scope, "Slack-4.39.90.pkg")
    }

    func testAFinishedRowStaysFinishedWhenTheNextInstallBegins() async throws {
        // Teams does not read "Installing" after it completed.
        let events = try await replay(orbitTwoInstalls, preset: "orbit", expecting: 8)
        let statuses = latestStatuses(from: events, items: orbitItems)

        XCTAssertEqual(statuses["teams"], "Completed")
        XCTAssertEqual(statuses["slack"], "Completed")
        // Any status containing "install" maps to .active, so a stale scope would un-complete the row.
        XCTAssertFalse(statuses["teams"]?.lowercased().contains("install") ?? false,
                       "Teams must not read as installing again once it has completed")
    }

    // MARK: munki

    /// munki's anonymous terminal line still attributes to the scope that opened, then spends it.
    func testMunkisAnonymousTerminalStillAttributesToTheScopeThatOpenedIt() async throws {
        let lines = [
            "2026-08-19 23:11:46.688+00:00 Installing Firefox (1 of 2)",
            "2026-08-19 23:11:51.385+00:00     The software was successfully installed.",
            "2026-08-19 23:11:52.010+00:00 Installing JamfPPPCUtility (2 of 2)",
            "2026-08-19 23:11:57.442+00:00     The software was successfully installed."
        ]
        let events = try await replay(lines, preset: "munki", expecting: 4)
        XCTAssertEqual(events.count, 4)

        XCTAssertEqual(events[1].text, "Completed")
        XCTAssertEqual(events[1].scope, "Firefox", "the anonymous success is attributed by scope")
        XCTAssertEqual(events[3].text, "Completed")
        XCTAssertEqual(events[3].scope, "JamfPPPCUtility",
                       "the second success must NOT still be holding Firefox")

        let items = [LogRouteCandidate(id: "firefox", displayName: "Firefox"),
                     LogRouteCandidate(id: "jamfpppc", displayName: "JamfPPPCUtility")]
        let statuses = latestStatuses(from: events, items: items)
        XCTAssertEqual(statuses["firefox"], "Completed")
        XCTAssertEqual(statuses["jamfpppc"], "Completed")
    }

    /// An anonymous line after a verdict routes nowhere, not to the row that finished last.
    func testAnAnonymousLineAfterAVerdictRoutesNowhere() async throws {
        let lines = [
            "2026-08-19 23:11:46.688+00:00 Installing Firefox (1 of 1)",
            "2026-08-19 23:11:51.385+00:00     The software was successfully installed.",
            "2026-08-19 23:11:52.100+00:00 Downloading Firefox-140.0.4.dmg..."
        ]
        let events = try await replay(lines, preset: "munki", expecting: 3)
        XCTAssertNil(events[2].scope, "the download line names the FILE and opens no scope")

        // With no scope, a line routes by its own text only.
        let anonymous = [LogRouteCandidate(id: "chrome", displayName: "Google Chrome")]
        XCTAssertEqual(
            LogPatternPreset.routeTargets(status: events[2].text, scope: events[2].scope,
                                          items: anonymous),
            [], "a line that names nothing this screen knows must land on no row at all")
    }
}

// MARK: - fleet preset: Setup Experience files to row states

final class FleetSetupMappingTests: XCTestCase {
    /// A window opened just before the fixture's first event (21:38:11Z).
    static let fixtureOpened = FleetSetup.time("2026-03-04T10:15:00Z")!

    /// finished_at means history; a recent stamp means live; an old or future stamp (clock still
    /// syncing) is judged by uptime instead, which no clock change moves.
    func testTheSnapshotIsJudgedWithoutTrustingTheClock() {
        let now = FleetSetup.time("2026-10-23T10:00:00Z")!
        func judged(_ snapshots: [[String: Any]], uptimes: [TimeInterval]) -> FleetSetup.SnapshotJudge.Verdict? {
            var judge = FleetSetup.SnapshotJudge()
            var verdict: FleetSetup.SnapshotJudge.Verdict?
            for (s, u) in zip(snapshots, uptimes) { verdict = judge.judge(s, now: now, uptime: u) }
            return verdict
        }
        XCTAssertEqual(judged([["finished_at": "2026-10-23T09:59:00Z", "updated_at": "2026-10-23T09:59:00Z"]], uptimes: [0]), .history)
        XCTAssertEqual(judged([["updated_at": "2026-10-23T09:55:00Z"]], uptimes: [0]), .live, "5 minutes old: a run in progress")
        XCTAssertEqual(judged([["version": 1]], uptimes: [0]), .live, "no stamp to judge: read as before")
        let old: [String: Any] = ["updated_at": "2026-10-20T10:00:00Z"]
        XCTAssertNil(judged([old], uptimes: [0]), "three days old: watched, not believed")
        XCTAssertNil(judged([old, old], uptimes: [0, 60]), "unchanged for 60 s: still watching")
        XCTAssertEqual(judged([old, old], uptimes: [0, 95]), .history, "unchanged for 95 s of uptime: orbit is done with it")
        XCTAssertEqual(judged([old, ["updated_at": "2026-10-20T10:00:31Z"]], uptimes: [0, 31]), .live,
                       "rewritten: a live run whose clock was days off")
        XCTAssertNil(judged([["updated_at": "2026-11-30T10:00:00Z"]], uptimes: [0]), "in the future: watched too")
    }

    /// With finished_at set, the window reads the events alone, and an unlisted install gets its own row.
    func testAFinishedSnapshotLeavesTheWindowToTheEvents() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let snap = dir.appendingPathComponent("setup_experience_progress.json")
        try #"{"version":1,"updated_at":"2026-10-23T10:00:00Z","finished_at":"2026-10-23T10:00:00Z","software":[{"name":"Slack","status":"success","software_title_id":1}]}"#
            .write(to: snap, atomically: true, encoding: .utf8)
        let events = dir.appendingPathComponent(FleetSetup.eventsFileName)
        try (#"{"version":1,"time":"2026-10-23T11:00:05Z","install_id":"n","event":"download_started","filename":"Zoom-6.1.pkg"}"# + "\n")
            .write(to: events, atomically: true, encoding: .utf8)
        let source = FleetSetupSource(snapshotPath: snap.path, eventsPath: events.path, items: [],
                                      startedAt: FleetSetup.time("2026-10-23T11:00:00Z")!, emit: { _ in })
        source.tick()
        XCTAssertNil(source.sent["sw-1"], "the old setup list is not shown as current")
        XCTAssertEqual(source.live["app-zoom"]?.status, .active, "Zoom, which setup never named, has its own row")
    }

    /// Installs that finished over a minute before the window, or went silent for 30 minutes, are history.
    func testInstallsFromBeforeTheWindowAreHistory() {
        let opened = FleetSetup.time("2026-10-20T10:00:00Z")!
        func e(_ iid: String, _ event: String, _ time: String) -> [String: Any] {
            ["install_id": iid, "event": event, "time": time]
        }
        let past = FleetSetup.pastInstalls([
            e("old-fail", "download_started", "2026-08-01T09:00:00Z"), e("old-fail", "install_finished", "2026-08-01T09:05:00Z"),
            e("abandoned", "download_progress", "2026-10-20T09:00:00Z"),
            e("installing", "install_started", "2026-10-20T09:45:00Z"),
            e("just-done", "install_finished", "2026-10-20T09:59:30Z"),
            e("now", "download_started", "2026-10-20T10:00:05Z")
        ], openedAt: opened)
        XCTAssertEqual(past, ["old-fail", "abandoned"])
    }

    /// An old failure does not mark the row failed; a failure while the window is open does.
    func testAnOldFailureIsNotTheWindowsNews() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let events = dir.appendingPathComponent(FleetSetup.eventsFileName)
        func line(_ iid: String, _ event: String, _ time: String, _ extra: String = "") -> String {
            #"{"version":1,"time":"\#(time)","install_id":"\#(iid)","event":"\#(event)"\#(extra)}"#
        }
        let history = [line("aug", "download_started", "2026-08-01T09:00:00Z", #","filename":"Slack-4.4.pkg""#),
                       line("aug", "install_finished", "2026-08-01T09:05:00Z", #","exit_code":1"#)]
        try (history.joined(separator: "\n") + "\n").write(to: events, atomically: true, encoding: .utf8)
        let source = FleetSetupSource(snapshotPath: dir.appendingPathComponent("setup_experience_progress.json").path,
                                      eventsPath: events.path,
                                      items: [InspectConfig.ItemConfig(id: "slack", displayName: "Slack", paths: [])],
                                      startedAt: FleetSetup.time("2026-10-20T10:00:00Z")!, emit: { _ in })
        source.tick()
        XCTAssertNil(source.live["slack"], "August is history")
        let handle = try FileHandle(forWritingTo: events)
        handle.seekToEndOfFile()
        handle.write(Data((line("now", "download_started", "2026-10-20T10:01:00Z", #","filename":"Slack-4.5.pkg""#) + "\n"
                           + line("now", "install_finished", "2026-10-20T10:02:00Z", #","exit_code":1"#) + "\n").utf8))
        try handle.close()
        source.tick()
        XCTAssertEqual(source.live["slack"]?.status, .failed, "a failure while the window is open is news")
    }

    /// The running row is never taken by another install (an abandoned download, or one held while nothing ran).
    func testTheRunningRowIsNotTakenByAnotherInstall() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let snap = dir.appendingPathComponent("setup_experience_progress.json")
        try #"{"version":1,"software":[{"name":"Microsoft Office","status":"pending","software_title_id":7}]}"#
            .write(to: snap, atomically: true, encoding: .utf8)
        let events = dir.appendingPathComponent(FleetSetup.eventsFileName)
        let lines = [
            #"{"version":1,"time":"2026-10-01T09:00:00Z","install_id":"stalled","event":"download_started","filename":"OldTool.pkg"}"#,
            #"{"version":1,"time":"2026-10-01T09:00:05Z","install_id":"stalled","event":"download_progress","percent":40}"#,
            #"{"version":1,"time":"2026-10-20T10:00:10Z","install_id":"other","event":"download_started","filename":"Unrelated.pkg"}"#,
            #"{"version":1,"time":"2026-10-20T10:00:20Z","install_id":"other","event":"install_finished","exit_code":0}"#
        ]
        try (lines.joined(separator: "\n") + "\n").write(to: events, atomically: true, encoding: .utf8)
        let source = FleetSetupSource(snapshotPath: snap.path, eventsPath: events.path, items: [],
                                      startedAt: FleetSetup.time("2026-10-20T10:00:00Z")!, emit: { _ in })
        source.tick()
        XCTAssertNil(source.live["sw-7"], "nothing is running yet: both installs are held")
        try #"{"version":1,"software":[{"name":"Microsoft Office","status":"running","software_title_id":7}]}"#
            .write(to: snap, atomically: true, encoding: .utf8)
        source.tick()
        XCTAssertNil(source.live["sw-7"], "Office runs now: neither the abandoned download nor the finished Unrelated.pkg is it")
    }

    private let snapshot: [String: Any] = [
        "bootstrap_package": ["name": "acme-bootstrap.pkg", "status": "installed"],
        "configuration_profiles": [["name": "Wi-Fi", "status": "verified"], ["name": "FileVault", "status": "verifying"]],
        "software": [["name": "Google Chrome", "status": "success", "software_title_id": 936],
                     ["name": "1Password", "display_name": "1Password 8", "status": "failure",
                      "error": "Installation failed", "software_title_id": 20],
                     ["name": "Slack", "status": "running", "software_title_id": 2792]],
        "script": ["name": "enroll-finalize.sh", "status": "pending"]
    ]

    /// Rows follow orbit's order with stable ids; "profiles" follows the profiles it sums up.
    func testRowsComeInOrbitsOrderWithStableIds() {
        XCTAssertEqual(FleetSetup.rows(snapshot).map(\.id),
                       ["bootstrap", "profile-wifi", "profile-filevault", "profiles", "sw-936", "sw-20", "sw-2792", "script"])
    }

    /// One row for all profiles: the state of the whole set, and how far it is.
    func testProfilesAreSummedUpInOneRow() {
        func summary(_ states: [String]) -> FleetSetup.Shown? {
            let rows = FleetSetup.rows(["configuration_profiles": states.enumerated().map { ["name": "P\($0.offset)", "status": $0.element] }])
            return rows.first { $0.id == "profiles" }.map(FleetSetup.shown)
        }
        XCTAssertEqual(summary(["verified", "verified"]), FleetSetup.Shown(status: .completed, text: "2 of 2 verified", percent: 100))
        XCTAssertEqual(summary(["verified", "verifying", "pending"])?.text, "1 of 3 verified")
        XCTAssertEqual(summary(["verified", "verifying", "pending"])?.status, .active)
        XCTAssertEqual(summary(["pending", "pending"])?.status, .pending)
        XCTAssertEqual(summary(["verified", "failed"])?.status, .failed)
        XCTAssertNil(summary([]), "no profiles, no row")
    }

    /// An install list deployed empty fills from the snapshot: software, script and one profiles row, in order.
    func testAnEmptyInstallListIsFilledFromTheSnapshot() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let snap = dir.appendingPathComponent("setup_experience_progress.json")
        try JSONSerialization.data(withJSONObject: snapshot).write(to: snap)
        let source = FleetSetupSource(snapshotPath: snap.path,
                                      items: [InspectConfig.ItemConfig(id: "sw-20", displayName: "1Password", paths: [])],
                                      emit: { _ in })
        source.tick()
        XCTAssertEqual(source.sentOrder, ["bootstrap", "profiles", "sw-936", "sw-20", "sw-2792", "script"],
                       "the config's own row and every added one, in Fleet's order")
        XCTAssertEqual(source.sent["sw-2792"]?.status, .active, "Slack, added from Fleet, is running")
        XCTAssertNotNil(source.sent["profiles"])
    }

    /// `showProfilesRow: false` leaves profiles out entirely.
    /// A title removed from Setup Experience mid-run is deleted; a row the config lists stays.
    func testARowFleetNoLongerListsIsDeleted() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let snap = dir.appendingPathComponent("setup_experience_progress.json")
        func write(_ titles: [(String, Int)]) throws {
            let software = titles.map { #"{"name":"\#($0.0)","status":"pending","software_title_id":\#($0.1)}"# }
            try #"{"version":1,"software":[\#(software.joined(separator: ","))]}"#.write(to: snap, atomically: true, encoding: .utf8)
        }
        final class Lines: @unchecked Sendable { var all: [String] = [] }
        let emitted = Lines()
        try write([("Slack", 1), ("Zoom", 2), ("Teams", 3)])
        let source = FleetSetupSource(snapshotPath: snap.path,
                                      items: [InspectConfig.ItemConfig(id: "sw-3", displayName: "Teams", paths: [])],
                                      emit: { emitted.all.append($0) })
        source.tick()
        try write([("Slack", 1)])
        source.tick()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3)) // emit lands on main
        XCTAssertTrue(emitted.all.contains("listitem: delete, id: sw-2"), "Zoom left Fleet's list")
        XCTAssertFalse(emitted.all.contains("listitem: delete, id: sw-1"), "Slack is still listed")
        XCTAssertFalse(emitted.all.contains { $0.hasPrefix("listitem: delete, id: sw-3") }, "the config's Teams stays")
        XCTAssertNil(source.sent["sw-2"])
    }

    /// A name with no Latin letters or digits slugs to "" and joins no other such name.
    func testANameWithoutLatinLettersJoinsNothingElse() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let snap = dir.appendingPathComponent("setup_experience_progress.json")
        try #"{"version":1,"software":[{"name":"Телеграм","status":"success","software_title_id":9}]}"#
            .write(to: snap, atomically: true, encoding: .utf8)
        let source = FleetSetupSource(snapshotPath: snap.path,
                                      items: [InspectConfig.ItemConfig(id: "wechat", displayName: "微信", paths: [])],
                                      emit: { _ in })
        source.tick()
        XCTAssertNil(source.sent["wechat"], "Telegram's state is not WeChat's")
        XCTAssertEqual(source.sent["sw-9"]?.status, .completed, "Telegram has a row of its own")
    }

    func testTheProfilesRowCanBeLeftOut() throws {
        XCTAssertEqual(FleetSetup.rows(snapshot, profilesRow: false).map(\.id),
                       ["bootstrap", "profile-wifi", "profile-filevault", "sw-936", "sw-20", "sw-2792", "script"])
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let snap = dir.appendingPathComponent("setup_experience_progress.json")
        try JSONSerialization.data(withJSONObject: snapshot).write(to: snap)
        let source = FleetSetupSource(snapshotPath: snap.path, profilesRow: false, items: [], emit: { _ in })
        source.tick()
        XCTAssertEqual(source.sentOrder, ["bootstrap", "sw-936", "sw-20", "sw-2792", "script"])
        XCTAssertNil(source.sent["profiles"])
        let decoded = try JSONDecoder().decode(InspectConfig.self, from: Data(#"{"preset": "5", "showProfilesRow": false}"#.utf8))
        XCTAssertEqual(decoded.showProfilesRow, false)
    }

    func testOrbitsWordsBecomeInspectStates() {
        let rows = FleetSetup.rows(snapshot)
        let s = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, FleetSetup.shown($0)) })
        XCTAssertEqual(s["bootstrap"]?.status, .completed)
        XCTAssertEqual(s["profile-wifi"]?.text, "Verified")
        XCTAssertEqual(s["profile-filevault"]?.status, .active)
        XCTAssertEqual(s["sw-20"], FleetSetup.Shown(status: .failed, text: "Installation failed", percent: nil))
        XCTAssertEqual(s["sw-2792"]?.text, "Installing")
        XCTAssertEqual(s["script"]?.status, .pending)
    }

    /// The join: a filename that names a row wins; without one, the snapshot's running row.
    func testEventsJoinTheirRowByFilenameElseTheRunningRow() {
        let rows = FleetSetup.rows(snapshot)
        var join = FleetSetup.Join()
        XCTAssertEqual(join.feed(["install_id": "b", "event": "downloaded", "filename": "1Password.pkg"], rows: rows).map(\.0),
                       ["sw-20"], "named by its installer")
        XCTAssertEqual(join.feed(["install_id": "c", "event": "install_started"], rows: rows).map(\.0),
                       ["sw-2792"], "unnamed: the row the snapshot calls running (Slack)")
        XCTAssertEqual(FleetSetup.match(filename: "googlechrome.pkg", in: rows)?.id, "sw-936")
        XCTAssertEqual(FleetSetup.match(filename: "Slack-4.52.178-macOS.dmg", in: rows)?.id, "sw-2792")
    }

    /// Real orbit output (package renamed), 5 % steps: "Widgets" is found even with "Widget" listed first.
    func testRealOrbitEventsJoinTheClosestName() throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/orbit-software_install_events.jsonl")
        let lines = try String(contentsOf: fixture, encoding: .utf8).split(separator: "\n")
        XCTAssertEqual(lines.count, 24)
        XCTAssertEqual(lines.filter { $0.contains(#""event":"download_progress""#) }.count, 20, "every 5 %, no 10 MB steps")

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let snap = dir.appendingPathComponent("setup_experience_progress.json")
        try #"{"version":1,"software":[{"name":"Widget","status":"pending","software_title_id":1},{"name":"Widgets","status":"running","software_title_id":2}]}"#
            .write(to: snap, atomically: true, encoding: .utf8)
        let events = dir.appendingPathComponent(FleetSetup.eventsFileName)
        try FileManager.default.copyItem(at: fixture, to: events)
        let source = FleetSetupSource(snapshotPath: snap.path, eventsPath: events.path, items: [], startedAt: Self.fixtureOpened, emit: { _ in })
        source.tick()
        XCTAssertNotNil(source.live["sw-2"], "Widgets-3.0.3.pkg is Widgets")
        XCTAssertNil(source.live["sw-1"], "not Widget, though \"widgets\" contains \"widget\"")
    }

    /// Without a snapshot, the events drive the config's rows, joined by installer name.
    func testWithoutASnapshotTheEventsDriveTheConfigsRows() throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/orbit-software_install_events.jsonl")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let events = dir.appendingPathComponent(FleetSetup.eventsFileName)
        try FileManager.default.copyItem(at: fixture, to: events)
        let items = [InspectConfig.ItemConfig(id: "app-widget", displayName: "Widget", paths: []),
                     InspectConfig.ItemConfig(id: "app-widgets", displayName: "Widgets", paths: []),
                     InspectConfig.ItemConfig(id: "profile-wifi", displayName: "Wi-Fi", paths: [])]
        let source = FleetSetupSource(snapshotPath: dir.appendingPathComponent("setup_experience_progress.json").path,
                                      eventsPath: events.path, items: items, startedAt: Self.fixtureOpened, emit: { _ in })
        source.tick()
        XCTAssertEqual(source.live["app-widgets"]?.status, .completed, "install_finished exit 0")
        XCTAssertEqual(source.live["app-widgets"]?.text, "Installed")
        XCTAssertNil(source.live["app-widget"])
        XCTAssertNil(source.live["profile-wifi"], "a profile is not an install")
    }

    /// An unlisted install gets a row only if it began after the window opened.
    func testAnUnlistedInstallGetsARowOnlyIfItIsCurrent() throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/orbit-software_install_events.jsonl")   // 2026-03-04T10:15:30Z
        for (startedAt, expectRow) in [("2026-03-04T10:15:00Z", true), ("2026-03-04T11:00:00Z", false)] {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }
            let events = dir.appendingPathComponent(FleetSetup.eventsFileName)
            try FileManager.default.copyItem(at: fixture, to: events)
            let source = FleetSetupSource(snapshotPath: dir.appendingPathComponent("setup_experience_progress.json").path,
                                          eventsPath: events.path,
                                          items: [InspectConfig.ItemConfig(id: "app-other", displayName: "Other", paths: [])],
                                          startedAt: try XCTUnwrap(FleetSetup.time(startedAt)), emit: { _ in })
            source.tick()
            XCTAssertEqual(source.sent["app-widgets"]?.status, expectRow ? .completed : nil, "window opened \(startedAt)")
            XCTAssertNil(source.sent["app-other"])
        }
    }

    /// The snapshot's order replaces the config's, by id or name, sent once per change.
    func testTheSnapshotsOrderIsSentToTheWindow() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let snap = dir.appendingPathComponent("setup_experience_progress.json")
        try #"{"version":1,"software":[{"name":"Alpha","status":"success","software_title_id":3},{"name":"beta-pkg","display_name":"Beta","status":"running","software_title_id":2},{"name":"Gamma","status":"pending","software_title_id":1}],"script":{"name":"finish.sh","status":"pending"}}"#
            .write(to: snap, atomically: true, encoding: .utf8)
        let items = [InspectConfig.ItemConfig(id: "app-gamma", displayName: "Gamma", paths: []),
                     InspectConfig.ItemConfig(id: "app-beta", displayName: "Beta", paths: []),
                     InspectConfig.ItemConfig(id: "sw-3", displayName: "Alpha", paths: []),
                     InspectConfig.ItemConfig(id: "script", displayName: "Finishing setup", paths: [])]
        let source = FleetSetupSource(snapshotPath: snap.path, items: items, emit: { _ in })
        source.tick()
        XCTAssertEqual(source.sentOrder, ["sw-3", "app-beta", "app-gamma", "script"])
    }

    func testARowTitleIsTheInstallersNameBeforeItsVersion() {
        XCTAssertEqual(FleetSetup.title(fromFilename: "MiddleClick.zip"), "MiddleClick")
        XCTAssertEqual(FleetSetup.title(fromFilename: "Support.3.0.5.pkg"), "Support")
        XCTAssertEqual(FleetSetup.title(fromFilename: "Slack-4.52.178-macOS.dmg"), "Slack")
        XCTAssertEqual(FleetSetup.title(fromFilename: "Nudge-2.1.4.81863.pkg"), "Nudge")
        XCTAssertEqual(FleetSetup.title(fromFilename: "googlechrome.pkg"), "googlechrome")
        XCTAssertEqual(FleetSetup.title(fromFilename: "Tool_v2.1.pkg"), "Tool")
    }

    /// A reader started before any step handed over rows takes the install step's rows when configured.
    func testAReaderStartedWithoutRowsTakesTheStepsRows() throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/orbit-software_install_events.jsonl")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let events = dir.appendingPathComponent(FleetSetup.eventsFileName)
        try FileManager.default.copyItem(at: fixture, to: events)
        let source = FleetSetupSource(snapshotPath: dir.appendingPathComponent("setup_experience_progress.json").path,
                                      eventsPath: events.path, items: [], startedAt: Self.fixtureOpened, emit: { _ in })
        source.setItems([InspectConfig.ItemConfig(id: "app-widgets", displayName: "Widgets", paths: [])])
        Thread.sleep(forTimeInterval: 0.2)   // setItems lands on the reader's queue
        source.tick()
        XCTAssertEqual(source.live["app-widgets"]?.status, .completed)
    }

    /// After setup, a reinstall is read from the events; while setup runs, the snapshot's final word stands.
    func testAReinstallAfterSetupIsReadFromTheEvents() throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/orbit-software_install_events.jsonl")
        let midDownload = try String(contentsOf: fixture, encoding: .utf8).split(separator: "\n").prefix(10)
            .joined(separator: "\n") + "\n"   // events at 2026-03-04T10:15:30Z, up to 45 %
        let now = ISO8601DateFormatter().string(from: Date())
        for (stamps, finished) in [(#""updated_at":"2026-10-01T08:00:00Z","finished_at":"2026-10-01T08:00:00Z""#, true),
                                   (#""updated_at":"\#(now)""#, false)] {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let snap = dir.appendingPathComponent("setup_experience_progress.json")
            try #"{"version":1,\#(stamps),"software":[{"name":"Widgets","status":"success","software_title_id":2}]}"#
                .write(to: snap, atomically: true, encoding: .utf8)
            let events = dir.appendingPathComponent(FleetSetup.eventsFileName)
            try midDownload.write(to: events, atomically: true, encoding: .utf8)
            let source = FleetSetupSource(snapshotPath: snap.path, eventsPath: events.path, items: [], startedAt: Self.fixtureOpened, emit: { _ in })
            source.tick()
            if finished {
                XCTAssertNil(source.sent["sw-2"], "a finished snapshot is not shown as current")
                XCTAssertEqual(source.live["app-widgets"]?.status, .active, "the reinstall, on a row of its own")
            } else {
                XCTAssertEqual(source.sent["sw-2"]?.status, .completed, "a live snapshot's final word stands")
                XCTAssertEqual(source.live["sw-2"]?.status, .active, "the events still say downloading")
            }
        }
    }

    /// Progress decorates only a row the snapshot calls running; a final word always wins.
    func testTheSnapshotsFinalWordBeatsALateEvent() {
        let rows = FleetSetup.rows(snapshot)
        let live: [String: FleetSetup.Shown] = [
            "sw-2792": .init(status: .active, text: "Downloading · 45%", percent: 45),
            "sw-936": .init(status: .active, text: "Downloading · 90%", percent: 90)
        ]
        let out = FleetSetup.compose(rows: rows, live: live)
        XCTAssertEqual(out["sw-2792"]?.text, "Downloading · 45%")
        XCTAssertEqual(out["sw-936"]?.status, .completed, "the snapshot says done; a stale event cannot reopen it")
        XCTAssertEqual(FleetSetup.commands(id: "sw-2792", out["sw-2792"]!),
                       ["item:sw-2792:active:Downloading · 45%", "progress:sw-2792:45"])
    }

    func testAFailedInstallNamesItsExitCode() {
        let row = FleetSetup.rows(snapshot).first { $0.id == "sw-20" }!
        XCTAssertEqual(FleetSetup.shown(event: ["event": "install_finished", "exit_code": 1], row: row).text,
                       "Installation failed (exit 1)")
    }

    /// Once an install starts the download is whole, so the row shows the installing spinner.
    func testAnInstallThatStartedReadsAsAWholeDownload() {
        let row = FleetSetup.rows(snapshot).first { $0.id == "sw-20" }!
        let shown = FleetSetup.shown(event: ["event": "install_started"], row: row)
        XCTAssertEqual(shown.status, .active)
        XCTAssertEqual(shown.text, "Installing")
        XCTAssertEqual(shown.percent, 100)
    }
}

// MARK: - fleet preset: versioned files, rotation, running-row link

final class FleetSetupJoinAndRotationTests: XCTestCase {
    private func rows(running: String?) -> [FleetSetup.Row] {
        FleetSetup.rows(["software": [
            ["name": "Google Chrome", "status": running == "chrome" ? "running" : "success", "software_title_id": 936],
            ["name": "Okta Verify", "status": running == "okta" ? "running" : "pending", "software_title_id": 42909]
        ]])
    }

    /// No filename on the event: the snapshot's running row is the link.
    func testTheRunningRowClaimsAnUnnamedInstall() {
        var join = FleetSetup.Join()
        let got = join.feed(["install_id": "a", "event": "download_progress", "percent": 40], rows: rows(running: "okta"))
        XCTAssertEqual(got.map(\.0), ["sw-42909"])
    }

    /// A lagging snapshot holds the next install's events until it catches up, then releases them to the right row.
    func testALaggingSnapshotNeverHandsOneRowTwoInstalls() {
        var join = FleetSetup.Join()
        _ = join.feed(["install_id": "a", "event": "install_started"], rows: rows(running: "chrome"))
        XCTAssertTrue(join.feed(["install_id": "b", "event": "download_started"], rows: rows(running: "chrome")).isEmpty)
        XCTAssertTrue(join.release(rows: rows(running: "chrome")).isEmpty, "still lagging: held")
        XCTAssertEqual(join.release(rows: rows(running: "okta")).map(\.0), ["sw-42909"])
    }

    /// After orbit rotates the events file to .1, the reader finishes the old file, then reads the new one.
    func testRotationLosesNoEvents() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fleet-rotate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let snap = dir.appendingPathComponent("setup_experience_progress.json")
        let events = dir.appendingPathComponent(FleetSetup.eventsFileName)
        try #"{"version":1,"software":[{"name":"Google Chrome","status":"running","software_title_id":936}]}"#
            .write(to: snap, atomically: true, encoding: .utf8)
        func line(_ e: String, _ pct: Int? = nil) -> String {
            #"{"version":1,"install_id":"a","event":"\#(e)""# + (pct.map { #","percent":\#($0)"# } ?? "")
                + #","filename":"googlechrome.pkg"}"# + "\n"
        }
        try (line("download_started") + line("download_progress", 20)).write(to: events, atomically: false, encoding: .utf8)
        let source = FleetSetupSource(snapshotPath: snap.path, eventsPath: events.path, items: [], emit: { _ in })
        source.tick()
        XCTAssertEqual(source.live["sw-936"]?.percent, 20)

        // An unread line lands in the old file before rotation.
        let h = try FileHandle(forWritingTo: events); h.seekToEndOfFile(); h.write(Data(line("download_progress", 45).utf8)); try h.close()
        try FileManager.default.moveItem(at: events, to: URL(fileURLWithPath: events.path + ".1"))
        try line("download_progress", 70).write(to: events, atomically: false, encoding: .utf8)
        source.tick()
        XCTAssertEqual(source.live["sw-936"]?.percent, 70, "the new file read after the old one's tail")

        try (line("download_progress", 70) + line("downloaded", 100)).write(to: events, atomically: false, encoding: .utf8)
        source.tick()
        XCTAssertEqual(source.live["sw-936"]?.text, "Downloaded")
    }

    /// No events path is guessed beside the snapshot; only a configured one is read.
    func testNoEventsPathReadsNoEvents() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fleet-noevents-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let snap = dir.appendingPathComponent("setup_experience_progress.json")
        try #"{"version":1,"software":[{"name":"Google Chrome","status":"running","software_title_id":936}]}"#
            .write(to: snap, atomically: true, encoding: .utf8)
        try #"{"version":1,"install_id":"a","event":"download_progress","percent":20,"filename":"googlechrome.pkg"}"#
            .appending("\n").write(to: dir.appendingPathComponent(FleetSetup.eventsFileName), atomically: true, encoding: .utf8)
        let source = FleetSetupSource(snapshotPath: snap.path, items: [], emit: { _ in })
        source.tick()
        XCTAssertNil(source.live["sw-936"])
    }

    /// The logged file state tells a missing file from an unreadable one.
    func testFileStateTellsMissingFromUnreadable() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
            try? FileManager.default.removeItem(at: dir)
        }
        let file = dir.appendingPathComponent("setup_experience_progress.json")
        XCTAssertEqual(FleetSetupSource.fileState(file.path), "missing")
        try "{}".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertEqual(FleetSetupSource.fileState(file.path), "readable")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        XCTAssertEqual(FleetSetupSource.fileState(file.path), "not readable (permissions)")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: dir.path)
        XCTAssertEqual(FleetSetupSource.fileState(file.path), "not readable (folder permissions)")
    }
}

// MARK: - Row icons: `itemicon:` and fleet icons

final class ItemIconCommandTests: XCTestCase {
    /// The value keeps its own colons (a URL).
    @MainActor
    func testItemIconCarriesAURLWhole() {
        let router = CommandRouter()
        var got: (String, String)?
        router.onItemIcon = { got = ($0, $1) }
        router.processCommand("itemicon:sw-83571:https://fleet.example.com/icon.png")
        XCTAssertEqual(got?.0, "sw-83571")
        XCTAssertEqual(got?.1, "https://fleet.example.com/icon.png")
        router.processCommand("itemicon:sw-83571:")
        XCTAssertEqual(got?.1, "", "empty clears the override")
    }

    /// Only titles the snapshot marks as having an icon are requested, through the device route.
    func testTheSnapshotSaysWhichTitlesHaveAnIcon() {
        let rows = FleetSetup.rows(["software": [
            ["name": "Fleet Desktop", "status": "running", "software_title_id": 83571,
             "icon_url": "/api/latest/fleet/software/titles/83571/icon?team_id=3"],
            ["name": "Slack", "status": "pending", "software_title_id": 2792]
        ]])
        XCTAssertEqual(rows.filter(\.hasIcon).map(\.titleID), [83571])
        XCTAssertEqual(FleetSetup.iconURL(server: "https://fleet.example.com/", token: "T", titleID: 83571)?.absoluteString,
                       "https://fleet.example.com/api/latest/fleet/device/T/software/titles/83571/icon")
    }
}

// MARK: - A long install list follows the work

final class InstallFocusRowTests: XCTestCase {
    private func row(_ id: String, _ status: StepStatus) -> InstallationItemData {
        InstallationItemData(id: id, displayName: id, status: status)
    }

    func testTheRunningRowIsTheOneInView() {
        XCTAssertEqual(InstallMath.focusRow([row("a", .completed), row("b", .active), row("c", .pending)]), "b")
    }

    func testBetweenInstallsTheNextOneWaitingIs() {
        XCTAssertEqual(InstallMath.focusRow([row("a", .completed), row("b", .failed), row("c", .pending)]), "c")
    }

    func testAFinishedListLeavesTheReaderWhereTheyAre() {
        XCTAssertNil(InstallMath.focusRow([row("a", .completed), row("b", .failed)]))
    }
}

// MARK: - Tailing a log while it is written

extension LogMonitorServiceTests {
    /// A line caught mid-write is matched once, whole.
    func testALineWrittenInTwoPartsIsMatchedWhole() throws {
        let path = try XCTUnwrap(testLogPath)
        FileManager.default.createFile(atPath: path, contents: nil)
        let config = try JSONDecoder().decode(InspectConfig.LogMonitorConfig.self,
                                              from: Data(#"{"path": "\#(path)", "pattern": "^status: (.+)$"}"#.utf8))
        let monitor = LogFileMonitor(config: config, path: path)
        let lock = NSLock()
        var statuses: [String] = []
        let whole = expectation(description: "the whole line")
        monitor.onStatusExtracted = { event in
            lock.withLock { statuses.append(event.text) }
            if event.text == "half done" { whole.fulfill() }
        }
        monitor.start()
        defer { monitor.stop() }

        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
        defer { try? handle.close() }
        handle.write(Data("status: half".utf8))
        Thread.sleep(forTimeInterval: 0.3)          // the monitor reads the unfinished line
        handle.write(Data(" done\n".utf8))
        wait(for: [whole], timeout: 5)
        XCTAssertEqual(lock.withLock { statuses }, ["half done"])
    }
}

/// Log patterns are compiled once, not for every line read.
final class LogPatternRegexCacheTests: XCTestCase {

    func testAPatternIsCompiledOnceAndReused() {
        let cache = LogPatternRegexCache.shared
        let first = cache.regex(for: #"Installed (.+?), version"#)
        XCTAssertNotNil(first)
        XCTAssertTrue(first === cache.regex(for: #"Installed (.+?), version"#))
    }

    func testAnInvalidPatternGivesNoRegexAndNoCapture() {
        XCTAssertNil(LogPatternRegexCache.shared.regex(for: "(unclosed"))
        XCTAssertNil(LogPatternPreset.firstCapture(in: "anything", pattern: "(unclosed", group: 0))
    }
}

/// Rows Fleet serves no icon for get macOS's own bundle for that kind of work.
final class FleetSetupSystemIconTests: XCTestCase {
    func testEveryNonSoftwareKindHasAnIconThatExists() {
        for kind in [FleetSetup.Row.Kind.bootstrap, .profile, .script] {
            let path = FleetSetup.systemIcon(for: kind)
            XCTAssertNotNil(path, "\(kind)")
            XCTAssertTrue(FileManager.default.fileExists(atPath: path ?? ""), "\(kind): \(path ?? "nil")")
        }
        XCTAssertNil(FleetSetup.systemIcon(for: .software), "Fleet serves software icons")
    }
}
