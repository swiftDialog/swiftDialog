//
//  HelpView.swift
//  dialog
//
//  Created by Bart Reardon on 11/12/2022.
//  Refactored to standalone view for reusability
//

import SwiftUI
import Textual

struct HelpView: View {
    var helpMessage: String
    var alignment: TextAlignment
    var helpImagePath: String
    var helpSheetButtonText: String
    @Binding var showHelp: Bool

    var settings: AppDefaults = .init()
    
    var body: some View {
        VStack {
            Image(systemName: "questionmark.circle.fill")
                .resizable()
                .foregroundColor(.orange)
                .frame(width: 32, height: 32)
                .padding(.top, settings.topPadding)
            HStack {
                StructuredText(markdown: helpMessage, baseURL: URL(string: "http://"))
                    .multilineTextAlignment(alignment)
                    .textual.structuredTextStyle(.gitHub)
                    .padding(32)
                    .focusable(false)
                if !helpImagePath.isEmpty {
                    Divider()
                        .padding(settings.sidePadding)
                        .frame(width: 2)
                    IconView(image: helpImagePath)
                        .frame(height: 160)
                        .padding(.leading, settings.sidePadding)
                        .padding(.trailing, settings.sidePadding)
                }
            }
            Spacer()
            Button(action: {
                showHelp = false
            }, label: {
                Text(helpSheetButtonText)
            })
            .padding(settings.sidePadding)
            .keyboardShortcut(.defaultAction)
        }
        .frame(minWidth: 400)
        .fixedSize()
    }
}


