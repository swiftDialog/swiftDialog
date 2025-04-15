//
//  InfoView.swift
//  dialog
//
//  Created by Bart Reardon on 11/12/2022.
//

import SwiftUI
import MarkdownUI

struct HelpView: View {
    @ObservedObject var observedData: DialogUpdatableContent

    //var markdownStyle: MarkdownStyle = MarkdownStyle(font: .system(size: appvars.messageFontSize, weight: appvars.messageFontWeight), foregroundColor: .primary)

    init(observedContent: DialogUpdatableContent) {
        self.observedData = observedContent
    }

    var body: some View {
        VStack {
            Image(systemName: "questionmark.circle.fill")
                .resizable()
                .foregroundColor(.orange)
                .frame(width: 32, height: 32)
                .padding(.top, appDefaults.topPadding)
            HStack {
                Markdown(observedData.args.helpMessage.value, baseURL: URL(string: "http://"))
                    .multilineTextAlignment(observedData.appProperties.helpAlignment)
                    .markdownTextStyle {
                        FontSize(appvars.messageFontSize)
                        ForegroundColor(.primary)
                    }
                    .markdownTextStyle(\.link) {
                        FontSize(appvars.messageFontSize)
                        ForegroundColor(.link)
                    }
                    .padding(32)
                    .focusable(false)
                if observedData.args.helpImage.present {
                    Divider()
                        .padding(appDefaults.sidePadding)
                        .frame(width: 2)
                    IconView(image: observedData.args.helpImage.value)
                        .frame(height: 160)
                        .padding(.leading, appDefaults.sidePadding)
                        .padding(.trailing, appDefaults.sidePadding)
                }
            }
            Spacer()
            Button(action: {
                observedData.appProperties.showHelpMessage = false
            }, label: {
                Text(observedData.args.helpSheetButton.value)
            })
            .padding(appDefaults.sidePadding)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: observedData.appProperties.windowWidth-100)
        .fixedSize()
    }
}


