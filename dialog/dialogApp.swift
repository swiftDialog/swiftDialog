//
//  dialogApp.swift
//  dialog
//
//  Created by Bart Reardon on 9/3/21.
//

import SwiftUI
import Combine
import UserNotifications

import SystemConfiguration

var background = BlurWindowController()

// AppDelegate and extension used for notifications
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                didReceive response: UNNotificationResponse,
                withCompletionHandler completionHandler:
                                @escaping () -> Void) {

        writeLog("reading notification", logLevel: .debug)

        if response.notification.request.content.categoryIdentifier == "SD_NOTIFICATION" {
            appvars.isProcessingNotification = true
            processNotification(response: response)
        } else {
            writeLog("unknown notification type", logLevel: .debug)
        }

        // call the completion handler when done.
        completionHandler()
        // quit dialog since we dont need to show anything
        if appvars.isProcessingNotification {
            //quitDialog(exitCode: appDefaults.exitNow.code)
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self

    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        //var blurredScreen = [BlurWindowController]()

        if let window = NSApplication.shared.windows.first {
            window.standardWindowButton(.closeButton)?.isHidden = !appArguments.windowButtonsEnabled.present
            window.standardWindowButton(.miniaturizeButton)?.isHidden = !appArguments.windowButtonsEnabled.present
            window.standardWindowButton(.zoomButton)?.isHidden = !appArguments.windowButtonsEnabled.present
            window.standardWindowButton(.closeButton)?.isEnabled = appvars.windowCloseEnabled
            window.standardWindowButton(.miniaturizeButton)?.isEnabled = appvars.windowMinimiseEnabled
            window.standardWindowButton(.zoomButton)?.isEnabled = appvars.windowMaximiseEnabled
            window.title = appArguments.titleOption.value
            window.isMovable = appArguments.movableWindow.present
            window.isMovableByWindowBackground = true
            if appArguments.showOnAllScreens.present {
                window.collectionBehavior = [.canJoinAllSpaces]
            }
            if appArguments.loginWindow.present {
                window.canBecomeVisibleWithoutLogin = true
                writeLog("Window can appear at the loginwindow", logLevel: .debug)
                while CGSessionCopyCurrentDictionary() == nil {
                    // Wait until the session is available before continuing
                    // appropriated from munkistatus
                    // https://github.com/munki/munki/blob/main/code/apps/MunkiStatus/MunkiStatus/main.swift
                    writeLog("Waiting for a CGSession...", logLevel: .debug)
                    usleep(500000)
                }
                writeLog("CGSession found. Continuing", logLevel: .debug)
            }

            // Set window level
            if appArguments.forceOnTop.present || appArguments.blurScreen.present {
                window.level = .floating
                writeLog("Window is forced on top", logLevel: .debug)
            } else {
                window.level = .normal
            }

            // display a blur screen window on all screens.
            if appArguments.blurScreen.present && !appArguments.fullScreenWindow.present {
                writeLog("Blurscreen enabled", logLevel: .debug)
                blurredScreen.show()
                //window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow) + 1))
            } else if appArguments.forceOnTop.present {
                window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow) + 1))
            } else {
                background.close()
            }

            placeWindow(window, size: window.frame.size,
                        vertical: appvars.windowPositionVertical,
                horozontal: appvars.windowPositionHorozontal,
                        offset: appvars.windowPositionOffset)

            // order to the front
            window.makeKeyAndOrderFront(self)

            if appArguments.forceOnTop.present || appArguments.blurScreen.present {
                writeLog("Activating window", logLevel: .debug)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
            return true
        }
}

