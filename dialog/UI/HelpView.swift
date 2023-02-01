//
//  InfoView.swift
//  dialog
//
//  Created by Bart Reardon on 11/12/2022.
//

import SwiftUI
import MarkdownUI

struct HelpView: View {
    @ObservedObject var observedData : DialogUpdatableContent
    
    var markdownStyle: MarkdownStyle = MarkdownStyle(font: .system(size: appvars.messageFontSize, weight: appvars.messageFontWeight), foregroundColor: .primary)
    
    init(observedContent : DialogUpdatableContent) {
        self.observedData = observedContent
    }
    
    var body: some View {
        VStack {
            Image(systemName: "questionmark.circle.fill")
                .resizable()
                .foregroundColor(.orange)
                .frame(width: 32, height: 32)
                .padding(.top, observedData.appProperties.topPadding)
            Markdown(observedData.args.helpMessage.value, baseURL: URL(string: "http://"))
                .multilineTextAlignment(observedData.appProperties.messageAlignment)
                .markdownStyle(markdownStyle)
                .padding(32)
                .focusable(false)
            Spacer()
            Button(action: {
                observedData.appProperties.showHelpMessage = false
            }) {
                Text("button-ok".localized)
            }
            .padding(observedData.appProperties.sidePadding)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: observedData.appProperties.windowWidth-100)
    }
}


