//
//  MessageContentView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 19/3/21.
//

import Foundation
import SwiftUI
import MarkdownUI

struct MessageContent: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @State private var contentHeight: CGFloat = 40

    var fieldPadding: CGFloat = 15
    var dataEntryMaxWidth: CGFloat = 700

    var messageColour: Color

    var iconDisplayWidth: CGFloat

    /*
    var markdownStyle: MarkdownStyle {
        if observedData.appProperties.messageFontName == "" {
            return MarkdownStyle(font: .system(size: appvars.messageFontSize, weight: appvars.messageFontWeight), foregroundColor: messageColour)
        } else {
            return MarkdownStyle(font: .custom(appvars.messageFontName, size: appvars.messageFontSize), foregroundColor: messageColour)
        }
    }
    */

    let theAllignment: Alignment = .topLeading

    init(observedDialogContent: DialogUpdatableContent) {
        writeLog("Displaying main message content")
        self.observedData = observedDialogContent
        if !observedDialogContent.args.iconOption.present { //cloptions.hideIcon.present {
            writeLog("Icon is hidden")
            fieldPadding = 30
            iconDisplayWidth = 0
        } else {
            fieldPadding = 20
            iconDisplayWidth = observedDialogContent.iconSize
        }
        messageColour = observedDialogContent.appProperties.messageFontColour
    }

    var body: some View {
        VStack {
            if observedData.args.mainImage.present {

                if observedData.args.iconOption.present && observedData.args.centreIcon.present { //}&& observedData.args.iconOption.value != "none" {
                    IconView(image: observedData.args.iconOption.value,
                             overlay: observedData.args.overlayIconOption.value,
                             alpha: observedData.iconAlpha)
                        .frame(width: iconDisplayWidth, alignment: .top)
                        .padding(.bottom, observedData.appProperties.bottomPadding)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                        .accessibilityHint(observedData.args.iconAccessabilityLabel.value)
                }
                ImageView(imageArray: observedData.imageArray, captionArray: observedData.appProperties.imageCaptionArray, autoPlaySeconds: string2float(string: observedData.args.autoPlay.value))
            } else {
                if ["bottom"].contains(observedData.args.messageVerticalAlignment.value) {
                    Spacer()
                }
                if observedData.args.centreIcon.present && observedData.args.iconOption.present {
                    IconView(image: observedData.args.iconOption.value,
                             overlay: observedData.args.overlayIconOption.value,
                             alpha: observedData.iconAlpha)
                        .frame(width: iconDisplayWidth, alignment: .top)
                        .padding(.bottom, observedData.appProperties.bottomPadding)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                        .accessibilityHint(observedData.args.iconAccessabilityLabel.value)
                }

                if !["", "none"].contains(observedData.args.messageOption.value) {
                    if ["centre", "center"].contains(observedData.args.messageVerticalAlignment.value) {
                        Spacer()
                    }

                    Markdown(observedData.args.messageOption.value, baseURL: URL(string: "http://"))
                        .multilineTextAlignment(observedData.appProperties.messageAlignment)
                        .markdownTextStyle {
                            FontSize(appvars.messageFontSize)
                            ForegroundColor(messageColour)
                        }
                        .markdownTheme(.sdMarkdown)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                        .accessibilityHint(observedData.args.messageOption.value)
                        .focusable(false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .if(!observedData.args.webcontent.present && !observedData.args.listItem.present && !observedData.args.messageVerticalAlignment.present) { view in
                            view.scrollOnOverflow()
                        }
                }
                if ["centre", "center"].contains(observedData.args.messageVerticalAlignment.value) {
                    Spacer()
                }

                Group {
                    WebContentView(observedDialogContent: observedData, url: observedData.args.webcontent.value)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                        .padding(.bottom, observedData.appProperties.bottomPadding)

                    ListView(observedDialogContent: observedData)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                        .padding(.bottom, observedData.appProperties.bottomPadding)

                    CheckboxView(observedDialogContent: observedData)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                        .frame(maxWidth: dataEntryMaxWidth)

                    TextEntryView(observedDialogContent: observedData)
                        .padding(.bottom, observedData.appProperties.bottomPadding)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                        .frame(maxWidth: dataEntryMaxWidth)

                    RadioView(observedDialogContent: observedData)
                        .padding(.bottom, observedData.appProperties.bottomPadding)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                        .frame(maxWidth: dataEntryMaxWidth)

                    DropdownView(observedDialogContent: observedData)
                        .padding(.bottom, observedData.appProperties.bottomPadding)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                        .frame(maxWidth: dataEntryMaxWidth, alignment: .leading)
                }

                if ["top"].contains(observedData.args.messageVerticalAlignment.value) {
                    Spacer()
                }
                if observedData.appProperties.userInputRequired {
                    HStack {
                        Spacer()
                        Text("required-note")
                            .font(.system(size: 10)
                                    .weight(.light))
                    }
                }
            }
        }
        .padding(.leading, observedData.appProperties.sidePadding)
        .padding(.trailing, observedData.appProperties.sidePadding)
        .padding(.top, observedData.appProperties.topPadding)
        .textSelection(.enabled)
    }
}

struct PriorityView<Content: View>: View {
    private var content: () -> Content
    private var priority: Int

    init(priority: Int, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.priority = priority
    }

    var body: some View {
        EmptyView()
            .overlay(content())
            .zIndex(Double(priority))
    }
}
