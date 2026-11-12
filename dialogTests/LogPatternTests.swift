//
//  LogPatternTests.swift
//  dialogTests
//
//  The log monitor's presets and routing: pattern classification, the Installomator, Munki, Jamf
//  and orbit evidence, route targets, aliases, failure classification and the detection
//  mechanics table that names the presets.
//

import XCTest
@testable import Dialog

/// The status string is a state machine: a "Failed" prefix marks failure, "Completed" marks done,
/// anything else is progress. Lines are copied from a real munki run.
final class LogPatternClassifierTests: XCTestCase {

    private let munki = LogPatternPreset.presets["munki"]!

    func testARealProgressLineIsStillProgress() {
        let line = "2026-08-19 21:39:41.123+00:00 Downloading PPPC Utility-1.5.0.dmg from PPPC Utility-1.5.0.dmg"
        let status = LogPatternPreset.status(for: line, using: munki)
        XCTAssertEqual(status, "Downloading PPPC Utility-1.5.0.dmg from PPPC Utility-1.5.0.dmg")
        XCTAssertFalse(status!.hasPrefix("Failed"))
    }

    func testARealFAILURELineNowReachesTheFailedState() {
        let line = "2026-08-19 21:41:02.001+00:00 WARNING: Download of jamfpppcutility failed: error -1001: The request timed out."
        let status = LogPatternPreset.status(for: line, using: munki)
        XCTAssertNotNil(status, "the failure must be captured at all")
        XCTAssertTrue(LogPatternPreset.isTerminal(line: line, preset: munki),
                      "and be recognised as TERMINAL, not progress")
        // cleanupStatus is the one owner of the "Failed" prefix.
        XCTAssertTrue(LogPatternPreset.cleanupStatus(status!).hasPrefix("Failed"),
                      LogPatternPreset.cleanupStatus(status!))
    }

    func testTheFailureStatusStillCarriesTheItemNameSoItCanBeROUTED() {
        let line = "2026-08-19 21:41:02.001+00:00 WARNING: Download of jamfpppcutility failed: error -1001: The request timed out."
        XCTAssertTrue(LogPatternPreset.status(for: line, using: munki)!.contains("jamfpppcutility"))
    }

    func testFailureIsTestedBEFOREProgressSoAFailingDownloadIsNotReadAsRunning() {
        let line = "2026-08-19 21:41:02.001+00:00 WARNING: Download of Firefox failed: error -1001: The request timed out."
        XCTAssertTrue(LogPatternPreset.isTerminal(line: line, preset: munki))
        XCTAssertTrue(LogPatternPreset.cleanupStatus(
            LogPatternPreset.status(for: line, using: munki)!).hasPrefix("Failed"))
    }

    func testAPresetWithASuccessPatternCanReachCompleted() {
        let preset = LogPatternPreset(pattern: #"^(Doing .*)$"#, captureGroup: 1,
                                      failurePattern: nil,
                                      successPattern: #"^Finished\b.*$"#)
        XCTAssertEqual(LogPatternPreset.status(for: "Finished the thing", using: preset), "Completed")
        XCTAssertEqual(LogPatternPreset.status(for: "Doing the thing", using: preset), "Doing the thing")
    }

    func testMunkiSuccessPatternMatchesTheOBSERVEDWording() {
        let installed = "2026-08-19 23:11:51.385+00:00     The software was successfully installed."
        let removed   = "2026-08-19 23:14:37.520+00:00     The software was successfully removed."
        XCTAssertEqual(LogPatternPreset.status(for: installed, using: munki), "Completed")
        XCTAssertEqual(LogPatternPreset.status(for: removed, using: munki), "Completed")

        // munki announces intent long before it acts; that line is not success.
        let intent = "2026-08-19 23:11:46.528+00:00 The following items will be installed or upgraded:"
        XCTAssertNotEqual(LogPatternPreset.status(for: intent, using: munki), "Completed")
    }

    func testAnUnrelatedLineIsIgnored() {
        let line = "2026-08-19 21:39:41.075+00:00 Obsidian version 1.8.10 (or newer) is already installed."
        XCTAssertNil(LogPatternPreset.status(for: line, using: munki))
    }
}

/// Installomator lines from a real run; the success pattern is the observed wording.
final class InstallomatorPresetTests: XCTestCase {

