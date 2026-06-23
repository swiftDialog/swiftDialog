//
//  DistributedNotificationsTests.swift
//  dialogTests
//
//  Unit tests for the DistributedNotification IPC layer:
//    - Command shorthand key expansion
//    - Ack notification posting
//    - Select command round-trip
//    - Ready event enrichment fields
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

        DialogNotifications.startObserving { command in
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

        DialogNotifications.startObserving { command in
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

        DialogNotifications.startObserving { command in
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

        DialogNotifications.startObserving { command in
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

    /// Verify postAck sends a notification on com.swiftdialog.ack.
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

        // Clean up temp file
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
        // Currently silently dropped (parts.count == 1, guard requires 2)
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
}
