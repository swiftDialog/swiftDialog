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
    
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    
    //@State var selectedOption = cloptions.dropdownDefault.value
    @State var selectedOption : [String] //= Array(repeating: "", count: dropdownItems.count)
    //var defaultOption = Array(repeating: "", count: dropdownItems.count)

    var dropdownValues = appvars.dropdownValuesArray
    var dropdownTitle: String = cloptions.dropdownTitle.value
    var showDropdown: Bool = cloptions.dropdownValues.present
    var defaultValue: String = ""
    var fieldwidth: CGFloat = 0
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
        if cloptions.hideIcon.present {
            fieldwidth = appvars.windowWidth
        } else {
            fieldwidth = appvars.windowWidth - appvars.iconWidth
        }
        
        var defaultOptions : [String] = []
        for i in 0..<dropdownItems.count {
            print("default \(i) is \(dropdownItems[i].defaultValue)")
            defaultOptions.append(dropdownItems[i].defaultValue)
            //selectedOption[i] = State(initialValue: dropdownItems[i].defaultValue) //.init(initialValue: dropdownItems[i].defaultValue)
            //selectedOption.append(dropdownItems[i].defaultValue)
        }
        _selectedOption = State(initialValue: defaultOptions)
        print(selectedOption)
    }
        
    var body: some View {
        if showDropdown {
            VStack {
                ForEach(0..<dropdownItems.count, id: \.self) {index in
                    HStack {
                        // we could print the title as part of the picker control but then we don't get easy access to swiftui text formatting
                        // so we print it seperatly and use a blank value in the picker
                        Spacer()
                        Text(dropdownItems[index].title)
                            .bold()
                            .font(.system(size: 15))
                            .frame(idealWidth: fieldwidth*0.20, maxWidth: 150, alignment: .leading)
                        Spacer()
                            .frame(width: 20)
                        Picker("", selection: $selectedOption[index])
                        {
                            ForEach(dropdownItems[index].values, id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(DefaultPickerStyle())
                        .frame(idealWidth: fieldwidth*0.50, maxWidth: 300, alignment: .trailing)
                        .onChange(of: selectedOption[index]) { _ in
                            //update appvars with the option that was selected. this will be printed to stdout on exit
                            //appvars.selectedOption = selectedOption[index]
                            //appvars.selectedIndex = dropdownValues.firstIndex {$0 == selectedOption[index]} ?? -1
                        }
                        Spacer()
                    }
                }
            }
            
            /*
            HStack {
                // we could print the title as part of the picker control but then we don't get easy access to swiftui text formatting
                // so we print it seperatly and use a blank value in the picker
                Spacer()
                Text(dropdownTitle)
                    .bold()
                    .font(.system(size: 15))
                    .frame(idealWidth: fieldwidth*0.20, maxWidth: 150, alignment: .leading)
                Spacer()
                    .frame(width: 20)
                Picker("", selection: $selectedOption)
                {
                    ForEach(dropdownValues, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(DefaultPickerStyle())
                .frame(idealWidth: fieldwidth*0.50, maxWidth: 300, alignment: .trailing)
                .onChange(of: selectedOption) { _ in
                    //update appvars with the option that was selected. this will be printed to stdout on exit
                    appvars.selectedOption = selectedOption
                    appvars.selectedIndex = dropdownValues.firstIndex {$0 == selectedOption} ?? -1
                }
                Spacer()
            }
             */
        }
    }
}
