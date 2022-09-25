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
    
    var messageColour : NSColor
        
    var iconDisplayWidth : CGFloat
        
    //var defaultStyle: MarkdownStyle
    //var customStyle: MarkdownStyle
    
    var defaultStyle: MarkdownStyle {
            return MarkdownStyle(font: .system(size: appvars.messageFontSize, weight: appvars.messageFontWeight), foregroundColor: appvars.messageFontColour)
        }
        
        var customStyle: MarkdownStyle {
            return MarkdownStyle(font: .custom(appvars.messageFontName, size: appvars.messageFontSize), foregroundColor: appvars.messageFontColour)
        }
    
    let theAllignment: Alignment = .topLeading
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        if !observedDialogContent.args.iconOption.present { //cloptions.hideIcon.present {
            fieldPadding = 40
            iconDisplayWidth = 0
        } else {
            fieldPadding = 15
            iconDisplayWidth = observedDialogContent.iconSize
        }
        messageColour = NSColor(observedDialogContent.appProperties.messageFontColour)

    }
    
    var body: some View {
        
        if observedData.args.mainImage.present {
            VStack {
                if observedData.args.iconOption.present && observedData.args.centreIcon.present { //}&& observedData.args.iconOption.value != "none" {
                    IconView(image: observedData.args.iconOption.value, overlay: observedData.args.overlayIconOption.value)
                        .frame(width: iconDisplayWidth, alignment: .top)
                        .padding(.top, 15)
                        .padding(.bottom, 10)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                }
                ImageView(imageArray: observedData.imageArray, captionArray: observedData.appProperties.imageCaptionArray, autoPlaySeconds: string2float(string: observedData.args.autoPlay.value))
            }
        } else {
            VStack {
                GeometryReader { proxy in
                    if observedData.args.centreIcon.present && observedData.args.iconOption.present {
                        IconView(image: observedData.args.iconOption.value, overlay: observedData.args.overlayIconOption.value)
                            .frame(width: iconDisplayWidth, alignment: .top)
                            .padding(.top, 15)
                            .padding(.bottom, 10)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                    }
                    
                    if observedData.args.listItem.present {
                        Markdown(observedData.args.messageOption.value, baseURL: URL(string: "http://"))
                            .multilineTextAlignment(observedData.appProperties.messageAlignment)
                            .markdownStyle(defaultStyle)
                        ListView(observedDialogContent: observedData)
                            .padding(.top, 10)
                    } else if observedData.args.messageVerticalAlignment.present {
                        Markdown(observedData.args.messageOption.value, baseURL: URL(string: "http://"))
                            .multilineTextAlignment(observedData.appProperties.messageAlignment)
                            .markdownStyle(defaultStyle)
                            .frame(minHeight: proxy.size.height)
                    } else {
                        ScrollView() {
                            if observedData.appProperties.messageFontName == "" {
                                Markdown(observedData.args.messageOption.value, baseURL: URL(string: "http://"))
                                    .multilineTextAlignment(observedData.appProperties.messageAlignment)
                                    .markdownStyle(defaultStyle)
                            } else {
                                Markdown(observedData.args.messageOption.value, baseURL: URL(string: "http://"))
                                    .multilineTextAlignment(observedData.appProperties.messageAlignment)
                                    .markdownStyle(customStyle)
                            }
                        }
                        .padding(.top, 10)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                    }
                }
                Spacer()
                HStack() {
                    //Spacer()
                    VStack {
                        CheckboxView()
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .padding(.trailing, 30)
                            .padding(.bottom, 10)
                        TextEntryView(observedDialogContent: observedData)
                            //.padding(.leading, 50)
                            .padding(.trailing, 30)
                            .padding(.bottom, 10)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                        DropdownView(observedDialogContent: observedData)
                            //.padding(.leading, 50)
                            .padding(.trailing, 30)
                            .padding(.bottom, 10)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                    }
                }
            }
            .padding(.leading, fieldPadding)
            .padding(.trailing, fieldPadding)
        }
    }
}

