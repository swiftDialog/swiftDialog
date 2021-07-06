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
        
        // Correct feng shui so the app accepts keyboard input
        // from https://stackoverflow.com/questions/58872398/what-is-the-minimally-viable-gui-for-command-line-swift-scripts
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        
        
        // process command line options that just display info and exit before we show the main window
        if (CLOptionPresent(OptionName: CLOptions.helpOption) || CommandLine.arguments.count == 1) {
            print(helpText)
            quitDialog(exitCode: 0)
            //exit(0)
        }
        if CLOptionPresent(OptionName: CLOptions.getVersion) {
            printVersionString()
            quitDialog(exitCode: 0)
            //exit(0)
        }
        if CLOptionPresent(OptionName: CLOptions.showLicense) {
            print(licenseText)
            quitDialog(exitCode: 0)
            //exit(0)
        }
        if CLOptionPresent(OptionName: CLOptions.buyCoffee) {
            //I'm a teapot
            print("If you like this app and want to buy me a coffee https://www.buymeacoffee.com/bartreardon")
            quitDialog(exitCode: 418)
            //exit(418)
        }
        
        if CLOptionPresent(OptionName: CLOptions.hideIcon) {
            appvars.iconIsHidden = true
        //} else {
        //    iconVisible = true
        }
        
        if CLOptionPresent(OptionName: CLOptions.lockWindow) {
            appvars.windowIsMoveable = true
        }
        
        if CLOptionPresent(OptionName: CLOptions.forceOnTop) {
            appvars.windowOnTop = true
        }
        
        if CLOptionPresent(OptionName: CLOptions.jsonOutPut) {
            appvars.jsonOut = true
        }
                
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
        
        if CLOptionPresent(OptionName: CLOptions.fullScreenWindow) {
            FullscreenView().showFullScreen()
        }

    }
    var body: some Scene {

        WindowGroup {
            ContentView()
                .frame(width: appvars.windowWidth, height: appvars.windowHeight + appvars.bannerHeight)
                //.edgesIgnoringSafeArea(.all)
        }
        // Hide Title Bar
        .windowStyle(HiddenTitleBarWindowStyle())
        //.windowStyle(TitleBarWindowStyle())
        //.windowStyle(DefaultWindowStyle())
        //.windowStyle(TitleBarWindowStyle())
    }
    
}


