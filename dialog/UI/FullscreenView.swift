//
//  FullscreenView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 6/4/21.
//

import Foundation
import SwiftUI
import MarkdownUI

struct FullscreenView: View {
            
    @ObservedObject var observedData : DialogUpdatableContent
        
    let displayDetails:CGRect = NSScreen.main!.frame
    var windowHeight:CGFloat = 0
    var windowWidth:CGFloat = 0
    
    // setup element sizes
    var titleContentFontSize:CGFloat
    var messageContentFontSize:CGFloat
    var iconImageScaleFactor:CGFloat
    var emptyStackPadding:CGFloat
    var bannerPadding:CGFloat
    var maxBannerHeight:CGFloat = 120
    var maxBannerWidth:CGFloat = 0
    var minScreenHeightToDisplayBanner:CGFloat = 1000
    var messageTextLineSpacing:CGFloat = 20
    
    var useDefaultStyle = true
    var defaultStyle: MarkdownStyle {
        useDefaultStyle
        ? MarkdownStyle(font: .system(size: messageContentFontSize),
                               foregroundColor: .white)
        : MarkdownStyle(font: .system(size: messageContentFontSize),
                               foregroundColor: .white)
    }
     
    init (observedData : DialogUpdatableContent) {
        self.observedData = observedData
        // Ensure the singleton NSApplication exists.
        // required for correct determination of screen dimentions for the screen in use in multi screen scenarios
        _ = NSApplication.shared
        
        windowHeight = displayDetails.size.height
        windowWidth = displayDetails.size.width
        
        messageContentFontSize = 70
        emptyStackPadding = 70
        titleContentFontSize = observedData.appProperties.titleFontSize*3
        iconImageScaleFactor = 1.5
        bannerPadding = 25
        messageTextLineSpacing = 15
        
        // adjust element sizes - standard display is 27"
        // bigger displays we scale up
        // smaller display we scale down
        
        maxBannerWidth = windowWidth * 0.95
        maxBannerHeight = windowHeight * 0.10
        
        if windowHeight <= 1440 {
            messageContentFontSize = 40
            emptyStackPadding = 50
            titleContentFontSize = observedData.appProperties.titleFontSize*2
            iconImageScaleFactor = 0.8
            bannerPadding = 20
            messageTextLineSpacing = 15
        } else if windowHeight > 1440 {
            messageContentFontSize = 60
            titleContentFontSize = observedData.appProperties.titleFontSize*4
            iconImageScaleFactor = 1.8
            emptyStackPadding = 90
            messageTextLineSpacing = 30
        }
                
        if observedData.appProperties.titleFontColour == Color.primary {
            observedData.appProperties.titleFontColour = Color.white
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
        window.contentView = NSHostingView(rootView: FullscreenView(observedData: observedData))

        // open fullScreen mode
        let mainScreen: NSScreen = NSScreen.main!
        window.contentView?.enterFullScreenMode(mainScreen)
    }
    
    var body: some View {
        
        VStack{
            // banner image vstack
            if observedData.args.bannerImage.present {
                Image(nsImage: getImageFromPath(fileImagePath: observedData.args.bannerImage.value))
                    .resizable()
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .scaledToFit()
                    .frame(maxWidth: maxBannerWidth, maxHeight: maxBannerHeight)
                    .border(observedData.appProperties.debugBorderColour, width: 2)
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
                        .foregroundColor(observedData.appProperties.titleFontColour)
                        .bold()
                        .font(.system(size: titleContentFontSize, weight: observedData.appProperties.titleFontWeight))
                        .multilineTextAlignment(.center)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                    Spacer()
                }
            }
            
            // icon and message vstack group
            VStack {
                if observedData.args.mainImage.present {
                    // print image and caption
                    VStack {
                        ImageView(imageArray: observedData.appProperties.imageArray, captionArray: observedData.appProperties.imageCaptionArray, autoPlaySeconds: string2float(string: observedData.args.autoPlay.value))
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                    }
                } else {
                    // icon vstack
                    VStack {
                        if observedData.args.iconOption.present {
                            IconView(image: observedData.args.iconOption.value, overlay: observedData.args.overlayIconOption.value)
                        } else {
                            VStack{}.padding(emptyStackPadding)
                        }
                    }
                    .padding(40)
                    .frame(minHeight: 200, maxHeight: (NSScreen.main?.frame.height)!/3)
                    .border(observedData.appProperties.debugBorderColour, width: 2)
                
                    // message vstack
                    VStack() {
                        Markdown(observedData.messageText)
                            .markdownStyle(defaultStyle)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                        
                        //TaskProgressView(observedDialogContent: observedDialogContent)  // future feature
                        
                        if observedData.args.timerBar.present {
                            TimerView(progressSteps: string2float(string: observedData.args.timerBar.value), visible: observedData.args.timerBar.present, observedDialogContent: observedData)
                        }
                    }
                    .padding(10)
                }
            }
            .padding(.horizontal, 20) // total padding for the icon/message group
        }
        .background(
                //LinearGradient(gradient: Gradient(colors: [Color(hex: 0x0e539a), .black]), startPoint: .top, endPoint: .bottom)
                LinearGradient(gradient: Gradient(colors: [Color(hex: 0x252535), .black]), startPoint: .top, endPoint: .bottom)
            )
        
    }
    
}


