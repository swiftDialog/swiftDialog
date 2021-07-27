//
//  MessageContentView.swift
//  Dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 19/3/21.
//

import Foundation
import SwiftUI
import MarkdownUI

struct MessageContent: View {
    init () {
        
        viewHeight = appvars.windowHeight - 110
        
        if CLOptionPresent(OptionName: CLOptions.smallWindow) {
            viewHeight = appvars.windowHeight - 90
        } else if CLOptionPresent(OptionName: CLOptions.bigWindow) {
            viewHeight = appvars.windowHeight - 120
        }
        
        // adjust the content dimentions based on whether we are showing the icon or not.
        // adjustment multiplyiers determined by careful process of trial and error
        if appvars.iconIsHidden {
            viewWidth = appvars.windowWidth*0.9
            //viewHeight = appvars.windowHeight
            viewOffset = 0
        } else {
            viewWidth = (appvars.windowWidth - appvars.imageWidth - 50)*0.9//(appvars.imageWidth*1.5) - 50
            //viewHeight = appvars.windowHeight
            viewOffset = 20
        }
        
        
    }
    
    var useDefaultStyle = true
    var style: MarkdownStyle {
        useDefaultStyle
            ? DefaultMarkdownStyle(font: .system(size: 20))
            : DefaultMarkdownStyle(font: .system(size: 20))
    }
    
    var viewWidth = CGFloat(0)
    var viewHeight = CGFloat(0)
    var viewOffset = CGFloat(0)
    
    let messageContentOption: String = CLOptionText(OptionName: CLOptions.messageOption, DefaultValue: appvars.messageDefault)
    let theAllignment: Alignment = .topLeading
    
    
    //@State var thing: String = "" //testing
    
    var body: some View {
        VStack {
            ScrollView() {
                Markdown(Document(messageContentOption))
                    .markdownStyle(style)
                    //.frame(width: viewWidth-50, alignment: .center)
                    //.border(Color.red)
            }
            //.border(Color.red)
            //.frame(width: viewWidth, height: viewHeight, alignment: .topLeading)
            
            Spacer()
            
            DropdownView()
                //.border(Color.blue)
                .frame(alignment: .bottomLeading)
        }
        .frame(width: viewWidth, height: viewHeight)
        //.frame(alignment: theAllignment)
        //.padding(15)
        //.offset(x: viewOffset)
        //.border(Color.orange) //debuging
    }
}

