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
        
    var TitleViewOption: String = cloptions.titleOption.value // CLOptionText(OptionName: cloptions.titleOption, DefaultValue: appvars.titleDefault)
    var messageContentOption: String = cloptions.messageOption.value // CLOptionText(OptionName: cloptions.messageOption, DefaultValue: appvars.messageDefault)
    
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
    
    var BannerImageOption: String = cloptions.bannerImage.value // CLOptionText(OptionName: cloptions.bannerImage)
    
    var useDefaultStyle = true
    var style: MarkdownStyle {
        useDefaultStyle
            ? DefaultMarkdownStyle(font: .system(size: 20))
            : DefaultMarkdownStyle(font: .system(size: 20))
    }
     
    init () {
        windowHeight = displayDetails.size.height
        windowWidth = displayDetails.size.width
        
        // adjust element sizes - standard display is 27"
        // bigger displays we scale up
        // smaller display we scale down
        
        maxBannerWidth = windowWidth * 0.95
        maxBannerHeight = windowHeight * 0.10
        
        if windowHeight < 1440 {
            messageContentFontSize = 40
            emptyStackPadding = 50
            titleContentFontSize = appvars.titleFontSize*2
            iconImageScaleFactor = 0.8
            bannerPadding = 20
            messageTextLineSpacing = 15
        } else if windowHeight > 1440 {
            messageContentFontSize = 80
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
           let mainScreen: NSScreen = NSScreen.screens[0]
           window.contentView?.enterFullScreenMode(mainScreen)
    }
    
    var body: some View {
        
        VStack{
            // banner image vstack
            if cloptions.bannerImage.present {
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
            HStack {
                // the spacers in this section push the title and thus the full screen area across the width of the display
                Spacer()
                Text(TitleViewOption)
                    .foregroundColor(appvars.titleFontColour)
                    .bold()
                    .font(.system(size: titleContentFontSize, weight: appvars.titleFontWeight))
                    .multilineTextAlignment(.center)
                    .border(appvars.debugBorderColour, width: 2)
                Spacer()
            }
            
            // icon and message vstack group
            VStack {
                if cloptions.mainImage.present {
                    // print image and caption
                    ImageView(imageArray: appvars.imageArray, captionArray: appvars.imageCaptionArray, autoPlaySeconds: NumberFormatter().number(from: cloptions.autoPlay.value) as! CGFloat)
                        .frame(maxHeight: windowHeight/1.3)
                    if cloptions.mainImageCaption.present {
                        Text(cloptions.mainImageCaption.value)
                            .font(.system(size: messageContentFontSize))
                            .foregroundColor(.white)
                    }
                } else {
                    // icon vstack
                    VStack {
                        if cloptions.iconOption.present {
                            IconView()
                        } else {
                            VStack{}.padding(emptyStackPadding)
                        }
                    }
                    .padding(40)
                    .border(appvars.debugBorderColour, width: 2)
                
                    
                    // message vstack
                    VStack() {
                        Text(messageContentOption)
                            .font(.system(size: messageContentFontSize))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(12)
                            .lineSpacing(messageTextLineSpacing)
                            .border(appvars.debugBorderColour, width: 2)
                    }
                    .padding(10)
                    .frame(maxHeight: .infinity, alignment: .center) // setting to .infinity should make the message content take up the remainder of the screen
                }
                
            }
            .padding(.horizontal, 20) // total padding for the icon/message group
            .padding(.vertical, 50)
        }
        .background(
                //LinearGradient(gradient: Gradient(colors: [Color(hex: 0x0e539a), .black]), startPoint: .top, endPoint: .bottom)
                LinearGradient(gradient: Gradient(colors: [Color(hex: 0x252535), .black]), startPoint: .top, endPoint: .bottom)
            )
        
    }
    
}


