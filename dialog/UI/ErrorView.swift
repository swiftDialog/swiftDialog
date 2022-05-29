//
//  ErrorView.swift
//  dialog
//
//  Created by Bart Reardon on 29/5/2022.
//

import SwiftUI

struct ErrorView: View {
    
    //@Binding var showingSheet : Bool
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    //var sheetMessage : String
    
    init(observedContent : DialogUpdatableContent) {
        //sheetMessage = text
        self.observedDialogContent = observedContent
        //self._showingSheet = sheet
    }
    
    var body: some View {
        VStack {
            ZStack {
                Image(systemName: "triangle.fill")
                    .resizable()
                    .foregroundColor(.white)
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .foregroundColor(.yellow)
            }
            .frame(width: 64, height: 64)
            .padding(20)
            Text("One or more input fields is incorrect").bold()
                .padding()
            Text(observedDialogContent.sheetErrorMessage)
            Spacer()
            Button(action: {observedDialogContent.showSheet = false}) {
                Text("OK")
            }
            .padding()
        }
        .frame(width: 350, height: 250)
    }
}

