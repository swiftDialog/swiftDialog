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
        if cloptions.mainImage.present {
            ImageView(imagePath: cloptions.mainImage.value, caption: cloptions.mainImageCaption.value)
        } else {
            VStack {

                ScrollView() {
                    if appvars.messageFontName == "" {
                        Markdown(Document(messageContentOption))
                            .multilineTextAlignment(appvars.messageAlignment)
                            .markdownStyle(defaultStyle)
                    } else {
                        Markdown(Document(messageContentOption))
                            .multilineTextAlignment(appvars.messageAlignment)
                            .markdownStyle(customStyle)
                    }
                }
                .padding(.top, 10)
                
                Spacer()
                
                TextEntryView()
                    .padding(.leading, 50)
                    .padding(.trailing, 50)
                    .border(appvars.debugBorderColour, width: 2)
                
                DropdownView()
                    .padding(.leading, 50)
                    .padding(.trailing, 50)
                    .border(appvars.debugBorderColour, width: 2)
            }
            .padding(.leading, 40)
            .padding(.trailing, 40)
        }

    }
}

