//
//  MiniView.swift
//  dialog
//
//  Created by Bart Reardon on 5/8/2022.
//

import SwiftUI

struct MiniProgressView: View {
    
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    
    var body: some View {
        if cloptions.progressBar.present {
            VStack {
                ProgressView(value: observedDialogContent.progressValue, total: observedDialogContent.progressTotal)
                Text(observedDialogContent.statusText)
                    .lineLimit(1)
            }
        }
    }
}

struct MiniView: View {
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    
    init(observedContent : DialogUpdatableContent) {
        self.observedDialogContent = observedContent
    }
    
    var body: some View {
        ZStack {
            if !cloptions.progressBar.present {
                VStack {
                    Spacer() //push button bar to the bottom of the window
                    HStack {
                        ButtonView(observedDialogContent: observedDialogContent)
                            .padding(.bottom, 15)
                            .padding(.trailing, 15)
                    }
                }
            }
            VStack {
                if observedDialogContent.titleText != "none" {
                    Text(observedDialogContent.titleText)
                        .font(.system(size: 18, weight: .semibold))
                        .border(appvars.debugBorderColour, width: 2)
                        .padding(.top, 5)
                        .lineLimit(1)
                    
                    Divider()
                        .frame(height: 1)
                        .offset(y: -5)
                    
                } else {
                    Spacer()
                        .frame(height: 34)
                }

                HStack {
                    VStack{
                        if (observedDialogContent.iconPresent && observedDialogContent.iconImage != "none") {
                            IconView(image: observedDialogContent.iconImage, overlay: observedDialogContent.overlayIconImage)
                                .frame( maxHeight: 90)
                                .padding(.leading, 25)
                            Spacer()
                        }
                    }
                    VStack {
                        HStack {
                            Text(observedDialogContent.messageText)
                                .lineLimit(4)
                                .font(.system(size: 15))
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        Spacer()
                        if cloptions.progressBar.present {
                            
                            MiniProgressView(observedDialogContent: observedDialogContent)
                        }
                    }
                    .padding(.leading,40)
                    .padding(.trailing,40)
                    .padding(.bottom, 15)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .border(appvars.debugBorderColour, width: 2)
        .hostingWindowPosition(vertical: appvars.windowPositionVertical, horizontal: appvars.windowPositionHorozontal)
    }
}


