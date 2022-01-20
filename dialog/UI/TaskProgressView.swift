//
//  TaskProgressView.swift
//  dialog
//
//  Created by Bart Reardon on 20/1/2022.
//

import SwiftUI

struct TaskProgressView: View {
    
    @ObservedObject var observedDialogContent = DialogUpdatableContent()
    
    var body: some View {
        if cloptions.progressBar.present {
            VStack {
                ProgressView(value: observedDialogContent.progressValue, total: Double(cloptions.progressBar.value) ?? 0)
                    .padding(.leading,10)
                    .padding(.trailing,10)
                Text(observedDialogContent.statusText)

            }
        }
    }
}

struct TaskProgressView_Previews: PreviewProvider {
    static var previews: some View {
        TaskProgressView()
    }
}
