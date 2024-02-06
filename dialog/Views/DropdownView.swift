//
//  DropdownView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 2/6/21.
//

import Foundation
import SwiftUI
import Combine


struct DropdownView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @State var selectedOption: [String]

    var fieldwidth: CGFloat = 0

    var dropdownCount = 0

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent

        if !observedDialogContent.args.hideIcon.present {
            fieldwidth = observedDialogContent.args.windowWidth.value.floatValue()
        } else {
            fieldwidth = observedDialogContent.args.windowWidth.value.floatValue() - observedDialogContent.args.iconSize.value.floatValue()
        }

        var defaultOptions: [String] = []
        for index in 0..<userInputState.dropdownItems.count {
            defaultOptions.append(userInputState.dropdownItems[index].defaultValue)
            if userInputState.dropdownItems[index].style != "radio" {
                dropdownCount+=1
            }
            for subIndex in 0..<userInputState.dropdownItems[index].values.count {
                let selectValue = userInputState.dropdownItems[index].values[subIndex]
                if selectValue.hasPrefix("---") && !selectValue.hasSuffix("<") {
                    // We need to modify each `---` entry so it is unique and doesn't cause errors when building the menu
                    userInputState.dropdownItems[index].values[subIndex].append(String(repeating: "-", count: subIndex).appending("<"))
                }
            }
        }
        _selectedOption = State(initialValue: defaultOptions)

        if dropdownCount > 0 {
            writeLog("Displaying select list")
        }
    }

    var body: some View {
        if observedData.args.dropdownValues.present && dropdownCount > 0 {
            VStack {
                ForEach(0..<userInputState.dropdownItems.count, id: \.self) {index in
                    if userInputState.dropdownItems[index].style != "radio" {
                        HStack {
                            // we could print the title as part of the picker control but then we don't get easy access to swiftui text formatting
                            // so we print it seperatly and use a blank value in the picker
                            Text(userInputState.dropdownItems[index].title + (userInputState.dropdownItems[index].required ? " *":""))
                                .frame(idealWidth: fieldwidth*0.20, alignment: .leading)
                            Spacer()
                            Picker("", selection: $selectedOption[index]) {
                                if userInputState.dropdownItems[index].defaultValue.isEmpty {
                                    // prevents "Picker: the selection "" is invalid and does not have an associated tag" errors on stdout
                                    // this does mean we are creating a blank selection but it will still be index -1
                                    // previous indexing schemes (first entry being index 0 etc) should still apply.
                                    Text("").tag("")
                                }
                                ForEach(userInputState.dropdownItems[index].values, id: \.self) {
                                    if $0.hasPrefix("---") {
                                        Divider()
                                    } else {
                                        Text($0).tag($0)
                                            .font(.system(size: observedData.appProperties.labelFontSize))
                                    }
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .onChange(of: selectedOption[index], perform: { selectedOption in
                                userInputState.dropdownItems[index].selectedValue = selectedOption
                            })
                            .frame(idealWidth: fieldwidth*0.50, maxWidth: 350, alignment: .trailing)
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(userInputState.dropdownItems[index].requiredfieldHighlight, lineWidth: 2)
                                .animation(
                                    .easeIn(duration: 0.2).repeatCount(3, autoreverses: true),
                                    value: observedData.showSheet
                                )
                            )
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
