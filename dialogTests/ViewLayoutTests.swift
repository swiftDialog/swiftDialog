//
//  ViewLayoutTests.swift
//  dialogTests
//
//  Covers extended `--vieworder`: deciding whether a value is the original type ordering or the
//  new input layout, parsing CSV / JSON forms, and resolving names to inputs. The key guarantee
//  is that every value that worked before still means exactly what it did.
//

import Testing
import SwiftyJSON
@testable import Dialog

struct ViewLayoutTests {

    private let names: Set<String> = ["fullname", "email", "newsletter", "checkbox", "gateway"]

    private func inputs() -> ViewLayoutInputs {
        ViewLayoutInputs(textFields: ["fullname", "email"],
                         checkboxes: ["newsletter", "checkbox"],
                         selects: [(name: "gateway", isRadio: false), (name: "channel", isRadio: true)],
                         blocks: [])
    }

    // MARK: - Classification (backward compatibility)

    @Test func typeNamesOnlyStayTypeOrdering() {
        #expect(ViewLayoutParser.classify("textfield,checkbox,dropdown", inputNames: names) == .typeOrder)
    }

    @Test func unknownWordsStayTypeOrdering() {
        #expect(ViewLayoutParser.classify("textfield,nonsense", inputNames: names) == .typeOrder)
    }

    @Test func emptyValueStaysTypeOrdering() {
        #expect(ViewLayoutParser.classify("", inputNames: names) == .typeOrder)
    }

    @Test func inputNamedLikeATypeStaysTypeOrdering() {
        // "checkbox" is both a type and an input name: reserved word wins, so it's the old behaviour
        #expect(ViewLayoutParser.classify("checkbox,textfield", inputNames: names) == .typeOrder)
    }

    @Test func groupTokenSwitchesToLayout() {
        guard case .layout(let spec) = ViewLayoutParser.classify("[Account],fullname,email", inputNames: names) else {
            Issue.record("expected layout"); return
        }
        #expect(spec.groups.count == 1)
        #expect(spec.groups[0].title == "Account")
        #expect(spec.groups[0].items == ["fullname", "email"])
    }

    @Test func inputNameSwitchesToLayout() {
        guard case .layout(let spec) = ViewLayoutParser.classify("email,textfield", inputNames: names) else {
            Issue.record("expected layout"); return
        }
        #expect(spec.groups.count == 1)
        #expect(spec.groups[0].title == nil)
        #expect(spec.groups[0].items == ["email", "textfield"])
    }

    // MARK: - CSV parsing

    @Test func emptyGroupTokenIsUntitled() {
        let spec = ViewLayoutParser.parseCSV(["[]", "email", "[Prefs]", "newsletter"])
        #expect(spec.groups.map(\.title) == [nil, "Prefs"])
        #expect(spec.groups.map(\.items) == [["email"], ["newsletter"]])
    }

    @Test func itemsBeforeFirstGroupGetAnUntitledGroup() {
        let spec = ViewLayoutParser.parseCSV(["email", "[Prefs]", "newsletter"])
        #expect(spec.groups.map(\.title) == [nil, "Prefs"])
    }

    // MARK: - JSON parsing

    @Test func jsonObjectIsLayout() {
        let json = #"{"groups":[{"title":"Proxy","description":"Careful","footer":"Done","items":["fullname","checkbox"]}]}"#
        guard case .layout(let spec) = ViewLayoutParser.classify(json, inputNames: names) else {
            Issue.record("expected layout"); return
        }
        #expect(spec.groups[0].title == "Proxy")
        #expect(spec.groups[0].description == "Careful")
        #expect(spec.groups[0].footer == "Done")
        #expect(spec.groups[0].items == ["fullname", "checkbox"])
    }

    @Test func jsonObjectWithoutGroupsFallsBackToTypeOrdering() {
        #expect(ViewLayoutParser.classify(#"{"nothing": true}"#, inputNames: names) == .typeOrder)
    }

    @Test func brokenJSONFallsBackToCSV() {
        #expect(ViewLayoutParser.classify("{not json", inputNames: names) == .typeOrder)
    }

    // MARK: - Resolution

