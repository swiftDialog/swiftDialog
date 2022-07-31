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
    var progressSteps : CGFloat = appvars.timerDefaultSeconds
    
    //@ObservedObject var observedDialogContent = DialogUpdatableContent()
    @ObservedObject var observedData : DialogUpdatableContent
    
    init (observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        if appArguments.timerBar.present {
            progressSteps = string2float(string: appArguments.timerBar.value)
        }
        if observedData.args.bannerImage.present {
            titlePadding = 0
        }
        
        // capture command+quitKey for quit
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.modifierFlags.intersection(.deviceIndependentFlagsMask) {
            case [.command] where "wnm".contains(event.characters ?? ""):
                return nil
            case [.command] where event.characters == "q":
                if appArguments.quitKey.value != "q" {
                    return nil
                }
                observedDialogContent.end()
            case [.command] where event.characters == appArguments.quitKey.value, [.command, .shift] where event.characters == appArguments.quitKey.value.lowercased():
                observedDialogContent.end()
                quitDialog(exitCode: appvars.exit10.code)
            default:
                return event
            }
            return event
        }
        /*
        // TODO: monitor for global events like minimise all app windows while the app isfocused and write to the log
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            switch event.modifierFlags.intersection(.deviceIndependentFlagsMask) {
            case [.command, .option] where event.characters == "m":
                print("app Minimised")
            default: () //do nothing
            }
        }
        */
    }
//
//    // set up timer to read data from temp file
//    let updateTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect() // tick every 1 second
//
    var body: some View {
                        
        ZStack {            
            if appArguments.watermarkImage.present {
                    watermarkView(imagePath: appArguments.watermarkImage.value, opacity: Double(appArguments.watermarkAlpha.value), position: appArguments.watermarkPosition.value, scale: appArguments.watermarkFill.value)
            }
        
            // this stack controls the main view. Consists of a VStack containing all the content, and a HStack positioned at the bottom of the display area
            VStack {
                if observedData.args.bannerImage.present {
                    BannerImageView(imagePath: observedData.args.bannerImage.value)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                }

                if observedData.args.titleOption.value != "none" {
                    // Dialog title
                    TitleView(observedData: observedData)
                        .border(appvars.debugBorderColour, width: 2)
                        .padding(.top, titlePadding)
                        .frame(minWidth: string2float(string: observedData.args.windowWidth.value), minHeight: appvars.titleHeight, alignment: .center)
                    
                    // Horozontal Line
                    Divider()
                        .frame(width: observedData.windowWidth*appvars.horozontalLineScale, height: 2)
                }
                
                if appArguments.video.present {
                    VideoView(videourl: appArguments.video.value, autoplay: appArguments.autoPlay.present, caption: appArguments.videoCaption.value)
                } else {
                    DialogView(observedDialogContent: observedData)
                }
                
                Spacer()
                
                // Buttons
                HStack() {
                    if appArguments.infoText.present {
                        Text(appArguments.infoText.value)
                            .foregroundColor(.secondary.opacity(0.7))
                            //.font(.system(size: 10))
                    } else if observedData.args.infoButtonOption.present { //} || appArguments.buttonInfoTextOption.present {
                        MoreInfoButton(observedDialogContent: observedData)
                        if !appArguments.timerBar.present {
                            Spacer()
                        }
                    }
                    if appArguments.timerBar.present {
                        timerBarView(progressSteps: progressSteps, visible: !appArguments.hideTimerBar.present, observedDialogContent : observedData)
                            .frame(alignment: .bottom)
                    }
                    if (appArguments.timerBar.present && appArguments.button1TextOption.present) || !appArguments.timerBar.present || appArguments.hideTimerBar.present  {
                        ButtonView(observedDialogContent: observedData) // contains both button 1 and button 2
                    }
                }
                //.frame(alignment: .bottom)
                .padding(.leading, 15)
                .padding(.trailing, 15)
                .padding(.bottom, 15)
                .border(appvars.debugBorderColour, width: 2)
            }
        
        }
        .edgesIgnoringSafeArea(.all)
        .hostingWindowPosition(vertical: appvars.windowPositionVertical, horizontal: appvars.windowPositionHorozontal)

         
    }
    

}

