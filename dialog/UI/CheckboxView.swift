//
//  CheckboxView.swift
//  dialog
//
//  Created by Bart Reardon on 23/1/2022.
//

import SwiftUI

struct CheckboxView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    var toggleStyle : any ToggleStyle = .checkbox

    var rowHeight : CGFloat = 10
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        
        if observedData.appProperties.checkboxControlSize == .large {
            rowHeight = observedData.appProperties.messageFontSize + 24
        } else {
            rowHeight = observedData.appProperties.messageFontSize + 14
        }
        
    }

    var body: some View {
        if observedData.args.checkbox.present {
            VStack {
                ForEach(0..<observedData.appProperties.checkboxArray.count, id: \.self) {index in
                    HStack {
                        if observedData.appProperties.checkboxControlStyle == "switch" {
                            if observedData.appProperties.checkboxArray[index].icon != "" {
                                IconView(image: observedData.appProperties.checkboxArray[index].icon, overlay: "")
                                    .frame(height: rowHeight)
                            } else {
                                IconView(image: "none", overlay: "")
                                    .frame(height: rowHeight)
                            }
                            Text(observedData.appProperties.checkboxArray[index].label)
                                //.frame(minWidth: 120, alignment: .leading)
                            Spacer()
                            Toggle("", isOn: $observedData.appProperties.checkboxArray[index].checked)
                                .toggleStyle(.switch)
                                .disabled(observedData.appProperties.checkboxArray[index].disabled)
                                .controlSize(observedData.appProperties.checkboxControlSize)
                        } else {
                            Toggle(observedData.appProperties.checkboxArray[index].label, isOn: $observedData.appProperties.checkboxArray[index].checked)
                                .toggleStyle(.checkbox)
                                .disabled(observedData.appProperties.checkboxArray[index].disabled)
                            Spacer()
                        }
                    }
                    .font(.system(size: 16))
                    .frame(alignment: .center)
                    .frame(width: .infinity)
                    
                    // Horozontal Line
                    if index < observedData.appProperties.checkboxArray.count-1 {
                        Divider().opacity(0.5)
                    }
                }
            }
            .padding(10)
            .background(Color.background.opacity(0.5))
            .cornerRadius(8)
            //.border(.red)
            //.padding(.leading, observedData.appProperties.sidePadding)
            //.padding(.trailing, observedData.appProperties.sidePadding)
        }
    }
}


