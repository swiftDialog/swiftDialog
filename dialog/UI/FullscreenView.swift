//
//  FullscreenView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 6/4/21.
//

import Foundation
import SwiftUI
import MarkdownUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct FullscreenView: View {
            
    @ObservedObject var observedData = DialogUpdatableContent()
        
    var TitleViewOption: String = appArguments.titleOption.value // CLOptionText(OptionName: appArguments.titleOption, DefaultValue: appvars.titleDefault)
    var messageContentOption: String = appArguments.messageOption.value // CLOptionText(OptionName: appArguments.messageOption, DefaultValue: appvars.messageDefault)
    
    let displayDetails:CGRect = NSScreen.main!.frame
    var windowHeight:CGFloat = 0
    var windowWidth:CGFloat = 0
    
    // setup element sizes
    var titleContentFontSize:CGFloat = appvars.titleFontSize*3
    var messageContentFontSize:CGFloat = 70 //need to add to appvars
    var iconImageScaleFactor:CGFloat = 1.5
    var emptyStackPadding:CGFloat = 70
    var bannerPadding:CGFloat = 25
    var maxBannerHeight:CGFloat = 120
    var maxBannerWidth:CGFloat = 0
    var minScreenHeightToDisplayBanner:CGFloat = 1000
    var messageTextLineSpacing:CGFloat = 20
    
    var BannerImageOption: String = appArguments.bannerImage.value // CLOptionText(OptionName: appArguments.bannerImage)
    
    var useDefaultStyle = true
    var defaultStyle: MarkdownStyle {
        useDefaultStyle
        ? MarkdownStyle(font: .system(size: messageContentFontSize),
                               foregroundColor: .white)
        : MarkdownStyle(font: .system(size: messageContentFontSize),
                               foregroundColor: .white)
    }
     
    init () {
        // Ensure the singleton NSApplication exists.
        // required for correct determination of screen dimentions for the screen in use in multi screen scenarios
        _ = NSApplication.shared
        
        windowHeight = displayDetails.size.height
        windowWidth = displayDetails.size.width
        
        // adjust element sizes - standard display is 27"
        // bigger displays we scale up
        // smaller display we scale down
        
        maxBannerWidth = windowWidth * 0.95
        maxBannerHeight = windowHeight * 0.10
        
        if windowHeight <= 1440 {
            messageContentFontSize = 40
            emptyStackPadding = 50
            titleContentFontSize = appvars.titleFontSize*2
            iconImageScaleFactor = 0.8
            bannerPadding = 20
            messageTextLineSpacing = 15
        } else if windowHeight > 1440 {
            messageContentFontSize = 60
            titleContentFontSize = appvars.titleFontSize*4
            iconImageScaleFactor = 1.8
            emptyStackPadding = 90
            messageTextLineSpacing = 30
        }
                
        if appvars.titleFontColour == Color.primary {
            appvars.titleFontColour = Color.white
        }
        
    }
            
    public func showFullScreen() {
        
        var window: NSWindow!
        window = NSWindow(
               contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
               styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
               backing: .buffered, defer: false)
        window.makeKeyAndOrderFront(self)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: FullscreenView())

        // open fullScreen mode
        let mainScreen: NSScreen = NSScreen.main!
        window.contentView?.enterFullScreenMode(mainScreen)
    }
    
    var body: some View {
        
        VStack{
            // banner image vstack
            if appArguments.bannerImage.present {
                Image(nsImage: getImageFromPath(fileImagePath: BannerImageOption))
                    .resizable()
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .scaledToFit()
                    .frame(maxWidth: maxBannerWidth, maxHeight: maxBannerHeight)
                    .border(appvars.debugBorderColour, width: 2)
                // Horozontal Line
                VStack{
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(height: 2)
                }
                .frame(width: (maxBannerWidth))
                .padding(.vertical,20)
            }
            
            // title vstack
            if observedData.args.titleOption.value != "none" {
                HStack {
                    // the spacers in this section push the title and thus the full screen area across the width of the display
                    Spacer()
                    Text(observedData.args.titleOption.value)
                        .foregroundColor(appvars.titleFontColour)
                        .bold()
                        .font(.system(size: titleContentFontSize, weight: appvars.titleFontWeight))
                        .multilineTextAlignment(.center)
                        .border(appvars.debugBorderColour, width: 2)
                    Spacer()
                }
            }
            
            // icon and message vstack group
            VStack {
                if appArguments.mainImage.present {
                    // print image and caption
                    VStack {
                        ImageView(imageArray: appvars.imageArray, captionArray: appvars.imageCaptionArray, autoPlaySeconds: string2float(string: appArguments.autoPlay.value))
                            .border(appvars.debugBorderColour, width: 2)
                    }
                } else {
                    // icon vstack
                    VStack {
                        if appArguments.iconOption.present {
                            IconView(observedDialogContent: observedData)
                        } else {
                            VStack{}.padding(emptyStackPadding)
                        }
                    }
                    .padding(40)
                    .frame(minHeight: 200, maxHeight: (NSScreen.main?.frame.height)!/3)
                    .border(appvars.debugBorderColour, width: 2)
                
                    // message vstack
                    VStack() {
                        Markdown(observedData.messageText)
                            //.multilineTextAlignment(appvars.messageAlignment)
                            .markdownStyle(defaultStyle)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                        
                        //TaskProgressView(observedDialogContent: observedDialogContent)  // future feature
                        
                        if appArguments.timerBar.present {
                            timerBarView(progressSteps: string2float(string: appArguments.timerBar.value), visible: appArguments.timerBar.present, observedDialogContent: observedData)
                        }
                    }
                    .padding(10)
                }
            }
            .padding(.horizontal, 20) // total padding for the icon/message group
            //.padding(.vertical, 50)
        }
        .background(
                //LinearGradient(gradient: Gradient(colors: [Color(hex: 0x0e539a), .black]), startPoint: .top, endPoint: .bottom)
                LinearGradient(gradient: Gradient(colors: [Color(hex: 0x252535), .black]), startPoint: .top, endPoint: .bottom)
            )
        
    }
    
}


