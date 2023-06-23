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
    var waterMarkFill          = String("")
    var progressSteps: CGFloat = appvars.timerDefaultSeconds

    @ObservedObject var observedData: DialogUpdatableContent

    init (observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
        if observedDialogContent.args.timerBar.present {
            progressSteps = string2float(string: observedDialogContent.args.timerBar.value)
        }
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
            }

            // this stack controls the main view. Consists of a VStack containing all the content, and a HStack positioned at the bottom of the display area
            VStack {
                if observedData.args.bannerImage.present {
                    BannerImageView(observedDialogContent: observedData)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                }

                if observedData.args.titleOption.value != "none" && !appArguments.bannerTitle.present {
                    // Dialog title
                    TitleView(observedData: observedData)
                        .border(appvars.debugBorderColour, width: 2)
                        .padding(.top, titlePadding)
                        .frame(minWidth: string2float(string: observedData.args.windowWidth.value), minHeight: appvars.titleHeight, alignment: .center)

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
                HStack {
                    if observedData.args.infoText.present {
                        Text(observedData.args.infoText.value)
                            .foregroundColor(.secondary.opacity(0.7))
                    } else if observedData.args.infoButtonOption.present || observedData.args.buttonInfoTextOption.present {
                        MoreInfoButton(observedDialogContent: observedData)
                        if !observedData.args.timerBar.present {
                            Spacer()
                        }
                    }
                    if observedData.args.timerBar.present {
                        TimerView(progressSteps: progressSteps, visible: !observedData.args.hideTimerBar.present, observedDialogContent: observedData)
                            .frame(alignment: .bottom)
                    }
                    if (observedData.args.timerBar.present && observedData.args.button1TextOption.present) || !observedData.args.timerBar.present || observedData.args.hideTimerBar.present {
                        ButtonView(observedDialogContent: observedData) // contains both button 1 and button 2
                    }
                }
                .padding(.leading, observedData.appProperties.sidePadding)
                .padding(.trailing, observedData.appProperties.sidePadding)
                .padding(.bottom, observedData.appProperties.bottomPadding)
                .border(appvars.debugBorderColour, width: 2)
            }

        }
        .edgesIgnoringSafeArea(.all)

    }


}

