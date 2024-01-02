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
        datepickerID = Array(0...textfieldContent.count-1)
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

                            Text(textfieldContent[index].title + (textfieldContent[index].required ? " *":""))
                                .frame(idealWidth: fieldwidth*0.20, alignment: .leading)
                            Spacer()

                            if textfieldContent[index].fileSelect {
                                Button("button-select".localized) {
                                    let panel = NSOpenPanel()
                                    panel.allowsMultipleSelection = false
                                    panel.canChooseDirectories = false
                                    if textfieldContent[index].fileType != "" {
                                        var fileTypesArray: [UTType] = []
                                        for type in textfieldContent[index].fileType.components(separatedBy: " ") {
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
                                    if panel.runModal() == .OK {
                                        textfieldContent[index].value = panel.url?.path ?? "<none>"
                                    }
                                }
                            }
                            HStack {
                                if textfieldContent[index].secure {
                                    ZStack {
                                        SecureField("", text: $textfieldContent[index].value)
                                            .disableAutocorrection(true)
                                            .textContentType(textfieldContent[index].passwordFill ? .password: .none)
                                            .onChange(of: textfieldContent[index].value, perform: { textContent in
                                                userInputState.textFields[index].value = textContent
                                            })
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(Color(argument: "#008815")).opacity(0.5)
                                            .frame(idealWidth: fieldwidth*0.50, maxWidth: 350, alignment: .trailing)
                                    }
                                } else {
                                    TextField(textfieldContent[index].prompt, text: $textfieldContent[index].value)
                                        .onChange(of: textfieldContent[index].value, perform: { textContent in
                                            userInputState.textFields[index].value = textContent
                                        })
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
