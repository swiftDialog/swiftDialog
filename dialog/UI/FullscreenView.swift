//
//  FullscreenView.swift
//  Dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 6/4/21.
//

import Foundation
import SwiftUI

struct FullscreenView: View {
        
    var TitleViewOption: String = CLOptionText(OptionName: CLOptions.titleOption, DefaultValue: appvars.titleDefault)
    let messageContentOption: String = CLOptionText(OptionName: CLOptions.messageOption, DefaultValue: appvars.messageDefault)
    
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
    
    var BannerImageOption: String = CLOptionText(OptionName: CLOptions.bannerImage, DefaultValue: "")
     
    
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
            //maxBannerHeight = 90
            bannerPadding = 20
        } else if windowHeight > 1440 {
            messageContentFontSize = 80
            titleContentFontSize = appvars.titleFontSize*4
            iconImageScaleFactor = 1.8
            emptyStackPadding = 90
            //maxBannerHeight = 150
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
           window.setFrameAutosaveName("Main Window")
           window.contentView = NSHostingView(rootView: FullscreenView())

       // open fullScreen mode
           let mainScreen: NSScreen = NSScreen.screens[0]
           window.contentView?.enterFullScreenMode(mainScreen)
    }
    
    var body: some View {
        
        VStack{
            // banner image vstack
            VStack{
                if CLOptionPresent(OptionName: CLOptions.bannerImage) {
                    Image(nsImage: getImageFromPath(fileImagePath: BannerImageOption))
                        .resizable()
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .scaledToFit()
                        .frame(maxWidth: maxBannerWidth, maxHeight: maxBannerHeight)
                    /*
                    BannerImageView()
                        .frame(maxWidth: maxBannerWidth, maxHeight: maxBannerHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .fixedSize()
                    */
                }
            }.padding(bannerPadding) //padding for the top of the display
            //.border(Color.green)
            
            // title vstack
            VStack{
                HStack {
                    Spacer()
                    Text(TitleViewOption)
                        .foregroundColor(.white)
                        .bold()
                        .font(.system(size: titleContentFontSize))
                    Spacer()
                }
                //.border(Color.red)
            }
            //.border(Color.blue)
            
            // icon and message vstack group
            VStack {
                // icon vstack
                VStack {
                    if CLOptionPresent(OptionName: CLOptions.iconOption) {
                        IconView()
                            //.colorInvert()
                            .frame(maxHeight: appvars.imageHeight*iconImageScaleFactor, alignment: .center)
                            //.background(Color.white)
                    } else {
                        VStack{}.padding(emptyStackPadding)
                    }
                }
                //.border(Color.orange)
                
                // message vstack
                VStack() {
                    Text(messageContentOption)
                        .font(.system(size: messageContentFontSize))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(10)
                        
                }//.border(Color.red)
                .padding(10)
                .frame(maxHeight: .infinity, alignment: .top) // setting to .infinity should make the message content take up the remainder of the screen
                //.border(Color.yellow)
            }//.border(Color.red)
            .padding(20) // total padding for the icon/message group
        }
        .background(Color.black)
        
    }
    
}


