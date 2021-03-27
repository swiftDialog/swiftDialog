//
//  dialogApp.swift
//  dialog
//
//  Created by Bart Reardon on 9/3/21.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    // check for a few command line options before loading
    func applicationWillFinishLaunching(_ notification: Notification) {
        //print("applicationWillFinishLaunching")

    }
}

@available(OSX 11.0, *)
@main
struct dialogApp: App {
    init () {
        if CLOptionPresent(OptionName: CLOptions.smallWindow) {
            // scale everything down a notch
            
            appvars.smallWindow = true

            appvars.scaleFactor = 0.75
            appvars.dialogContentScale = 0.80
            
            appvars.overlayOffsetX = appvars.overlayOffsetX * (appvars.scaleFactor)
            appvars.overlayOffsetY = appvars.overlayOffsetY * (appvars.scaleFactor*appvars.scaleFactor)
            appvars.overlayIconScale = appvars.overlayIconScale * appvars.scaleFactor
        } else if CLOptionPresent(OptionName: CLOptions.bigWindow) {
            // scale everything up a notch
            
            appvars.bigWindow = true
            appvars.scaleFactor = 1.25
            appvars.dialogContentScale = 0.55
            
            //appvars.overlayOffsetX = appvars.overlayOffsetX * (appvars.scaleFactor)
            //appvars.overlayOffsetY = appvars.overlayOffsetY * (appvars.scaleFactor)
            appvars.overlayIconScale = appvars.overlayIconScale / appvars.scaleFactor
        }
        
        

        appvars.overlayShadow = 1
        
        //appvars.titleFontSize
        
        appvars.titleHeight = appvars.titleHeight * appvars.scaleFactor
        appvars.windowWidth = appvars.windowWidth * appvars.scaleFactor
        appvars.windowHeight = appvars.windowHeight * appvars.scaleFactor
        appvars.imageWidth = appvars.imageWidth * appvars.scaleFactor
        appvars.imageHeight = appvars.imageHeight * appvars.scaleFactor

    }
    var body: some Scene {
                        
        WindowGroup {
            ContentView()
                .frame(width: appvars.windowWidth, height: appvars.windowHeight + appvars.bannerHeight)
        }
        // Hide Title Bar
        .windowStyle(HiddenTitleBarWindowStyle())
        //.windowStyle(TitleBarWindowStyle())
        //.windowStyle(DefaultWindowStyle())
        //.windowStyle(TitleBarWindowStyle())
    }
    
}


