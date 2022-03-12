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
    
    var textFieldPresent: Bool = false
    var fieldwidth: CGFloat = 0
    var highlight = [Color]()
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
        if cloptions.textField.present {
            textFieldPresent = true
            for _ in 0..<textFields.count {
                textFieldValue.append(" ")
                highlight.append(Color.clear)
            }
        }
        if cloptions.hideIcon.present {
            fieldwidth = appvars.windowWidth
        } else {
            fieldwidth = appvars.windowWidth - appvars.iconWidth
        }
    }
    
    var body: some View {
        if textFieldPresent {
            VStack {
                ForEach(0..<textFields.count, id: \.self) {index in
                    HStack {
                        Spacer()
                        Text(textFields[index].title)
                            .bold()
                            .font(.system(size: 15))
                            .frame(idealWidth: fieldwidth*0.20, maxWidth: 150, alignment: .leading)
                        Spacer()
                            .frame(width: 20)
                        HStack {
                            if textFields[index].secure {
                                ZStack() {
                                    SecureField("", text: $textFieldValue[index])
                                        .disableAutocorrection(true)
                                        .textContentType(.password)
                                        //.border(highlight[index])
                                        .overlay(RoundedRectangle(cornerRadius: 5)
                                                    .stroke(observedDialogContent.requiredTextfieldHighlight[index], lineWidth: 1))

                                    Image(systemName: "lock.fill")
                                        .foregroundColor(stringToColour("#008815")).opacity(0.5)
                                            .frame(idealWidth: fieldwidth*0.50, maxWidth: 300, alignment: .trailing)
                                }
                            } else {
                                TextField("", text: $textFieldValue[index])
                                    //.border(highlight[index])
                                    .overlay(RoundedRectangle(cornerRadius: 5)
                                                .stroke(observedDialogContent.requiredTextfieldHighlight[index], lineWidth: 1))
                            }
                        }
                        .frame(idealWidth: fieldwidth*0.50, maxWidth: 300, alignment: .trailing)
                        .onChange(of: textFieldValue[index], perform: { value in
                            //update appvars with the text that was entered. this will be printed to stdout on exit
                            textFields[index].value = textFieldValue[index]
                        })
                        Spacer()
                    }
                }
            }
        }
    }
}


