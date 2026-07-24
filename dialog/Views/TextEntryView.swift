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

    var fieldwidth: CGFloat = 0
    var textFieldValidationOpacity: CGFloat = 0

    let dateFormatter = DateFormatter()

    init(observedDialogContent: DialogUpdatableContent) {
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

    /// Format a date field's current date. Uses a strftime-style `format=` string when
    /// supplied (e.g. "+%s" for epoch), otherwise the default ISO format for its components.
    func formattedDate(_ field: TextFieldState) -> String {
        if !field.dateOutputFormat.isEmpty {
            return strftimeString(from: field.date, format: field.dateOutputFormat)
        }
        dateFormatter.dateFormat = field.dateFormat
        return dateFormatter.string(from: field.date)
    }

    var body: some View {
        // Guard against array size mismatch during card transitions
        let textFieldCount = observedData.textFieldArray.count
        if observedData.args.textField.present && textFieldCount == userInputState.textFields.count {
            VStack {
                ForEach(0..<textFieldCount, id: \.self) {index in
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
                                .requiredFieldHighlight(userInputState.textFields[index].requiredTextfieldHighlight, trigger: observedData.showSheet)
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
                                } else if observedData.textFieldArray[index].isDatePicker {
                                    // Date/time field: the picker replaces the text field.
                                    DatePicker("", selection: $observedData.textFieldArray[index].date,
                                               displayedComponents: observedData.textFieldArray[index].dateComponents)
                                        .labelsHidden()
                                        .datePickerStyle(.field)
                                        .onAppear {
                                            // return the initial (default) date even if the user never changes it
                                            let formatted = formattedDate(observedData.textFieldArray[index])
                                            observedData.textFieldArray[index].value = formatted
                                            userInputState.textFields[index].value = formatted
                                        }
                                        .onChange(of: observedData.textFieldArray[index].date) { _, _ in
                                            let formatted = formattedDate(observedData.textFieldArray[index])
                                            observedData.textFieldArray[index].value = formatted
                                            userInputState.textFields[index].value = formatted
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
                                            
                                            // Handle cards mode - advance to next card instead of exiting
                                            if cardState.isCardsMode {
                                                // Validate required fields first
                                                let validation = validateRequiredFields(observedObject: observedData)
                                                if !validation.isValid {
                                                    observedData.sheetErrorMessage = validation.errorMessage
                                                    observedData.showSheet = true
                                                    return
                                                }
                                                
                                                // Execute onAdvance callback if configured
                                                if appArguments.onAdvance.present && !appArguments.onAdvance.value.isEmpty {
                                                    let currentInput = observedData.collectCurrentUserInput()
                                                    let cardId = cardState.currentCard?.configuration["cardId"].string
                                                    let callbackResult = executeOnAdvanceCallback(
                                                        command: appArguments.onAdvance.value,
                                                        cardIndex: cardState.currentCardIndex,
                                                        cardId: cardId,
                                                        input: currentInput
                                                    )
                                                    
                                                    if !callbackResult.success {
                                                        observedData.sheetErrorMessage = callbackResult.errorMessage
                                                        observedData.showSheet = true
                                                        return
                                                    }
                                                }
                                                
                                                if cardState.isLastCard {
                                                    // On last card, exit with collected input
                                                    let button1action = observedData.args.button1ShellActionOption.present ?
                                                        observedData.args.button1ShellActionOption.value :
                                                        (observedData.args.button1ActionOption.present ? observedData.args.button1ActionOption.value : "")
                                                    let buttonShellAction = observedData.args.button1ShellActionOption.present
                                                    buttonAction(action: button1action, exitCode: 0, executeShell: buttonShellAction, shouldQuit: true, observedObject: observedData, isCardsMode: true)
                                                } else {
                                                    // Advance to next card
                                                    _ = observedData.advanceToNextCard()
                                                }
                                            } else {
                                                // Normal mode - original behavior
                                                let button1action = observedData.args.button1ShellActionOption.present ?
                                                    observedData.args.button1ShellActionOption.value :
                                                    (observedData.args.button1ActionOption.present ? observedData.args.button1ActionOption.value : "")
                                                let buttonShellAction = observedData.args.button1ShellActionOption.present
                                                buttonAction(action: button1action, exitCode: 0, executeShell: buttonShellAction, observedObject: observedData)
                                            }
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
