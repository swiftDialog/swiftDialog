//
//  NumberInputTests.swift
//  dialogTests
//
//  Sliders and steppers (--slider / --stepper): parsing, range handling, formatting, output
//  and vieworder placement.
//

import Testing
import SwiftyJSON
@testable import Dialog

struct NumberInputTests {

    @Test func jsonDefaults() {
        let input = makeNumberInput(from: JSON(["title": "Volume", "name": "volume"]), kind: "slider")
        #expect(input.kind == "slider")
        #expect(input.minValue == 0)
        #expect(input.maxValue == 100)
        #expect(input.step == 1)
        #expect(input.value == 0)
        #expect(input.showValue)
    }

    @Test func jsonValuesAcceptNumbersAndStrings() {
        let input = makeNumberInput(from: JSON(["min": 10, "max": "50", "step": 5, "value": "25"]), kind: "stepper")
        #expect(input.minValue == 10)
        #expect(input.maxValue == 50)
        #expect(input.value == 25)
    }

    @Test func csvForm() {
        let input = makeNumberInput(fromCSV: "Volume,name=volume,min=0,max=10,step=0.5,value=3,unit=%,detail=Output level,showvalue=false",
                                    kind: "slider")
        #expect(input.title == "Volume")
        #expect(input.name == "volume")
        #expect(input.step == 0.5)
        #expect(input.value == 3)
        #expect(input.unit == "%")
        #expect(input.detail == "Output level")
        #expect(!input.showValue)
    }

    @Test func valueIsClampedIntoRange() {
        #expect(makeNumberInput(from: JSON(["min": 0, "max": 10, "value": 99]), kind: "slider").value == 10)
        #expect(makeNumberInput(from: JSON(["min": 5, "max": 10, "value": 1]), kind: "slider").value == 5)
    }

    @Test func invalidRangeAndStepAreRepaired() {
        let input = makeNumberInput(from: JSON(["min": 10, "max": 10, "step": 0]), kind: "stepper")
        #expect(input.step == 1)
        #expect(input.maxValue > input.minValue)
    }

    @Test func decimalsFollowTheStep() {
        var input = NumberInput()
        input.step = 1;    #expect(input.decimals == 0)
        input.step = 0.5;  #expect(input.decimals == 1)
        input.step = 0.25; #expect(input.decimals == 2)
    }

    @Test func displayValueUsesStepPrecision() {
        var input = NumberInput()
        input.step = 1; input.value = 42
        #expect(input.displayValue == "42")
        input.step = 0.25; input.value = 0.75
        #expect(input.displayValue == "0.75")
    }

    @Test func keyFallsBackToTitle() {
        var input = NumberInput()
        input.title = "Volume"
        #expect(input.key == "Volume")
        input.name = "vol"
        #expect(input.key == "vol")
    }

    @Test func outputIsNumeric() {
        var whole = NumberInput(); whole.name = "retention"; whole.value = 30
        var fractional = NumberInput(); fractional.name = "gain"; fractional.step = 0.5; fractional.value = 2.5
        let entries = numberOutputEntries([whole, fractional])
        #expect(entries[0].line == "\"retention\" : \"30\"")
        #expect(entries[0].value as? Int == 30)
        #expect(entries[1].line == "\"gain\" : \"2.5\"")
        #expect(entries[1].value as? Double == 2.5)
    }

    @Test func noNumbersMeansNoOutput() {
        #expect(numberOutputEntries([]).isEmpty)
    }

    // MARK: vieworder

    private func inputs() -> ViewLayoutInputs {
        ViewLayoutInputs(textFields: ["name"], checkboxes: [], selects: [], buttons: [],
                         numbers: [(name: "volume", kind: "slider"), (name: "days", kind: "stepper")], blocks: [])
    }

    @Test func numbersPlaceByNameAndKind() {
        let groups = ViewLayoutParser.resolve(ViewLayoutParser.parseCSV(["days", "volume", "name"]), inputs: inputs())
        #expect(groups[0].rows.prefix(3) == [.stepper(1), .slider(0), .textField(0)])
    }

    @Test func sliderAndStepperAreReservedTypeWords() {
        #expect(ViewLayoutParser.reservedWords.contains("slider"))
        #expect(ViewLayoutParser.reservedWords.contains("stepper"))
        let groups = ViewLayoutParser.resolve(ViewLayoutParser.parseCSV(["stepper"]), inputs: inputs())
        #expect(groups[0].rows.first == .stepper(1))
    }

    @Test func unplacedNumbersAreAppended() {
        let groups = ViewLayoutParser.resolve(ViewLayoutParser.parseCSV(["name"]), inputs: inputs())
        #expect(groups.last?.rows == [.slider(0), .stepper(1)])
    }
}

struct NumberColumnWidthTests {

