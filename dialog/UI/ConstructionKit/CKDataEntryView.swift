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
                        .onChange(of: textfieldContent[item].required, perform: { textRequired in
                            observedData.requiredFieldsPresent.toggle()
                            userInputState.textFields[item].required = textRequired
                        })
                        .toggleStyle(.switch)
                    Toggle("ck-secure".localized, isOn: $textfieldContent[item].secure)
                        .onChange(of: textfieldContent[item].secure, perform: { textSecure in
                            userInputState.textFields[item].secure = textSecure
                        })
                        .toggleStyle(.switch)
                    Spacer()
                }
                HStack {
                    TextField("ck-title".localized, text: $textfieldContent[item].title)
                        .onChange(of: textfieldContent[item].title, perform: { textTitle in
                            userInputState.textFields[item].title = textTitle
                        })
                    TextField("ck-value".localized, text: $textfieldContent[item].value)
                        .onChange(of: textfieldContent[item].value, perform: { textValue in
                            userInputState.textFields[item].value = textValue
                        })
                    TextField("ck-prompt".localized, text: $textfieldContent[item].prompt)
                        .onChange(of: textfieldContent[item].prompt, perform: { textPrompt in
                            userInputState.textFields[item].prompt = textPrompt
                        })
                }
                .padding(.leading, 20)
                HStack {
                    TextField("ck-regex".localized, text: $textfieldContent[item].regex)
                        .onChange(of: textfieldContent[item].regex, perform: { textRegex in
                            userInputState.textFields[item].regex = textRegex
                        })
                    TextField("ck-regexerror".localized, text: $textfieldContent[item].regexError)
                        .onChange(of: textfieldContent[item].regexError, perform: { textRegexError in
                            userInputState.textFields[item].regexError = textRegexError
                        })
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

