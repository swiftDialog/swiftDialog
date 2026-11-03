//
//  ButtonTests.swift
//  dialogTests
//
//  Page buttons (--button / "button"): parsing, output shape, vieworder placement and the
//  background process runner.
//

import Testing
import Foundation
import SwiftyJSON
import SwiftUI
@testable import Dialog

struct ButtonParsingTests {

    @Test func csvFormIsASingleButtonRow() {
        let row = makeButtonRow(fromCSV: "name=shortcuts,label=Shortcuts…,url=x-apple.systempreferences:com.apple.Desktop")
        #expect(row.items.count == 1)
        #expect(row.name == "shortcuts")
        #expect(row.items[0].label == "Shortcuts…")
        #expect(row.items[0].url == "x-apple.systempreferences:com.apple.Desktop")
        #expect(row.items[0].type == "action")
    }

    @Test func csvFirstUnkeyedItemIsTheLabel() {
        let row = makeButtonRow(fromCSV: "Open Self Service,shell=open -a 'Self Service',disabled")
        #expect(row.items[0].label == "Open Self Service")
        #expect(row.items[0].shell == "open -a 'Self Service'")
        #expect(row.items[0].disabled)
    }

    @Test func jsonObjectWithoutItemsIsOneButton() {
        let row = makeButtonRow(from: JSON(["name": "help", "symbol": "questionmark", "display": "symbol", "sheet": "Hello"]))
        #expect(row.items.count == 1)
        #expect(row.items[0].symbol == "questionmark")
        #expect(row.items[0].display == "symbol")
        #expect(row.items[0].sheet == "Hello")
    }

    @Test func jsonItemsShareARow() {
        let row = makeButtonRow(from: JSON([
            "name": "tools",
            "items": [["name": "a", "label": "A", "url": "https://a.example"],
                      ["name": "b", "label": "B", "shell": "true"]]
        ]))
        #expect(row.items.count == 2)
        #expect(row.items.map(\.name) == ["a", "b"])
    }

    @Test func sheetObjectCarriesImageAndButtonText() {
        let item = makeButtonItem(from: JSON(["sheet": ["message": "Hi", "image": "/x.png", "buttontext": "Got it"]]))
        #expect(item.sheet == "Hi")
        #expect(item.sheetImage == "/x.png")
        #expect(item.sheetButtonText == "Got it")
    }

    @Test func typesAndColourAlias() {
        #expect(makeButtonItem(from: JSON(["type": "color"])).type == "colour")
        #expect(makeButtonItem(from: JSON(["type": "colour"])).type == "colour")
        #expect(makeButtonItem(from: JSON(["type": "info"])).type == "info")
        #expect(makeButtonItem(from: JSON(["type": "anything"])).type == "action")
        #expect(makeButtonItem(from: JSON([:])).type == "action")
    }

    @Test func selectableItemsDefaultTheirValueToTheNameOrLabel() {
        let row = makeButtonRow(from: JSON([
            "name": "accent", "selectable": true, "default": "blue",
            "items": [["name": "blue", "label": "Blue"], ["label": "Red"]]
        ]))
        #expect(row.items.map(\.value) == ["blue", "Red"])
        #expect(row.selectedValue == "blue")
    }

    @Test func plainStyleOnlyWhenAsked() {
        #expect(makeButtonRow(from: JSON(["style": "plain"])).style == "plain")
        #expect(makeButtonRow(from: JSON(["style": "weird"])).style == "bordered")
        #expect(makeButtonRow(from: JSON([:])).style == "bordered")
    }

    @Test func symbolSpecParsing() {
        let spec = ButtonSymbolSpec("SF=circle.fill,colour=blue,size=30")
        #expect(spec.name == "circle.fill")
        #expect(spec.size == 30)
        #expect(spec.colour != nil)
        #expect(ButtonSymbolSpec("gear").name == "gear")
        #expect(ButtonSymbolSpec("star,palette=red-blue").palette.count == 2)
    }

    @Test func layoutNameFallsBackToFirstItem() {
        var row = ButtonRow()
        row.items = [ButtonItem(name: "first", label: "First")]
        #expect(row.layoutName == "first")
        row.name = "row"
        #expect(row.layoutName == "row")
    }
}

struct ButtonOutputTests {

    @Test func unclickedButtonReportsNotClicked() {
        let row = makeButtonRow(from: JSON(["name": "hot", "label": "Hot Corners", "shell": "true"]))
        let entries = buttonOutputEntries([row])
        #expect(entries.count == 1)
        #expect(entries[0].lines == ["\"hot\" : \"not clicked\""])
    }

