//
//  backgroundBlur.swift
//
//  Created by Bart Reardon on 23/2/2022.
//

import Foundation
import Cocoa

var allScreens = NSScreen()

class BlurWindow: NSWindow {

    private var blurredWindows = [BlurWindowController()]

    public func show() {
        writeLog("initiating blurred window")
        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            blurredWindows.append(BlurWindowController())
            allScreens = screen
            blurredWindows[index].close()
            blurredWindows[index].loadWindow()
            blurredWindows[index].showWindow(NSApp.windows.first)
        }
        NSApp.windows.first?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow) + 1))
    }

    public func hide() {
        writeLog("removing blurred window")
        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            blurredWindows[index].close()
        }
    }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.fullSizeContentView],  backing: .buffered, defer: true)
     }
}

class BlurWindowController: NSWindowController {

    convenience init() {
        self.init(windowNibName: "BlurScreen")
    }

    override func loadWindow() {
        window = BlurWindow(contentRect: CGRect(x: 0, y: 0, width: 100, height: 100), styleMask: [], backing: .buffered, defer: true)
        self.window?.contentViewController = BlurViewController()
        self.window?.setFrame((allScreens.frame), display: true)
        self.window?.collectionBehavior = [.canJoinAllSpaces]
        if appArguments.loginWindow.present {
            self.window?.canBecomeVisibleWithoutLogin = true
        }
    }
}

class BlurViewController: NSViewController {

    init() {
         super.init(nibName: nil, bundle: nil)
     }

    required init?(coder: NSCoder) {
         fatalError()
     }

    override func loadView() {
        super.viewDidLoad()
        self.view = NSView()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.isOpaque = false
        view.window?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow) - 1 ))

        let blurView = NSVisualEffectView(frame: view.bounds)
        blurView.blendingMode = .behindWindow
        blurView.material = .fullScreenUI
        blurView.state = .active
        view.window?.contentView?.addSubview(blurView)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        view.window?.contentView?.removeFromSuperview()
    }

}
