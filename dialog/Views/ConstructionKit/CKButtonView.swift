//
//  CKButtonView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKButtonView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        VStack { //buttons
            VStack {
                     LabelView(label: "ck-buttonsize".localized)
                     HStack {
                         Button("mini") {
                             observedData.args.buttonSize.value = "mini"
                         } .controlSize(.mini)

                         Button("small") {
                             observedData.args.buttonSize.value = "small"
                         } .controlSize(.small)
                         Button("regular") {
                             observedData.args.buttonSize.value = "regular"
                         } .controlSize(.regular)
                         Button("large") {
                             observedData.args.buttonSize.value = "large"
                         } .controlSize(.large)


                         TextField("", text: $observedData.args.buttonSize.value)
                             .onChange(of: observedData.args.buttonSize.value) { newValue in
                                    observedData.appProperties.buttonSize = appDefaults.buttonSizeStates[newValue] ?? .regular
                                }
                     }
                 }
            VStack {
                LabelView(label: "ck-button1".localized)
                HStack {
                    Toggle("ck-disabled".localized, isOn: $observedData.args.button1Disabled.present)
                        .toggleStyle(.switch)
                    TextField("", text: $observedData.args.button1TextOption.value)
                }
            }
            VStack {
                LabelView(label: "ck-button2".localized)
                HStack {
                    Toggle("ck-visible".localized, isOn: $observedData.args.button2Option.present)
                        .onChange(of: observedData.args.button2Option.present, perform: { _ in
                            observedData.args.button2TextOption.present.toggle()
                        })
                        .toggleStyle(.switch)
                    TextField("", text: $observedData.args.button2TextOption.value)
                }
            }
            VStack {
                LabelView(label: "ck-infobuttonlabel".localized)
                HStack {
                    Toggle("ck-visible".localized, isOn: $observedData.args.infoButtonOption.present)
                        .onChange(of: observedData.args.infoButtonOption.present, perform: { _ in
                            observedData.args.infoText.present = !observedData.args.infoButtonOption.present
                            //observedData.args.buttonInfoTextOption.present = true
                        })
                        .toggleStyle(.switch)
                    Toggle("ck-quitoninfo".localized, isOn: $observedData.args.quitOnInfo.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                HStack {
                    Text("ck-label".localized)
                    TextField("", text: $observedData.args.buttonInfoTextOption.value)
                }
                HStack {
                    Text("ck-infobuttonaction".localized)
                    TextField("", text: $observedData.args.buttonInfoActionOption.value)
                        .onChange(of: observedData.args.buttonInfoActionOption.value, perform: { _ in
                            observedData.args.buttonInfoActionOption.present = true
                        })
                    Spacer()
                }
            }
            Spacer()
        }
        .padding(20)
    }
}


