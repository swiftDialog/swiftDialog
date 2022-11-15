//
//  TextEntryView.swift
//  dialog
//
//  Created by Reardon, Bart  on 23/7/21.
//

import SwiftUI

extension NSTextView {
    open override var frame: CGRect {
        didSet {
            backgroundColor = .clear
            drawsBackground = true
        }

    }
}

struct TextEntryView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    @State private var showingSheet = false

    //var textFieldPresent: Bool = false
    var fieldwidth: CGFloat = 0
    var requiredFieldsPresent : Bool = false

    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        if appArguments.textField.present {
            for i in 0..<observedDialogContent.appProperties.textFields.count {
                if observedDialogContent.appProperties.textFields[i].required {
                    self.requiredFieldsPresent = true
                }
            }
        }
        if !observedDialogContent.args.hideIcon.present { //} appArguments.hideIcon.present {
            fieldwidth = string2float(string: observedDialogContent.args.windowWidth.value)
        } else {
            fieldwidth = string2float(string: observedDialogContent.args.windowWidth.value) - string2float(string: observedDialogContent.args.iconSize.value)
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
                                    .bold()
                                    .font(.system(size: 15))
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
                                                .repeatCount(3, autoreverses: true)
                                            )
                                         )
                        }
                        .padding(.bottom, observedData.appProperties.bottomPadding)
                    } else {
                        HStack {

                            Text(observedData.appProperties.textFields[index].title + (observedData.appProperties.textFields[index].required ? " *":""))
                                .bold()
                                .font(.system(size: 15))
                                .frame(idealWidth: fieldwidth*0.20, alignment: .leading)
                            Spacer()

                            if observedData.appProperties.textFields[index].fileSelect {
                                Button("button-select".localized)
                                {
                                    let panel = NSOpenPanel()
                                    panel.allowsMultipleSelection = false
                                    panel.canChooseDirectories = false
                                    if observedData.appProperties.textFields[index].fileType != "" {
                                        panel.allowedFileTypes = [observedData.appProperties.textFields[index].fileType]
                                    }
                                    if panel.runModal() == .OK {
                                        observedData.appProperties.textFields[index].value = panel.url?.path ?? "<none>"
                                    }
                                }
                            }
                            HStack {
                                if observedData.appProperties.textFields[index].secure {
                                    ZStack() {
                                        SecureField("", text: $observedData.appProperties.textFields[index].value)
                                            .disableAutocorrection(true)
                                            .textContentType(observedData.appProperties.textFields[index].passwordFill ? .password : .none)
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
                                            .repeatCount(3, autoreverses: true)
                                        )
                                     )
                        }
                        .frame(maxWidth: 600)
                    }
                }
                if self.requiredFieldsPresent {
                    HStack {
                        Spacer()
                        Text("required-note")
                            .font(.system(size: 10)
                                    .weight(.light))
                            //.padding(.trailing, observedData.appProperties.sidePadding)
                    }
                }
            }
                    
        }
    }
}
