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
    
    //@State var textFieldValue = Array(repeating: "", count: appvars.textFields.count)
    //var textPromptValue = Array(repeating: "", count: appvars.textFields.count)
    
    @State private var animationAmount = 1.0

    @State private var showingSheet = false

    var textFieldPresent: Bool = false
    var fieldwidth: CGFloat = 0
    var requiredFieldsPresent : Bool = false

    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        if appArguments.textField.present {
            for i in 0..<observedDialogContent.appProperties.textFields.count {
                if observedDialogContent.appProperties.textFields[i].required {
                    observedDialogContent.requiredFieldsPresent = true
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
                ForEach(0..<appvars.textFields.count, id: \.self) {index in
                    Group {
                        if appvars.textFields[index].editor {
                            VStack {
                                HStack {
                                    Text(appvars.textFields[index].title + (appvars.textFields[index].required ? " *":""))
                                        .bold()
                                        .font(.system(size: 15))
                                        .frame(alignment: .leading)
                                    Spacer()
                                }
                                TextEditor(text: $observedData.textEntryArray[index].value)
                                    .background(Color("editorBackgroundColour"))
                                    .font(.custom("HelveticaNeue", size: 14))
                                    .cornerRadius(3.0)
                                    .frame(height: 80)
                            }
                            .padding(.bottom, 10)
                        } else {
                            HStack {
                                //Spacer()
                                Text(appvars.textFields[index].title + (appvars.textFields[index].required ? " *":""))
                                    .bold()
                                    .font(.system(size: 15))
                                    .frame(idealWidth: fieldwidth*0.20, alignment: .leading)
                                Spacer()
                                    //.frame(width: 20)
                                if appvars.textFields[index].fileSelect {
                                    Button("button-select".localized)
                                    {
                                        let panel = NSOpenPanel()
                                        panel.allowsMultipleSelection = false
                                        panel.canChooseDirectories = false
                                        if appvars.textFields[index].fileType != "" {
                                            panel.allowedFileTypes = [appvars.textFields[index].fileType]
                                        }
                                        if panel.runModal() == .OK {
                                            observedData.textEntryArray[index].value = panel.url?.path ?? "<none>"
                                        }
                                    }
                                }
                                HStack {
                                    if appvars.textFields[index].secure {
                                        ZStack() {
                                            SecureField("", text: $observedData.textEntryArray[index].value)
                                                .disableAutocorrection(true)
                                                .textContentType(appvars.textFields[index].passwordFill ? .password : .none)
                                            Image(systemName: "lock.fill")
                                                .foregroundColor(stringToColour("#008815")).opacity(0.5)
                                                    .frame(idealWidth: fieldwidth*0.50, maxWidth: 250, alignment: .trailing)
                                        }
                                    } else {
                                        TextField(appvars.textFields[index].prompt, text: $observedData.textEntryArray[index].value)
                                            
                                    }
                                }
                                .frame(idealWidth: fieldwidth*0.50, maxWidth: 250, alignment: .trailing)
                                
                                .overlay(RoundedRectangle(cornerRadius: 5)
                                            .stroke(observedData.textEntryArray[index].requiredTextfieldHighlight, lineWidth: 2)
                                            .animation(.easeIn(duration: 0.2)
                                                        .repeatCount(3, autoreverses: true)
                                                       )
                                         )
                                Spacer()
                            }
                        }
                    }
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
