//
//  CKCheckboxes.swift
//  dialog
//
//  Created by Bart Reardon on 22/10/2025.
//

import SwiftUI

struct CKCheckBoxesView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @State private var showHelp: Bool = false

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        VStack {
            CKLabelView(label: "Checkboxes".localized)
            HStack {
                Toggle("Format output as JSON".localized, isOn: $observedData.args.jsonOutPut.present)
                    .toggleStyle(.switch)
                Spacer()
            }
            HStack {
                Button(action: {
                    showHelp.toggle()
                }, label: {
                    Image.init(systemName: "questionmark.app.fill")
                })
                .popover(isPresented: $showHelp) {
                    let sdHelp = SDHelp(arguments: observedData.args)
                    CKHelpView(text: sdHelp.argument.checkbox.helpLong)
                }

                Button(action: {
                    observedData.observedUserInputState.checkBoxes.append(CheckBoxes(label: "New Item"))
                    observedData.args.checkbox.present = true
                    appArguments.checkbox.present = true
                }, label: {
                    Image(systemName: "plus")
                })
                Toggle("Switch Style".localized, isOn: $observedData.args.checkboxStyle.present)
                    .toggleStyle(.switch)
                    .onChange(of: observedData.args.checkboxStyle.present) { _, style in
                        observedData.appProperties.checkboxControlStyle = style ? "switch" : ""
                    }
                Toggle("Show".localized, isOn: $observedData.args.checkbox.present)
                    .toggleStyle(.switch)

                Spacer()
            }
            .padding(.bottom, 20)

            List {
                ForEach($observedData.observedUserInputState.checkBoxes) { $box in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                        CKIconPicker(
                            icon: $box.icon,
                            sfPicker: $box.sfPicker,
                            sfSymbol: $box.sfSymbol,
                            sfColour: $box.sfColour,
                            opacity: box.icon.isEmpty || observedData.appProperties.checkboxControlStyle == "switch" ? 1 : 0.5
                        )

                        TextField("Label".localized, text: $box.label)
                        TextField("Name".localized+": \(box.name)", text: $box.name)
                        Toggle("Checked".localized, isOn: $box.checked)
                            .toggleStyle(.switch)
                        Toggle("Disabled".localized, isOn: $box.disabled)
                            .toggleStyle(.switch)
                        Button(action: {
                            writeLog("Delete checkbox \(box.label)", logLevel: .info)
                            observedData.observedUserInputState.checkBoxes.removeAll { $0.id == box.id }
                        }, label: {
                            Image(systemName: "trash")
                        })
                    }
                }
                .onMove { from, to in
                    withAnimation(.smooth) {
                        observedData.observedUserInputState.checkBoxes.move(fromOffsets: from, toOffset: to)
                    }
                }
            }
        }
        .padding(20)
        // Single sync point to the canonical userInputState used for output/validation.
        .onChange(of: observedData.observedUserInputState.checkBoxes) { _, newValue in
            userInputState.checkBoxes = newValue
        }
    }
}
