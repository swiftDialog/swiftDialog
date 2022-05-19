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
    
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    @State private var contentHeight: CGFloat = 40
    
    var fieldPadding: CGFloat = 15
    
    var messageColour : NSColor = NSColor(appvars.messageFontColour)
        
    var iconDisplayWidth : CGFloat
        
    var defaultStyle: MarkdownStyle {
        return MarkdownStyle(font: .system(size: appvars.messageFontSize), foregroundColor: appvars.messageFontColour)
    }
    
    var customStyle: MarkdownStyle {
        return MarkdownStyle(font: .custom(appvars.messageFontName, size: appvars.messageFontSize), foregroundColor: appvars.messageFontColour)
    }
    
    let messageContentOption: String = cloptions.messageOption.value
    let theAllignment: Alignment = .topLeading
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
        if !observedDialogContent.iconPresent { //cloptions.hideIcon.present {
            fieldPadding = 40
            iconDisplayWidth = 0
        } else {
            fieldPadding = 15
            iconDisplayWidth = observedDialogContent.iconSize
        }
    }
    
    var body: some View {
        
        if observedDialogContent.imagePresent || (observedDialogContent.imagePresent && observedDialogContent.imageCaptionPresent) {
            VStack {
                if observedDialogContent.iconPresent && observedDialogContent.centreIconPresent && !appvars.iconIsHidden && !(observedDialogContent.iconImage == "none") {
                    IconView(observedDialogContent: observedDialogContent)
                        .frame(width: iconDisplayWidth, alignment: .top)
                        .padding(.top, 15)
                        .padding(.bottom, 10)
                        .border(appvars.debugBorderColour, width: 2)
                }
                ImageView(imageArray: appvars.imageArray, captionArray: appvars.imageCaptionArray, autoPlaySeconds: string2float(string: cloptions.autoPlay.value))
            }
        } else {
            VStack {
                
                if observedDialogContent.centreIconPresent && observedDialogContent.centreIconPresent && !(observedDialogContent.iconImage == "none") {
                    IconView(observedDialogContent: observedDialogContent)
                        .frame(width: iconDisplayWidth, alignment: .top)
                        .padding(.top, 15)
                        .padding(.bottom, 10)
                        .border(appvars.debugBorderColour, width: 2)
                }
                
                if observedDialogContent.listItemPresent {
                    Markdown(observedDialogContent.messageText, baseURL: URL(string: "http://"))
                        .multilineTextAlignment(appvars.messageAlignment)
                        .markdownStyle(defaultStyle)
                    ListView(observedDialogContent: observedDialogContent)
                        .padding(.top, 10)
                } else {
                    ScrollView() {
                        if appvars.messageFontName == "" {
                            Markdown(observedDialogContent.messageText, baseURL: URL(string: "http://"))
                                .multilineTextAlignment(appvars.messageAlignment)
                                .markdownStyle(defaultStyle)
                        } else {
                            Markdown(observedDialogContent.messageText, baseURL: URL(string: "http://"))
                                .multilineTextAlignment(appvars.messageAlignment)
                                .markdownStyle(customStyle)
                        }
                        
                        CheckboxView()
                            .border(appvars.debugBorderColour, width: 2)
                            .padding(.top, 10)
                    
                    }
                    .padding(.top, 10)
                    .border(appvars.debugBorderColour, width: 2)
                }
                
                Spacer()
                HStack() {
                    //Spacer()
                    VStack {
                        TextEntryView(observedDialogContent: observedDialogContent)
                            //.padding(.leading, 50)
                            //.padding(.trailing, 50)
                            .padding(.bottom, 10)
                            .border(appvars.debugBorderColour, width: 2)

                        DropdownView(observedDialogContent: observedDialogContent)
                            //.padding(.leading, 50)
                            //.padding(.trailing, 50)
                            .padding(.bottom, 10)
                            .border(appvars.debugBorderColour, width: 2)
                    }
                }
            }
            .padding(.leading, fieldPadding)
            .padding(.trailing, fieldPadding)
        }
    }
}

