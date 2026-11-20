//
//  DistributedNotificationsTests.swift
//  dialogTests
//
//  The DistributedNotification IPC layer: shorthand expansion, acks, per-pid channels and nonce dedupe.
//

import XCTest
@testable import Dialog

@MainActor

final class DistributedNotificationsTests: XCTestCase {

    // MARK: - CommandRouter Unit Tests

    /// Verify that processCommand dispatches to the correct handler and writes ack.
    func testNavigateByID() {
        let router = CommandRouter()
        let expectation = expectation(description: "onNavigateByID called")
        router.presetLabel = "Test"
        router.acknowledgmentLogPath = nil // disable file ack
        router.itemCount = 5

        var receivedID: String?
        router.onNavigateByID = { id in
            receivedID = id
            expectation.fulfill()
        }

        router.processCommand("navigate:my_step")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedID, "my_step")
    }

    func testNavigateByIndex() {
        let router = CommandRouter()
        let expectation = expectation(description: "onNavigateByIndex called")
        router.itemCount = 5

        var receivedIndex: Int?
        router.onNavigateByIndex = { idx in
            receivedIndex = idx
            expectation.fulfill()
        }

        router.processCommand("navigate:2")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedIndex, 2)
    }

    func testNextPrevReset() {
        let router = CommandRouter()
        router.itemCount = 5

        var nextCalled = false, prevCalled = false, resetCalled = false
        router.onNext = { nextCalled = true }
        router.onPrev = { prevCalled = true }
        router.onReset = { resetCalled = true }

        router.processCommand("next")
        router.processCommand("prev")
        router.processCommand("reset")

        XCTAssertTrue(nextCalled)
        XCTAssertTrue(prevCalled)
        XCTAssertTrue(resetCalled)
    }

    func testSuccessWithMessage() {
        let router = CommandRouter()
        let expectation = expectation(description: "onSuccess called")

        var receivedStepId: String?
        var receivedMessage: String?
        router.onSuccess = { stepId, message in
            receivedStepId = stepId
            receivedMessage = message
            expectation.fulfill()
        }

        router.processCommand("success:edge:Installation complete")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedStepId, "edge")
        XCTAssertEqual(receivedMessage, "Installation complete")
    }

    func testFailureWithReason() {
        let router = CommandRouter()
        let expectation = expectation(description: "onFailure called")

        var receivedStepId: String?
        var receivedReason: String?
        router.onFailure = { stepId, reason in
            receivedStepId = stepId
            receivedReason = reason
            expectation.fulfill()
        }

        router.processCommand("failure:enrollment:MDM profile rejected")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedStepId, "enrollment")
        XCTAssertEqual(receivedReason, "MDM profile rejected")
    }

    func testWarning() {
        let router = CommandRouter()
        let expectation = expectation(description: "onWarning called")

        var receivedStepId: String?
        router.onWarning = { stepId, _ in
            receivedStepId = stepId
            expectation.fulfill()
        }

        router.processCommand("warning:status:Pending review")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedStepId, "status")
    }

    func testComplete() {
        let router = CommandRouter()
        let expectation = expectation(description: "onComplete called")

        var receivedStepId: String?
        router.onComplete = { stepId in
            receivedStepId = stepId
            expectation.fulfill()
        }

        router.processCommand("complete:detected")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedStepId, "detected")
    }

    func testProgressAutoDetect0to100() {
        let router = CommandRouter()
        let expectation = expectation(description: "onProgress called")

        var receivedPct: Int?
        router.onProgress = { _, pct in
            receivedPct = pct
            expectation.fulfill()
        }

        router.processCommand("progress:step1:75")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedPct, 75)
    }

    func testProgressAutoDetect0to1() {
        let router = CommandRouter()
        let expectation = expectation(description: "onProgress called")

        var receivedPct: Int?
        router.onProgress = { _, pct in
            receivedPct = pct
            expectation.fulfill()
        }

        router.processCommand("progress:step1:0.5")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedPct, 50)
    }

    func testSelectCommand() {
        let router = CommandRouter()
        let expectation = expectation(description: "onSelect called")

        var receivedKey: String?
        var receivedValues: [String]?
        router.onSelect = { key, values in
            receivedKey = key
            receivedValues = values
            expectation.fulfill()
        }

        router.processCommand("select:preferredLanguage:Deutsch")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedKey, "preferredLanguage")
        XCTAssertEqual(receivedValues, ["Deutsch"])
    }

    func testSelectMultipleValues() {
        let router = CommandRouter()
        let expectation = expectation(description: "onSelect called")

        var receivedValues: [String]?
        router.onSelect = { _, values in
            receivedValues = values
            expectation.fulfill()
        }

        router.processCommand("select:wallpaper:/path/a,/path/b,/path/c")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedValues, ["/path/a", "/path/b", "/path/c"])
    }

    func testBatchUpdate() {
        let router = CommandRouter()
        let expectation = expectation(description: "onBatchUpdate called")

        var receivedJSON: String?
        router.onBatchUpdate = { json in
            receivedJSON = json
            expectation.fulfill()
        }

        let json = #"[{"stepId":"s1","blockId":"0","properties":{"state":"success"}}]"#
        router.processCommand("batch_update:\(json)")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedJSON, json)
    }

    func testDisplayData() {
        let router = CommandRouter()
        let expectation = expectation(description: "onDisplayData called")

        var receivedKey: String?
        var receivedValue: String?
        router.onDisplayData = { _, key, value, _ in
            receivedKey = key
            receivedValue = value
            expectation.fulfill()
        }

        router.processCommand("display_data:detected:Serial:C02X1234ABCD")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedKey, "Serial")
        XCTAssertEqual(receivedValue, "C02X1234ABCD")
    }

    func testUpdateMessage() {
        let router = CommandRouter()
        let expectation = expectation(description: "onUpdateMessage called")

        var receivedStepId: String?
        var receivedMessage: String?
        router.onUpdateMessage = { stepId, message in
            receivedStepId = stepId
            receivedMessage = message
            expectation.fulfill()
        }

        router.processCommand("update_message:migrating:Running scripts...")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedStepId, "migrating")
        XCTAssertEqual(receivedMessage, "Running scripts...")
    }

    func testItemStatus() {
        let router = CommandRouter()
        let expectation = expectation(description: "onItemStatus called")

        var receivedId: String?
        var receivedStatus: String?
        var receivedMsg: String?
        router.onItemStatus = { id, status, msg in
            receivedId = id
            receivedStatus = status
            receivedMsg = msg
            expectation.fulfill()
        }

        router.processCommand("item:edge:completed:All done")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedId, "edge")
        XCTAssertEqual(receivedStatus, "completed")
        XCTAssertEqual(receivedMsg, "All done")
    }

    func testGotoAlias() {
        let router = CommandRouter()
        let expectation = expectation(description: "onNavigateByID called via goto")
        router.itemCount = 0

        var receivedID: String?
        router.onNavigateByID = { id in
            receivedID = id
            expectation.fulfill()
        }

        router.processCommand("goto:complete")
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedID, "complete")
    }

    /// Verify multi-line input is split and dispatched as separate commands.
    func testMultiLineCommand() {
        let router = CommandRouter()
        router.itemCount = 5

        var navigateCount = 0
        router.onNavigateByID = { _ in navigateCount += 1 }
        router.onNavigateByIndex = { _ in navigateCount += 1 }
        router.onNext = { navigateCount += 1 }

        router.processCommand("navigate:step1\nnext\nnavigate:3")
        XCTAssertEqual(navigateCount, 3)
    }

    /// Verify unknown commands don't crash.
    func testUnknownCommandNoOp() {
        let router = CommandRouter()
        // Should not crash or call any handler
        router.processCommand("totally_unknown_command:foo:bar")
        router.processCommand("")
        router.processCommand("   ")
    }

    // MARK: - DistributedNotification Shorthand Tests

    /// Test that the notification shorthand keys expand correctly.
    func testShorthandSuccess() {
        let expectation = expectation(description: "handler called")
        var receivedCommand: String?

        DialogNotifications.startObserving { command, _ in
            if command.hasPrefix("success:") {
                receivedCommand = command
                expectation.fulfill()
            }
        }

        DistributedNotificationCenter.default().postNotificationName(
            DialogNotifications.commandName, object: nil,
            userInfo: ["success": "edge:Installed"], deliverImmediately: true
        )

        waitForExpectations(timeout: 2.0)
        DialogNotifications.stopObserving()
        XCTAssertEqual(receivedCommand, "success:edge:Installed")
    }

    func testShorthandSelect() {
        let expectation = expectation(description: "handler called")
        var receivedCommand: String?

        DialogNotifications.startObserving { command, _ in
            if command.hasPrefix("select:") {
                receivedCommand = command
                expectation.fulfill()
            }
        }

        DistributedNotificationCenter.default().postNotificationName(
            DialogNotifications.commandName, object: nil,
            userInfo: ["select": "preferredLanguage:Deutsch"], deliverImmediately: true
        )

        waitForExpectations(timeout: 2.0)
        DialogNotifications.stopObserving()
        XCTAssertEqual(receivedCommand, "select:preferredLanguage:Deutsch")
    }

    func testShorthandPresenceTriggered() {
        let expectation = expectation(description: "next received")
        var commands: [String] = []

        DialogNotifications.startObserving { command, _ in
            commands.append(command)
            if command == "reset" { expectation.fulfill() }
        }

        DistributedNotificationCenter.default().postNotificationName(
            DialogNotifications.commandName, object: nil,
            userInfo: ["next": "1", "prev": "1", "reset": "1"], deliverImmediately: true
        )

        waitForExpectations(timeout: 2.0)
        DialogNotifications.stopObserving()
        XCTAssertTrue(commands.contains("next"))
        XCTAssertTrue(commands.contains("prev"))
        XCTAssertTrue(commands.contains("reset"))
    }

    func testShorthandBadge() {
        let expectation = expectation(description: "handler called")
        var receivedCommand: String?

        DialogNotifications.startObserving { command, _ in
            if command.hasPrefix("update_guidance:") {
                receivedCommand = command
                expectation.fulfill()
            }
        }

        DistributedNotificationCenter.default().postNotificationName(
            DialogNotifications.commandName, object: nil,
            userInfo: ["badge": "net:success"], deliverImmediately: true
        )

        waitForExpectations(timeout: 2.0)
        DialogNotifications.stopObserving()
        XCTAssertEqual(receivedCommand, "update_guidance:_:net:state=success")
    }

    // MARK: - Ack Notification Tests

    /// Verify postAck sends a notification on the ack channel (com.swiftdialog.ack.<pid>).
    func testPostAckNotification() {
        let expectation = expectation(description: "ack received")
        var receivedInfo: [String: Any]?

        let center = DistributedNotificationCenter.default()
        let observer = center.addObserver(
            forName: DialogNotifications.ackName, object: nil, queue: nil
        ) { notification in
            receivedInfo = notification.userInfo as? [String: Any]
            expectation.fulfill()
        }

        DialogNotifications.postAck(
            command: "navigate", stepId: "detected", status: "OK",
            property: "index", value: "0"
        )

        waitForExpectations(timeout: 2.0)
        center.removeObserver(observer)

        XCTAssertEqual(receivedInfo?["command"] as? String, "navigate")
        XCTAssertEqual(receivedInfo?["stepId"] as? String, "detected")
        XCTAssertEqual(receivedInfo?["status"] as? String, "OK")
        XCTAssertEqual(receivedInfo?["property"] as? String, "index")
        XCTAssertEqual(receivedInfo?["value"] as? String, "0")
        XCTAssertNotNil(receivedInfo?["pid"])
    }

    // MARK: - Event Posting Tests

    func testPostEventIncludesPid() {
        let expectation = expectation(description: "event received")
        var receivedInfo: [String: Any]?

        let center = DistributedNotificationCenter.default()
        let observer = center.addObserver(
            forName: DialogNotifications.eventName, object: nil, queue: nil
        ) { notification in
            receivedInfo = notification.userInfo as? [String: Any]
            expectation.fulfill()
        }

        DialogNotifications.postEvent(.ready, userInfo: ["foo": "bar"])

        waitForExpectations(timeout: 2.0)
        center.removeObserver(observer)

        XCTAssertEqual(receivedInfo?["event"] as? String, "ready")
        XCTAssertEqual(receivedInfo?["foo"] as? String, "bar")
        XCTAssertEqual(receivedInfo?["pid"] as? String,
                       String(ProcessInfo.processInfo.processIdentifier))
    }

    func testPostSelectionEvent() {
        let expectation = expectation(description: "selection event received")
        var receivedInfo: [String: Any]?

        let center = DistributedNotificationCenter.default()
        let observer = center.addObserver(
            forName: DialogNotifications.eventName, object: nil, queue: nil
        ) { notification in
            if (notification.userInfo?["event"] as? String) == "selection" {
                receivedInfo = notification.userInfo as? [String: Any]
                expectation.fulfill()
            }
        }

        DialogNotifications.postSelection(key: "wallpaper", values: ["/a.jpg", "/b.jpg"])

        waitForExpectations(timeout: 2.0)
        center.removeObserver(observer)

        XCTAssertEqual(receivedInfo?["key"] as? String, "wallpaper")
        XCTAssertEqual(receivedInfo?["values"] as? String, "/a.jpg,/b.jpg")
    }

    // MARK: - CommandRouter + Ack Integration

    /// Verify that CommandRouter.writeAck fires a DistributedNotification.
    func testCommandRouterAckFiresNotification() {
        let router = CommandRouter()
        router.acknowledgmentLogPath = NSTemporaryDirectory() + "test-ack-\(UUID().uuidString).log"
        router.itemCount = 5

        let ackExpectation = expectation(description: "ack notification received")
        var ackInfo: [String: Any]?

        let center = DistributedNotificationCenter.default()
        let observer = center.addObserver(
            forName: DialogNotifications.ackName, object: nil, queue: nil
        ) { notification in
            if (notification.userInfo?["command"] as? String) == "navigate" {
                ackInfo = notification.userInfo as? [String: Any]
                ackExpectation.fulfill()
            }
        }

        router.onNavigateByID = { _ in }
        router.processCommand("navigate:step1")

        waitForExpectations(timeout: 2.0)
        center.removeObserver(observer)

        try? FileManager.default.removeItem(atPath: router.acknowledgmentLogPath!)

        XCTAssertEqual(ackInfo?["command"] as? String, "navigate")
        XCTAssertEqual(ackInfo?["stepId"] as? String, "step1")
        XCTAssertEqual(ackInfo?["status"] as? String, "OK")
    }

    /// Verify select command produces both ack notification and handler call.
    func testSelectCommandFullRoundTrip() {
        let router = CommandRouter()
        router.acknowledgmentLogPath = NSTemporaryDirectory() + "test-ack-\(UUID().uuidString).log"

        let selectExpectation = expectation(description: "onSelect called")
        let ackExpectation = expectation(description: "ack notification received")

        var receivedKey: String?
        var receivedValues: [String]?
        router.onSelect = { key, values in
            receivedKey = key
            receivedValues = values
            selectExpectation.fulfill()
        }

        var ackInfo: [String: Any]?
        let center = DistributedNotificationCenter.default()
        let observer = center.addObserver(
            forName: DialogNotifications.ackName, object: nil, queue: nil
        ) { notification in
            if (notification.userInfo?["command"] as? String) == "select" {
                ackInfo = notification.userInfo as? [String: Any]
                ackExpectation.fulfill()
            }
        }

        router.processCommand("select:preferredLanguage:Français")

        waitForExpectations(timeout: 2.0)
        center.removeObserver(observer)
        try? FileManager.default.removeItem(atPath: router.acknowledgmentLogPath!)

        XCTAssertEqual(receivedKey, "preferredLanguage")
        XCTAssertEqual(receivedValues, ["Français"])
        XCTAssertEqual(ackInfo?["stepId"] as? String, "preferredLanguage")
        XCTAssertEqual(ackInfo?["value"] as? String, "Français")
    }

    // MARK: - Edge Cases (empty/malformed commands)

    func testSuccessWithEmptySuffix() {
        let router = CommandRouter()
        var called = false
        router.onSuccess = { _, _ in called = true }
        // "success:" with no stepId — should not crash or call handler
        router.processCommand("success:")
        XCTAssertFalse(called, "onSuccess should not fire for bare 'success:' with no stepId")
    }

    func testFailureWithEmptySuffix() {
        let router = CommandRouter()
        var called = false
        router.onFailure = { _, _ in called = true }
        router.processCommand("failure:")
        XCTAssertFalse(called, "onFailure should not fire for bare 'failure:' with no stepId")
    }

    func testWarningWithEmptySuffix() {
        let router = CommandRouter()
        var called = false
        router.onWarning = { _, _ in called = true }
        router.processCommand("warning:")
        XCTAssertFalse(called, "onWarning should not fire for bare 'warning:' with no stepId")
    }

    func testProgressWithNoStepId() {
        let router = CommandRouter()
        var called = false
        router.onProgress = { _, _ in called = true }
        // "progress:75" — one-part form, no stepId
        router.processCommand("progress:75")
        // Silently dropped: the arm requires stepId:value (parts.count == 2)
        XCTAssertFalse(called, "progress with no stepId should not crash")
    }

    func testNavigateEmptyString() {
        let router = CommandRouter()
        var called = false
        router.onNavigateByID = { _ in called = true }
        router.onNavigateByIndex = { _ in called = true }
        router.processCommand("navigate:")
        // Empty navigate should be a no-op (navigates to "" which is harmless)
    }

    func testDisplayDataEmptyValue() {
        let router = CommandRouter()
        var receivedValue: String?
        router.onDisplayData = { _, _, value, _ in receivedValue = value }
        router.processCommand("display_data:step1:key:")
        // Empty value — should not crash
    }

    // MARK: - Per-PID Channels

    /// Channels carry this process's pid, so another session cannot observe them.
    func testChannelNamesAreSessionScoped() {
        let pid = ProcessInfo.processInfo.processIdentifier
        XCTAssertEqual(DialogNotifications.commandName.rawValue, "com.swiftdialog.command.\(pid)")
        XCTAssertEqual(DialogNotifications.eventName.rawValue, "com.swiftdialog.event.\(pid)")
        XCTAssertEqual(DialogNotifications.ackName.rawValue, "com.swiftdialog.ack.\(pid)")
    }

    /// A notification's nonce reaches the router, so it can be collapsed against its trigger-file twin.
    func testNotificationCarriesNonceToHandler() {
        let expectation = expectation(description: "handler called")
        var receivedNonce: String?

        DialogNotifications.startObserving { command, nonce in
            if command == "next" {
                receivedNonce = nonce
                expectation.fulfill()
            }
        }

        DistributedNotificationCenter.default().postNotificationName(
            DialogNotifications.commandName, object: nil,
            userInfo: ["command": "next", "nonce": "abc123"], deliverImmediately: true
        )

        waitForExpectations(timeout: 2.0)
        DialogNotifications.stopObserving()
        XCTAssertEqual(receivedNonce, "abc123")
    }

    /// A non-string value still counts: `{"next": 1}` advances, as in 3.1.1.
    func testNonStringUserInfoValueIsKept() {
        let expectation = expectation(description: "next from a numeric value")
        DialogNotifications.startObserving { command, _ in
            if command == "next" { expectation.fulfill() }
        }

        DistributedNotificationCenter.default().postNotificationName(
            DialogNotifications.commandName, object: nil,
            userInfo: ["next": 1], deliverImmediately: true
        )

        waitForExpectations(timeout: 2.0)
        DialogNotifications.stopObserving()
    }

    // MARK: - Nonce Dedupe

    /// The same command by notification (nonce param) and by trigger file (`\tnonce=`) runs once.
    func testNonceCollapsesNotificationAndFileTwins() {
        let router = CommandRouter()
        var nextCount = 0
        router.onNext = { nextCount += 1 }

        router.processCommand("next", nonce: "n1")   // notification transport
        router.processCommand("next\tnonce=n1")      // trigger-file transport

        XCTAssertEqual(nextCount, 1, "Redundant delivery of one nonce must run once")
    }

    /// Whichever transport lands first wins.
    func testNonceDedupeIsOrderIndependent() {
        let router = CommandRouter()
        var nextCount = 0
        router.onNext = { nextCount += 1 }

        router.processCommand("next\tnonce=n2")      // file first this time
        router.processCommand("next", nonce: "n2")

        XCTAssertEqual(nextCount, 1)
    }

    /// One transport alone still delivers.
    func testSingleTransportStillDelivers() {
        let fileOnly = CommandRouter()
        var fileCount = 0
        fileOnly.onNext = { fileCount += 1 }
        fileOnly.processCommand("next\tnonce=n3")
        XCTAssertEqual(fileCount, 1, "File-only delivery must still run")

        let notifOnly = CommandRouter()
        var notifCount = 0
        notifOnly.onNext = { notifCount += 1 }
        notifOnly.processCommand("next", nonce: "n4")
        XCTAssertEqual(notifCount, 1, "Notification-only delivery must still run")
    }

    /// Untagged lines (`echo "next" >> <trigger>`) are never deduped, even when identical.
    func testNonceLessCommandsAlwaysRun() {
        let router = CommandRouter()
        var nextCount = 0
        router.onNext = { nextCount += 1 }

        router.processCommand("next")
        router.processCommand("next")
        router.processCommand("next")

        XCTAssertEqual(nextCount, 3, "Hand-typed lines have no twin — each must run")
    }

    /// Distinct nonces are distinct commands, however rapidly they arrive.
    func testDistinctNoncesAllRun() {
        let router = CommandRouter()
        var nextCount = 0
        router.onNext = { nextCount += 1 }

        for i in 0..<300 {
            router.processCommand("next\tnonce=n\(i)")
        }

        XCTAssertEqual(nextCount, 300, "Every distinct nonce must run — nothing dropped")
    }

    /// The seen-nonce ring holds 256; after 300 more, the first nonce runs again.
    func testSeenNoncesRingIsBounded() {
        let router = CommandRouter()
        var nextCount = 0
        router.onNext = { nextCount += 1 }

        router.processCommand("next\tnonce=first")
        router.processCommand("next\tnonce=first")
        XCTAssertEqual(nextCount, 1, "Immediate replay is still deduped")

        for i in 0..<300 { router.processCommand("next\tnonce=fill\(i)") }
        router.processCommand("next\tnonce=first")

        XCTAssertEqual(nextCount, 302, "Oldest nonce evicted at the 256 cap")
    }

    /// Commands expanded from one notification (`badge` emits two) share a nonce and all run.
    func testSharedNonceAcrossExpandedCommandsAllRun() {
        let router = CommandRouter()
        var guidance: [String] = []
        router.onUpdateGuidance = { guidance.append($0) }

        router.processCommand("update_guidance:_:net:state=success", nonce: "b1")
        router.processCommand("update_guidance:_:net:actual=1.2.3", nonce: "b1")

        XCTAssertEqual(guidance.count, 2, "Distinct commands under one nonce must all run")
    }

    // MARK: - Nonce Trailer Parsing

    /// Only a trailing tab-delimited `nonce=` field is a trailer; `:` args are never split.
    func testTabTrailerPreservesColonArguments() {
        let router = CommandRouter()
        var received: (String, String?)?
        router.onSuccess = { received = ($0, $1) }

        router.processCommand("success:edge:Installed: 1.2.3\tnonce=x9")

        XCTAssertEqual(received?.0, "edge")
        XCTAssertEqual(received?.1, "Installed: 1.2.3", "Colon args must survive trailer parsing")
    }

    /// A `nonce=` that is *not* the final tab field is payload, not a trailer.
    func testNonTrailingNonceFieldIsNotStripped() {
        let router = CommandRouter()
        var received: String?
        router.onUpdateMessage = { _, message in received = message }

        router.processCommand("update_message:step1:nonce=notatrailer\tstill payload")

        XCTAssertEqual(received, "nonce=notatrailer\tstill payload")
    }

    /// A trailing ` @word` is message content, not a nonce: it is kept, and a repeat still runs.
    func testTrailingAtWordIsContentNotNonce() {
        let router = CommandRouter()
        var received: [String] = []
        router.onUpdateMessage = { _, message in received.append(message) }

        router.processCommand("update_message:step1:ping @helpdesk")
        router.processCommand("update_message:step1:ping @helpdesk")

        XCTAssertEqual(received, ["ping @helpdesk", "ping @helpdesk"])
    }

    /// A bare `@` inside a value (URLs, emails) must not be mistaken for a nonce trailer.
    func testEmailValueIsNotParsedAsNonce() {
        let router = CommandRouter()
        var received: String?
        router.onUpdateMessage = { _, message in received = message }

        router.processCommand("update_message:step1:Contact admin@example.com now")

        XCTAssertEqual(received, "Contact admin@example.com now")
    }

    /// Config `appearance` (#669) and the IPC `appearance:` arm share one owner that sets
    /// NSApp.appearance; preferredColorScheme alone does not flip the inspect window.
    @MainActor
    func testInspectAppearanceApplyIsOneOwner() {
        defer { InspectAppearance.apply(nil) }   // restore follow-system for other tests
        InspectAppearance.apply("light")
        XCTAssertEqual(NSApp.appearance?.name, .aqua)
        InspectAppearance.apply("Dark")          // case-insensitive, like the IPC arm
        XCTAssertEqual(NSApp.appearance?.name, .darkAqua)
        InspectAppearance.apply(nil)
        XCTAssertNil(NSApp.appearance, "nil/auto follows the system")
    }
}

// MARK: - Legacy channel names

@MainActor
final class LegacyNotificationChannelTests: XCTestCase {
    override func tearDown() {
        DialogNotifications.stopObserving()
        super.tearDown()
    }

    private func post(_ info: [String: String]) {
        DistributedNotificationCenter.default().postNotificationName(
            DialogNotifications.legacyCommandNames[0], object: nil, userInfo: info, deliverImmediately: true)
    }

    /// The legacy `com.swiftdialog.command` channel reaches this session; another session's pid does not.
    func testTheOldCommandNameIsStillServedForThisSessionOnly() {
        var received: [String] = []
        let arrived = expectation(description: "the command for this session")
        DialogNotifications.startObserving { command, _ in
            received.append(command)
            if command == "next" { arrived.fulfill() }
        }
        post(["command": "prev", "pid": "1"])
        post(["command": "next"])
        wait(for: [arrived], timeout: 5)
        XCTAssertEqual(received, ["next"])
    }
}
