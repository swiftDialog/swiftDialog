//
//  ItemBaseOverridesTests.swift
//  dialogTests
//
//  `wireItemBase` is the one wiring of the item presets' commands; Preset 4 states its four
//  differences through `overrides` rather than re-wiring the router.
//

import XCTest
@testable import Dialog

@MainActor
final class ItemBaseOverridesTests: XCTestCase {

    private func wire(_ overrides: ((CommandRouter) -> Void)?) -> (CommandRouter, InspectState, String) {
        let state = InspectState()
        state.items = [InspectConfig.ItemConfig(id: "a", displayName: "A", paths: ["/nonexistent/a"]),
                       InspectConfig.ItemConfig(id: "b", displayName: "B", paths: ["/nonexistent/b"])]
        let path = NSTemporaryDirectory() + "item-base-\(UUID().uuidString).trigger"
        let router = CommandRouter()
        router.wireItemBase(state: state, presetLabel: "Test", triggerFilePath: path, overrides: overrides)
        return (router, state, path)
    }

    func testTheBaseHandlersAreWiredWithoutOverrides() {
        let (router, state, path) = wire(nil)
        defer { router.stopMonitoring(); try? FileManager.default.removeItem(atPath: path) }

        router.onProgress?("a", 40)
        XCTAssertEqual(state.itemProgress["a"], 40, "the base progress is per item")
        router.onComplete?("a")
        XCTAssertTrue(state.completedItems.contains("a"))
    }

    func testAnOverrideReplacesOnlyWhatItNamesAndResetCanExtendTheBase() {
        var extraReset = false
        let (router, state, path) = wire { router in
            router.onProgress = { _, _ in }                       // one overall bar: no per-item write
            let baseReset = router.onReset
            router.onReset = { baseReset?(); extraReset = true }
        }
        defer { router.stopMonitoring(); try? FileManager.default.removeItem(atPath: path) }

        router.onProgress?("a", 40)
        XCTAssertNil(state.itemProgress["a"], "the override took the progress line")

        router.onComplete?("b")
        XCTAssertTrue(state.completedItems.contains("b"), "everything not overridden is still the base")

        state.itemProgress["a"] = 10
        router.onReset?()
        XCTAssertTrue(extraReset)
        XCTAssertTrue(state.completedItems.isEmpty && state.itemProgress.isEmpty,
                      "the extended reset still ran the base reset")
    }

    func testPreset4DeclaresItsFourDifferencesThroughTheHook() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent(
            "dialog/Views/Inspect/Preset Layouts/Preset4.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("commandRouter.wireItemBase("))
        XCTAssertFalse(source.contains("commandRouter.onComplete ="), "Preset 4 must not re-wire the base")
        XCTAssertFalse(source.contains("commandRouter.startMonitoring"), "the base starts monitoring")
    }
}
