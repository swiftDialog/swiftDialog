//
//  TextEntryView.swift
//  dialog
//
//  Created by Reardon, Bart  on 23/7/21.
//

import SwiftUI

struct TextEntryView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    @State var textFieldValue = Array(repeating: "", count: appvars.textFields.count)
    //var textPromptValue = Array(repeating: "", count: appvars.textFields.count)
    
    @State private var animationAmount = 1.0
    
    @State private var showingSheet = false
    
    var textFieldPresent: Bool = false
    var fieldwidth: CGFloat = 0
    var requiredFieldsPresent : Bool = false
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        if appArguments.textField.present {
            textFieldPresent = true
            for i in 0..<appvars.textFields.count {
                textFieldValue.append(" ")
                if appvars.textFields[i].required {
                    requiredFieldsPresent = true
                }
                //highlight.append(Color.clear)
            }
        }
        if !observedDialogContent.args.hideIcon.present { //} appArguments.hideIcon.present {
            fieldwidth = string2float(string: observedDialogContent.args.windowWidth.value)
        } else {
            fieldwidth = string2float(string: observedDialogContent.args.windowWidth.value) - string2float(string: observedDialogContent.args.iconSize.value)
        }
    }
    
    var body: some View {
        if textFieldPresent {
            VStack {
                ForEach(0..<appvars.textFields.count, id: \.self) {index in
                    HStack {
                        Spacer()
                        Text(appvars.textFields[index].title + (appvars.textFields[index].required ? " *":""))
                            .bold()
                            .font(.system(size: 15))
                            .frame(idealWidth: fieldwidth*0.20, maxWidth: 150, alignment: .leading)
                        Spacer()
                            .frame(width: 20)
                        HStack {
                            if appvars.textFields[index].secure {
                                ZStack() {
                                    SecureField("", text: $textFieldValue[index])
                                        .disableAutocorrection(true)
                                        .textContentType(.password)
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(stringToColour("#008815")).opacity(0.5)
                                            .frame(idealWidth: fieldwidth*0.50, maxWidth: 300, alignment: .trailing)
                                }
                            } else {
                                if #available(macOS 12.0, *) {
                                    TextField("", text: $textFieldValue[index], prompt:Text(appvars.textFields[index].prompt))
                                } else {
                                    TextField("", text: $textFieldValue[index])
                                }
                            }
                        }
                        .frame(idealWidth: fieldwidth*0.50, maxWidth: 300, alignment: .trailing)
                        .onChange(of: textFieldValue[index], perform: { value in
                            //update appvars with the text that was entered. this will be printed to stdout on exit
                            appvars.textFields[index].value = textFieldValue[index]
                        })
                        .overlay(RoundedRectangle(cornerRadius: 5)
                                    .stroke(observedData.requiredTextfieldHighlight[index], lineWidth: 2)
                                    .animation(.easeIn(duration: 0.2)
                                                .repeatCount(3, autoreverses: true)
                                               )
                                 )
                        Spacer()
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


