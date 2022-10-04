//
//  MiniView.swift
//  dialog
//
//  Created by Bart Reardon on 5/8/2022.
//

import SwiftUI

struct MiniProgressView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    var body: some View {
        if appArguments.progressBar.present {
            VStack {
                ProgressView(value: observedData.progressValue, total: observedData.progressTotal)
                Text(observedData.statusText)
                    .lineLimit(1)
            }
        }
    }
}

struct MiniView: View {
    @ObservedObject var observedData : DialogUpdatableContent
    
    init(observedContent : DialogUpdatableContent) {
        self.observedData = observedContent
    }
    
    var body: some View {
        ZStack {
            if !appArguments.progressBar.present {
                VStack {
                    Spacer() //push button bar to the bottom of the window
                    HStack {
                        ButtonView(observedDialogContent: observedData)
                            .padding(.bottom, observedData.appProperties.bottomPadding)
                            .padding(.trailing, observedData.appProperties.sidePadding)
                    }
                }
            }
            VStack {
                if observedData.args.titleOption.value != "none" {
                    Text(observedData.args.titleOption.value)
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
                        if (observedData.args.iconOption.present && observedData.args.iconOption.value != "none") {
                            IconView(image: observedData.args.iconOption.value, overlay: observedData.args.overlayIconOption.value)
                                .frame( maxHeight: 90)
                                .padding(.leading, observedData.appProperties.sidePadding)
                            Spacer()
                        }
                    }
                    VStack {
                        HStack {
                            Text(observedData.messageText)
                                .lineLimit(4)
                                .font(.system(size: 15))
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        Spacer()
                        if appArguments.progressBar.present {
                            
                            MiniProgressView(observedData: observedData)
                        }
                    }
                    .padding(.leading,observedData.appProperties.sidePadding)
                    .padding(.trailing,observedData.appProperties.sidePadding)
                    .padding(.bottom, observedData.appProperties.bottomPadding)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .border(appvars.debugBorderColour, width: 2)
    }
}


