//
//  RadioView.swift
//  Dialog
//
//  Created by Bart E Reardon on 2/5/2023.
//
// RadioView is just a special form of DropdownView
// It uses the exact same data, but jsuit presented ina  different way

import SwiftUI

struct RadioView: View {
    @ObservedObject var observedData: DialogUpdatableContent
    @State var selectedOption: [String]

    var fieldwidth: CGFloat = 0

    var radioCount = 0

    /// Only draw these select items (nil = all). Used when `vieworder` places inputs individually.
    var indices: [Int]?
    /// Drawn inside a group, which supplies the surrounding box and dividers
    var embedded: Bool = false

    init(observedDialogContent: DialogUpdatableContent, indices: [Int]? = nil, embedded: Bool = false) {
        self.observedData = observedDialogContent
        self.indices = indices
        self.embedded = embedded

        if !observedDialogContent.args.hideIcon.present {
            fieldwidth = observedDialogContent.args.windowWidth.value.floatValue()
        } else {
            fieldwidth = observedDialogContent.args.windowWidth.value.floatValue() - observedDialogContent.args.iconSize.value.floatValue()
        }

        var defaultOptions: [String] = []
        for index in 0..<userInputState.dropdownItems.count {
            if userInputState.dropdownItems[index].defaultValue.isEmpty && userInputState.dropdownItems[index].style == "radio" {
                userInputState.dropdownItems[index].defaultValue = userInputState.dropdownItems[index].values[0]
                userInputState.dropdownItems[index].selectedValue = userInputState.dropdownItems[index].values[0]
            }
            // Seed from selectedValue so restored values from prior cards survive view re-creation.
            // On a fresh page selectedValue == defaultValue, so behaviour is unchanged.
            defaultOptions.append(userInputState.dropdownItems[index].selectedValue)
            if userInputState.dropdownItems[index].style == "radio" {
                radioCount+=1
            }
        }
        _selectedOption = State(initialValue: defaultOptions)

        if radioCount > 0 {
            writeLog("Displaying radio button view")
        }

    }

    var body: some View {
        // Guard against array size mismatch during card transitions
        // When cards change, userInputState may have different count than @State selectedOption
        if observedData.args.dropdownValues.present && radioCount > 0 && selectedOption.count == userInputState.dropdownItems.count {
            VStack {
                // Iterate the collection's indices, not 0..<count: a Range-based ForEach pins to the
                // count it first saw and keeps evaluating stale indices after the array shrinks on a
                // card change, which traps on subscript. Array(indices) always tracks the current list.
                ForEach(Array(userInputState.dropdownItems.indices).filter { indices?.contains($0) ?? true }, id: \.self) {index in
                    Group {
                    if userInputState.dropdownItems[index].style == "radio" {
                        VStack {
                            HStack {
                                Text(userInputState.dropdownItems[index].title + (userInputState.dropdownItems[index].required ? " *":""))
                                    .frame(alignment: .leading)
                                Spacer()
                            }
                            .padding(.bottom, 8)
                            if !userInputState.dropdownItems[index].detail.isEmpty {
                                DetailText(userInputState.dropdownItems[index].detail)
                                    .padding(.top, -6)
                                    .padding(.bottom, 8)
                            }
                            HStack {
                                Picker("", selection: $selectedOption[index]) {
                                    ForEach(userInputState.dropdownItems[index].values, id: \.self) {
                                        Text($0).tag($0)
                                            .font(.system(size: observedData.appProperties.labelFontSize))
                                    }
                                }
                                .onChange(of: selectedOption[index]) { _, selectedOption in
                                    setIfInBounds(&userInputState.dropdownItems, index, \.selectedValue, selectedOption)
                                    setIfInBounds(&observedData.observedUserInputState.dropdownItems, index, \.selectedValue, selectedOption)
                                }
                                .pickerStyle(RadioGroupPickerStyle())
                                Spacer()
                            }
                            // Horozontal Line
                            if !embedded && index < radioCount-1 {
                                Divider().opacity(0.5)
                                    .padding(.top, 10)
                            }
                        }
                    }
                    }
                    // a reset (see enabledif) changes the data; follow it so the control shows the same choice
                    .onChange(of: observedData.observedUserInputState.dropdownItems.indices.contains(index)
                                ? observedData.observedUserInputState.dropdownItems[index].selectedValue : "") { _, newValue in
                        if selectedOption.indices.contains(index), selectedOption[index] != newValue {
                            selectedOption[index] = newValue
                        }
                    }
                    .controlDependencies(observedData, enabledIf: userInputState.dropdownItems[index].enabledIf,
                                         visibleIf: userInputState.dropdownItems[index].visibleIf)
                }
            }
            .font(.system(size: observedData.appProperties.labelFontSize))
            .inputBox(embedded: embedded)
        }
    }
}

