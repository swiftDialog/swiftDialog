//
//  CardReceiptPortTests.swift
//  dialogTests
//
//  Covers CardReceipt.rows (which receipt rows survive) and the card header's title-info hook.
//

import XCTest
@testable import Dialog

final class CardReceiptPortTests: XCTestCase {

    private func row(_ stepId: String, _ label: String) -> InspectConfig.IntroStep.ReceiptRow {
        InspectConfig.IntroStep.ReceiptRow(stepId: stepId, label: label,
                                           selectionKey: nil, fallbackValue: nil)
    }

    func testAChoiceWithNoAnswerIsOmittedRatherThanShownBlank() {
        let rows = CardReceipt.rows([row("brand", "Brand"), row("dock", "Dock")],
                                    label: { $0.label },
                                    value: { $0.stepId == "brand" ? "Globex" : nil })
        XCTAssertEqual(rows.map { $0.stepId }, ["brand"])
        XCTAssertEqual(rows.map { $0.value }, ["Globex"])
    }

    func testAuthoredOrderIsPreserved() {
        let rows = CardReceipt.rows([row("c", "C"), row("a", "A"), row("b", "B")],
                                    label: { $0.label },
                                    value: { _ in "x" })
        XCTAssertEqual(rows.map { $0.stepId }, ["c", "a", "b"])
    }

    func testTheLabelMapperIsUsedRatherThanTheRawAuthoredLabel() {
        // Labels are localized under receipt.<stepId>.label; the raw string must not win.
        let rows = CardReceipt.rows([row("brand", "Brand")],
                                    label: { "LOCALIZED-\($0.label)" },
                                    value: { _ in "Globex" })
        XCTAssertEqual(rows.map { $0.label }, ["LOCALIZED-Brand"])
    }

    func testEverythingUnansweredMeansNoReceiptAtAll() {
        XCTAssertTrue(CardReceipt.rows([row("a", "A")], label: { $0.label }, value: { _ in nil }).isEmpty)
        XCTAssertTrue(CardReceipt.rows([], label: { $0.label }, value: { _ in "x" }).isEmpty)
    }

    // MARK: - The step-overlay button

    /// The card model carries the action that opens the step overlay, not the overlay config.
    func testTheCardHeaderCarriesATitleInfoHookWhenAskedFor() {
        var fired = false
        let model = CardStepModel(title: "T",
                                  onTitleInfo: { fired = true },
                                  subtitle: nil,
                                  footer: CardFooterModel(continueText: "Continue",
                                                          onContinue: {}))
        XCTAssertNotNil(model.onTitleInfo)
        model.onTitleInfo?()
        XCTAssertTrue(fired, "the button runs the action the arm handed it")
    }

    func testTitleInfoIsAbsentByDefault() {
        let model = CardStepModel(title: "T", subtitle: nil,
                                  footer: CardFooterModel(continueText: "Continue",
                                                          onContinue: {}))
        XCTAssertNil(model.onTitleInfo, "no overlay authored, no button drawn")
    }
}
