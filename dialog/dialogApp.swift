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
    var body: some Scene {
              
        WindowGroup {
            ContentView()
                .frame(width: AppVariables.windowWidth, height: AppVariables.windowHeight)
        }
        // Hide Title Bar
        .windowStyle(HiddenTitleBarWindowStyle())
        //.windowStyle(TitleBarWindowStyle())
    }
}





