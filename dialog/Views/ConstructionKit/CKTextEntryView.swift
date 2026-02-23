//
//  CKDataEntryView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKTextEntryView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    //@State var textfieldContent: [TextFieldState]
    @State private var showHelp: Bool = false

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
        //textfieldContent = userInputState.textFields
    }

    var body: some View {
        
        VStack {
            LabelView(label: "Textfields".localized)
            HStack {
                Toggle("Format output as JSON", isOn: $observedData.args.jsonOutPut.present)
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
                    userInputState.textFields.append(TextFieldState(title: "New Text"))
                    observedData.textFieldArray.append(TextFieldState(title: "New Text"))
                    observedData.args.textField.present = true
                    appArguments.textField.present = true
                }, label: {
                    Image(systemName: "plus")
                })
                Toggle("Show".localized, isOn: $observedData.args.textField.present)
                    .toggleStyle(.switch)
                
                //Button("Clear All") {
                //    observedData.listItemPresent = false
                //    observedData.listItemsArray = [ListItems]()
                //}
                
                Spacer()
            }
            .padding(.bottom, 20)
            ScrollView {
                //List {
                ForEach(0..<userInputState.textFields.count, id: \.self) { item in
                    HStack {
                        //Image(systemName: "line.3.horizontal")
                        //    .foregroundColor(.secondary)
                        
                        
                        Toggle("Required".localized, isOn: $observedData.textFieldArray[item].required)
                            .onChange(of: observedData.textFieldArray[item].required) { _, textRequired in
                                observedData.requiredFieldsPresent.toggle()
                                userInputState.textFields[item].required = textRequired
                            }
                            .toggleStyle(.switch)
                        
                        Toggle("Confirm".localized, isOn: $observedData.textFieldArray[item].confirm)
                            .onChange(of: observedData.textFieldArray[item].confirm) { _, textSecure in
                                userInputState.textFields[item].confirm = textSecure
                            }
                            .toggleStyle(.switch)
                        Toggle("File Select".localized, isOn: $observedData.textFieldArray[item].fileSelect)
                            .onChange(of: observedData.textFieldArray[item].fileSelect) { _, textSecure in
                                userInputState.textFields[item].fileSelect = textSecure
                            }
                            .toggleStyle(.switch)
                        //filetype
                        TextField("File type".localized, text: $observedData.textFieldArray[item].fileType)
                            .onChange(of: observedData.textFieldArray[item].title) { _, textTitle in
                                userInputState.textFields[item].title = textTitle
                            }
                            .disabled(!observedData.textFieldArray[item].fileSelect)
                        
                        //filepath
                        TextField("Initial path".localized, text: $observedData.textFieldArray[item].initialPath)
                            .onChange(of: observedData.textFieldArray[item].title) { _, textTitle in
                                userInputState.textFields[item].title = textTitle
                            }
                            .disabled(!observedData.textFieldArray[item].fileSelect)
                        
                        
                        Spacer()
                        
                        Button(action: {
                            guard item >= 0 && item < observedData.textFieldArray.count else {
                                writeLog("Could not delete textfield at position \(item)", logLevel: .info)
                                return
                            }
                            writeLog("Delete textfield at position \(item)", logLevel: .info)
                            userInputState.textFields.remove(at: item)
                            observedData.textFieldArray.remove(at: item)
                        }, label: {
                            Image(systemName: "trash")
                        })
                    }
                    HStack {
                        TextField("Label".localized, text: $observedData.textFieldArray[item].title)
                            .onChange(of: observedData.textFieldArray[item].title) { _, textTitle in
                                userInputState.textFields[item].title = textTitle
                            }
                        TextField("Name".localized+": \(observedData.textFieldArray[item].title)", text: $observedData.textFieldArray[item].name)
                            .onChange(of: observedData.textFieldArray[item].name) { _, textTitle in
                                userInputState.textFields[item].name = textTitle
                            }
                        TextField("Default Value".localized, text: $observedData.textFieldArray[item].value)
                            .onChange(of: observedData.textFieldArray[item].value) { _, textValue in
                                userInputState.textFields[item].value = textValue
                            }
                        TextField("Prompt".localized, text: $observedData.textFieldArray[item].prompt)
                            .onChange(of: observedData.textFieldArray[item].prompt) { _, textPrompt in
                                userInputState.textFields[item].prompt = textPrompt
                            }
                    }
                    .padding(.leading, 20)
                    HStack {
                        TextField("Regex".localized, text: $observedData.textFieldArray[item].regex)
                            .onChange(of: observedData.textFieldArray[item].regex) { _, textRegex in
                                userInputState.textFields[item].regex = textRegex
                            }
                        TextField("Regex Error".localized, text: $observedData.textFieldArray[item].regexError)
                            .onChange(of: observedData.textFieldArray[item].regexError) { _, textRegexError in
                                userInputState.textFields[item].regexError = textRegexError
                            }
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
        }
        .padding(20)
    }
}

