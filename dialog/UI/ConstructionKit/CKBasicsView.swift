//
//  CKBasicsView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKBasicsView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    let alignmentArray = ["left", "centre", "right"]
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }
    
    var body: some View {
        
        VStack {
            LabelView(label: "Title")
            HStack {
                TextField("", text: $observedData.args.titleOption.value)
                ColorPicker("Colour",selection: $observedData.titleFontColour)
                Button("Reset") {
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
            HStack {
                Picker("Text Alignment", selection: $observedData.args.messageAlignment.value)
                {
                    ForEach(alignmentArray, id: \.self) {
                        Text($0)
                    }
                }
                ColorPicker("Colour",selection: $observedData.appProperties.messageFontColour)
                Button("Reset") {
                    observedData.appProperties.messageFontColour = .primary
                }
            }
            TextEditor(text: $observedData.args.messageOption.value)
                .frame(minHeight: 50)
        }
        .padding(20)

    }
}

