//
//  CKWindowProperties.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKWindowProperties: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        
        VStack {
            LabelView(label: "Window Height")
            HStack {
                Slider(value: $observedData.windowHeight, in: 200...2000)
                //Text("Current Height value: \(observedDialogContent.windowHeight, specifier: "%.0f")")
                TextField("Height value:", value: $observedData.windowHeight, formatter: NumberFormatter())
                    .frame(width: 50)
            }
            LabelView(label: "Window Width")
            HStack {
                Slider(value: $observedData.windowWidth, in: 200...2000)
                TextField("Width value:", value: $observedData.windowWidth, formatter: NumberFormatter())
                    .frame(width: 50)
                //Text("Current Width value: \(observedDialogContent.windowWidth, specifier: "%.0f")")
            }
            Spacer()
        }
        .padding(20)
    }
}
