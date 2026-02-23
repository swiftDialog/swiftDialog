//
//  CKButtonView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKButtonView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @State var buttonFontSize: CGFloat = 16

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        ScrollView { //buttons
            VStack {
                 LabelView(label: "Button Size".localized)
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
                         .onChange(of: observedData.args.buttonSize.value) { _, newValue in
                                observedData.appProperties.buttonSize = appDefaults.buttonSizeStates[newValue] ?? .regular
                            }
                 }
                LabelView(label: "Button Text Size".localized)
                HStack {
                    Text("Button Font Size")
                    Slider(value: $buttonFontSize, in: 8...32, step: 1)
                        .onChange(of: buttonFontSize) { _, value in
                            observedData.args.buttonTextSize.value = "\(Int(value))"
                        }
                    Text("\(Int(buttonFontSize))")
                }
                 }
            VStack {
                LabelView(label: "Button1".localized)
                HStack {
                    Toggle("Disabled".localized, isOn: $observedData.args.button1Disabled.present)
                        .toggleStyle(.switch)
                    TextField("", text: $observedData.args.button1TextOption.value)
                }
                HStack {
                    TextField("Symbol", text: $observedData.args.button1Symbol.value)
                }
            }
            VStack {
                LabelView(label: "Button2".localized)
                HStack {
                    Toggle("Visible".localized, isOn: $observedData.args.button2Option.present)
                        .onChange(of: observedData.args.button2Option.present) {
                            observedData.args.button2TextOption.present.toggle()
                        }
                        .toggleStyle(.switch)
                    TextField("", text: $observedData.args.button2TextOption.value)
                }
                HStack {
                    TextField("Symbol", text: $observedData.args.button2Symbol.value)
                }
            }
            VStack {
                LabelView(label: "Info Button".localized)
                HStack {
                    Toggle("Visible".localized, isOn: $observedData.args.infoButtonOption.present)
                        .onChange(of: observedData.args.infoButtonOption.present) {
                            observedData.args.infoText.present = !observedData.args.infoButtonOption.present
                            //observedData.args.buttonInfoTextOption.present = true
                        }
                        .toggleStyle(.switch)
                    Toggle("Quit on Info".localized, isOn: $observedData.args.quitOnInfo.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                HStack {
                    Text("Label: ".localized)
                    TextField("", text: $observedData.args.buttonInfoTextOption.value)
                }
                HStack {
                    TextField("Symbol", text: $observedData.args.buttonInfoSymbol.value)
                }
                HStack {
                    Text("Info Button Action: ".localized)
                    TextField("", text: $observedData.args.buttonInfoActionOption.value)
                        .onChange(of: observedData.args.buttonInfoActionOption.value) {
                            observedData.args.buttonInfoActionOption.present = true
                        }
                    Spacer()
                }
            }
            Spacer()
        }
        .padding(20)
    }
}


