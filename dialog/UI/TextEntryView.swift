//
//  TextEntryView.swift
//  dialog
//
//  Created by Reardon, Bart  on 23/7/21.
//

import SwiftUI

struct TextEntryView: View {
    
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    
    @State var textFieldValue = Array(repeating: "", count: textFields.count)
    //var textPromptValue = Array(repeating: "", count: textFields.count)
    
    @State private var animationAmount = 1.0
    
    @State private var showingSheet = false
    
    var textFieldPresent: Bool = false
    var fieldwidth: CGFloat = 0
    var requiredFieldsPresent : Bool = false
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
        if cloptions.textField.present {
            textFieldPresent = true
            for i in 0..<textFields.count {
                textFieldValue.append(" ")
                if textFields[i].required {
                    requiredFieldsPresent = true
                }
                //highlight.append(Color.clear)
            }
        }
        if !observedDialogContent.iconPresent { //} cloptions.hideIcon.present {
            fieldwidth = appvars.windowWidth
        } else {
            fieldwidth = appvars.windowWidth - appvars.iconWidth
        }
    }
    
    var body: some View {
        if textFieldPresent {
            VStack {
                ForEach(0..<textFields.count, id: \.self) {index in
                    Group {
                        if textFields[index].editor {
                            VStack {
                                HStack {
                                    Text(textFields[index].title + (textFields[index].required ? " *":""))
                                        .bold()
                                        .font(.system(size: 15))
                                        .frame(idealWidth: fieldwidth*0.20, maxWidth: 150, alignment: .leading)
                                    Spacer()
                                }
                                TextEditor(text: $textFieldValue[index])
                                        .font(.custom("HelveticaNeue", size: 14))
                                        .frame(height: 80)
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text(textFields[index].title + (textFields[index].required ? " *":""))
                                    .bold()
                                    .font(.system(size: 15))
                                    .frame(idealWidth: fieldwidth*0.20, maxWidth: 150, alignment: .leading)
                                Spacer()
                                    .frame(width: 20)
                                if textFields[index].fileSelect {
                                    Button("button-select".localized)
                                    {
                                        let panel = NSOpenPanel()
                                        panel.allowsMultipleSelection = false
                                        panel.canChooseDirectories = false
                                        if textFields[index].fileType != "" {
                                            panel.allowedFileTypes = [textFields[index].fileType]
                                        }
                                        if panel.runModal() == .OK {
                                            textFieldValue[index] = panel.url?.path ?? "<none>"
                                        }
                                    }
                                }
                                HStack {
                                    if textFields[index].secure {
                                        ZStack() {
                                            SecureField("", text: $textFieldValue[index])
                                                .disableAutocorrection(true)
                                                .textContentType(.password)
                                            Image(systemName: "lock.fill")
                                                .foregroundColor(stringToColour("#008815")).opacity(0.5)
                                                    .frame(idealWidth: fieldwidth*0.50, maxWidth: 300, alignment: .trailing)
                                        }
                                    } else {
                                        TextField(textFields[index].prompt, text: $textFieldValue[index])
                                            
                                    }
                                }
                                .frame(idealWidth: fieldwidth*0.50, maxWidth: 300, alignment: .trailing)
                                
                                .overlay(RoundedRectangle(cornerRadius: 5)
                                            .stroke(observedDialogContent.requiredTextfieldHighlight[index], lineWidth: 2)
                                            .animation(.easeIn(duration: 0.2)
                                                        .repeatCount(3, autoreverses: true)
                                                       )
                                         )
                                Spacer()
                            }
                        }
                    }
                    .onChange(of: textFieldValue[index], perform: { value in
                        //update appvars with the text that was entered. this will be printed to stdout on exit
                        textFields[index].value = textFieldValue[index]
                    })
                }
                if requiredFieldsPresent {
                    HStack {
                        Spacer()
                        Text("required-note")
                            .font(.system(size: 10)
                                    .weight(.light))
                            .padding(.trailing, 10)
                    }
                }
            }
        }
    }
}


