//
//  TaskProgressView.swift
//  dialog
//
//  Created by Bart Reardon on 20/1/2022.
//

import SwiftUI

struct TaskProgressView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    var body: some View {
        if appArguments.progressBar.present {
            VStack {
                ProgressView(value: observedData.progressValue, total: observedData.progressTotal)
                    .padding(.leading,40)
                    .padding(.trailing,40)
                Text(observedData.statusText)

            }
        }
    }
}


