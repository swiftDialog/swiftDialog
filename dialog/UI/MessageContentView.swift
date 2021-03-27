//
//  MessageContentView.swift
//  Dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 19/3/21.
//

import Foundation
import SwiftUI

struct MessageContent: View {
    init () {
        // adjust the content dimentions based on whether we are showing the icon or not.
        // adjustment multiplyiers determined by careful process of trial and error
        
        if appvars.iconIsHidden {
            viewWidth = appvars.windowWidth*0.8
            viewHeight = appvars.windowHeight/1.6
            viewOffset = 0
        } else {
            viewWidth = appvars.windowWidth - (appvars.imageWidth*1.5)
            viewHeight = appvars.windowHeight/1.6
            viewOffset = 20
        }
    }
    
    var viewWidth = CGFloat(0)
    var viewHeight = CGFloat(0)
    var viewOffset = CGFloat(0)
    
    let messageContentOption: String = CLOptionText(OptionName: CLOptions.messageOption, DefaultValue: appvars.messageDefault)
    let theAllignment: Alignment = .topLeading
    
    var body: some View {
        VStack {
            Text(messageContentOption)
                .font(.system(size: 20))
        }
        .frame(width: viewWidth, height: viewHeight, alignment: theAllignment)
        .padding(20)
        .offset(x: viewOffset)
        //.border(Color.orange) //debuging
    }
}

