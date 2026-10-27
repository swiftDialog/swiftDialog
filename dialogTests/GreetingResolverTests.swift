//
//  GreetingResolverTests.swift
//  dialogTests
//
//  Chrome placeholder resolution ({userName}, {managed:domain:key|fallback}, segment-drop lines),
//  preset sizing, the Preset 5 form wire contract, `IconRef`, and required pickers.
//

import XCTest
@testable import Dialog

@MainActor
final class GreetingResolverTests: XCTestCase {

    var tempBase: URL!

    override func setUp() {
        super.setUp()
        tempBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("managed-prefs-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
        // Documented test seam: redirect the managed-preferences read path.
        CadenceMonitorService.managedPreferencesBase = tempBase.path
    }

    override func tearDown() {
        CadenceMonitorService.managedPreferencesBase = "/Library/Managed Preferences"
        try? FileManager.default.removeItem(at: tempBase)
        super.tearDown()
    }

    private func writeDomain(_ domain: String, _ dict: [String: Any]) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: tempBase.appendingPathComponent("\(domain).plist"))
    }

    // MARK: {userName}

    func testSubstituteGreetingReplacesPlaceholder() {
        XCTAssertEqual(substituteGreeting("Hello, {userName}!", userName: "Maya"), "Hello, Maya!")
        XCTAssertEqual(substituteGreeting("No placeholder", userName: "Maya"), "No placeholder")
    }

    // MARK: {managed:domain:key|fallback}

    func testManagedTokenResolvesFromManagedPref() throws {
        try writeDomain("io.test.setup", ["PolicyName": "Design – Standard"])
        XCTAssertEqual(
            substituteManagedValues("Policy {managed:io.test.setup:PolicyName}"),
            "Policy Design – Standard"
        )
    }

    func testManagedTokenUsesFallbackWhenMissing() {
        XCTAssertEqual(
            substituteManagedValues("{managed:io.test.absent:Key|the fallback}"),
            "the fallback"
        )
    }

    func testManagedTokenWithoutFallbackReturnsNilWhenMissing() {
        XCTAssertNil(substituteManagedValues("Policy {managed:io.test.absent:Key}"))
    }

    func testManagedTokenEmptyValueFallsBack() throws {
        try writeDomain("io.test.setup", ["Empty": "   "])
        XCTAssertEqual(substituteManagedValues("{managed:io.test.setup:Empty|fb}"), "fb")
        XCTAssertNil(substituteManagedValues("{managed:io.test.setup:Empty}"))
    }

    func testMultipleTokensInOneString() throws {
        try writeDomain("io.test.setup", ["A": "one", "B": "two"])
        XCTAssertEqual(
            substituteManagedValues("{managed:io.test.setup:A} and {managed:io.test.setup:B}"),
            "one and two"
        )
    }

    func testTextWithoutTokensPassesThrough() {
        XCTAssertEqual(substituteManagedValues("plain text"), "plain text")
    }

    // MARK: Segment-drop lines

    func testResolveManagedLineKeepsFullLineWhenResolved() throws {
        try writeDomain("io.test.setup", ["PolicyName": "Design – Standard"])
        XCTAssertEqual(
            resolveManagedLine("Fleet “{managed:io.test.setup:PolicyName}” · managed by Acme IT"),
            "Fleet “Design – Standard” · managed by Acme IT"
        )
    }

    func testResolveManagedLineDropsUnresolvedSegment() {
        // No profile → the fleet segment disappears, the rest reads naturally.
        XCTAssertEqual(
            resolveManagedLine("Fleet “{managed:io.test.absent:PolicyName}” · managed by Acme IT"),
            "managed by Acme IT"
        )
    }

    func testResolveManagedLineWholeKeySentence() throws {
        // The one-key-sets-the-sentence pattern with a fallback.
        XCTAssertEqual(
            resolveManagedLine("{managed:io.test.absent:SetupFootnote|Fleet managed by Acme IT}"),
            "Fleet managed by Acme IT"
        )
        try writeDomain("io.test.setup", ["SetupFootnote": "Fleet “X” · managed by Y"])
        XCTAssertEqual(
            resolveManagedLine("{managed:io.test.setup:SetupFootnote|Fleet managed by Acme IT}"),
            "Fleet “X” · managed by Y"
        )
    }

    func testResolveManagedLineDropsEmptySegments() throws {
        try writeDomain("io.test.setup", ["A": "kept"])
        XCTAssertEqual(
            resolveManagedLine("{managed:io.test.setup:A} · {managed:io.test.absent:B}"),
            "kept"
        )
    }

    // MARK: Preset 2 pager calibration

    func testCardsPerPageStandardWidthIsFour() {
        // 860pt at scale 1 gives the designed 4-across.
        XCTAssertEqual(preset2CardsPerPage(windowWidth: 860, scaleFactor: 1.0), 4)
    }

    /// The 800pt base also fits 4-across, which is why the card target is 168, not 172.
    func testCardsPerPageAppleBaseIsAlsoFour() {
        XCTAssertEqual(preset2CardsPerPage(windowWidth: 800, scaleFactor: 1.0), 4)
    }

    func testCardsPerPageClamps() {
        XCTAssertEqual(preset2CardsPerPage(windowWidth: 300, scaleFactor: 1.0), 2)   // floor
        XCTAssertEqual(preset2CardsPerPage(windowWidth: 2400, scaleFactor: 1.0), 6)  // ceiling
    }

    func testCardsPerPageGrowsWithWidth() {
        let narrow = preset2CardsPerPage(windowWidth: 700, scaleFactor: 1.0)
        let wide = preset2CardsPerPage(windowWidth: 1100, scaleFactor: 1.0)
        XCTAssertLessThan(narrow, wide)
    }

    // MARK: - Cadence `minimal`

    /// A finished run advances unless the author sets `autoAdvance: false`.
    func testAFinishedRunAdvancesUnlessTold() {
        XCTAssertTrue(CadenceCopy.shouldAutoAdvance(autoAdvance: nil))
        XCTAssertTrue(CadenceCopy.shouldAutoAdvance(autoAdvance: true))
        XCTAssertFalse(CadenceCopy.shouldAutoAdvance(autoAdvance: false))
    }

    // Rows-before-scroll is pinned in ProvisioningGridTests.
}


extension Result {
    /// The failure case, or nil on success.
    var failureCase: Failure? {
        if case .failure(let f) = self { return f }
        return nil
    }
}
