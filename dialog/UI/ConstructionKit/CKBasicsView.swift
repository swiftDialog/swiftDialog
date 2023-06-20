//
//  CKBasicsView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKBasicsView: View {
    
    @ObservedObject var observedData: DialogUpdatableContent
    
    let alignmentArray = ["left", "centre", "right"]
    
    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }
    
    var body: some View {
        
        VStack {
            LabelView(label: "ck-title".localized)
            HStack {
                TextField("", text: $observedData.args.titleOption.value)
                ColorPicker("ck-colour".localized,selection: $observedData.appProperties.titleFontColour)
                Button("ck-reset".localized) {
                    observedData.appProperties.titleFontColour = .primary
                }
            }
            HStack {
                Text("ck-fontsize".localized)
                Slider(value: $observedData.appProperties.titleFontSize, in: 10...80)
                TextField("ck-value", value: $observedData.appProperties.titleFontSize, formatter: NumberFormatter())
                    .frame(width: 50)
            }
            
            LabelView(label: "ck-message".localized)
            HStack {
                Picker("ck-textalignment".localized, selection: $observedData.args.messageAlignment.value) {
                    Text("").tag("")
                    ForEach(observedData.appProperties.allignmentStates.keys.sorted(), id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: observedData.args.messageAlignment.value) {
                    observedData.appProperties.messageAlignment = observedData.appProperties.allignmentStates[$0] ?? .leading
                    observedData.args.messageAlignment.present = true
                }
                Toggle("ck-verticalposition".localized, isOn: $observedData.args.messageVerticalAlignment.present)
                    .toggleStyle(.switch)
                ColorPicker("ck-colour".localized,selection: $observedData.appProperties.messageFontColour)
                Button("ck-reset".localized) {
                    observedData.appProperties.messageFontColour = .primary
                }
            }
            TextEditor(text: $observedData.args.messageOption.value)
                .frame(minHeight: 50)
                .background(Color("editorBackgroundColour"))
        }
        .padding(20)

    }
}