    @Test func clickedButtonReportsExitCode() {
        var row = makeButtonRow(from: JSON(["name": "hot", "label": "Hot Corners", "shell": "false"]))
        row.items[0].clicked = true
        row.items[0].lastExitCode = 1
        let entries = buttonOutputEntries([row])
        #expect(entries[0].lines == ["\"hot\" : \"clicked\"", "\"hot\" exitcode : \"1\""])
        let value = entries[0].value as? [String: Any]
        #expect(value?["clicked"] as? Bool == true)
        #expect(value?["exitcode"] as? Int == 1)
    }

    @Test func selectableRowReportsSelectedValue() {
        var row = makeButtonRow(from: JSON([
            "name": "accent", "selectable": true, "default": "blue",
            "items": [["name": "blue", "label": "Blue", "shell": "true"]]
        ]))
        row.items[0].clicked = true
        row.items[0].lastExitCode = 0
        let entries = buttonOutputEntries([row])
        #expect(entries.count == 1)
        #expect(entries[0].lines == ["\"accent\" : \"blue\"", "\"accent\" exitcode : \"0\""])
    }

    @Test func colourReportsHexAndInfoReportsNothing() {
        let colour = makeButtonRow(from: JSON(["name": "brand", "type": "colour", "value": "#0066FF"]))
        let info = makeButtonRow(from: JSON(["name": "serial", "type": "info", "value": "ABC"]))
        let entries = buttonOutputEntries([colour, info])
        #expect(entries.count == 1)
        #expect(entries[0].lines == ["\"brand\" : \"#0066FF\""])
    }

    @Test func noButtonsMeansNoOutput() {
        #expect(buttonOutputEntries([]).isEmpty)
    }

    @Test func hexRoundTrip() {
        #expect(Color(argument: "#0066FF").hexString == "#0066FF")
    }
}

struct ButtonLayoutTests {

    private func inputs() -> ViewLayoutInputs {
        ViewLayoutInputs(textFields: ["name"], checkboxes: [], selects: [], buttons: ["help", "tools"], blocks: [])
    }

    @Test func buttonRowsPlaceByName() {
        let groups = ViewLayoutParser.resolve(ViewLayoutParser.parseCSV(["tools", "name"]), inputs: inputs())
        #expect(groups[0].rows.prefix(2) == [.button(1), .textField(0)])
    }

    @Test func buttonAndButtonsAreReservedAndSynonyms() {
        #expect(ViewLayoutParser.reservedWords.contains("button"))
        #expect(ViewLayoutParser.reservedWords.contains("buttons"))
        let one = ViewLayoutParser.resolve(ViewLayoutParser.parseCSV(["button"]), inputs: inputs())
        let two = ViewLayoutParser.resolve(ViewLayoutParser.parseCSV(["buttons"]), inputs: inputs())
        #expect(one == two)
        #expect(one[0].rows.prefix(2) == [.button(0), .button(1)])
    }

    @Test func unplacedButtonsGoLast() {
        let groups = ViewLayoutParser.resolve(ViewLayoutParser.parseCSV(["name"]), inputs: inputs())
        #expect(groups.last?.rows == [.button(0), .button(1)])
    }
}

/// Serialised: the runner is a shared singleton, so one test's long-running action (or killAll) would
/// otherwise leak into another test's "nothing is running" check.
@Suite(.serialized)
struct ButtonRunnerTests {

    private func run(_ command: String) async -> Int32 {
        await withCheckedContinuation { continuation in
            ButtonActionRunner.shared.run(command, label: "test") { continuation.resume(returning: $0) }
        }
    }

    @Test func reportsExitCode() async {
        #expect(await run("exit 3") == 3)
        #expect(await run("true") == 0)
    }

    @Test func notRunningAfterItFinishes() async {
        _ = await run("true")
        #expect(!ButtonActionRunner.shared.hasRunning)
    }

    @Test func killAllTerminatesRunningActionsAndTheirChildren() async {
        async let code = run("sleep 30 & sleep 30")
        // let it start
        try? await Task.sleep(nanoseconds: 400_000_000)
        #expect(ButtonActionRunner.shared.hasRunning)
        ButtonActionRunner.shared.killAll()
        let result = await code
        #expect(result == 143 || result == 137)   // killed by SIGTERM / SIGKILL
        #expect(!ButtonActionRunner.shared.hasRunning)
    }
}
