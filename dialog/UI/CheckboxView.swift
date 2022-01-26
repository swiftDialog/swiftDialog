//
//  CheckboxView.swift
//  dialog
//
//  Created by Bart Reardon on 23/1/2022.
//

import SwiftUI

struct CheckboxView: View {
    @State var checkboxValues = appvars.checkboxValue //Array(repeating: false, count: 64)
    //@State var textFieldValue = ""
    //var textFieldLabel = CLOptionText(OptionName: cloptions.textField)
    let checkboxLabels = appvars.checkboxOptionsArray
    let checkboxDisabled = appvars.checkboxDisabled
    var checkboxPresent: Bool = cloptions.checkbox.present
    
    init() {
        /*
        if cloptions..present {
            checkboxPresent = true
            for _ in checkboxLabels {
                checkboxValues.append(" ")
            }
        }
         */
        //checkboxValues = appvars.checkboxValue
        //print(checkboxValues)
    }
    
    var body: some View {
        if checkboxPresent {
            VStack {
                ForEach(0..<checkboxLabels.count, id: \.self) {i in
                    HStack {
                        Toggle(" \(checkboxLabels[i])", isOn: $checkboxValues[i])
                            .toggleStyle(.checkbox)
                            .onChange(of: checkboxValues[i], perform: { value in
                                //update appvars with the text that was entered. this will be printed to stdout on exit
                                appvars.checkboxValue[i] = checkboxValues[i]
                            })
                            .disabled(appvars.checkboxDisabled[i])
                            
                        //Text(checkboxLabels[i])
                        
                        Spacer()
                    }
                    .font(.system(size: 16))
                    .frame(alignment: .center)
                }
            }
        }
    }
}

struct CheckboxView_Previews: PreviewProvider {
    static var previews: some View {
        CheckboxView()
    }
}