    private let preset = LogPatternPreset.presets["installomator"]!

    func testTheREALSuccessLineNowReachesCompleted() {
        let line = "2026-08-19 22:42:57 : REQ   : desktoppr : Installed desktoppr, version 0.5-218"
        XCTAssertEqual(LogPatternPreset.status(for: line, using: preset), "Completed")
    }

    func testASuccessLineNamingAnAppWithSpacesReachesCompleted() {
        let line = "2026-08-19 22:42:57 : REQ   : googlechrome : Installed Google Chrome, version 120.0.6099.109"
        XCTAssertEqual(LogPatternPreset.status(for: line, using: preset), "Completed")
    }

    func testTheOldSuccessAlternationNeverMatchedRealOutput() {
        let imagined = "2026-08-19 22:42:57 : REQ   : desktoppr : Installed version: 0.5"
        let real     = "2026-08-19 22:42:57 : REQ   : desktoppr : Installed desktoppr, version 0.5-218"
        XCTAssertNotEqual(imagined, real)
        XCTAssertEqual(LogPatternPreset.status(for: real, using: preset), "Completed")
    }

    func testProgressStillReadsAsProgress() {
        let line = "2026-08-19 22:42:52 : INFO  : desktoppr : Installing desktoppr"
        let status = LogPatternPreset.status(for: line, using: preset)
        XCTAssertEqual(status, "Installing desktoppr")
        XCTAssertFalse(LogPatternPreset.isTerminal(line: line, preset: preset))
    }

    func testTheCapturedProgressCarriesTheLabelSoAutoMatchCanRouteIt() {
        // Installomator names the label (munki names the file), so autoMatch is viable here.
        let line = "2026-08-19 22:42:52 : INFO  : desktoppr : Installing desktoppr"
        XCTAssertTrue(LogPatternPreset.status(for: line, using: preset)!.contains("desktoppr"))
    }
}

/// munki's success line names no item, so attribution comes from the scope the
/// "Installing X (n of m)" line opened.
final class MunkiScopeAttributionTests: XCTestCase {

    private let preset = LogPatternPreset.presets["munki"]!

    func testInstallLineOpensAScopeNamingTheItem() {
        let line = "2026-08-19 23:11:46.688+00:00 Installing Firefox (1 of 1)"
        XCTAssertEqual(LogPatternPreset.scopeName(for: line, using: preset), "Firefox")
    }

    func testTheSuccessLineNamesNothing() {
        let line = "2026-08-19 23:11:51.385+00:00     The software was successfully installed."
        XCTAssertNil(LogPatternPreset.scopeName(for: line, using: preset))
        XCTAssertEqual(LogPatternPreset.status(for: line, using: preset), "Completed")
        XCTAssertTrue(LogPatternPreset.isTerminal(line: line, preset: preset))
    }

    func testDownloadProgressOpensNoScopeBecauseItNamesTheFileNotTheItem() {
        let line = "2026-08-19 23:11:40.000+00:00     Downloading Firefox-140.0.4.dmg..."
        XCTAssertNil(LogPatternPreset.scopeName(for: line, using: preset))
    }
}

/// Routing precedence: a line that names an item routes by its text; the scope is consulted only
/// when the text matches no item.
final class LogRouteTargetTests: XCTestCase {

    private let items = [LogRouteCandidate(id: "firefox", displayName: "Firefox"),
                         LogRouteCandidate(id: "jamfpppc", displayName: "JamfPPPCUtility")]

    func testTextThatNamesAnItemWinsOverTheScope() {
        let targets = LogPatternPreset.routeTargets(
            status: "Installing Firefox (1 of 2)", scope: "JamfPPPCUtility", items: items)
        XCTAssertEqual(targets, ["firefox"])
    }