    @Test func labelSlotsAppearWhenAnyRowHasLabels() {
        var labelled = NumberInput(); labelled.minLabel = "Quiet"; labelled.maxLabel = "Loud"
        let plain = NumberInput()
        #expect(NumberColumnWidths.measuring([labelled, plain], fontSize: 13).minLabel > 0)
        #expect(NumberColumnWidths.measuring([plain], fontSize: 13).minLabel == 0)
    }

    @Test func everyRowGetsTheWidestLabel() {
        var short = NumberInput(); short.minLabel = "Lo"
        var long = NumberInput(); long.minLabel = "Very quiet"
        let together = NumberColumnWidths.measuring([short, long], fontSize: 13)
        #expect(together.minLabel == NumberColumnWidths.measuring([long], fontSize: 13).minLabel)
    }

    @Test func valueWidthCoversTheWholeRange() {
        var narrow = NumberInput(); narrow.minValue = 0; narrow.maxValue = 9; narrow.unit = "%"
        var wide = NumberInput(); wide.minValue = 0; wide.maxValue = 100; wide.unit = "%"
        #expect(NumberColumnWidths.measuring([wide], fontSize: 13).value > NumberColumnWidths.measuring([narrow], fontSize: 13).value)
    }

    @Test func valueWidthIsIndependentOfTheCurrentValue() {
        var low = NumberInput(); low.value = 1
        var high = NumberInput(); high.value = 100
        #expect(NumberColumnWidths.measuring([low], fontSize: 13).value == NumberColumnWidths.measuring([high], fontSize: 13).value)
    }

    @Test func hiddenValueReservesNothingUnlessOthersShowOne() {
        var hidden = NumberInput(); hidden.showValue = false
        #expect(NumberColumnWidths.measuring([hidden], fontSize: 13).value == 0)
    }

    @Test func stepperUnitsShareTheWidestUnit() {
        var minutes = NumberInput(); minutes.kind = "stepper"; minutes.unit = "minutes"
        var days = NumberInput(); days.kind = "stepper"; days.unit = "days"
        let widths = NumberColumnWidths.measuring([minutes, days], fontSize: 13)
        #expect(widths.unit == NumberColumnWidths.measuring([minutes], fontSize: 13).unit)
        #expect(widths.unit > NumberColumnWidths.measuring([days], fontSize: 13).unit)
    }
}

struct NumberRoundingAndFitTests {

    @Test func valuesAreRoundedToTwoDecimals() {
        var input = NumberInput(); input.maxValue = 1
        #expect(input.constrained(0.30000000000000004) == 0.3)
        #expect(input.constrained(0.123456) == 0.12)
    }

    @Test func decimalsAreNeverMoreThanTwo() {
        var input = NumberInput(); input.step = 0.125
        #expect(input.decimals == 2)
    }

    @Test func snapsToTheStepFromMin() {
        var input = NumberInput(); input.minValue = 0; input.maxValue = 100; input.step = 5
        #expect(input.constrained(63, snapToStep: true) == 65)
        #expect(input.constrained(62, snapToStep: true) == 60)
        input.minValue = 2
        #expect(input.constrained(9, snapToStep: true) == 7)    // steps are 2, 7, 12 ...
    }

    @Test func snappingStaysInsideTheRange() {
        var input = NumberInput(); input.minValue = 0; input.maxValue = 98; input.step = 5
        #expect(input.constrained(98, snapToStep: true) <= 98)
        #expect(input.constrained(-50, snapToStep: true) == 0)
    }

    @Test func notSnappedUnlessAsked() {
        var input = NumberInput(); input.step = 5
        #expect(input.constrained(63) == 63)
    }

    @Test func sliderLengthFollowsTheWidth() {
        var input = NumberInput(); input.title = "Output volume"; input.showValue = true; input.unit = "%"
        let measured = NumberColumnWidths.measuring([input], fontSize: 13)
        let narrow = measured.fitting(boxWidth: 300).slider
        let medium = measured.fitting(boxWidth: 500).slider
        let wide = measured.fitting(boxWidth: 2000).slider
        #expect(narrow <= medium)
        #expect(medium <= wide)
        #expect(narrow >= NumberColumnWidths.minSlider)
        #expect(wide <= NumberColumnWidths.maxSlider)
    }

    @Test func unmeasuredWidthKeepsTheIdealLength() {
        let widths = NumberColumnWidths.measuring([NumberInput()], fontSize: 13)
        #expect(widths.fitting(boxWidth: 0).slider == NumberColumnWidths.idealSlider)
    }

    @Test func rowsInAGroupGetTheSameSliderLength() {
        // the length depends only on the group, not on which row is asking
        var a = NumberInput(); a.title = "Volume"
        var b = NumberInput(); b.title = "A much longer title for brightness"
        let group = NumberColumnWidths.measuring([a, b], fontSize: 13).fitting(boxWidth: 600)
        #expect(group.slider == NumberColumnWidths.measuring([a, b], fontSize: 13).fitting(boxWidth: 600).slider)
    }
}
