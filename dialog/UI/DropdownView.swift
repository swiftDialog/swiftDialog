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
    
    @ObservedObject var observedData : DialogUpdatableContent
    @State var selectedOption : [String]

    var fieldwidth: CGFloat = 0
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        if !observedDialogContent.args.hideIcon.present {
            fieldwidth = observedDialogContent.windowWidth
        } else {
            fieldwidth = observedDialogContent.windowWidth - observedDialogContent.appProperties.iconWidth
        }
        
        var defaultOptions : [String] = []
        for i in 0..<observedDialogContent.appProperties.dropdownItems.count {
            defaultOptions.append(observedDialogContent.appProperties.dropdownItems[i].defaultValue)
        }
        _selectedOption = State(initialValue: defaultOptions)
    }
        
    var body: some View {
        if observedData.args.dropdownValues.present {
            VStack {
                ForEach(0..<observedData.appProperties.dropdownItems.count, id: \.self) {index in
                    HStack {
                        // we could print the title as part of the picker control but then we don't get easy access to swiftui text formatting
                        // so we print it seperatly and use a blank value in the picker
                        //Spacer()
                        Text(observedData.appProperties.dropdownItems[index].title)
                            .bold()
                            .font(.system(size: 15))
                            .frame(idealWidth: fieldwidth*0.20, alignment: .leading)
                        Spacer()
                        //    .frame(width: 20)
                        Picker("", selection: $selectedOption[index])
                        {
                            ForEach(observedData.appProperties.dropdownItems[index].values, id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        .pickerStyle(DefaultPickerStyle())
                        .frame(idealWidth: fieldwidth*0.50, maxWidth: 350, alignment: .trailing)
                        .onChange(of: selectedOption[index]) { _ in
                            //update observedData.args.dropdownItems with the option that was selected. this will be printed to stdout on exit
                            observedData.appProperties.dropdownItems[index].selectedValue = selectedOption[index]
                        }
                        //Spacer()
                    }
                }
            }
        
        }
    }
}
