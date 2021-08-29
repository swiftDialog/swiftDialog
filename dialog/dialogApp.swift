//
//  dialogApp.swift
//  dialog
//
//  Created by Bart Reardon on 9/3/21.
//

import SwiftUI

import SystemConfiguration


extension StringProtocol {
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
}

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
        
        processCLOptions()
        processCLOptionValues()
                
        appvars.overlayShadow = 1
                
        appvars.titleHeight = appvars.titleHeight * appvars.scaleFactor
        appvars.windowWidth = appvars.windowWidth * appvars.scaleFactor
        appvars.windowHeight = appvars.windowHeight * appvars.scaleFactor
        appvars.imageWidth = appvars.imageWidth * appvars.scaleFactor
        appvars.imageHeight = appvars.imageHeight * appvars.scaleFactor
        
        if CLOptionPresent(OptionName: CLOptions.fullScreenWindow) {
            //appvars.overlayIconScale = appvars.overlayIconScale * 2
            FullscreenView().showFullScreen()
        }
    
    }
    var body: some Scene {

        WindowGroup {
            ContentView()
                .frame(width: appvars.windowWidth, height: appvars.windowHeight + appvars.bannerHeight)
                .edgesIgnoringSafeArea(.all)
        }
        // Hide Title Bar
        .windowStyle(HiddenTitleBarWindowStyle())
        //.windowStyle(TitleBarWindowStyle())
        //.windowStyle(DefaultWindowStyle())
        //.windowStyle(TitleBarWindowStyle())
    }
    
}


