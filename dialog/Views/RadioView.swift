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

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent

        if !observedDialogContent.args.hideIcon.present {
            fieldwidth = string2float(string: observedDialogContent.args.windowWidth.value)
        } else {
            fieldwidth = string2float(string: observedDialogContent.args.windowWidth.value) - string2float(string: observedDialogContent.args.iconSize.value)
        }

        var defaultOptions: [String] = []
        for index in 0..<userInputState.dropdownItems.count {
            if userInputState.dropdownItems[index].defaultValue.isEmpty && userInputState.dropdownItems[index].style == "radio" {
                userInputState.dropdownItems[index].defaultValue = userInputState.dropdownItems[index].values[0]
                userInputState.dropdownItems[index].selectedValue = userInputState.dropdownItems[index].values[0]
            }
            defaultOptions.append(userInputState.dropdownItems[index].defaultValue)
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
        if observedData.args.dropdownValues.present && radioCount > 0 {
            VStack {
                ForEach(0..<userInputState.dropdownItems.count, id: \.self) {index in
                    if userInputState.dropdownItems[index].style == "radio" {
                        VStack {
                            HStack {
                                Text(userInputState.dropdownItems[index].title + (userInputState.dropdownItems[index].required ? " *":""))
                                    .frame(alignment: .leading)
                                Spacer()
                            }
                            HStack {
                                Picker("", selection: $selectedOption[index]) {
                                    ForEach(userInputState.dropdownItems[index].values, id: \.self) {
                                        Text($0).tag($0)
                                            .font(.system(size: observedData.appProperties.labelFontSize))
                                    }
                                }
                                .onChange(of: selectedOption[index], perform: { selectedOption in
                                    userInputState.dropdownItems[index].selectedValue = selectedOption
                                })
                                .pickerStyle(RadioGroupPickerStyle())
                                Spacer()
                            }
                            // Horozontal Line
                            if index < radioCount-1 {
                                Divider().opacity(0.5)
                                    .padding(.top, 10)
                            }
                        }
                    }
                }
            }
            .font(.system(size: observedData.appProperties.labelFontSize))
            .padding(10)
            .background(Color.background.opacity(0.5))
            .cornerRadius(8)
        }
    }
}

