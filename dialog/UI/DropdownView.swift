//
//  DropdownView.swift
//  Dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 2/6/21.
//

import Foundation
import SwiftUI
import Combine


struct DropdownView: View {
    
    @State var selectedOption = CLOptionText(OptionName: CLOptions.dropdownDefault)
    //@Binding var selectedOption: String = CLOptionText(OptionName: CLOptions.dropdownDefault, DefaultValue: "")
    var selectedIndex = -1
    var dropdownValues = [""]
    var dropdownCLValues: String = ""
    var dropdownTitle: String = ""
    
    var showDropdown: Bool = false
    var defaultValue: String = ""
    
    init() {
        if CLOptionPresent(OptionName: CLOptions.dropdownValues) {
            showDropdown = true
            dropdownCLValues = CLOptionText(OptionName: CLOptions.dropdownValues)
            dropdownValues = dropdownCLValues.components(separatedBy: ",")
            dropdownValues = dropdownValues.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma
            dropdownTitle = CLOptionText(OptionName: CLOptions.dropdownTitle)
        }
        if CLOptionPresent(OptionName: CLOptions.dropdownDefault) && CLOptionText(OptionName: CLOptions.dropdownValues).contains(CLOptionText(OptionName: CLOptions.dropdownDefault)) {
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
                Text(dropdownTitle)
                    .bold()
                    .font(.system(size: 15))
                Picker("", selection: $selectedOption)
                {
                    ForEach(dropdownValues, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(DefaultPickerStyle())
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
