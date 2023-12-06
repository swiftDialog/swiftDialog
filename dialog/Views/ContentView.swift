//
//  ContentView.swift
//  dialog
//
//  Created by Bart Reardon on 9/3/21.
//

import SwiftUI
import Cocoa

struct ContentView: View {

    var titlePadding       = CGFloat(10)

    @ObservedObject var observedData: DialogUpdatableContent

    init (observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
        if observedData.args.bannerImage.present {
            writeLog("Banner Image is present")
            titlePadding = 0
        }

        // capture command+quitKey for quit
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.modifierFlags.intersection(.deviceIndependentFlagsMask) {
            case [.command] where "wnm".contains(event.characters ?? ""):
                writeLog("Detected cmd+w or cmd+n or cmd+m")
                return nil
            case [.command] where event.characters == "q":
                writeLog("Detected cmd+q")
                if observedDialogContent.args.quitKey.value != "q" {
                    writeLog("cmd+q is disabled")
                    return nil
                } else {
                    quitDialog(exitCode: observedDialogContent.appProperties.exit10.code)
                }
            case [.command] where event.characters == observedDialogContent.args.quitKey.value, [.command, .shift] where event.characters == observedDialogContent.args.quitKey.value.lowercased():
                writeLog("detected cmd+\(observedDialogContent.args.quitKey.value)")
                quitDialog(exitCode: observedDialogContent.appProperties.exit10.code)
            default:
                return event
            }
            return event
        }
    }
//
//    // set up timer to read data from temp file
//    let updateTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect() // tick every 1 second
//
    var body: some View {

        ZStack {
            if observedData.args.watermarkImage.present {
                    WatermarkView(observedContent: observedData)
                    .frame(width: observedData.appProperties.windowWidth, height: observedData.appProperties.windowHeight)
            }

            // this stack controls the main view. Consists of a VStack containing all the content, and a HStack positioned at the bottom of the display area
            VStack {
                if observedData.args.bannerImage.present {
                    BannerImageView(observedDialogContent: observedData)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                }

                if observedData.args.titleOption.value != "none" && !observedData.args.bannerTitle.present {
                    // Dialog title
                    TitleView(observedData: observedData)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                        .padding(.top, titlePadding)
                        .frame(minWidth: observedData.args.windowWidth.value.floatValue(), minHeight: observedData.appProperties.titleHeight, alignment: .center)

                    // Horozontal Line
                    Divider()
                        .padding(.leading, observedData.appProperties.sidePadding)
                        .padding(.trailing, observedData.appProperties.sidePadding)
                        .frame(height: 2)
                } else {
                    Spacer()
                        .frame(height: observedData.appProperties.sidePadding)
                }

                DialogView(observedDialogContent: observedData)

                Spacer()

                // Buttons
                ButtonView(observedDialogContent: observedData)
                    .padding(.leading, observedData.appProperties.sidePadding)
                    .padding(.trailing, observedData.appProperties.sidePadding)
                    .padding(.bottom, observedData.appProperties.bottomPadding)
                    .border(observedData.appProperties.debugBorderColour, width: 2)
            }

            if observedData.appProperties.authorised {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "lock.circle")
                        //.resizable()
                            .font(Font.title.weight(.light))
                            .symbolRenderingMode(.monochrome)
                            .foregroundColor(.yellow)
                            .opacity(0.5)
                    }
                    Spacer()
                }
            }

        }
        .edgesIgnoringSafeArea(.all)

    }


}

