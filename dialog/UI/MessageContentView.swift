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
    
    var messageColour : NSColor = NSColor(appvars.messageFontColour)
    
    var useDefaultStyle = true
        
    var defaultStyle: MarkdownStyle {
        useDefaultStyle
            ? DefaultMarkdownStyle(font: .system(size: appvars.messageFontSize), foregroundColor: messageColour)
            : DefaultMarkdownStyle(font: .system(size: appvars.messageFontSize), foregroundColor: messageColour)
    }
    
    var customStyle: MarkdownStyle {
        useDefaultStyle
            ? DefaultMarkdownStyle(font: .custom(appvars.messageFontName, size: appvars.titleFontSize), foregroundColor: messageColour)
            : DefaultMarkdownStyle(font: .custom(appvars.messageFontName, size: appvars.titleFontSize), foregroundColor: messageColour)
    }
    
    let messageContentOption: String = cloptions.messageOption.value
    let theAllignment: Alignment = .topLeading
    
    
    var body: some View {
        
        if observedDialogContent.imagePresent || (observedDialogContent.imagePresent && observedDialogContent.imageCaptionPresent) {
            ImageView(imageArray: appvars.imageArray, captionArray: appvars.imageCaptionArray, autoPlaySeconds: NumberFormatter().number(from: cloptions.autoPlay.value) as! CGFloat)
        } else {
            VStack {
                if observedDialogContent.listItemPresent {
                    Markdown(Document(observedDialogContent.messageText))
                        .multilineTextAlignment(appvars.messageAlignment)
                        .markdownStyle(defaultStyle)
                    ListView(observedDialogContent: observedDialogContent)
                        .padding(.top, 10)
                } else {
                    ScrollView() {
                        if appvars.messageFontName == "" {
                            Markdown(Document(observedDialogContent.messageText))
                                .multilineTextAlignment(appvars.messageAlignment)
                                .markdownStyle(defaultStyle)
                        } else {
                            Markdown(Document(observedDialogContent.messageText))
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
                    Spacer()
                    VStack {
                        TextEntryView()
                            .padding(.leading, 50)
                            .padding(.trailing, 50)
                            .border(appvars.debugBorderColour, width: 2)

                        DropdownView()
                            .padding(.leading, 50)
                            .padding(.trailing, 50)
                            .border(appvars.debugBorderColour, width: 2)
                    }
                }
            }
            .padding(.leading, 40)
            .padding(.trailing, 40)
        }
    }
}

