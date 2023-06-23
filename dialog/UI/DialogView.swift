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

    @ObservedObject var observedData: DialogUpdatableContent

    var iconDisplayWidth: CGFloat

    init(observedDialogContent: DialogUpdatableContent) {
        if !observedDialogContent.args.iconOption.present { //} appvars.iconIsHidden {
            writeLog("Icon is hidden")
            iconDisplayWidth = 0
        } else {
            iconDisplayWidth = observedDialogContent.iconSize
        }
        self.observedData = observedDialogContent
    }


    var body: some View {
        VStack { //}(alignment: .top, spacing: nil) {
            if observedData.args.video.present {
                VideoView(videourl: observedData.args.video.value, autoplay: observedData.args.autoPlay.present, caption: observedData.args.videoCaption.value)
            } else {
                HStack {
                    if observedData.args.iconOption.present && !observedData.args.centreIcon.present && observedData.args.iconOption.value != "none" {
                        VStack(alignment: .leading) {
                            IconView(image: observedData.args.iconOption.value,
                                     overlay: observedData.args.overlayIconOption.value,
                                     alpha: observedData.iconAlpha)
                                .accessibilityHint(observedData.args.iconAccessabilityLabel.value)
                                .frame(width: iconDisplayWidth, alignment: .top)
                            if observedData.args.infoBox.present {
                                InfoBoxView(observedData: observedData)
                            }
                            Spacer()
                        }
                        .border(appvars.debugBorderColour, width: 2)
                        .padding(.top, observedData.appProperties.topPadding)
                        .padding(.bottom, observedData.appProperties.bottomPadding)
                        .padding(.leading, observedData.appProperties.sidePadding+10)
                        .padding(.trailing, observedData.appProperties.sidePadding+10)
                    }

                    MessageContent(observedDialogContent: observedData)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                }
            }
            TaskProgressView(observedData: observedData)
        }
    }
}

