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
    
    init() {
        if appvars.iconIsHidden {
            appvars.imageWidth = 0
        }
        //print("icon width: \(appvars.imageWidth) icon height: \(appvars.imageHeight)")
    }
    
    var body: some View {
        HStack { //}(alignment: .top, spacing: nil) {
            let iconFrameWidth: CGFloat = appvars.imageWidth
            HStack {
                
                if (!appvars.iconIsHidden) {
                    VStack {
                        IconView()
                            .frame(width: iconFrameWidth, alignment: .top)
                            .border(appvars.debugBorderColour, width: 2)
                            .padding(.top, 20)
                            .padding(.leading, 30)
                        Spacer()
                    }
                }
                
                VStack(alignment: .center) {
                    //TitleView()
                    MessageContent()
                        .border(appvars.debugBorderColour, width: 2)
                }
            }
        }
    }
}

