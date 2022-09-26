//
//  dialogApp.swift
//  dialog
//
//  Created by Bart Reardon on 9/3/21.
//

import SwiftUI
import Combine

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
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    @State private var cancellables = Set<AnyCancellable>()
    @State var window : NSWindow?
    
    func monitorVisibility(window: NSWindow) {
        window.publisher(for: \.isVisible)
            .dropFirst()  // we know: the first value is not interesting
            .sink(receiveValue: { isVisible in
                if isVisible {
                    self.window = window
                    placeWindow(window)
                }
            })
            .store(in: &cancellables)
    }
    
    func placeWindow(_ window: NSWindow) {
        let main = NSScreen.main!
        let visibleFrame = main.visibleFrame
        let windowSize = window.frame.size
        
        let windowX = setWindowXPos(screenWidth: visibleFrame.width - windowSize.width, position: appvars.windowPositionHorozontal)
        let windowY = setWindowYPos(screenHeight: visibleFrame.height - windowSize.height, position: appvars.windowPositionVertical)
        
        let desiredOrigin = CGPoint(x: visibleFrame.origin.x + windowX, y: visibleFrame.origin.y + windowY)
        window.setFrameOrigin(desiredOrigin)
    }
        
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
        
        if appArguments.miniMode.present {
            print("mini mode")
            appvars.windowWidth = 540
            appvars.windowHeight = 128
        }
        
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
        
        observedData = DialogUpdatableContent()
        
        if appArguments.constructionKit.present {
            ConstructionKitView(observedDialogContent: observedData).showConstructionKit()
            observedData.args.movableWindow.present = true
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
                    window?.isMovable = observedData.args.movableWindow.present

                    if observedData.args.forceOnTop.present {
                        window?.level = .floating
                    } else {
                        window?.level = .normal
                    }

                    if observedData.args.blurScreen.present && !appArguments.fullScreenWindow.present { //blur background
                        background.showWindow(self)
                        for i in 0..<NSApp.windows.count {
                            if NSApp.windows[i].identifier != NSUserInterfaceItemIdentifier("blur") {
                                NSApp.windows[i].level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
                            }
                        }
                    } else {
                        background.close()
                    }
                    
                    if observedData.args.forceOnTop.present || observedData.args.blurScreen.present {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    
                }
                .frame(width: 0, height: 0) //ensures hostingwindowfinder isn't taking up any real estate
                
                if appArguments.miniMode.present {
                    MiniView(observedContent: observedData)
                        .frame(width: observedData.windowWidth, height: observedData.windowHeight)
                        .background(WindowAccessor { newWindow in
                                if let newWindow = newWindow {
                                    monitorVisibility(window: newWindow)

                                } else {
                                    // window closed: release all references
                                    self.window = nil
                                    self.cancellables.removeAll()
                                }
                            })
                } else {
                    ContentView(observedDialogContent: observedData)
                        .frame(width: observedData.windowWidth, height: observedData.windowHeight) // + appvars.bannerHeight)
                        .sheet(isPresented: $observedData.showSheet, content: {
                            ErrorView(observedContent: observedData)
                        })
                        .background(WindowAccessor { newWindow in
                                if let newWindow = newWindow {
                                    monitorVisibility(window: newWindow)

                                } else {
                                    // window closed: release all references
                                    self.window = nil
                                    self.cancellables.removeAll()
                                }
                            })
                }

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


