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
        if observedData.args.progressBar.present {
            VStack {
                ProgressView(value: observedData.progressValue, total: Double(observedData.args.progressBar.value) ?? 100)
                    .progressViewStyle(.linear)
                Text(observedData.args.progressText.value)
            }
            .padding(.leading,observedData.appProperties.sidePadding)
            .padding(.trailing,observedData.appProperties.sidePadding)
        }
    }
}