    @Test func mixesInputTypesInOrder() {
        let spec = ViewLayoutParser.parseCSV(["email", "newsletter", "fullname"])
        let groups = ViewLayoutParser.resolve(spec, inputs: inputs())
        #expect(groups[0].rows == [.textField(1), .checkbox(0), .textField(0)])
    }

    @Test func typeNameExpandsToRemainingInputsOfThatType() {
        // email is placed individually, so the textfield block only contains the others
        let spec = ViewLayoutParser.parseCSV(["email", "textfield"])
        let groups = ViewLayoutParser.resolve(spec, inputs: inputs())
        #expect(groups[0].rows == [.textField(1), .textField(0)])
    }

    @Test func reservedWordNeverMeansTheInputOfThatName() {
        // The checkbox input is literally named "checkbox": the token means the type block
        var logs: [String] = []
        let spec = ViewLayoutParser.parseCSV(["checkbox"])
        let groups = ViewLayoutParser.resolve(spec, inputs: inputs(), log: { logs.append($0) })
        #expect(groups[0].rows == [.checkbox(0), .checkbox(1)])
        #expect(logs.contains { $0.contains("reserved word") })
    }

    @Test func unknownTokenIsSkippedWithWarning() {
        var logs: [String] = []
        let spec = ViewLayoutParser.parseCSV(["email", "bogus"])
        _ = ViewLayoutParser.resolve(spec, inputs: inputs(), log: { logs.append($0) })
        #expect(logs.contains { $0.contains("'bogus'") })
    }

    @Test func duplicatePlacementKeepsFirst() {
        var logs: [String] = []
        let spec = ViewLayoutParser.parseCSV(["[A]", "email", "[B]", "email"])
        let groups = ViewLayoutParser.resolve(spec, inputs: inputs(), log: { logs.append($0) })
        #expect(groups.first { $0.title == "A" }?.rows == [.textField(1)])
        #expect(groups.first { $0.title == "B" } == nil)   // empty group draws nothing
        #expect(logs.contains { $0.contains("more than once") })
    }

    @Test func unplacedInputsAreAppendedInDefaultOrder() {
        let spec = ViewLayoutParser.parseCSV(["[Account]", "email"])
        let groups = ViewLayoutParser.resolve(spec, inputs: inputs())
        #expect(groups.count == 2)
        #expect(groups[1].title == nil)
        // default order: checkbox, textfield, radiobutton, dropdown
        #expect(groups[1].rows == [.checkbox(0), .checkbox(1), .textField(0), .radio(1), .dropdown(0)])
    }

    @Test func radioAndDropdownResolveByStyle() {
        let spec = ViewLayoutParser.parseCSV(["channel", "gateway"])
        let groups = ViewLayoutParser.resolve(spec, inputs: inputs())
        #expect(groups[0].rows.prefix(2) == [.radio(1), .dropdown(0)])
    }

    @Test func blocksOnlyAppearWhenPresent() {
        var withBlocks = inputs()
        withBlocks.blocks = [.listitem]
        let spec = ViewLayoutParser.parseCSV(["listitem", "webcontent", "email"])
        let groups = ViewLayoutParser.resolve(spec, inputs: withBlocks)
        #expect(groups[0].rows.prefix(2) == [.block(.listitem), .textField(1)])
    }
}

/// `detail` is optional subtext under an input's title; absent means empty (nothing drawn).
struct DetailPropertyTests {

    @Test func textFieldDetailFromJSON() {
        #expect(makeTextFieldState(from: JSON(["title": "Host", "detail": "Leave blank for none"])).detail == "Leave blank for none")
    }

    @Test func checkboxDetailFromJSON() {
        #expect(makeCheckBox(from: JSON(["label": "Notify me", "detail": "Before maintenance"])).detail == "Before maintenance")
    }

    @Test func selectDetailFromJSON() {
        let item = makeDropDownItem(from: JSON(["title": "Gateway", "values": ["a"], "detail": "Pick the nearest"]))
        #expect(item.detail == "Pick the nearest")
    }

    @Test func detailDefaultsToEmpty() {
        #expect(makeTextFieldState(from: JSON(["title": "Host"])).detail.isEmpty)
        #expect(makeCheckBox(from: JSON(["label": "Notify me"])).detail.isEmpty)
        #expect(makeDropDownItem(from: JSON(["title": "Gateway", "values": ["a"]])).detail.isEmpty)
    }
}
