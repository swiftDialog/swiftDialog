//
//  ErrorView.swift
//  dialog
//
//  Created by Bart Reardon on 29/5/2022.
//

import SwiftUI

struct ErrorView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    init(observedContent: DialogUpdatableContent) {
        self.observedData = observedContent
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
            .padding(observedData.appProperties.sidePadding)
            Text("invalid-input").bold()
                .padding()
            Text(observedData.sheetErrorMessage)
                .padding(.leading, observedData.appProperties.sidePadding)
                .padding(.trailing, observedData.appProperties.sidePadding)
            Spacer()
            Button(action: {
                observedData.showSheet = false
                observedData.sheetErrorMessage = ""
            }, label: {
                Text("button-ok".localized)
            })
            .padding(observedData.appProperties.sidePadding)
        }
        .frame(width: 400, height: 350)
    }
}

