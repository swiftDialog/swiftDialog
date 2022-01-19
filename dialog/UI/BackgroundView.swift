//
//  BGView.swift
//  file watch test
//
//  Created by Bart Reardon on 19/1/2022.
//

import Foundation
import SwiftUI

class Background: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()

        if let backgroundWindow = self.window {
            let mainDisplayRect = NSScreen.main?.frame
            backgroundWindow.contentRect(forFrameRect: mainDisplayRect!)
            backgroundWindow.setFrame((NSScreen.main?.frame)!, display: true)
            backgroundWindow.setFrameOrigin((NSScreen.main?.frame.origin)!)
            backgroundWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow) - 1 ))
        }
    }

    func sendBack() {
        self.window?.orderBack(self)
        print("going back")
    }
    
}
