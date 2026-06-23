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

    public func show(image: NSImage? = nil) {
        writeLog("initiating blurred window")
        for controller in blurredWindows {
            controller.close()
        }
        blurredWindows.removeAll()
        let screens = NSScreen.screens
        for screen in screens {
            let controller = BlurWindowController(image: image)
            blurredWindows.append(controller)
            allScreens = screen
            controller.loadWindow()
            controller.showWindow(NSApp.windows.first)
        }
        NSApp.windows.first?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow) + 1))
    }

    public func hide() {
        writeLog("removing blurred window")
        let screens = NSScreen.screens
        for (index, _) in screens.enumerated() {
            blurredWindows[index].close()
        }
    }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.fullSizeContentView],  backing: .buffered, defer: true)
     }
}

class BlurWindowController: NSWindowController {

    private var image: NSImage?

    convenience init(image: NSImage? = nil) {
        self.init(windowNibName: "BlurScreen")
        self.image = image
    }

    override func loadWindow() {
        window = BlurWindow(contentRect: CGRect(x: 0, y: 0, width: 100, height: 100), styleMask: [], backing: .buffered, defer: true)
        self.window?.contentViewController = BlurViewController(image: image)
        self.window?.setFrame((allScreens.frame), display: true)
        self.window?.collectionBehavior = [.canJoinAllSpaces]
        if appArguments.loginWindow.present {
            self.window?.canBecomeVisibleWithoutLogin = true
        }
    }
}

class BlurViewController: NSViewController {

    private var image: NSImage?

    init(image: NSImage? = nil) {
        self.image = image
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

        if let image = image {
            let imageView = NSImageView(frame: view.bounds)
            imageView.image = image
            imageView.imageScaling = .scaleAxesIndependently
            imageView.autoresizingMask = [.width, .height]
            view.window?.contentView?.addSubview(imageView)
        } else {
            let blurView = NSVisualEffectView(frame: view.bounds)
            blurView.blendingMode = .behindWindow
            blurView.material = .fullScreenUI
            blurView.state = .active
            view.window?.contentView?.addSubview(blurView)
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        view.window?.contentView?.removeFromSuperview()
    }

}
