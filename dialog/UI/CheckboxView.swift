//
//  CheckboxView.swift
//  dialog
//
//  Created by Bart Reardon on 23/1/2022.
//

import SwiftUI
import ScrollViewIfNeeded

struct renderToggles : View {
    @ObservedObject var observedData : DialogUpdatableContent
    
    var iconPresent : Bool = false
    var rowHeight : CGFloat = 10
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        if observedData.appProperties.checkboxControlSize == .large {
            rowHeight = observedData.appProperties.messageFontSize + 24
        } else {
            rowHeight = observedData.appProperties.messageFontSize + 14
        }
        
        iconPresent = observedData.appProperties.checkboxArray.contains { $0.icon != "" }
    }
    
    var body: some View {
        VStack {
            ForEach(0..<observedData.appProperties.checkboxArray.count, id: \.self) {index in
                HStack {
                    if observedData.appProperties.checkboxControlStyle == "switch" {
                        if iconPresent {
                            if observedData.appProperties.checkboxArray[index].icon != "" {
                                IconView(image: observedData.appProperties.checkboxArray[index].icon, overlay: "")
                                    .frame(height: rowHeight)
                            } else {
                                IconView(image: "none", overlay: "")
                                    .frame(height: rowHeight)
                            }
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
                .frame(alignment: .center)
                .frame(width: .infinity)
                
                // Horozontal Line
                if index < observedData.appProperties.checkboxArray.count-1 {
                    Divider().opacity(0.5)
                }
            }
        }
        .font(.system(size: observedData.appProperties.labelFontSize))
        .padding(10)
        .background(Color.background.opacity(0.5))
        .cornerRadius(8)
    }
}

struct CheckboxView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    @State private var contentSize: CGSize = .zero
    
    var toggleStyle : any ToggleStyle = .checkbox
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        
    }

    var body: some View {
        if observedData.args.checkbox.present {
            VStack {
                if observedData.appProperties.checkboxControlStyle == "switch" {
                    ScrollViewIfNeeded {
                        Spacer()
                        renderToggles(observedDialogContent: observedData)
                    }
                } else {
                    renderToggles(observedDialogContent: observedData)
                }
            }
        }
    }
}


