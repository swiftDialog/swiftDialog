//
//  WindowPositioning.swift
//  dialog
//
//  Created by Bart Reardon on 26/9/2022.
//
// logic updated from https://stackoverflow.com/questions/70091919/how-set-position-of-window-on-the-desktop-in-swiftui

import AppKit
import Combine
import SwiftUI

extension NSWindow {

    struct Position {

        static let defaultPadding: CGFloat = 16

        var vertical: Vertical
        var horizontal: Horizontal
        var padding = Self.defaultPadding
    }
}

extension NSWindow.Position {

    enum Horizontal {
        case left, center, right
    }

    enum Vertical {
        case top, center, deadcenter, bottom
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onChange: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitorView(view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
    }

    func makeCoordinator() -> WindowMonitor {
        WindowMonitor(onChange)
    }

    class WindowMonitor: NSObject {
        private var cancellables = Set<AnyCancellable>()
        private var onChange: (NSWindow?) -> Void

        init(_ onChange: @escaping (NSWindow?) -> Void) {
            self.onChange = onChange
        }

        /// This function uses KVO to observe the `window` property of `view` and calls `onChange()`
        func monitorView(_ view: NSView) {
            view.publisher(for: \.window)
                .removeDuplicates()
                .dropFirst()
                .sink { [weak self] newWindow in
                    guard let self = self else { return }
                    self.onChange(newWindow)
                    if let newWindow = newWindow {
                        self.monitorClosing(of: newWindow)
                    }
                }
                .store(in: &cancellables)
        }

        /// This function uses notifications to track closing of `window`
        private func monitorClosing(of window: NSWindow) {
            NotificationCenter.default
                .publisher(for: NSWindow.willCloseNotification, object: window)
                .sink { [weak self] notification in
                    guard let self = self else { return }
                    self.onChange(nil)
                    self.cancellables.removeAll()
                }
                .store(in: &cancellables)
        }
    }
}

func calculateWindowYPos(screenHeight: CGFloat, position: NSWindow.Position.Vertical) -> CGFloat {
    let padding : CGFloat = 16
    switch position {
    case .top: return screenHeight - padding
    case .center:
        return (screenHeight / 2) + (screenHeight * 0.15)
    case .deadcenter: return screenHeight / 2
    case .bottom: return padding
    }
}

func calculateWindowXPos(screenWidth: CGFloat, position: NSWindow.Position.Horizontal) -> CGFloat {
    let padding : CGFloat = 16
    switch position {
    case .left: return padding
    case .center: return screenWidth / 2
    case .right: return screenWidth - padding
    }
}


func placeWindow(_ window: NSWindow, size : CGSize? = nil) {
    let main = NSScreen.main!
    let visibleFrame = main.visibleFrame
    var windowSize : CGSize
    if size == nil {
        windowSize = window.frame.size
    } else {
        windowSize = size ?? window.frame.size
    }
    
    let windowX = calculateWindowXPos(screenWidth: visibleFrame.width - windowSize.width, position: appvars.windowPositionHorozontal)
    let windowY = calculateWindowYPos(screenHeight: visibleFrame.height - windowSize.height, position: appvars.windowPositionVertical)
    
    let desiredOrigin = CGPoint(x: visibleFrame.origin.x + windowX, y: visibleFrame.origin.y + windowY)
    window.setContentSize(windowSize)
    window.setFrameOrigin(desiredOrigin)
}
 