@available(OSX 12.0, *)
@main
struct dialogApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @ObservedObject var observedData: DialogUpdatableContent

    init () {

        appvars.debugMode = CLOptionPresent(optionName: appArguments.debug)

        if CommandLine.arguments.count > 1 {
            appvars.isProcessingNotification = false
        } else {
            appvars.noargs = true
        }

        writeLog("Dialog Launched", logLevel: .info)

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

        if !(appArguments.setAppIcon.present ||
            appArguments.getVersion.present ||
            appArguments.buyCoffee.present ||
            appArguments.helpOption.present ||
            appArguments.licence.present) {
            checkNotificationAuthorisation(notificationPresent: appArguments.notification.present)
        }

        captureQuitKey(keyValue: appArguments.quitKey.value)

        // check if we are sending a notification
        if checkForDialogNotificationMode(appArguments) {
            writeLog("Notification sent")
            quitDialog(exitCode: 0)
        }

        // check for jamfhelper mode
        if appArguments.jamfHelperMode.present {
            writeLog("converting jh to dialog")
            convertFromJamfHelperSyntax()
        }

        // process remaining command line options
        processCLOptions()

        appvars.overlayShadow = 1

        appvars.titleHeight *= appvars.scaleFactor
        appvars.windowWidth *= appvars.scaleFactor
        appvars.windowHeight *= appvars.scaleFactor
        appvars.iconWidth *= appvars.scaleFactor
        appvars.iconHeight *= appvars.scaleFactor

        if appArguments.miniMode.present {
            appvars.windowWidth = 540
            appvars.windowHeight = 128
        }

        //check debug mode and print info
        if appArguments.debug.present {
            writeLog("debug options presented. dialog state sent to stderr", logLevel: .debug)
            appvars.debugMode = true
            appvars.debugBorderColour = appArguments.debug.value != "" ? Color(argument: appArguments.debug.value) : Color.clear

            writeLog("Window Height = \(appvars.windowHeight): Window Width = \(appvars.windowWidth)", logLevel: .debug)
        }

        // Create main dialog state object
        observedData = DialogUpdatableContent()

        if appArguments.fullScreenWindow.present {
            FullscreenView(observedData: observedData).showFullScreen()
        }


        if appvars.noargs {
            let timer = BackgroundTimer()
            timer.startTimer(duration: 3.0) {
                writeLog("No arguments. Quitting", logLevel: .debug)
                quitDialog(exitCode: 0)
            }
        } else {
            // bring to front on launch
            writeLog("Activating", logLevel: .debug)
            NSApp.activate(ignoringOtherApps: true)
            writeLog("Activated", logLevel: .debug)
        }
    }

    var body: some Scene {

        WindowGroup {
            if !appArguments.notification.present && !appvars.noargs {
                ZStack {
                    if appArguments.miniMode.present {
                        MiniView(observedDialogContent: observedData)
                            .frame(width: observedData.appProperties.windowWidth, height: observedData.appProperties.windowHeight)
                    } else if appArguments.presentationMode.present {
                        PresentationView(observedData: observedData)
                            .frame(width: observedData.appProperties.windowWidth, height: observedData.appProperties.windowHeight)
                    } else {
                        if appArguments.windowResizable.present {
                            ContentView(observedDialogContent: observedData)
                        } else {
                            ContentView(observedDialogContent: observedData)
                                .frame(width: observedData.appProperties.windowWidth, height: observedData.appProperties.windowHeight)
                        }
                    }
                    DebugOverlay(observedData: observedData)
                }
                .onAppear {
                    // Only show the construction kit once, if needed.
                    if appArguments.constructionKit.present && !observedData.constructionKitShown {
                        observedData.constructionKitShown = true
                        DispatchQueue.main.async {
                            ConstructionKitView(observedDialogContent: observedData).showConstructionKit()
                            appArguments.movableWindow.present = true
                        }
                    }
                }
                .preferredColorScheme(observedData.args.preferredAppearance.present &&
                                      observedData.args.preferredAppearance.value.lowercased() == "dark" ? .dark
                                      : observedData.args.preferredAppearance.present &&
                                      observedData.args.preferredAppearance.value.lowercased() == "light" ? .light
                                      : nil)
            }
        }
        // Hide Title Bar
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizabilityContentSize()
    }


}