    func testAnonymousTerminalLineFallsBackToTheOpenScope() {
        let targets = LogPatternPreset.routeTargets(
            status: "Completed", scope: "JamfPPPCUtility", items: items)
        XCTAssertEqual(targets, ["jamfpppc"])
    }

    func testAnonymousLineWithNoScopeRoutesNowhereRatherThanEverywhere() {
        // Routing an anonymous success everywhere would mark the whole list done on one install.
        XCTAssertEqual(LogPatternPreset.routeTargets(status: "Completed", scope: nil, items: items), [])
    }

    func testShortItemIdsOverMatch() {
        // Routing is substring-based on id and displayName, so a short id captures unrelated lines.
        let short = [LogRouteCandidate(id: "pppc", displayName: "JamfPPPCUtility")]
        XCTAssertEqual(LogPatternPreset.routeTargets(
            status: "Downloading PPPC Utility-1.5.0.dmg...", scope: nil, items: short), ["pppc"])

        let long = [LogRouteCandidate(id: "jamfpppc", displayName: "JamfPPPCUtility")]
        XCTAssertEqual(LogPatternPreset.routeTargets(
            status: "Downloading PPPC Utility-1.5.0.dmg...", scope: nil, items: long), [])
    }

    func testAScopeThatMatchesNoConfiguredItemRoutesNowhere() {
        XCTAssertEqual(LogPatternPreset.routeTargets(
            status: "Completed", scope: "SomeOtherApp", items: items), [])
    }

    func testFileNamedProgressRoutesOnlyByLUCKOfNaming() {
        // The download line names the file; it routes only when the file name contains the item.
        XCTAssertEqual(LogPatternPreset.routeTargets(
            status: "Downloading Firefox-140.0.4.dmg...", scope: nil, items: items), ["firefox"])
        XCTAssertEqual(LogPatternPreset.routeTargets(
            status: "Downloading PPPC Utility-1.5.0.dmg...", scope: nil, items: items), [])
        XCTAssertEqual(LogPatternPreset.routeTargets(
            status: "Downloading PPPC Utility-1.5.0.dmg...", scope: "JamfPPPCUtility", items: items), ["jamfpppc"])
    }
}


/// logAliases routes log text that names something the row's id and displayName do not.
final class LogAliasRoutingTests: XCTestCase {

    private let aliased = [LogRouteCandidate(id: "jamfpppc", displayName: "JamfPPPCUtility",
                                             aliases: ["PPPC Utility"])]

    func testAnAliasRoutesAFileNamedLineThatNothingElseMatches() {
        XCTAssertEqual(LogPatternPreset.routeTargets(
            status: "Downloading PPPC Utility-1.5.0.dmg...", scope: nil, items: aliased), ["jamfpppc"])
    }

    func testWithoutTheAliasTheSameLineRoutesNowhere() {
        let bare = [LogRouteCandidate(id: "jamfpppc", displayName: "JamfPPPCUtility")]
        XCTAssertEqual(LogPatternPreset.routeTargets(
            status: "Downloading PPPC Utility-1.5.0.dmg...", scope: nil, items: bare), [])
    }

    func testAnAliasDoesNotWidenMatchingToUnrelatedLines() {
        XCTAssertEqual(LogPatternPreset.routeTargets(
            status: "Downloading Firefox-140.0.4.dmg...", scope: nil, items: aliased), [])
    }
}

/// Installomator failure lines: the label sits outside the capture and reaches a row through the
/// scope; the capture skips the "ERROR: " prefix because cleanupStatus stamps its own.
final class InstallomatorFailureEvidenceTests: XCTestCase {

    private let preset = LogPatternPreset.presets["installomator"]!
    private let failureLine = "2026-08-20 06:32:51 : ERROR : desktoppr : ERROR: not running as root, exiting"

