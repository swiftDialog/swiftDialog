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

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
        if !observedDialogContent.args.hideIcon.present { //} appArguments.hideIcon.present {
            fieldwidth = string2float(string: observedDialogContent.args.windowWidth.value)
        } else {
            fieldwidth = string2float(string: observedDialogContent.args.windowWidth.value) - string2float(string: observedDialogContent.args.iconSize.value)
        }
        if observedDialogContent.args.textField.present {
            writeLog("Displaying text entry")
            writeLog("\(observedDialogContent.appProperties.textFields.count) textfields detected")
        }
    }

    var body: some View {
        if observedData.args.textField.present {
            VStack {
                ForEach(0..<observedData.appProperties.textFields.count, id: \.self) {index in
                    if observedData.appProperties.textFields[index].editor {
                        VStack {
                            HStack {
                                Text(observedData.appProperties.textFields[index].title + (observedData.appProperties.textFields[index].required ? " *":""))
                                    .frame(alignment: .leading)
                                Spacer()
                            }
                            TextEditor(text: $observedData.appProperties.textFields[index].value)
                                .background(Color("editorBackgroundColour"))
                                .font(.custom("HelveticaNeue", size: 14))
                                .cornerRadius(3.0)
                                .frame(minHeight: 80, maxHeight: observedData.appProperties.windowHeight/2)
                                .overlay(RoundedRectangle(cornerRadius: 5)
                                            .stroke(observedData.appProperties.textFields[index].requiredTextfieldHighlight, lineWidth: 2)
                                            .animation(
                                                .easeIn(duration: 0.2)
                                                .repeatCount(3, autoreverses: true),
                                                value: observedData.showSheet
                                            )
                                         )
                        }
                        .padding(.bottom, observedData.appProperties.bottomPadding)
                    } else {
                        HStack {

                            Text(observedData.appProperties.textFields[index].title + (observedData.appProperties.textFields[index].required ? " *":""))
                                .frame(idealWidth: fieldwidth*0.20, alignment: .leading)
                            Spacer()

                            if observedData.appProperties.textFields[index].fileSelect {
                                Button("button-select".localized) {
                                    let panel = NSOpenPanel()
                                    panel.allowsMultipleSelection = false
                                    panel.canChooseDirectories = false
                                    if observedData.appProperties.textFields[index].fileType != "" {
                                        var fileTypesArray: [UTType] = []
                                        for type in observedData.appProperties.textFields[index].fileType.components(separatedBy: " ") {
                                            if type == "folder" {
                                                panel.canChooseDirectories = true
                                            } else {
                                                fileTypesArray.append(UTType(filenameExtension: type) ?? .text)
                                            }
                                        }
                                        panel.allowedContentTypes = fileTypesArray
                                    }
                                    if panel.runModal() == .OK {
                                        observedData.appProperties.textFields[index].value = panel.url?.path ?? "<none>"
                                    }
                                }
                            }
                            HStack {
                                if observedData.appProperties.textFields[index].secure {
                                    ZStack {
                                        SecureField("", text: $observedData.appProperties.textFields[index].value)
                                            .disableAutocorrection(true)
                                            .textContentType(observedData.appProperties.textFields[index].passwordFill ? .password: .none)
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(stringToColour("#008815")).opacity(0.5)
                                            .frame(idealWidth: fieldwidth*0.50, maxWidth: 350, alignment: .trailing)
                                    }
                                } else {
                                    TextField(observedData.appProperties.textFields[index].prompt, text: $observedData.appProperties.textFields[index].value)
                                        
                                }
                            }
                            .frame(idealWidth: fieldwidth*0.50, maxWidth: 350, alignment: .trailing)
                            
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                        .stroke(observedData.appProperties.textFields[index].requiredTextfieldHighlight, lineWidth: 2)
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
