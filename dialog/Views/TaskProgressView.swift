//
//  TaskProgressView.swift
//  dialog
//
//  Created by Bart Reardon on 20/1/2022.
//

import SwiftUI

struct TaskProgressView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    var body: some View {
        if observedData.args.progressBar.present {
            VStack {
                HStack {
                    ProgressView(value: observedData.progressValue, total: observedData.progressTotal )
                        .progressViewStyle(TaskProgressViewStyle())
                }
                if observedData.args.progressText.present {
                    HStack {
                        if observedData.args.progressTextAlignment.value.lowercased() == "right" {
                            Spacer()
                        }
                        Text(observedData.args.progressText.value)
                        if observedData.args.progressTextAlignment.value.lowercased() == "left" {
                            Spacer()
                        }
                    }
                }
            }
            .padding(.leading,appDefaults.sidePadding)
            .padding(.trailing,appDefaults.sidePadding)
        }
    }
}

struct TaskProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {

        let determinate = (configuration.fractionCompleted == nil) ? false : true

        ZStack {
            if determinate {
                ProgressView(value: configuration.fractionCompleted)
            } else {
                IndeterminateProgressView()
            }
        }
        .frame(height: 20)
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        .progressViewStyle(.linear)
    }
}

