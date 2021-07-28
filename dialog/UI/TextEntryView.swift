//
//  TextEntryView.swift
//  dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 23/7/21.
//

import SwiftUI

struct TextEntryView: View {
    
    @State var textFieldValue = Array(repeating: "", count: 8)
    //@State var textFieldValue = ""
    //var textFieldLabel = CLOptionText(OptionName: CLOptions.textField)
    let textFieldLabels = appvars.textOptionsArray
    var textFieldPresent: Bool = false
    
    
    init() {
        if CLOptionPresent(OptionName: CLOptions.textField) {
            textFieldPresent = true
            for _ in textFieldLabels {
                textFieldValue.append(" ")
            }
        }
    }
    
    var body: some View {
        if textFieldPresent {
            VStack {
                ForEach(0..<textFieldLabels.count, id: \.self) {i in
                    HStack {
                        //Spacer()
                        Text(textFieldLabels[i])
                            .bold()
                            .font(.system(size: 15))
                            .frame(alignment: .leading)
                        Spacer()
                        TextField("", text: $textFieldValue[i])
                            .frame(width: appvars.windowWidth*0.40, alignment: .trailing)
                            .onChange(of: textFieldValue[i], perform: { value in
                                //update appvars with the text that was entered. this will be printed to stdout on exit
                                appvars.textFieldText[i] = textFieldValue[i]
                            })
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
