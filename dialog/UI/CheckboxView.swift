//
//  CheckboxView.swift
//  dialog
//
//  Created by Bart Reardon on 23/1/2022.
//

import SwiftUI

struct CheckboxView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    var toggleStyle : any ToggleStyle = .checkbox

    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        if observedData.args.checkbox.present {
            VStack {
                ForEach(0..<observedData.appProperties.checkboxOptionsArray.count, id: \.self) {index in
                    HStack {
                        if observedData.args.checkboxStyle.value == "switch" {
                            Text(observedData.appProperties.checkboxOptionsArray[index])
                                //.frame(minWidth: 120, alignment: .leading)
                            Spacer()
                            Toggle("", isOn: $observedData.appProperties.checkboxValue[index])
                                .toggleStyle(.switch)
                                .disabled(observedData.appProperties.checkboxDisabled[index])
                        } else {
                            Toggle(observedData.appProperties.checkboxOptionsArray[index], isOn: $observedData.appProperties.checkboxValue[index])
                                .toggleStyle(.checkbox)
                                .disabled(observedData.appProperties.checkboxDisabled[index])
                            Spacer()
                        }
                    }
                    .font(.system(size: 16))
                    .frame(alignment: .center)
                    .frame(width: .infinity)
                }
            }
        }
    }
}


