//
//  CardStatsFoldTests.swift
//  dialogTests
//
//  Covers CardStepBlocks.fold: step-level stats become one leading stat-row block on card chrome.
//

import XCTest
@testable import Dialog

final class CardStatsFoldTests: XCTestCase {

    private func stat(_ value: String, _ label: String) -> InspectConfig.PresetIntroScreen.OverviewStat {
        InspectConfig.PresetIntroScreen.OverviewStat(value: value, label: label)
    }

    func testAStepCarryingStatsGetsAStatRowBlockOnTheCardContract() throws {
        let blocks = CardStepBlocks.fold(content: [],
                                         stats: [stat("9 min", "Estimated"), stat("5 choices", "Brand, Dock")])
        XCTAssertEqual(blocks.count, 1, "the stats must become exactly one block")
        XCTAssertEqual(blocks[0].type, "stat-row")
        XCTAssertEqual(blocks[0].stats?.map { $0.value }, ["9 min", "5 choices"])
        XCTAssertEqual(blocks[0].stats?.map { $0.label }, ["Estimated", "Brand, Dock"])
    }

    func testTheStatsLeadTheContentRatherThanTrailingIt() throws {
        let authored = try JSONDecoder().decode(InspectConfig.GuidanceContent.self,
                                                from: Data(#"{"type":"paragraph","text":"hello"}"#.utf8))
        let blocks = CardStepBlocks.fold(content: [authored], stats: [stat("1 restart", "At the end")])
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].type, "stat-row")
        XCTAssertEqual(blocks[1].type, "paragraph")
    }

    func testAStepThatAlreadyAuthorsAStatRowIsNotGivenASecondOne() throws {
        let authored = try JSONDecoder().decode(InspectConfig.GuidanceContent.self,
                                                from: Data(#"{"type":"stat-row","stats":[{"value":"2","label":"apps"}]}"#.utf8))
        let blocks = CardStepBlocks.fold(content: [authored], stats: [stat("9 min", "Estimated")])
        XCTAssertEqual(blocks.count, 1, "the authored block wins; no synthesized duplicate")
        XCTAssertEqual(blocks[0].stats?.map { $0.value }, ["2"])
    }

    func testNoStatsChangesNothing() throws {
        let authored = try JSONDecoder().decode(InspectConfig.GuidanceContent.self,
                                                from: Data(#"{"type":"paragraph","text":"hello"}"#.utf8))
        XCTAssertEqual(CardStepBlocks.fold(content: [authored], stats: nil).count, 1)
        XCTAssertEqual(CardStepBlocks.fold(content: [authored], stats: []).count, 1)
        XCTAssertEqual(CardStepBlocks.fold(content: [], stats: nil).count, 0)
    }

    func testTheResolveHookIsAppliedToBothValueAndLabel() {
        let blocks = CardStepBlocks.fold(content: [],
                                         stats: [stat("{itemCount} apps", "{itemCount} to download")],
                                         resolve: { _, _, text in text.replacingOccurrences(of: "{itemCount}", with: "7") })
        XCTAssertEqual(blocks[0].stats?.map { $0.value }, ["7 apps"])
        XCTAssertEqual(blocks[0].stats?.map { $0.label }, ["7 to download"])
    }

    func testResolveIsToldWhichCellAndWhichHalfItIsResolving() {
        // The caller looks up <stepId>.stats.<i>.value|label, so it needs index and field.
        var seen: [String] = []
        _ = CardStepBlocks.fold(content: [],
                                stats: [stat("a", "b"), stat("c", "d")],
                                resolve: { index, field, text in
                                    seen.append("\(index)-\(field == .value ? "value" : "label")-\(text)")
                                    return text
                                })
        XCTAssertEqual(seen, ["0-value-a", "0-label-b", "1-value-c", "1-label-d"])
    }
}
