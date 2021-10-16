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

@available(OSX 11.0, *)
@main
struct dialogApp: App {
        
    init () {
        
        // get all the command line option values
        processCLOptionValues()
        
        // check for jamfhelper mode
        if cloptions.jamfHelperMode.present {
            print("converting jh to dialog")
            convertFromJamfHelperSyntax()
        }
        
        // process remaining command line options
        processCLOptions()
                        
        appvars.overlayShadow = 1
                
        appvars.titleHeight = appvars.titleHeight * appvars.scaleFactor
        appvars.windowWidth = appvars.windowWidth * appvars.scaleFactor
        appvars.windowHeight = appvars.windowHeight * appvars.scaleFactor
        appvars.imageWidth = appvars.imageWidth * appvars.scaleFactor
        appvars.imageHeight = appvars.imageHeight * appvars.scaleFactor
        
        if cloptions.fullScreenWindow.present {
            FullscreenView().showFullScreen()
        }
        
        // print appvariables and options if debug mode is on
        if cloptions.debug.present {
            print("CLOPTIONS")
            print(cloptions)
            print("APPVARS")
            print(appvars)
        }
    }
    var body: some Scene {

        WindowGroup {
            ContentView()
                .frame(width: appvars.windowWidth, height: appvars.windowHeight) // + appvars.bannerHeight)
                //.frame(idealWidth: appvars.windowWidth, idealHeight: appvars.windowHeight)
        }
        // Hide Title Bar
        .windowStyle(HiddenTitleBarWindowStyle())
    }

    
}


