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
    
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    
    var iconDisplayWidth : CGFloat
    
    init(observedDialogContent : DialogUpdatableContent) {
        if !observedDialogContent.iconPresent { //} appvars.iconIsHidden {
            iconDisplayWidth = 0
        } else {
            iconDisplayWidth = observedDialogContent.iconSize
        }
        self.observedDialogContent = observedDialogContent
    }
    
    
    var body: some View {
        VStack { //}(alignment: .top, spacing: nil) {
            HStack {
                if (observedDialogContent.iconPresent && !observedDialogContent.centreIconPresent && !(observedDialogContent.iconImage == "none")) {
                    VStack {
                        IconView(image: observedDialogContent.iconImage, overlay: observedDialogContent.overlayIconImage)
                            .frame(width: iconDisplayWidth, alignment: .top)
                            .border(appvars.debugBorderColour, width: 2)
                            .padding(.top, 20)
                            .padding(.leading, 30)
                        Spacer()
                    }
                }
                
                MessageContent(observedDialogContent: observedDialogContent)
                    .border(appvars.debugBorderColour, width: 2)
            }
            TaskProgressView(observedDialogContent: observedDialogContent)
        }
    }
}

