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
    
    @State var selectedOption = CLOptionText(OptionName: CLOptions.dropdownDefault, DefaultValue: "")
    //@Binding var selectedOption: String = CLOptionText(OptionName: CLOptions.dropdownDefault, DefaultValue: "")
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
            dropdownValues = dropdownValues.map { $0.trimmingCharacters(in: .whitespaces) }
            dropdownTitle = CLOptionText(OptionName: CLOptions.dropdownTitle)
        }
        if CLOptionPresent(OptionName: CLOptions.dropdownDefault) && CLOptionText(OptionName: CLOptions.dropdownValues).contains(CLOptionText(OptionName: CLOptions.dropdownDefault)) {
            appvars.selectedOption = selectedOption
        }
        
        //.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func updateSelectedOption() {
        appvars.selectedOption = self.selectedOption
    }
    
    var body: some View {
        if showDropdown {
            HStack {
                Text(dropdownTitle).bold()
                Picker("", selection: $selectedOption)
                {
                    ForEach(dropdownValues, id: \.self) {
                        Text($0)
                    }
                }.frame(width: 200)
                .pickerStyle(DefaultPickerStyle())
                .onChange(of: selectedOption) { _ in
                            //print(selectedOption)
                            appvars.selectedOption = selectedOption
                        }
                
            }
        }
    }
    
    
}
