//
//  DialogView.swift
//  dialog
//
//  Created by Bart Reardon on 9/3/21.
//
// Center portion of the dialog window consisting of icon/image if optioned and message content

import Foundation
import SwiftUI
import AppKit

struct DialogView: View {
    
    var imageOffsetX: CGFloat = -25
    var imageOffsetY: CGFloat = 10
    
    init() {
        if appvars.iconIsHidden {
            appvars.imageWidth = 0
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: /*@START_MENU_TOKEN@*/nil/*@END_MENU_TOKEN@*/) {
            let iconFrameWidth: CGFloat = appvars.imageWidth
            let iconFrameHeight: CGFloat = appvars.imageHeight
            HStack {
                if (!appvars.iconIsHidden) {
                    VStack {
                            IconView()
                            
                    }.frame(width: iconFrameWidth, height: iconFrameHeight, alignment: .top)
                    .offset(x: imageOffsetX, y: imageOffsetY) //position the icon area
                    .padding(10)
                    //.border(Color.purple)
                }
                
                VStack(alignment: .center) {
                    //TitleView()
                    MessageContent()
                }
            }
            //.border(Color.green)
            
        }
    }
}

