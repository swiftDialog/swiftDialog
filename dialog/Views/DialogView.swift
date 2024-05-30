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

    var showSideBar: Bool = true
    var showInfoBox: Bool = false

    var iconPadding: CGFloat = 10

    init(observedDialogContent: DialogUpdatableContent) {
        if !observedDialogContent.args.iconOption.present { //} appvars.iconIsHidden {
            writeLog("Icon is hidden")
            iconDisplayWidth = 0
        } else {
            iconDisplayWidth = observedDialogContent.iconSize
        }
        showSideBar = observedDialogContent.args.iconOption.present && !observedDialogContent.args.centreIcon.present && observedDialogContent.args.iconOption.value != "none"
        showInfoBox = observedDialogContent.args.infoBox.present
        self.observedData = observedDialogContent
    }


    var body: some View {
        VStack { //}(alignment: .top, spacing: nil) {
            if observedData.args.video.present {
                VideoView(videourl: observedData.args.video.value, autoplay: observedData.args.autoPlay.present, caption: observedData.args.videoCaption.value)
            } else {
                    HStack {
                        if showSideBar || showInfoBox {
                            VStack {
                                if showSideBar {
                                    IconView(image: observedData.args.iconOption.value,
                                             overlay: observedData.args.overlayIconOption.value,
                                             alpha: observedData.iconAlpha, padding: iconPadding)
                                    .accessibilityHint(observedData.args.iconAccessabilityLabel.value)
                                    .frame(width: iconDisplayWidth, alignment: .top)
                                    //.border(.red)
                                }
                                if showInfoBox {
                                    InfoBoxView(observedData: observedData)
                                        .frame(width: iconDisplayWidth < 150 ? 150 : iconDisplayWidth)
                                        .frame(minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
                                        .padding(.top, observedData.appProperties.topPadding)
                                        .clipped()
                                } else {
                                    Spacer()
                                }
                            }
                            .border(appvars.debugBorderColour, width: 2)
                            .padding(.top, observedData.appProperties.topPadding)
                            //.padding(.bottom, observedData.appProperties.bottomPadding)
                            .padding(.leading, observedData.appProperties.sidePadding+10)
                            .padding(.trailing, observedData.iconSize/10)
                        }
                        Spacer()
                        MessageContent(observedDialogContent: observedData)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                    }
            }
            TaskProgressView(observedData: observedData)
        }
    }
}

