//
//  CKDataEntryView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKDataEntryView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @State var textfieldContent: [TextFieldState]

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
        textfieldContent = userInputState.textFields
    }

    var body: some View {
        VStack {
            HStack {
                Toggle("Format output as JSON", isOn: $observedData.args.jsonOutPut.present)
                .toggleStyle(.switch)
                Spacer()
            }
            LabelView(label: "ck-textfields".localized)
            HStack {
                Button(action: {
                    userInputState.textFields.append(TextFieldState(title: ""))
                    textfieldContent.append(TextFieldState(title: ""))
                    observedData.args.textField.present = true
                    appArguments.textField.present = true
                }, label: {
                    Image(systemName: "plus")
                })
                Toggle("ck-show".localized, isOn: $observedData.args.textField.present)
                    .toggleStyle(.switch)

                //Button("Clear All") {
                //    observedData.listItemPresent = false
                //    observedData.listItemsArray = [ListItems]()
                //}

                Spacer()
            }

            ForEach(0..<userInputState.textFields.count, id: \.self) { item in
                HStack {
                    Button(action: {
                        //observedData.listItemsArray.remove(at: i)
                    }, label: {
                        Image(systemName: "trash")
                    })
                    .disabled(true) // MARK: disabled until I can work out how to delete from the array without causing a crash
                    Toggle("ck-required".localized, isOn: $textfieldContent[item].required)
                        .onChange(of: textfieldContent[item].required) {
                            observedData.requiredFieldsPresent.toggle()
                            userInputState.textFields[item].required = textfieldContent[item].required
                        }
                        .toggleStyle(.switch)
                    Toggle("ck-secure".localized, isOn: $textfieldContent[item].secure)
                        .onChange(of: textfieldContent[item].secure) {
                            userInputState.textFields[item].secure = textfieldContent[item].secure
                        }
                        .toggleStyle(.switch)
                    Spacer()
                }
                HStack {
                    TextField("ck-title".localized, text: $textfieldContent[item].title)
                        .onChange(of: textfieldContent[item].title) {
                            userInputState.textFields[item].title = textfieldContent[item].title
                        }
                    TextField("ck-value".localized, text: $textfieldContent[item].value)
                        .onChange(of: textfieldContent[item].value) {
                            userInputState.textFields[item].value = textfieldContent[item].value
                        }
                    TextField("ck-prompt".localized, text: $textfieldContent[item].prompt)
                        .onChange(of: textfieldContent[item].prompt) {
                            userInputState.textFields[item].prompt = textfieldContent[item].prompt
                        }
                }
                .padding(.leading, 20)
                HStack {
                    TextField("ck-regex".localized, text: $textfieldContent[item].regex)
                        .onChange(of: textfieldContent[item].regex) {
                            userInputState.textFields[item].regex = textfieldContent[item].regex
                        }
                    TextField("ck-regexerror".localized, text: $textfieldContent[item].regexError)
                        .onChange(of: textfieldContent[item].regexError) {
                            userInputState.textFields[item].regexError = textfieldContent[item].regexError
                        }
                }
                .padding(.leading, 20)
                Divider()
            }
            LabelView(label: "ck-select".localized)

            LabelView(label: "ck-checkbox".localized)
            Spacer()
        }
        .padding(20)
    }
}

