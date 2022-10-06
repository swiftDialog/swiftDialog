//
//  CheckboxView.swift
//  dialog
//
//  Created by Bart Reardon on 23/1/2022.
//

import SwiftUI

struct CheckboxView: View {
    @State var checkboxValues = appvars.checkboxValue
    // @State var textFieldValue = ""
    // var textFieldLabel = CLOptionText(OptionName: appArguments.textField)
    let checkboxLabels = appvars.checkboxOptionsArray
    let checkboxDisabled = appvars.checkboxDisabled
    var checkboxPresent: Bool = appArguments.checkbox.present

    init() {
        /*
        if appArguments..present {
            checkboxPresent = true
            for _ in checkboxLabels {
                checkboxValues.append(" ")
            }
        }
         */
        // checkboxValues = appvars.checkboxValue
        // print(checkboxValues)
    }

    var body: some View {
        if checkboxPresent {
            VStack {
                ForEach(0..<checkboxLabels.count, id: \.self) {index in
                    HStack {
                        Toggle(" \(checkboxLabels[index])", isOn: $checkboxValues[index])
                            .toggleStyle(.checkbox)
                            .onChange(of: checkboxValues[index], perform: { _ in
                                // update appvars with the text that was entered. this will be printed to stdout on exit
                                appvars.checkboxValue[index] = checkboxValues[index]
                            })
                            .disabled(appvars.checkboxDisabled[index])
                        // Text(checkboxLabels[i])
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
