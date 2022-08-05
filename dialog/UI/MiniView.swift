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
            VStack {
                Text(observedDialogContent.titleText)
                    .font(.system(size: 18, weight: .semibold))
                    .border(appvars.debugBorderColour, width: 2)
                    .padding(.top, 5)
                Divider()
                    .frame(height: 0)
                    .offset(y: -5)
                HStack {
                    VStack{
                        if (observedDialogContent.iconPresent && observedDialogContent.iconImage != "none") {
                            IconView(observedDialogContent: observedDialogContent)
                                .frame( height: 80, alignment: .center)
                                .padding(.leading, 30)
                            Spacer()
                        }
                    }
                    .frame( height: observedDialogContent.windowHeight, alignment: .center)
                    VStack {
                        HStack {
                            Text(observedDialogContent.messageText)
                                .font(.system(size: 15))
                                .lineLimit(2)
                            Spacer()
                        }
                        if cloptions.progressBar.present {
                            Spacer()
                            MiniProgressView(observedDialogContent: observedDialogContent)
                        }
                        Spacer()
                    }
                    .padding(.leading,40)
                    .padding(.trailing,40)
                    .padding(.bottom, 20)
                }
            }
            if !cloptions.progressBar.present {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ButtonView(observedDialogContent: observedDialogContent)
                            .padding(.bottom, 30)
                            .padding(.trailing, 15)
                    }
                }
            }
            
        }
        .edgesIgnoringSafeArea(.all)
        .border(appvars.debugBorderColour, width: 2)
        .hostingWindowPosition(vertical: appvars.windowPositionVertical, horizontal: appvars.windowPositionHorozontal)
    }
}


