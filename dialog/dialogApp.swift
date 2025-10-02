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

    var monitor: PIDMonitor?

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

        // Check for calling app pid
        if appArguments.callingPid.present {
            monitor = PIDMonitor(pid: Int32(appArguments.callingPid.value) ?? 0) {
                quitDialog(exitCode: 40, exitMessage: "dialog quit becasue calling process was terminated")
            }
            writeLog("Monitoring for calling pid \(appArguments.callingPid.value)", logLevel: .debug)
        }

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

            // Set initial window level
            if appArguments.forceOnTop.present {
                window.level = .floating  // Start with floating, will be elevated after positioning
                writeLog("Window initially set to floating level for force on top", logLevel: .debug)
            } else if appArguments.blurScreen.present {
                window.level = .floating
                writeLog("Window set to floating level for blur screen", logLevel: .debug)
            } else {
                window.level = .normal
            }

            // display a blur screen window on all screens.
            if appArguments.blurScreen.present && !appArguments.fullScreenWindow.present {
                writeLog("Blurscreen enabled", logLevel: .debug)
                blurredScreen.show()
            } else {
                background.close()
            }

            placeWindow(window, size: CGSize(width: appvars.windowWidth,
                                             height: appvars.windowHeight),
                        vertical: appvars.windowPositionVertical,
                        horozontal: appvars.windowPositionHorozontal,
                        offset: appvars.windowPositionOffset,
                        useFullScreen: appArguments.blurScreen.present || appArguments.forceOnTop.present)

            // order to the front
            window.makeKeyAndOrderFront(self)

            // Force on top configuration - apply after window is positioned and visible
            if appArguments.forceOnTop.present {
                DispatchQueue.main.async {
                    // Set the highest possible window level
                    let maxLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow) + 1))
                    window.level = maxLevel

                    // Ensure window collection behavior allows it to appear on all spaces
                    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

                    // Force the window to order front again with new level
                    window.orderFront(nil)

                    writeLog("Window level elevated to maximum: \(maxLevel.rawValue)", logLevel: .debug)
                    writeLog("Window collection behavior set for force on top", logLevel: .debug)
                }
            }

            if appArguments.forceOnTop.present || appArguments.blurScreen.present {
                writeLog("Activating window", logLevel: .debug)
                activateDialog()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
            return true
        }
}

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
        observedData = DialogUpdatableContent.shared

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
            activateDialog()
            writeLog("Activated", logLevel: .debug)
        }
    }

    var body: some Scene {

        WindowGroup {
            if !appArguments.notification.present && !appvars.noargs {
                let _ = appvars.debugMode ? print("DEBUG: Checking modes - mini:\(appArguments.miniMode.present) inspect:\(appArguments.inspectMode.present) presentation:\(appArguments.presentationMode.present)") : ()
                ZStack {
                    if appArguments.miniMode.present {
                        let _ = appvars.debugMode ? print("DEBUG: Loading MiniView") : ()
                        MiniView(observedDialogContent: observedData)
                            .frame(width: observedData.appProperties.windowWidth, height: observedData.appProperties.windowHeight)
                    } else if appArguments.inspectMode.present {
                        // Wrap InspectView to delay its initialization
                        let _ = appvars.debugMode ? print("DEBUG: Loading InspectView") : ()
                        InspectView()
                            .frame(width: observedData.appProperties.windowWidth,
                                  height: observedData.appProperties.windowHeight)
                    } else if appArguments.presentationMode.present {
                        let _ = appvars.debugMode ? print("DEBUG: Loading PresentationView") : ()
                        PresentationView(observedData: observedData)
                            .frame(width: observedData.appProperties.windowWidth, height: observedData.appProperties.windowHeight)
                    } else {
                        let _ = appvars.debugMode ? print("DEBUG: Loading default ContentView") : ()
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
                .onDisappear {
                    quitDialog(exitCode: appDefaults.exit15.code)
                }
                .preferredColorScheme(observedData.args.preferredAppearance.present &&
                                      observedData.args.preferredAppearance.value.lowercased() == "dark" ? .dark
                                      : observedData.args.preferredAppearance.present &&
                                      observedData.args.preferredAppearance.value.lowercased() == "light" ? .light
                                      : nil)
            }
        }
        // Hide Title Bar
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }


}
