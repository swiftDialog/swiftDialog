//
//  RequiredItemsTests.swift
//  dialogTests
//
//  The item presets' primary button waits for required items only (`required: false` opts out),
//  and is re-checked from `completedItems` / `failedItems` whichever source writes them.
//

import XCTest
@testable import Dialog

@MainActor
final class RequiredItemsTests: XCTestCase {

    private func state(_ itemsJSON: String) throws -> InspectState {
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data("""
        {"preset":"1","title":"t","autoEnableButtonText":"Done","items":[\(itemsJSON)]}
        """.utf8))
        let state = InspectState()
        state.config = config
        state.items = config.items
        return state
    }

    private let three = """
    {"id":"edr","displayName":"Agent","guiIndex":0,"paths":["/nonexistent/a"]},
    {"id":"vpn","displayName":"VPN","guiIndex":1,"paths":["/nonexistent/b"]},
    {"id":"slack","displayName":"Slack","guiIndex":2,"paths":["/nonexistent/c"],"required":false}
    """

    func testAnItemWithoutTheKeyIsRequired() throws {
        let s = try state(#"{"id":"a","displayName":"A","guiIndex":0,"paths":["/x"]}"#)
        XCTAssertEqual(s.requiredItems.map(\.id), ["a"])
        XCTAssertFalse(s.allRequiredItemsCompleted)
        s.completedItems = ["a"]
        XCTAssertTrue(s.allRequiredItemsCompleted)
    }

    func testAnOptionalItemDoesNotHoldTheButton() throws {
        let s = try state(three)
        XCTAssertEqual(s.requiredItems.map(\.id), ["edr", "vpn"])
        s.completedItems = ["edr"]
        XCTAssertFalse(s.allRequiredItemsCompleted, "a required item is still pending")
        s.completedItems = ["edr", "vpn"]
        s.failedItems = ["slack"]
        XCTAssertTrue(s.allRequiredItemsCompleted, "the optional item failed; the required ones are done")
    }

    func testAFailedRequiredItemStillReleasesTheButton() throws {
        let s = try state(three)
        s.completedItems = ["edr"]
        s.failedItems = ["vpn"]
        XCTAssertFalse(s.allRequiredItemsCompleted, "vpn failed, so not every required item succeeded")
        XCTAssertTrue(s.allRequiredItemsFinished, "but nothing is left running, so the held button releases")
        s.failedItems = []
        XCTAssertFalse(s.allRequiredItemsFinished, "vpn is still pending")
    }

    func testAnEmptyListNeverCountsAsComplete() throws {
        let s = InspectState()
        XCTAssertFalse(s.allRequiredItemsCompleted)
    }

    func testAFailedStatusOverIPCLeavesTheCompletedSet() throws {
        let s = try state(three)
        let router = CommandRouter()
        let trigger = NSTemporaryDirectory() + "required-items-\(UUID().uuidString).trigger"
        router.wireItemBase(state: s, presetLabel: "test", triggerFilePath: trigger)
        defer { router.stopMonitoring(); try? FileManager.default.removeItem(atPath: trigger) }
        s.completedItems = ["vpn"]
        router.onItemStatus?("vpn", "failed", "Not detected")
        XCTAssertFalse(s.completedItems.contains("vpn"))
        XCTAssertTrue(s.failedItems.contains("vpn"))
    }

    /// A completion written straight into the set enables a disabled button once the required
    /// items are done.
    func testCompletingTheRequiredItemsEnablesTheButtonFromAnySource() throws {
        let s = try state(three)
        s.buttonConfiguration.button1Disabled = true
        s.buttonConfiguration.autoEnableButton = true
        s.completedItems.insert("edr")
        s.completedItems.insert("vpn")

        let enabled = expectation(description: "button enabled")
        DispatchQueue.main.asyncAfter(deadline: .now() + InspectConstants.debounceDelay + 0.2) {
            XCTAssertFalse(s.buttonConfiguration.button1Disabled)
            XCTAssertEqual(s.buttonConfiguration.button1Text, "Done")
            enabled.fulfill()
        }
        wait(for: [enabled], timeout: 2)
    }

    func testTheButtonStaysDisabledWhileARequiredItemIsPending() throws {
        let s = try state(three)
        s.buttonConfiguration.button1Disabled = true
        s.completedItems.insert("edr")
        s.failedItems.insert("slack")

        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + InspectConstants.debounceDelay + 0.2) {
            XCTAssertTrue(s.buttonConfiguration.button1Disabled)
            settled.fulfill()
        }
        wait(for: [settled], timeout: 2)
    }
}
