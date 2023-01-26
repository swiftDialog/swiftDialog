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
                HStack {
                    ProgressView(value: observedData.progressValue, total: observedData.progressTotal )
                        .progressViewStyle(TaskProgressViewStyle())
                }
                Text(observedData.args.progressText.value)
            }
            .padding(.leading,observedData.appProperties.sidePadding)
            .padding(.trailing,observedData.appProperties.sidePadding)
        }
    }
}

struct TaskProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
                
        let determinate = (configuration.fractionCompleted == nil) ? 0.0 : 1.0
        let indeterminate = (configuration.fractionCompleted == nil) ? 1.0 : 0.0
                
        ZStack {
            ProgressView(value: configuration.fractionCompleted)
                .opacity(determinate)

            ProgressView()
                .opacity(indeterminate)
        }
        .transition(.opacity)
        .progressViewStyle(.linear)
    }
}

