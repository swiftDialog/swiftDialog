//
//  BGView.swift
//  file watch test
//
//  Created by Bart Reardon on 19/1/2022.
//
/// This code is taken from depNotify
/// Particularly https://gitlab.com/Mactroll/DEPNotify/-/blob/master/DEPNotify/Background.swift
/// https://gitlab.com/Mactroll/DEPNotify/-/blob/master/LICENSE
///
/// MIT License

/// Copyright (c) 2017 Joel Rennich
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.

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
