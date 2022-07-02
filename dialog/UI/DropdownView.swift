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
    @State var selectedOption : [String]

    var showDropdown: Bool = cloptions.dropdownValues.present
    var fieldwidth: CGFloat = 0
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
        if !observedDialogContent.args.hideIcon.present { //} cloptions.hideIcon.present {
            fieldwidth = observedDialogContent.windowWidth
        } else {
            fieldwidth = observedDialogContent.windowWidth - appvars.iconWidth
        }
        
        var defaultOptions : [String] = []
        for i in 0..<dropdownItems.count {
            defaultOptions.append(dropdownItems[i].defaultValue)
        }
        _selectedOption = State(initialValue: defaultOptions)
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
                            //update dropdownItems with the option that was selected. this will be printed to stdout on exit
                            dropdownItems[index].selectedValue = selectedOption[index]
                        }
                        Spacer()
                    }
                }
            }
        
        }
    }
}
