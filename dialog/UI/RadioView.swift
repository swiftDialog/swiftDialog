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
    @ObservedObject var observedData : DialogUpdatableContent
    @State var selectedOption : [String]

    var fieldwidth: CGFloat = 0
    
    var radioCount = 0
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        
        if !observedDialogContent.args.hideIcon.present {
            fieldwidth = string2float(string: observedDialogContent.args.windowWidth.value)
        } else {
            fieldwidth = string2float(string: observedDialogContent.args.windowWidth.value) - string2float(string: observedDialogContent.args.iconSize.value)
        }
                
        var defaultOptions : [String] = []
        for i in 0..<observedDialogContent.appProperties.dropdownItems.count {
            if observedDialogContent.appProperties.dropdownItems[i].defaultValue.isEmpty {
                observedDialogContent.appProperties.dropdownItems[i].defaultValue = observedDialogContent.appProperties.dropdownItems[i].values[0]
                observedDialogContent.appProperties.dropdownItems[i].selectedValue = observedDialogContent.appProperties.dropdownItems[i].values[0]
            }
            defaultOptions.append(observedDialogContent.appProperties.dropdownItems[i].defaultValue)
            if observedDialogContent.appProperties.dropdownItems[i].style == "radio" {
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
                ForEach(0..<observedData.appProperties.dropdownItems.count, id: \.self) {index in
                    if observedData.appProperties.dropdownItems[index].style == "radio" {
                        VStack {
                            HStack {
                                Text(observedData.appProperties.dropdownItems[index].title + (observedData.appProperties.dropdownItems[index].required ? " *":""))
                                    .frame(alignment: .leading)
                                Spacer()
                            }
                            HStack {
                                Picker("", selection: $observedData.appProperties.dropdownItems[index].selectedValue)
                                {
                                    ForEach(observedData.appProperties.dropdownItems[index].values, id: \.self) {
                                        Text($0).tag($0)
                                            .font(.system(size: observedData.appProperties.labelFontSize))
                                    }
                                }
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

