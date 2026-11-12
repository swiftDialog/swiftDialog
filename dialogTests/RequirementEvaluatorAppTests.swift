//
//  RequirementEvaluatorAppTests.swift
//  dialogTests
//
//  The `app` requirement: an installed app found by bundle id through LaunchServices, wherever it lives.
//

import XCTest
@testable import Dialog

final class RequirementEvaluatorAppTests: XCTestCase {

    /// Present on every macOS install, so the true case does not depend on the test machine.
    private let presentBundleId = "com.apple.finder"
    private let absentBundleId = "com.example.dialog.definitely-not-installed"

    /// Built from JSON, the way configs supply requirements.
    private func requirement(_ json: String) throws -> InspectConfig.ItemConfig.Requirement {
        try JSONDecoder().decode(InspectConfig.ItemConfig.Requirement.self,
                                 from: Data(json.utf8))
    }

    private func satisfied(_ json: String) throws -> Bool {
        RequirementEvaluator.isSatisfied(try requirement(json), receiptsBasePath: "/var/db/receipts")
    }

    func testInstalledAppIsDetectedByBundleId() throws {
        XCTAssertTrue(try satisfied("""
        {"type": "app", "bundleId": "\(presentBundleId)"}
        """), "Finder is installed on every Mac — the app requirement must find it")
    }

    func testMissingAppIsNotDetected() throws {
        XCTAssertFalse(try satisfied("""
        {"type": "app", "bundleId": "\(absentBundleId)"}
        """))
    }

    /// `negate` works on `app` requirements in both directions.
    func testNegateInvertsBothDirections() throws {
        XCTAssertFalse(try satisfied("""
        {"type": "app", "bundleId": "\(presentBundleId)", "negate": true}
        """))
        XCTAssertTrue(try satisfied("""
        {"type": "app", "bundleId": "\(absentBundleId)", "negate": true}
        """))
    }

    /// A requirement with no bundle id is unsatisfied, never assumed met.
    func testMissingBundleIdIsUnsatisfiedRatherThanSatisfied() throws {
        XCTAssertFalse(try satisfied(#"{"type": "app"}"#))
        XCTAssertFalse(try satisfied(#"{"type": "app", "bundleId": ""}"#))
    }

    // MARK: - Group roll-up

    private func item(_ json: String) throws -> InspectConfig.ItemConfig {
        try JSONDecoder().decode(InspectConfig.ItemConfig.self, from: Data(json.utf8))
    }

    /// An item with only an app requirement (no `paths`) still evaluates.
    func testItemWithOnlyAnAppRequirementEvaluates() throws {
        let cfg = try item("""
        {"id": "finder", "displayName": "Finder", "paths": [],
         "requirements": [{"type": "app", "bundleId": "\(presentBundleId)"}]}
        """)
        let group = RequirementEvaluator.evaluate(cfg, receiptsBasePath: "/var/db/receipts")
        XCTAssertNotNil(group, "an item with requirements must produce a verdict even with no paths")
        XCTAssertEqual(group?.total, 1)
        XCTAssertEqual(group?.satisfied, 1)
        XCTAssertTrue(group?.done == true)
    }

    /// Two of three present under ALL is not done, and the counts are exact ("Install N missing" uses them).
    func testPartialGroupReportsHonestCounts() throws {
        let cfg = try item("""
        {"id": "mixed", "displayName": "Mixed", "paths": [],
         "requirements": [
           {"type": "app", "bundleId": "\(presentBundleId)"},
           {"type": "path", "paths": ["/usr/bin/true"]},
           {"type": "app", "bundleId": "\(absentBundleId)"}
         ]}
        """)
        let group = RequirementEvaluator.evaluate(cfg, receiptsBasePath: "/var/db/receipts")
        XCTAssertEqual(group?.satisfied, 2)
        XCTAssertEqual(group?.total, 3)
        XCTAssertFalse(group?.done == true)
    }

    func testSatisfyAnyCompletesOnOne() throws {
        let cfg = try item("""
        {"id": "either", "displayName": "Either", "paths": [], "satisfy": "any",
         "requirements": [
           {"type": "app", "bundleId": "\(absentBundleId)"},
           {"type": "app", "bundleId": "\(presentBundleId)"}
         ]}
        """)
        XCTAssertTrue(RequirementEvaluator.evaluate(cfg, receiptsBasePath: "/var/db/receipts")?.done == true)
    }

    // MARK: - Identifier an item shows

    /// The identifier comes from the app requirement's `bundleId`, so what is shown is what is checked.
    func testAnItemsIdentifierComesFromItsAppRequirement() throws {
        let cfg = try item("""
        {"id":"figma","displayName":"Figma","guiIndex":0,"paths":[],
         "requirements":[{"type":"app","bundleId":"com.figma.Desktop"}]}
        """)
        XCTAssertEqual(cfg.displayIdentifier, "com.figma.Desktop")
    }

    /// An item detected by path has no identifier.
    func testAnItemDetectedByPathHasNoIdentifier() throws {
        let cfg = try item("""
        {"id":"thing","displayName":"Thing","guiIndex":0,"paths":["/tmp/x"],
         "requirements":[{"type":"path","paths":["/tmp/x"]}]}
        """)
        XCTAssertNil(cfg.displayIdentifier)
    }

    /// With no requirements at all there is nothing to derive from.
    func testAnItemWithNoRequirementsHasNoIdentifier() throws {
        let cfg = try item("""
        {"id":"bare","displayName":"Bare","guiIndex":0,"paths":[]}
        """)
        XCTAssertNil(cfg.displayIdentifier)
    }

    /// The app requirement is found among others, whatever its position.
    func testTheAppRequirementIsFoundAmongOthers() throws {
        let cfg = try item("""
        {"id":"mix","displayName":"Mix","guiIndex":0,"paths":[],
         "requirements":[{"type":"path","paths":["/tmp/x"]},
                         {"type":"app","bundleId":"com.docker.docker"}]}
        """)
        XCTAssertEqual(cfg.displayIdentifier, "com.docker.docker")
    }

    // MARK: - Claim and size

    /// `claim` and `size` decode on an item; `claim` is its own field, not a subtitle.
    func testClaimAndSizeDecodeOnAnItem() throws {
        let cfg = try item("""
        {"id":"1p","displayName":"1Password","guiIndex":0,"paths":[],
         "claim":"Handing over the keys","size":"86 MB"}
        """)
        XCTAssertEqual(cfg.claim, "Handing over the keys")
        XCTAssertEqual(cfg.size, "86 MB")
    }

    /// Both are optional; items without them decode unchanged.
    func testAnItemWithoutThemStillDecodes() throws {
        let cfg = try item("""
        {"id":"plain","displayName":"Plain","guiIndex":0,"paths":[]}
        """)
        XCTAssertNil(cfg.claim)
        XCTAssertNil(cfg.size)
    }
}
