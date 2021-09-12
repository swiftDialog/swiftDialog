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
    
    @State var selectedOption = cloptions.dropdownDefault.value // CLOptionText(OptionName: cloptions.dropdownDefault)
    //@Binding var selectedOption: String = CLOptionText(OptionName: cloptions.dropdownDefault, DefaultValue: "")
    var selectedIndex = -1
    var dropdownValues = [""]
    var dropdownCLValues: String = ""
    var dropdownTitle: String = ""
    
    var showDropdown: Bool = false
    var defaultValue: String = ""
    
    init() {
        if cloptions.dropdownValues.present {
            showDropdown = true
            dropdownCLValues = cloptions.dropdownValues.value
            dropdownValues = dropdownCLValues.components(separatedBy: ",")
            dropdownValues = dropdownValues.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma
            dropdownTitle = cloptions.dropdownTitle.value
        }
        if cloptions.dropdownDefault.present && cloptions.dropdownValues.value.contains(cloptions.dropdownDefault.value) {
            appvars.selectedOption = selectedOption
            appvars.selectedIndex = dropdownValues.firstIndex {$0 == selectedOption} ?? -1
            //appvars.selectedIndex += 1
        }
    }
    
    func updateSelectedOption() {
        appvars.selectedOption = self.selectedOption
    }
    
    var body: some View {
        if showDropdown {
            HStack {
                // we could print the title as part of the picker control but then we don't get easy access to swiftui text formatting
                // so we print it seperatly and use a blank value in the picker
                //Spacer()
                Text(dropdownTitle)
                    .bold()
                    .font(.system(size: 15))
                    .frame(alignment: .leading)
                Spacer()
                Picker("", selection: $selectedOption)
                {
                    ForEach(dropdownValues, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(DefaultPickerStyle())
                .frame(width: appvars.windowWidth*0.45, alignment: .trailing)
                .onChange(of: selectedOption) { _ in
                            //update appvars with the option that was selected. this will be printed to stdout on exit
                            appvars.selectedOption = selectedOption
                            appvars.selectedIndex = dropdownValues.firstIndex {$0 == selectedOption} ?? -1
                            //appvars.selectedIndex += 1  // removed by popular opinion
                        }
            }
        }
    }
    
    
}
