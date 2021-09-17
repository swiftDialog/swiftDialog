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
    
    var useDefaultStyle = true
    var style: MarkdownStyle {
        useDefaultStyle
            ? DefaultMarkdownStyle(font: .system(size: 20))
            : DefaultMarkdownStyle(font: .system(size: 20))
    }
    
    let messageContentOption: String = cloptions.messageOption.value
    let theAllignment: Alignment = .topLeading
    
    var body: some View {
        VStack {
            if cloptions.mainImage.present {
                ImageView(imagePath: cloptions.mainImage.value, caption: cloptions.mainImageCaption.value)
            } else {
                ScrollView() {
                    Markdown(Document(messageContentOption))
                        .multilineTextAlignment(appvars.messageAlignment)
                        .markdownStyle(style)
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
        }
        .padding(.leading, 40)
        .padding(.trailing, 40)
    }
}

