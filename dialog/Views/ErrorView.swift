//
//  ErrorView.swift
//  dialog
//
//  Created by Bart Reardon on 29/5/2022.
//

import SwiftUI
import MarkdownUI

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
            .padding(appDefaults.sidePadding)
            Text("invalid-input").bold()
                .padding()
            Markdown(observedData.sheetErrorMessage)
                .markdownTheme(.basic)
            //Text(observedData.sheetErrorMessage)
                .padding(.leading, appDefaults.sidePadding)
                .padding(.trailing, appDefaults.sidePadding)

            Spacer()
            Button(action: {
                observedData.showSheet = false
                observedData.sheetErrorMessage = ""
            }, label: {
                Text("button-ok".localized)
            })
            .padding(appDefaults.sidePadding)
        }
        .frame(width: 400, height: 350)
    }
}

