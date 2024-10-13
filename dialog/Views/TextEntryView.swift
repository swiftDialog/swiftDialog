//
//  TextEntryView.swift
//  dialog
//
//  Created by Reardon, Bart  on 23/7/21.
//

import SwiftUI
import UniformTypeIdentifiers

struct TextEntryView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @State var textfieldContent: [TextFieldState]
    @State var datepickerID: [Int]

    var fieldwidth: CGFloat = 0
    var textFieldValidationOpacity: CGFloat = 0

    let dateFormatter = DateFormatter()

    init(observedDialogContent: DialogUpdatableContent, textfieldContent: [TextFieldState]) {
        // we take in textfieldContent but that just populates the State variable
        // When the state variable is updated, the global textFields variable initiated in AppState.swift is updated

        self.observedData = observedDialogContent
        if !observedDialogContent.args.hideIcon.present { //} appArguments.hideIcon.present {
            fieldwidth = observedDialogContent.args.windowWidth.value.floatValue()
        } else {
            fieldwidth = observedDialogContent.args.windowWidth.value.floatValue() - observedDialogContent.args.iconSize.value.floatValue()
        }
        if observedDialogContent.args.textField.present {
            writeLog("Displaying text entry")
            writeLog("\(userInputState.textFields.count) textfields detected")
        }
        self.textfieldContent = textfieldContent
        datepickerID = Array(0...textfieldContent.count)

        if observedDialogContent.args.textFieldLiveValidation.present {
            textFieldValidationOpacity = 0.1
        }
    }

    func openFilePanel(fileType: String, completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if fileType != "" {
            var fileTypesArray: [UTType] = []
            for type in fileType.components(separatedBy: " ") {
                switch type {
                case "folder":
                    panel.canChooseDirectories = true
                case "image":
                    fileTypesArray.append(UTType.image)
                case "movie","video":
                    fileTypesArray.append(UTType.movie)
                case "audio":
                    fileTypesArray.append(UTType.audio)
                default:
                    fileTypesArray.append(UTType(filenameExtension: type) ?? .item)
                }
            }
            panel.allowedContentTypes = fileTypesArray
        }
        // Find the main app window
        if let window = NSApp.mainWindow {
            // Begin the modal as a sheet attached to the window
            panel.beginSheetModal(for: window, completionHandler: { response in
                // Handle the response after the panel is dismissed
                if response == .OK {
                    completion(panel.url?.path ?? "")  // Call the completion handler with the selection
                }
            })
        }
    }

    var body: some View {
        if observedData.args.textField.present {
            VStack {
                ForEach(0..<textfieldContent.count, id: \.self) {index in
                    if textfieldContent[index].editor {
                        VStack {
                            HStack {
                                Text(textfieldContent[index].title + (textfieldContent[index].required ? " *":""))
                                    .frame(alignment: .leading)
                                Spacer()
                            }
                            TextEditor(text: $textfieldContent[index].value)
                                .onChange(of: textfieldContent[index].value, perform: { textContent in
                                    userInputState.textFields[index].value = textContent
                                })
                                .background(Color("editorBackgroundColour"))
                                .font(.custom("HelveticaNeue", size: 14))
                                .cornerRadius(3.0)
                                .frame(minHeight: 80, maxHeight: observedData.appProperties.windowHeight/2)
                                .overlay(RoundedRectangle(cornerRadius: 5)
                                    .stroke(userInputState.textFields[index].requiredTextfieldHighlight, lineWidth: 2)
                                            .animation(
                                                .easeIn(duration: 0.2)
                                                .repeatCount(3, autoreverses: true),
                                                value: observedData.showSheet
                                            )
                                         )
                        }
                        .padding(.bottom, observedData.appProperties.contentPadding)
                    } else {
                        HStack {
                            VStack {
                                HStack {
                                    Text(textfieldContent[index].title + (textfieldContent[index].required ? " *":""))
                                    Spacer()
                                }
                                if textfieldContent[index].confirm {
                                    HStack {
                                        Text("Confirm".localized + " \(textfieldContent[index].title)")
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 5)
                                        Spacer()
                                    }
                                }
                            }
                            .frame(idealWidth: fieldwidth*0.20, alignment: .leading)
                            Spacer()

                            if textfieldContent[index].fileSelect {
                                Button("button-select".localized) {
                                    openFilePanel(fileType: textfieldContent[index].fileType) { selectedPath in
                                         textfieldContent[index].value = selectedPath
                                    }
                                }
                            }
                            HStack {
                                if textfieldContent[index].secure {
                                    VStack {
                                        ZStack {
                                            SecureField(textfieldContent[index].prompt, text: $textfieldContent[index].value)
                                                .disableAutocorrection(true)
                                                .textContentType(textfieldContent[index].passwordFill ? .password: .none)
                                                .onChange(of: textfieldContent[index].value, perform: { textContent in
                                                    userInputState.textFields[index].value = textContent
                                                })
                                            Image(systemName: "lock.fill")
                                                .foregroundColor(Color(argument: "#008815")).opacity(0.5)
                                                .frame(idealWidth: fieldwidth*0.50, maxWidth: 350, alignment: .trailing)
                                        }
                                        if textfieldContent[index].confirm {
                                            ZStack {
                                                SecureField(textfieldContent[index].prompt, text: $textfieldContent[index].validationValue)
                                                    .onChange(of: textfieldContent[index].validationValue, perform: { textContent in
                                                        userInputState.textFields[index].validationValue = textContent
                                                    })
                                                Image(systemName: "lock.fill")
                                                    .foregroundColor(Color(argument: "#008815")).opacity(0.5)
                                                    .frame(idealWidth: fieldwidth*0.50, maxWidth: 350, alignment: .trailing)
                                            }
                                            .padding(.top, 5)
                                        }
                                    }
                                } else {
                                    VStack {
                                        TextField(textfieldContent[index].prompt, text: $textfieldContent[index].value)
                                            .onChange(of: textfieldContent[index].value, perform: { textContent in
                                                userInputState.textFields[index].value = textContent
                                                if textfieldContent[index].regex != "" && observedData.args.textFieldLiveValidation.present {
                                                    if checkRegexPattern(regexPattern: textfieldContent[index].regex, textToValidate: textfieldContent[index].value) {
                                                        textfieldContent[index].backgroundColour = Color.green
                                                    } else {
                                                        textfieldContent[index].backgroundColour = Color.red
                                                    }
                                                    if textfieldContent[index].value == "" {
                                                        textfieldContent[index].backgroundColour = Color.clear
                                                    }
                                                }
                                            })
                                        //.background(textfieldContent[index].backgroundColour)
                                        if textfieldContent[index].confirm {
                                            TextField(textfieldContent[index].prompt, text: $textfieldContent[index].validationValue)
                                                .onChange(of: textfieldContent[index].validationValue, perform: { textContent in
                                                    userInputState.textFields[index].validationValue = textContent
                                                })
                                        }
                                    }


                                    if textfieldContent[index].isDate {
                                        DatePicker("", selection: $textfieldContent[index].date, displayedComponents: [.date])
                                            .onChange(of: textfieldContent[index].date, perform: { dateContent in
                                                dateFormatter.timeStyle = .none
                                                dateFormatter.dateStyle = .short
                                                textfieldContent[index].value = dateFormatter.string(from: dateContent)
                                                datepickerID[index] += 1 // stupid hack to make the picker disappear when a date is selected
                                            })
                                            .labelsHidden()
                                            .id(datepickerID[index])
                                    }
                                }
                            }
                            .frame(idealWidth: fieldwidth*0.50, maxWidth: 350, alignment: .trailing)

                            .overlay(RoundedRectangle(cornerRadius: 5)
                                        .stroke(userInputState.textFields[index].requiredTextfieldHighlight, lineWidth: 2)
                                        .animation(
                                            .easeIn(duration: 0.2)
                                            .repeatCount(3, autoreverses: true),
                                            value: observedData.showSheet
                                        )
                                            .background(textfieldContent[index].backgroundColour.opacity(textFieldValidationOpacity))
                                     )
                        }
                    }
                }
            }
            .font(.system(size: observedData.appProperties.labelFontSize))
            .padding(10)
            .background(Color.background.opacity(0.5))
            .cornerRadius(8)
        }
    }
}
