//
//  CKMessageView.swift
//  dialog
//
//  Created by Reardon, Bart (IM&T, Black Mountain) on 23/10/2025.
//

import SwiftUI


struct CKMessageView: View {
    @ObservedObject var observedData: DialogUpdatableContent


    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        CKLabelView(label: "Message".localized)
        VStack {
            HStack {
                Picker("Text Alignment".localized, selection: $observedData.args.messageAlignment.value) {
                    Text("").tag("")
                    ForEach(appDefaults.allignmentStates.keys.sorted(), id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: observedData.args.messageAlignment.value) { _, state in
                    observedData.appProperties.messageAlignment = appDefaults.allignmentStates[state] ?? .leading
                    observedData.args.messageAlignment.present = true
                }
                Toggle("Vertical Position".localized, isOn: $observedData.args.messageVerticalAlignment.present)
                    .toggleStyle(.switch)
                ColorPicker("Colour".localized, selection: $observedData.appProperties.messageFontColour)
                Button("Reset".localized) {
                    observedData.appProperties.messageFontColour = .primary
                }
            }
            CKMarkdownEditor(text: $observedData.args.messageOption.value,
                             source: $observedData.messageSource,
                             present: $observedData.args.messageOption.present,
                             minHeight: 50)
        }
        .padding(20)
    }

}