    func testTheFailureIsClassifiedAsTerminal() {
        XCTAssertTrue(LogPatternPreset.isTerminal(line: failureLine, preset: preset))
    }

    func testTheRedundantERRORPrefixIsNotCarriedIntoTheStatus() {
        let status = LogPatternPreset.status(for: failureLine, using: preset)
        XCTAssertEqual(status, "not running as root, exiting")
    }

    func testTheLabelOpensAScopeSoTheFailureCanRouteToARow() {
        XCTAssertEqual(LogPatternPreset.scopeName(for: failureLine, using: preset), "desktoppr")

        let items = [LogRouteCandidate(id: "desktoppr", displayName: "desktoppr")]
        let scope = LogPatternPreset.scopeName(for: failureLine, using: preset)
        let status = LogPatternPreset.status(for: failureLine, using: preset)!
        XCTAssertEqual(LogPatternPreset.routeTargets(status: status, scope: scope, items: items),
                       ["desktoppr"],
                       "an Installomator failure that cannot reach a row is only half a fix")
    }

    func testEveryLineKindOpensTheScopeBecauseInstallomatorAlwaysNamesTheLabel() {
        let lines = [
            "2026-08-19 22:42:52 : INFO  : desktoppr : Installing desktoppr",
            "2026-08-19 22:42:57 : REQ   : desktoppr : Installed desktoppr, version 0.5-218",
            "2026-08-20 06:32:51 : ERROR : desktoppr : ERROR: not running as root, exiting"
        ]
        for line in lines {
            XCTAssertEqual(LogPatternPreset.scopeName(for: line, using: preset), "desktoppr", line)
        }
    }

    func testTheSuccessRunStillBehaves() {
        let installed = "2026-08-19 22:42:57 : REQ   : desktoppr : Installed desktoppr, version 0.5-218"
        XCTAssertEqual(LogPatternPreset.status(for: installed, using: preset), "Completed")
    }
}

/// A line that matched the failure pattern is stamped failed whatever its wording; word sniffing
/// remains for callers that do not know.
final class FailureClassificationTests: XCTestCase {

    func testAKnownFailureIsStampedRegardlessOfItsWording() {
        XCTAssertEqual(LogPatternPreset.cleanupStatus("not running as root, exiting", isFailure: true),
                       "Failed: not running as root, exiting")
    }

    func testTheWordSniffingStillWorksWhenTheCallerDoesNotKnow() {
        XCTAssertEqual(LogPatternPreset.cleanupStatus("Download error 404"),
                       "Failed: Download error 404")
    }

    func testAKnownFailureIsNotDoublePrefixed() {
        XCTAssertEqual(LogPatternPreset.cleanupStatus("Download of X failed: timed out", isFailure: true),
                       "Failed: Download of X failed: timed out")
    }

    func testNeutralProgressIsUntouchedWhenNotAFailure() {
        XCTAssertEqual(LogPatternPreset.cleanupStatus("not running as root, exiting"),
                       "not running as root, exiting")
    }
}

/// jamf writes syslog lines with no level field; the hostname can contain spaces, so the anchor
/// is the process field.
final class JamfEvidenceTests: XCTestCase {

    private let preset = LogPatternPreset.presets["jamf"]!

    private let success  = "Thu Aug 20 06:59:07 MAC-FRUIT-0042 jamf[33329]: Successfully installed Obsidian-1.12.7.pkg."
    private let policy   = "Thu Aug 20 00:46:57 MAC-FRUIT-0042 jamf[22705]: Executing Policy Set Proxy on Network Change (proxy.pac)"
    private let checkin  = "Thu Aug 20 00:24:51 MAC-FRUIT-0042 jamf[21937]: Checking for policies triggered by \"recurring check-in\" for user \"U000042\"..."
    private let spacedHost = "Wed Aug 19 08:37:50 MacBook Pro jamf[1974]: Successfully installed Thing-1.0.pkg."

