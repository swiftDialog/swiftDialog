//
//  dialogApp.swift
//  dialog
//
//  Created by Bart Reardon on 9/3/21.
//

import SwiftUI


@available(OSX 11.0, *)
@main
struct dialogApp: App {
    var body: some Scene {
              
        WindowGroup {
            ContentView()
                .frame(maxWidth: AppVariables.windowWidth, maxHeight: AppVariables.windowHeight)
        }
        // Hide Title Bar
        .windowStyle(HiddenTitleBarWindowStyle())
        //.windowStyle(TitleBarWindowStyle())
        
    }

}



