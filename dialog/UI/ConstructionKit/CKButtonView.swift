//
//  CKButtonView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKButtonView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }
    
    var body: some View {
        VStack { //buttons
            VStack {
                LabelView(label: "Button1")
                HStack {
                    Toggle("Disabled", isOn: $observedData.args.button1Disabled.present)
                        .toggleStyle(.switch)
                    TextField("", text: $observedData.args.button1TextOption.value)
                }
            }
            VStack {
                LabelView(label: "Button2")
                HStack {
                    Toggle("Visible", isOn: $observedData.args.button2Option.present)
                        .onChange(of: observedData.args.button2Option.present, perform: { _ in
                            observedData.args.button2TextOption.present.toggle()
                        })
                        .toggleStyle(.switch)
                    TextField("", text: $observedData.args.button2TextOption.value)
                }
            }
            VStack {
                LabelView(label: "Info Button")
                HStack {
                    Toggle("Visible", isOn: $observedData.args.infoButtonOption.present)
                        .onChange(of: observedData.args.infoButtonOption.present, perform: { _ in
                            observedData.args.infoText.present = !observedData.args.infoButtonOption.present
                            //observedData.args.buttonInfoTextOption.present = true
                        })
                        .toggleStyle(.switch)
                    Toggle("Quit on Info", isOn: $observedData.args.quitOnInfo.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                HStack {
                    Text("Label: ")
                    TextField("", text: $observedData.args.buttonInfoTextOption.value)
                }
                HStack {
                    Text("Info Button Action: ")
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


