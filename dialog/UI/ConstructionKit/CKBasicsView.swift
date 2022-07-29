//
//  CKBasicsView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKBasicsView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }
    
    var body: some View {
        
        VStack {
            LabelView(label: "Title")
            HStack {
                TextField("", text: $observedData.args.titleOption.value)
                ColorPicker("Colour",selection: $observedData.titleFontColour)
                Button("Default") {
                    observedData.titleFontColour = .primary
                }
            }
            HStack {
                Text("Font Size: ")
                Slider(value: $observedData.titleFontSize, in: 10...80)
                TextField("value:", value: $observedData.titleFontSize, formatter: NumberFormatter())
                    .frame(width: 50)
            }
            
            LabelView(label: "Message")
            TextEditor(text: $observedData.args.messageOption.value)
                .frame(minHeight: 50)
        }
        .padding(20)

    }
}

