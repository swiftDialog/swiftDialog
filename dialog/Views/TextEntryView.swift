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
    //@State var textfieldContent: [TextFieldState]
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
        //self.textfieldContent = textfieldContent
        datepickerID = Array(0...textfieldContent.count)

        if observedDialogContent.args.textFieldLiveValidation.present {
            textFieldValidationOpacity = 0.1
        }
    }

    func openFilePanel(fileType: String, initialPath: String, completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if initialPath.isEmpty {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        } else {
            panel.directoryURL = URL(string: "file://\(initialPath)")
        }
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
                ForEach(0..<observedData.textFieldArray.count, id: \.self) {index in
                    if observedData.textFieldArray[index].editor {
                        VStack {
                            HStack {
                                Text(observedData.textFieldArray[index].title + (observedData.textFieldArray[index].required ? " *":""))
                                    .frame(alignment: .leading)
                                Spacer()
                            }
                            TextEditor(text: $observedData.textFieldArray[index].value)
                                .onChange(of: observedData.textFieldArray[index].value) { _, textContent in
                                    userInputState.textFields[index].value = textContent
                                }
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
                        .padding(.bottom, appDefaults.contentPadding)
                    } else {
                        HStack {
                            VStack {
                                HStack {
                                    Text(observedData.textFieldArray[index].title + (observedData.textFieldArray[index].required ? " *":""))
                                    Spacer()
                                }
                                if observedData.textFieldArray[index].confirm {
                                    HStack {
                                        Text("Confirm".localized + " \(observedData.textFieldArray[index].title)")
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 5)
                                        Spacer()
                                    }
                                }
                            }
                            .frame(idealWidth: fieldwidth*0.20, alignment: .leading)
                            Spacer()

                            if observedData.textFieldArray[index].fileSelect {
                                Button("Select".localized) {
                                    openFilePanel(fileType: observedData.textFieldArray[index].fileType, initialPath: observedData.textFieldArray[index].initialPath) { selectedPath in
                                         observedData.textFieldArray[index].value = selectedPath
                                    }
                                }
                            }
                            HStack {
                                if observedData.textFieldArray[index].secure {
                                    VStack {
                                        ZStack {
                                            SecureField(observedData.textFieldArray[index].prompt, text: $observedData.textFieldArray[index].value)
                                                .disableAutocorrection(true)
                                                .textContentType(observedData.textFieldArray[index].passwordFill ? .password: .none)
                                                .onChange(of: observedData.textFieldArray[index].value,) { _, textContent in
                                                    userInputState.textFields[index].value = textContent
                                                }
                                            Image(systemName: "lock.fill")
                                                .foregroundColor(Color(argument: "#008815")).opacity(0.5)
                                                .frame(idealWidth: fieldwidth*0.50, maxWidth: 350, alignment: .trailing)
                                        }
                                        if observedData.textFieldArray[index].confirm {
                                            ZStack {
                                                SecureField(observedData.textFieldArray[index].prompt, text: $observedData.textFieldArray[index].validationValue)
                                                    .onChange(of: observedData.textFieldArray[index].validationValue) { _, textContent in
                                                        userInputState.textFields[index].validationValue = textContent
                                                    }
                                                Image(systemName: "lock.fill")
                                                    .foregroundColor(Color(argument: "#008815")).opacity(0.5)
                                                    .frame(idealWidth: fieldwidth*0.50, maxWidth: 350, alignment: .trailing)
                                            }
                                            .padding(.top, 5)
                                        }
                                    }
                                } else {
                                    VStack {
                                        TextField(observedData.textFieldArray[index].prompt,
                                                  text: $observedData.textFieldArray[index].value)
                                        .onChange(of: observedData.textFieldArray[index].value) { _, textContent in
                                            userInputState.textFields[index].value = textContent
                                            
                                            // live regex checking
                                            if observedData.textFieldArray[index].regex != "" && observedData.args.textFieldLiveValidation.present {
                                                if checkRegexPattern(regexPattern: observedData.textFieldArray[index].regex, textToValidate: observedData.textFieldArray[index].value) {
                                                    observedData.textFieldArray[index].backgroundColour = Color.green
                                                } else {
                                                    observedData.textFieldArray[index].backgroundColour = Color.red
                                                }
                                                if observedData.textFieldArray[index].value == "" {
                                                    observedData.textFieldArray[index].backgroundColour = Color.clear
                                                }
                                            }
                                        }
                                        .onSubmit {
                                            userInputState.textFields[index].value = observedData.textFieldArray[index].value
                                            // Call the same action as Button1
                                            let button1action = observedData.args.button1ShellActionOption.present ?
                                                observedData.args.button1ShellActionOption.value :
                                                (observedData.args.button1ActionOption.present ? observedData.args.button1ActionOption.value : "")
                                            let buttonShellAction = observedData.args.button1ShellActionOption.present
                                            buttonAction(action: button1action, exitCode: 0, executeShell: buttonShellAction, observedObject: observedData)
                                        }
                                        .submitLabel(.done)
                                    
                                        if observedData.textFieldArray[index].confirm {
                                            TextField(observedData.textFieldArray[index].prompt,
                                                      text: $observedData.textFieldArray[index].validationValue)
                                            .onChange(of: observedData.textFieldArray[index].validationValue) { _, confirmed in
                                                userInputState.textFields[index].validationValue = confirmed
                                            }
                                        }
                                    }


                                    if observedData.textFieldArray[index].isDate {
                                        DatePicker("", selection: $observedData.textFieldArray[index].date, displayedComponents: [.date])
                                            .onChange(of: observedData.textFieldArray[index].date) { _, dateContent in
                                                dateFormatter.timeStyle = .none
                                                dateFormatter.dateStyle = .short
                                                observedData.textFieldArray[index].value = dateFormatter.string(from: dateContent)
                                                datepickerID[index] += 1 // stupid hack to make the picker disappear when a date is selected
                                            }
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
                                            .background(observedData.textFieldArray[index].backgroundColour.opacity(textFieldValidationOpacity))
                                            .allowsHitTesting(false)
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
