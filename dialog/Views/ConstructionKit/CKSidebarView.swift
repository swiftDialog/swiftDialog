//
//  CKIconView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKSidebarView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        ScrollView { // infoBox
            VStack {
                CKLabelView(label: "Infobox".localized)
                HStack {
                    Toggle("Visible".localized, isOn: $observedData.args.infoBox.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                CKMarkdownEditor(text: $observedData.args.infoBox.value,
                                 source: $observedData.infoBoxSource,
                                 present: $observedData.args.infoBox.present,
                                 minHeight: 100)
            }
            VStack {
                CKLabelView(label: "Infotext".localized)
                HStack {
                    Toggle("Visible".localized, isOn: $observedData.args.infoText.present)
                        .toggleStyle(.switch)
                    TextField("Infotext".localized, text: $observedData.args.infoText.value)
                }
            }

        }
        .padding(20)
        Spacer()
    }
}
