//
//  CKDataEntryView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKTextEntryView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @State private var showHelp: Bool = false

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {

        VStack {
            CKLabelView(label: "Textfields".localized)
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
                    CKHelpView(text: sdHelp.argument.textField.helpLong)
                }

                Button(action: {
                    observedData.textFieldArray.append(TextFieldState(title: "New Text"))
                    observedData.args.textField.present = true
                    appArguments.textField.present = true
                }, label: {
                    Image(systemName: "plus")
                })
                Toggle("Show".localized, isOn: $observedData.args.textField.present)
                    .toggleStyle(.switch)

                Spacer()
            }
            .padding(.bottom, 20)
            ScrollView {
                ForEach($observedData.textFieldArray) { $field in
                    HStack {
                        Toggle("Required".localized, isOn: $field.required)
                            .toggleStyle(.switch)
                        Toggle("Confirm".localized, isOn: $field.confirm)
                            .toggleStyle(.switch)
                        Toggle("File Select".localized, isOn: $field.fileSelect)
                            .toggleStyle(.switch)
                        TextField("File type".localized, text: $field.fileType)
                            .disabled(!field.fileSelect)
                        TextField("Initial path".localized, text: $field.initialPath)
                            .disabled(!field.fileSelect)

                        Spacer()

                        Button(action: {
                            writeLog("Delete textfield \(field.title)", logLevel: .info)
                            observedData.textFieldArray.removeAll { $0.id == field.id }
                        }, label: {
                            Image(systemName: "trash")
                        })
                    }
                    HStack {
                        TextField("Label".localized, text: $field.title)
                        TextField("Name".localized+": \(field.title)", text: $field.name)
                        TextField("Default Value".localized, text: $field.value)
                        TextField("Prompt".localized, text: $field.prompt)
                    }
                    .padding(.leading, 20)
                    HStack {
                        TextField("Regex".localized, text: $field.regex)
                        TextField("Regex Error".localized, text: $field.regexError)
                    }
                    .padding(.leading, 20)
                    Divider()
                        .padding(.bottom, 10)
                }
                .onMove { from, to in
                    withAnimation(.smooth) {
                        observedData.textFieldArray.move(fromOffsets: from, toOffset: to)
                    }
                }
                Spacer()
            }
            // Single sync point: mirror the edited structure to the canonical
            // userInputState the dialog runtime reads from.
            .onChange(of: observedData.textFieldArray) { _, newValue in
                userInputState.textFields = newValue
            }
        }
        .padding(20)
    }
}
