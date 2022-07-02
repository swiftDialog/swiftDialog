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

var background = BlurWindowController()

@available(OSX 11.0, *)
@main
struct dialogApp: App {
    
    @ObservedObject var observedDialogContent : DialogUpdatableContent
        
    init () {
        
        logger(logMessage: "Dialog Launched")
        
        // Ensure the singleton NSApplication exists.
        // required for correct determination of screen dimentions for the screen in use in multi screen scenarios
        _ = NSApplication.shared
        
        if let screen = NSScreen.main {
            let rect = screen.frame
            appvars.screenHeight = rect.size.height
            appvars.screenWidth = rect.size.width
        }
        
        // get all the command line option values
        processCLOptionValues()
        
        // check for jamfhelper mode
        if appArguments.jamfHelperMode.present {
            logger(logMessage: "converting jh to dialog")
            convertFromJamfHelperSyntax()
        }
        
        // process remaining command line options
        processCLOptions()
                        
        appvars.overlayShadow = 1
                
        appvars.titleHeight = appvars.titleHeight * appvars.scaleFactor
        appvars.windowWidth = appvars.windowWidth * appvars.scaleFactor
        appvars.windowHeight = appvars.windowHeight * appvars.scaleFactor
        appvars.iconWidth = appvars.iconWidth * appvars.scaleFactor
        appvars.iconHeight = appvars.iconHeight * appvars.scaleFactor
        
        if appArguments.fullScreenWindow.present {
            FullscreenView().showFullScreen()
        }
        
        //check debug mode and print info
        if appArguments.debug.present {
            logger(logMessage: "debug options presented. dialog state sent to stdout")
            appvars.debugMode = true
            appvars.debugBorderColour = Color.green
            
            print("Window Height = \(appvars.windowHeight): Window Width = \(appvars.windowWidth)")
            
            print("\nApplication State Variables")
            let mirrored_appvars = Mirror(reflecting: appvars)
            for (_, attr) in mirrored_appvars.children.enumerated() {
                if let propertyName = attr.label as String? {
                print("  \(propertyName) = \(attr.value)")
              }
            }
            print("\nApplication Command Line Options")
            let mirrored_appArguments = Mirror(reflecting: appArguments)
            for (_, attr) in mirrored_appArguments.children.enumerated() {
                if let propertyName = attr.label as String? {
                print("  \(propertyName) = \(attr.value)")
              }
            }
        }
        logger(logMessage: "width: \(appvars.windowWidth), height: \(appvars.windowHeight)")
        
        observedDialogContent = DialogUpdatableContent()
        
        if appArguments.constructionKit.present {
            ConstructionKitView(observedDialogContent: observedDialogContent).showConstructionKit()
            appvars.windowIsMoveable = true
        }
        
        // bring to front on launch
        NSApp.activate(ignoringOtherApps: true)
    }
    var body: some Scene {

        WindowGroup {
            ZStack {
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

                    if appArguments.blurScreen.present && !appArguments.fullScreenWindow.present { //blur background
                        background.showWindow(self)
                        NSApp.windows[0].level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
                    }
                    
                    if appArguments.forceOnTop.present || appArguments.blurScreen.present {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    
                }
                .frame(width: 0, height: 0) //ensures hostingwindowfinder isn't taking up any real estate
                
                ContentView(observedDialogContent: observedDialogContent)
                    .frame(width: observedDialogContent.windowWidth.rounded(), height: observedDialogContent.windowHeight.rounded()) // + appvars.bannerHeight)
                //.frame(idealWidth: appvars.windowWidth, idealHeight: appvars.windowHeight)
                    .sheet(isPresented: $observedDialogContent.showSheet, content: {
                        ErrorView(observedContent: observedDialogContent)
                    })

            }
        }
        // Hide Title Bar
        .windowStyle(HiddenTitleBarWindowStyle())
        /*
        WindowGroup("ConstructionKit") {
            ConstructionKitView(observedDialogContent: observedDialogContent)
        }
         */
    }

    
}


