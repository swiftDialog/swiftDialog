//
//  TextEntryView.swift
//  dialog
//
//  Created by Reardon, Bart  on 23/7/21.
//

import SwiftUI

struct TextEntryView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    //@State var textFieldValue = Array(repeating: "", count: appvars.textFields.count)
    //var textPromptValue = Array(repeating: "", count: appvars.textFields.count)
    
    @State private var animationAmount = 1.0
    
    @State private var showingSheet = false
    
    
    //var textFieldPresent: Bool = false
    var fieldwidth: CGFloat = 0
    
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
                ForEach(0..<observedData.textEntryArray.count, id: \.self) {index in
                    HStack {
                        Spacer()
                        Text(observedData.textEntryArray[index].title + (observedData.textEntryArray[index].required ? " *":""))
                            .bold()
                            .font(.system(size: 15))
                            .frame(idealWidth: fieldwidth*0.20, maxWidth: 150, alignment: .leading)
                        Spacer()
                            .frame(width: 20)
                        HStack {
                            if observedData.textEntryArray[index].secure {
                                ZStack() {
                                    SecureField("", text: $observedData.textEntryArray[index].value)
                                        .disableAutocorrection(true)
                                        .textContentType(.password)
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(stringToColour("#008815")).opacity(0.5)
                                            .frame(idealWidth: fieldwidth*0.50, maxWidth: 300, alignment: .trailing)
                                }
                            } else {
                                //if #available(macOS 12.0, *) {
                                //    TextField("", text: $observedData.appProperties.textFields[index].value, prompt:Text(observedData.appProperties.textFields[index].prompt))
                                //} else {
                                    TextField(observedData.textEntryArray[index].prompt, text: $observedData.textEntryArray[index].value)
                                //}
                            }
                        }
                        .frame(idealWidth: fieldwidth*0.50, maxWidth: 300, alignment: .trailing)
                        //.onChange(of: observedData.textEntryArray[index].value, perform: { value in
                            //update appvars with the text that was entered. this will be printed to stdout on exit
                            //appvars.textFields[index].value = observedData.textEntryArray[index].value
                        //})
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .stroke(observedData.textEntryArray[index].requiredTextfieldHighlight, lineWidth: 2)
                                    .animation(.easeIn(duration: 0.2)
                                                .repeatCount(3, autoreverses: true)
                                               )
                                 )
                        Spacer()
                    }
                }
                if observedData.requiredFieldsPresent {
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


