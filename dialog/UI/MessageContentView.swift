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
    
    @ObservedObject var observedData : DialogUpdatableContent
    @State private var contentHeight: CGFloat = 40
    
    var fieldPadding: CGFloat = 15
    
    var messageColour : Color
        
    var iconDisplayWidth : CGFloat
        
    //var defaultStyle: MarkdownStyle
    //var customStyle: MarkdownStyle
    
    var markdownStyle: MarkdownStyle {
        if observedData.appProperties.messageFontName == "" {
            return MarkdownStyle(font: .system(size: appvars.messageFontSize, weight: appvars.messageFontWeight), foregroundColor: messageColour)
        } else {
            return MarkdownStyle(font: .custom(appvars.messageFontName, size: appvars.messageFontSize), foregroundColor: messageColour)
        }
    }
            
    let theAllignment: Alignment = .topLeading
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        if !observedDialogContent.args.iconOption.present { //cloptions.hideIcon.present {
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
                        //.padding(.top, 15)
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
                        //.padding(.top, 15)
                        .padding(.bottom, observedData.appProperties.bottomPadding)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                        .accessibilityHint(observedData.args.iconAccessabilityLabel.value)
                }
                if !["", "none"].contains(observedData.args.messageOption.value) {
                    if ["centre", "center"].contains(observedData.args.messageVerticalAlignment.value) {
                        Spacer()
                    }
                    if observedData.args.webcontent.present || observedData.args.listItem.present || observedData.args.messageVerticalAlignment.present {
                        Markdown(observedData.args.messageOption.value, baseURL: URL(string: "http://"))
                            .multilineTextAlignment(observedData.appProperties.messageAlignment)
                            .markdownStyle(markdownStyle)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .accessibilityHint(observedData.args.messageOption.value)
                            .focusable(false)
                    } else {
                        ScrollView() {
                            Markdown(observedData.args.messageOption.value, baseURL: URL(string: "http://"))
                                .multilineTextAlignment(observedData.appProperties.messageAlignment)
                                .markdownStyle(markdownStyle)
                                .border(observedData.appProperties.debugBorderColour, width: 2)
                                .accessibilityHint(observedData.args.messageOption.value)
                                .focusable(false)
                        }
                    }
                    if ["centre", "center"].contains(observedData.args.messageVerticalAlignment.value) {
                        Spacer()
                    }
                }
                
                WebContentView(observedDialogContent: observedData, url: observedData.args.webcontent.value)
                    .border(observedData.appProperties.debugBorderColour, width: 2)
                    .padding(.bottom, observedData.appProperties.bottomPadding)

                ListView(observedDialogContent: observedData)
                    .border(observedData.appProperties.debugBorderColour, width: 2)
                    .padding(.bottom, observedData.appProperties.bottomPadding)
                
                CheckboxView(observedDialogContent: observedData)
                    .border(observedData.appProperties.debugBorderColour, width: 2)
                    //.padding(.bottom, observedData.appProperties.bottomPadding)
                    //.frame(maxWidth: 600)
                
                TextEntryView(observedDialogContent: observedData)
                    .padding(.bottom, observedData.appProperties.bottomPadding)
                    .border(observedData.appProperties.debugBorderColour, width: 2)
                    .frame(maxWidth: 600)
                
                DropdownView(observedDialogContent: observedData)
                    .padding(.bottom, observedData.appProperties.bottomPadding)
                    .border(observedData.appProperties.debugBorderColour, width: 2)
                    .frame(maxWidth: 600)
                if ["top"].contains(observedData.args.messageVerticalAlignment.value) {
                    Spacer()
                }
            }
        }
        .padding(.leading, observedData.appProperties.sidePadding)
        .padding(.trailing, observedData.appProperties.sidePadding)
        .padding(.top, observedData.appProperties.topPadding)
    }
}

