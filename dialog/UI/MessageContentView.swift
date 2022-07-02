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
    
    var messageColour : NSColor = NSColor(appvars.messageFontColour)
        
    var iconDisplayWidth : CGFloat
        
    var defaultStyle: MarkdownStyle {
        return MarkdownStyle(font: .system(size: appvars.messageFontSize, weight: appvars.messageFontWeight), foregroundColor: appvars.messageFontColour)
    }
    
    var customStyle: MarkdownStyle {
        return MarkdownStyle(font: .custom(appvars.messageFontName, size: appvars.messageFontSize), foregroundColor: appvars.messageFontColour)
    }
    
    let theAllignment: Alignment = .topLeading
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        if !observedDialogContent.args.hideIcon.present  { //appArguments.hideIcon.present {
            fieldPadding = 40
            iconDisplayWidth = 0
        } else {
            fieldPadding = 15
            iconDisplayWidth = observedDialogContent.iconSize
        }
    }
    
    var body: some View {
        
        if observedData.imagePresent || (observedData.imagePresent && observedData.imageCaptionPresent) {
            VStack {
                if observedData.args.iconOption.present && observedData.centreIconPresent && !observedData.args.hideIcon.present && !(observedData.args.iconOption.value == "none") {
                    IconView(observedDialogContent: observedData)
                        .frame(width: iconDisplayWidth, alignment: .top)
                        .padding(.top, 15)
                        .padding(.bottom, 10)
                        .border(appvars.debugBorderColour, width: 2)
                }
                ImageView(imageArray: appvars.imageArray, captionArray: appvars.imageCaptionArray, autoPlaySeconds: string2float(string: appArguments.autoPlay.value))
            }
        } else {
            VStack {
                
                if observedData.centreIconPresent && observedData.centreIconPresent && !(observedData.args.iconOption.value == "none") {
                    IconView(observedDialogContent: observedData)
                        .frame(width: iconDisplayWidth, alignment: .top)
                        .padding(.top, 15)
                        .padding(.bottom, 10)
                        .border(appvars.debugBorderColour, width: 2)
                }
                
                if observedData.listItemPresent {
                    Markdown(observedData.args.messageOption.value, baseURL: URL(string: "http://"))
                        .multilineTextAlignment(appvars.messageAlignment)
                        .markdownStyle(defaultStyle)
                    ListView(observedDialogContent: observedData)
                        .padding(.top, 10)
                } else {
                    ScrollView() {
                        if appvars.messageFontName == "" {
                            Markdown(observedData.args.messageOption.value, baseURL: URL(string: "http://"))
                                .multilineTextAlignment(appvars.messageAlignment)
                                .markdownStyle(defaultStyle)
                        } else {
                            Markdown(observedData.args.messageOption.value, baseURL: URL(string: "http://"))
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
                        TextEntryView(observedDialogContent: observedData)
                            //.padding(.leading, 50)
                            //.padding(.trailing, 50)
                            .padding(.bottom, 10)
                            .border(appvars.debugBorderColour, width: 2)

                        DropdownView(observedDialogContent: observedData)
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

