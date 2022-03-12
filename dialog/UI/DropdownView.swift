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
    
    @State var selectedOption = cloptions.dropdownDefault.value

    var dropdownValues = appvars.dropdownValuesArray
    var dropdownTitle: String = cloptions.dropdownTitle.value
    var showDropdown: Bool = cloptions.dropdownValues.present
    var defaultValue: String = ""
    var fieldwidth: CGFloat = 0
    
    init() {
        if cloptions.hideIcon.present {
            fieldwidth = appvars.windowWidth
        } else {
            fieldwidth = appvars.windowWidth - appvars.iconWidth
        }
    }
        
    var body: some View {
        if showDropdown {
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
        }
    }
}
