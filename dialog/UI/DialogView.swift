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
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    var iconDisplayWidth : CGFloat
    
    init(observedDialogContent : DialogUpdatableContent) {
        if !observedDialogContent.args.iconOption.present { //} appvars.iconIsHidden {
            iconDisplayWidth = 0
        } else {
            iconDisplayWidth = observedDialogContent.iconSize
        }
        self.observedData = observedDialogContent
    }
    
    
    var body: some View {
        VStack { //}(alignment: .top, spacing: nil) {
            HStack {
                if (observedData.args.iconOption.present && !observedData.args.centreIcon.present && observedData.args.iconOption.value != "none") {
                    VStack {
                        IconView(image: observedData.args.iconOption.value, overlay: observedData.args.overlayIconOption.value)
                            .frame(width: iconDisplayWidth, alignment: .top)
                            .border(appvars.debugBorderColour, width: 2)
                            .padding(.top, observedData.appProperties.topPadding)
                            .padding(.leading, observedData.appProperties.sidePadding+10)
                            .padding(.trailing, observedData.appProperties.sidePadding+10)
                        Spacer()
                    }
                }
                
                MessageContent(observedDialogContent: observedData)
                    .border(observedData.appProperties.debugBorderColour, width: 2)
            }
            TaskProgressView(observedData: observedData)
        }
    }
}