    func testTheSuccessLineCompletesARow() {
        XCTAssertEqual(LogPatternPreset.status(for: success, using: preset), "Completed")
        XCTAssertTrue(LogPatternPreset.isTerminal(line: success, preset: preset))
    }

    func testAHostnameWithSpacesStillParses() {
        XCTAssertEqual(LogPatternPreset.status(for: spacedHost, using: preset), "Completed")
    }

    func testPolicyExecutionReadsAsProgress() {
        let status = LogPatternPreset.status(for: policy, using: preset)
        XCTAssertEqual(status, "Executing Policy Set Proxy on Network Change (proxy.pac)")
        XCTAssertFalse(LogPatternPreset.isTerminal(line: policy, preset: preset))
    }

    func testRoutineCheckInChatterIsIgnored() {
        XCTAssertNil(LogPatternPreset.status(for: checkin, using: preset))
    }

    func testTheSuccessTextCarriesThePackageSoItCanRoute() {
        let status = LogPatternPreset.status(for: success, using: preset)!
        let scope  = LogPatternPreset.scopeName(for: success, using: preset)
        let items  = [LogRouteCandidate(id: "obsidian", displayName: "Obsidian")]
        XCTAssertEqual(LogPatternPreset.routeTargets(status: status, scope: scope, items: items),
                       ["obsidian"])
    }

    // Line shapes as jamf writes them; host, user and package names are fictional.
    private let installing = "Thu Aug 20 07:10:01 MAC-FRUIT-0042 jamf[4242]: Installing Example Helper 2.1.0.pkg..."
    private let failed = "Thu Aug 20 07:10:05 MAC-FRUIT-0042 jamf[4242]: Installation failed. The installer reported: installer: Package name is Helper Suite"
    private let download = "Thu Aug 20 07:12:00 MAC-FRUIT-0042 jamf[4242]: Error: Package was not successfully downloaded. -1001"
    private let zipped = "Thu Aug 20 07:11:00 MAC-FRUIT-0042 jamf[4242]: Successfully installed Example_Agent_4_0_0.zip."
    private let offline = "Thu Aug 20 07:13:00 MAC-FRUIT-0042 jamf[4242]: Could not connect to the JSS. Looking for cached policies..."

    func testAnInstallLineReadsAsProgressAndOpensTheScope() {
        XCTAssertEqual(LogPatternPreset.status(for: installing, using: preset), "Installing Example Helper 2.1.0.pkg...")
        XCTAssertFalse(LogPatternPreset.isTerminal(line: installing, preset: preset))
        XCTAssertEqual(LogPatternPreset.scopeName(for: installing, using: preset), "Example Helper 2.1.0")
    }

    func testAFailedInstallIsAFailureRoutedByTheOpenScope() {
        XCTAssertTrue(LogPatternPreset.isTerminal(line: failed, preset: preset))
        let status = LogPatternPreset.status(for: failed, using: preset)!
        XCTAssertTrue(status.hasPrefix("Installation failed."), status)
        let scope = LogPatternPreset.scopeName(for: installing, using: preset)
        let items = [LogRouteCandidate(id: "example-helper", displayName: "Example Helper"),
                     LogRouteCandidate(id: "obsidian", displayName: "Obsidian")]
        // The installer's package name is not the row's name, so only the open scope can route it.
        XCTAssertEqual(LogPatternPreset.routeTargets(status: status, scope: nil, items: items), [])
        XCTAssertEqual(LogPatternPreset.routeTargets(status: status, scope: scope, items: items), ["example-helper"])
    }

    func testAFailedDownloadIsAFailure() {
        XCTAssertTrue(LogPatternPreset.isTerminal(line: download, preset: preset))
        XCTAssertNotNil(preset.failurePattern.flatMap { LogPatternPreset.firstCapture(in: download, pattern: $0, group: 1) })
    }

    func testAZipPackageCompletes() {
        XCTAssertEqual(LogPatternPreset.status(for: zipped, using: preset), "Completed")
        XCTAssertEqual(LogPatternPreset.scopeName(for: zipped, using: preset), "Example_Agent_4_0_0")
    }

