//
//  CheckboxView.swift
//  dialog
//
//  Created by Bart Reardon on 23/1/2022.
//

import SwiftUI

struct CheckboxView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    //@State var checkboxValues = appvars.checkboxValue
    // @State var textFieldValue = ""
    // var textFieldLabel = CLOptionText(OptionName: appArguments.textField)
    //let checkboxLabels = appvars.checkboxOptionsArray
    //let checkboxDisabled = appvars.checkboxDisabled
    //var checkboxPresent: Bool = appArguments.checkbox.present

    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        if observedData.args.checkbox.present {
            VStack {
                ForEach(0..<observedData.appProperties.checkboxOptionsArray.count, id: \.self) {index in
                    HStack {
                        Toggle(observedData.appProperties.checkboxOptionsArray[index], isOn: $observedData.appProperties.checkboxValue[index])
                            .toggleStyle(.checkbox)
                            .disabled(observedData.appProperties.checkboxDisabled[index])
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


