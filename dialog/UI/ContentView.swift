//
//  ContentView.swift
//  dialog
//
//  Created by Bart Reardon on 9/3/21.
//

import SwiftUI



struct ContentView: View {

    var bannerAdjustment       = CGFloat(5)
    var waterMarkFill          = String("")
    var progressSteps : CGFloat = appvars.timerDefaultSeconds
    
    init () {
        if cloptions.timerBar.present {
            progressSteps = NumberFormatter().number(from: cloptions.timerBar.value) as! CGFloat
        }
    }
//
//    // set up timer to read data from temp file
//    let updateTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect() // tick every 1 second
//
    var body: some View {
                        
        ZStack {
            // Window Setings (pinched from Nudge https://github.com/macadmins/nudge/blob/main/Nudge/UI/ContentView.swift#L19)
            HostingWindowFinder {window in
                window?.standardWindowButton(.closeButton)?.isHidden = true //hides the red close button
                window?.standardWindowButton(.miniaturizeButton)?.isHidden = true //hides the yellow miniaturize button
                window?.standardWindowButton(.zoomButton)?.isHidden = true //this removes the green zoom button
                window?.isMovable = appvars.windowIsMoveable
                if appvars.windowOnTop {
                    window?.level = .floating
                } else {
                    window?.level = .normal
                }
                NSApp.activate(ignoringOtherApps: true) // bring to forefront upon launch
            }
            
            
            if cloptions.watermarkImage.present {
                    watermarkView(imagePath: cloptions.watermarkImage.value, opacity: Double(cloptions.watermarkAlpha.value), position: cloptions.watermarkPosition.value, scale: cloptions.watermarkFill.value)
            }
        
            // this stack controls the main view. Consists of a VStack containing all the content, and a HStack positioned at the bottom of the display area
            VStack {
                if cloptions.bannerImage.present {
                    BannerImageView(imagePath: cloptions.bannerImage.value)
                        .border(appvars.debugBorderColour, width: 2)
                }

                // Dialog title
                TitleView()
                    .border(appvars.debugBorderColour, width: 2)
                    .offset(y: 10) // shift the title down a notch
                
                // Horozontal Line
                Divider()
                    .frame(width: appvars.windowWidth*appvars.horozontalLineScale, height: 2)
                
                if cloptions.video.present {
                    VideoView(videourl: cloptions.video.value, autoplay: cloptions.autoPlay.present, caption: cloptions.videoCaption.value)
                } else {
                    DialogView()
                }
                
                Spacer()
                
                // Buttons
                HStack() {
                    if cloptions.infoButtonOption.present || cloptions.buttonInfoTextOption.present {
                        MoreInfoButton()
                        if !cloptions.timerBar.present {
                            Spacer()
                        }
                    }
                    if cloptions.timerBar.present {
                        //progressBarView(progressSteps: (NumberFormatter().number(from: cloptions.timerBar.value) as! CGFloat), visible: !cloptions.hideTimerBar.present)
                        progressBarView(progressSteps: progressSteps, visible: !cloptions.hideTimerBar.present)
                            .frame(alignment: .bottom)
                    }
                    if (cloptions.timerBar.present && cloptions.button1TextOption.present) || !cloptions.timerBar.present || cloptions.hideTimerBar.present  {
                        ButtonView() // contains both button 1 and button 2
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