    func testDeviceLevelErrorsAreNotItemFailures() {
        XCTAssertNil(LogPatternPreset.status(for: offline, using: preset))
        XCTAssertFalse(LogPatternPreset.isTerminal(line: offline, preset: preset))
    }
}

/// orbit keys every line by an opaque installer UUID; only the download line names the software,
/// so its file name opens the scope. Installs run sequentially, so one open scope suffices.
final class OrbitEvidenceTests: XCTestCase {

    private let preset = LogPatternPreset.presets["orbit"]!

    private let downloaded = "2026-01-15T09:03:28+00:00 INF software installer downloaded installerID=11111111-2222-4333-8444-555555555555 installerPath=/tmp/1000000001/MicrosoftTeams.pkg runner=installer"
    private let running    = "2026-01-15T09:03:28+00:00 INF about to run install script installerID=11111111-2222-4333-8444-555555555555 runner=installer"
    private let ok         = "2026-01-15T09:03:51+00:00 INF install script exitCode=0 installerID=11111111-2222-4333-8444-555555555555 runner=installer"
    private let failed     = "2026-01-15T09:03:51+00:00 INF install script exitCode=1 installerID=11111111-2222-4333-8444-555555555555 runner=installer"
    private let noise      = "2026-08-20T07:16:55+00:00 INF didn't find configuration values in system profile, trying again in 30 seconds"

    func testExitCodeZeroCompletesTheRow() {
        XCTAssertEqual(LogPatternPreset.status(for: ok, using: preset), "Completed")
        XCTAssertTrue(LogPatternPreset.isTerminal(line: ok, preset: preset))
    }

    func testANonZeroExitCodeFailsTheRow() {
        XCTAssertTrue(LogPatternPreset.isTerminal(line: failed, preset: preset))
        XCTAssertNotEqual(LogPatternPreset.status(for: failed, using: preset), "Completed")
    }

    func testTheInstallerPathOpensAScopeNamedAfterTheFile() {
        XCTAssertEqual(LogPatternPreset.scopeName(for: downloaded, using: preset),
                       "MicrosoftTeams.pkg")
    }

    func testTheUUIDLinesOpenNoScope() {
        XCTAssertNil(LogPatternPreset.scopeName(for: running, using: preset))
        XCTAssertNil(LogPatternPreset.scopeName(for: ok, using: preset))
    }

    func testTheExitCodeLineRoutesThroughTheScopeToARow() {
        // The file name and the row's display name differ, so an alias closes the gap.
        let items = [LogRouteCandidate(id: "msteams", displayName: "Microsoft Teams",
                                       aliases: ["MicrosoftTeams"])]
        let scope = LogPatternPreset.scopeName(for: downloaded, using: preset)
        let status = LogPatternPreset.status(for: ok, using: preset)!
        XCTAssertEqual(LogPatternPreset.routeTargets(status: status, scope: scope, items: items),
                       ["msteams"])
    }

    func testStartupChatterIsIgnored() {
        XCTAssertNil(LogPatternPreset.status(for: noise, using: preset))
    }

    func testDownloadAndInstallPhasesReadAsProgress() {
        for line in [downloaded, running] {
            let status = LogPatternPreset.status(for: line, using: preset)
            XCTAssertNotNil(status, line)
            XCTAssertFalse(LogPatternPreset.isTerminal(line: line, preset: preset), line)
        }
    }
}

// MARK: - Detection mechanics

/// Every mechanic is a log preset, so `--inspect-lint --explain` can show its caveat under that preset.
final class DetectionMechanicsTests: XCTestCase {

    func testEveryMechanicIsARealLogPreset() {
        for m in DetectionMechanic.allCases {
            XCTAssertNotNil(LogPatternPreset.presets[m.rawValue], "\(m.rawValue) is not a log preset")
            XCTAssertFalse(m.caveat.isEmpty)
        }
    }
}
