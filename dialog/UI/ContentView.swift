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
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    
    init (observedDialogContent : DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
        if cloptions.timerBar.present {
            progressSteps = string2float(string: cloptions.timerBar.value)
        }
        if cloptions.bannerImage.present {
            titlePadding = 0
        }
        
        // capture command+quitKey for quit
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.modifierFlags.intersection(.deviceIndependentFlagsMask) {
            case [.command] where "wnm".contains(event.characters ?? ""):
                return nil
            case [.command] where event.characters == "q":
                if cloptions.quitKey.value != "q" {
                    return nil
                }
            case [.command] where event.characters == cloptions.quitKey.value, [.command, .shift] where event.characters == cloptions.quitKey.value.lowercased():
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
            if cloptions.watermarkImage.present {
                    watermarkView(imagePath: cloptions.watermarkImage.value, opacity: Double(cloptions.watermarkAlpha.value), position: cloptions.watermarkPosition.value, scale: cloptions.watermarkFill.value)
            }
        
            // this stack controls the main view. Consists of a VStack containing all the content, and a HStack positioned at the bottom of the display area
            VStack {
                if cloptions.bannerImage.present {
                    BannerImageView(imagePath: cloptions.bannerImage.value)
                        .border(appvars.debugBorderColour, width: 2)
                }

                if observedDialogContent.titleText != "none" {
                    // Dialog title
                    TitleView(observedDialogContent: observedDialogContent)
                        .border(appvars.debugBorderColour, width: 2)
                        .padding(.top, titlePadding)
                        //.offset(y: 10) // shift the title down a notch
                    
                    // Horozontal Line
                    Divider()
                        .frame(width: appvars.windowWidth*appvars.horozontalLineScale, height: 2)
                        .offset(y: -10) // shift the divider up a notch
                }
                
                if cloptions.video.present {
                    VideoView(videourl: cloptions.video.value, autoplay: cloptions.autoPlay.present, caption: cloptions.videoCaption.value)
                } else {
                    DialogView(observedDialogContent: observedDialogContent)
                }
                
                Spacer()
                
                // Buttons
                HStack() {
                    if cloptions.infoText.present {
                        Text(cloptions.infoText.value)
                            .foregroundColor(.secondary.opacity(0.7))
                            //.font(.system(size: 10))
                    } else if cloptions.infoButtonOption.present || cloptions.buttonInfoTextOption.present {
                        MoreInfoButton()
                        if !cloptions.timerBar.present {
                            Spacer()
                        }
                    }
                    if cloptions.timerBar.present {
                        timerBarView(progressSteps: progressSteps, visible: !cloptions.hideTimerBar.present, observedDialogContent : observedDialogContent)
                            .frame(alignment: .bottom)
                    }
                    if (cloptions.timerBar.present && cloptions.button1TextOption.present) || !cloptions.timerBar.present || cloptions.hideTimerBar.present  {
                        ButtonView(observedDialogContent: observedDialogContent) // contains both button 1 and button 2
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

