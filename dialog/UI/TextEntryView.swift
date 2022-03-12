//
//  TextEntryView.swift
//  dialog
//
//  Created by Reardon, Bart  on 23/7/21.
//

import SwiftUI

struct TextEntryView: View {
    
    @State var textFieldValue = Array(repeating: "", count: 64)
    @State var textFieldValuej = Array(repeating: "", count: 64)
    //@State var textFieldValue = ""
    //var textFieldLabel = CLOptionText(OptionName: cloptions.textField)
    let textFieldLabels = appvars.textOptionsArray
    //let textfieldLabels2 = textFields
    var textFieldPresent: Bool = false
    var fieldwidth: CGFloat = 0
    var highlight = [Color]()
    
    init() {
        if cloptions.textField.present {
            textFieldPresent = true
            for i in 0..<textFields.count {
                textFieldValue.append(" ")
                highlight.append(Color.clear)
                if textFields[i].required {
                    highlight[i] = Color.red
                }
            }
        }
        if cloptions.hideIcon.present {
            fieldwidth = appvars.windowWidth
        } else {
            fieldwidth = appvars.windowWidth - appvars.iconWidth
        }
        print("highlight array is \(highlight)")
    }
    
    var body: some View {
        if textFieldPresent {
            VStack {
                ForEach(0..<textFields.count, id: \.self) {j in
                    HStack {
                        Spacer()
                        Text(textFields[j].title)
                            .bold()
                            .font(.system(size: 15))
                            .frame(idealWidth: fieldwidth*0.20, alignment: .leading)
                        Spacer()
                            .frame(width: 20)
                        HStack {
                            if textFields[j].secure {
                                SecureField("", text: $textFieldValuej[j])
                                    .border(highlight[j])
                            } else {
                                TextField("", text: $textFieldValuej[j])
                                    .border(highlight[j])
                            }
                        }
                        .frame(idealWidth: fieldwidth*0.50, alignment: .trailing)
                        .onChange(of: textFieldValuej[j], perform: { value in
                            //update appvars with the text that was entered. this will be printed to stdout on exit
                            textFields[j].value = textFieldValuej[j]
                        })
                        Spacer()
                    }
                }
            }
        }
    }
}

struct TextEntryView_Previews: PreviewProvider {
    static var previews: some View {
        TextEntryView()
    }
}
