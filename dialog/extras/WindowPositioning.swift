// Free to use
// Written by Alexis Bridoux - https://github.com/ABridoux

// from https://gist.github.com/ABridoux/b935c21c7ead92033d39b357fae6366b

import AppKit
import Combine

#if canImport(SwiftUI)
import SwiftUI
#endif


// MARK: Model
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

// MARK: Logic
extension NSWindow.Position {

    func value(forWindow windowRect: CGRect, inScreen screenRect: CGRect) -> CGPoint {
        let xPosition = horizontal.valueFor(
            screenRange: screenRect.minX..<screenRect.maxX,
            width: windowRect.width,
            padding: padding
        )

        let yPosition = vertical.valueFor(
            screenRange: screenRect.minY..<screenRect.maxY,
            height: windowRect.height,
            padding: padding
        )

        return CGPoint(x: xPosition, y: yPosition)
    }
}

extension NSWindow.Position.Horizontal {

    func valueFor(
        screenRange: Range<CGFloat>,
        width: CGFloat,
        padding: CGFloat)
    -> CGFloat {
        switch self {
        case .left: return screenRange.lowerBound + padding
        case .center: return (screenRange.upperBound + screenRange.lowerBound - width) / 2
        case .right: return screenRange.upperBound - width - padding
        }
    }
}

extension NSWindow.Position.Vertical {

    func valueFor(
        screenRange: Range<CGFloat>,
        height: CGFloat,
        padding: CGFloat)
    -> CGFloat {
        switch self {
        case .top: return screenRange.upperBound - height - padding
        case .center:
            let screenheight = screenRange.upperBound - screenRange.lowerBound
            return ((screenRange.upperBound + screenRange.lowerBound - height) / 2) + (screenheight*0.15)
        case .deadcenter: return (screenRange.upperBound + screenRange.lowerBound - height) / 2
        case .bottom: return screenRange.lowerBound + padding
        }
    }
}

// MARK: - AppKit extension
extension NSWindow {
    
    func setPosition(_ position: Position, in screen: NSScreen?) {
        guard let visibleFrame = (screen ?? self.screen)?.visibleFrame else { return }
        let origin = position.value(forWindow: frame, inScreen: visibleFrame)
        setFrameOrigin(origin)
    }

    func setPosition(
        vertical: Position.Vertical,
        horizontal: Position.Horizontal,
        padding: CGFloat = Position.defaultPadding,
        screen: NSScreen? = nil)
    {
        setPosition(
            Position(vertical: vertical, horizontal: horizontal, padding: padding),
            in: screen
        )
    }
}

// MARK: - SwiftUI modifier
#if canImport(SwiftUI)

/// - note: Idea from [LostMoa](https://lostmoa.com/blog/ReadingTheCurrentWindowInANewSwiftUILifecycleApp/)
struct HostingWindowFinder: NSViewRepresentable {
    var callback: (NSWindow?) -> ()

    func makeNSView(context: Self.Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.callback(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { self.callback(nsView.window) }
    }
}

private struct WindowPositionModifier: ViewModifier {

    let position: NSWindow.Position
    let screen: NSScreen?

    func body(content: Content) -> some View {
        content.background(
            HostingWindowFinder {
                $0?.setPosition(position, in: screen)
            }
        )
    }
}

extension View {

    func hostingWindowPosition(
        vertical: NSWindow.Position.Vertical,
        horizontal: NSWindow.Position.Horizontal,
        padding: CGFloat = NSWindow.Position.defaultPadding,
        screen: NSScreen? = nil
    ) -> some View {
        modifier(
            WindowPositionModifier(
                position: NSWindow.Position(
                    vertical: vertical,
                    horizontal: horizontal,
                    padding: padding
                ),
                screen: screen
            )
        )
    }
}
#endif


struct WindowHandler {
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

func setWindowYPos(screenHeight: CGFloat, position: NSWindow.Position.Vertical) -> CGFloat {
    let padding : CGFloat = 16
    switch position {
    case .top: return screenHeight - padding
    case .center:
        //let screenheight = screenRange.upperBound - screenRange.lowerBound
        return (screenHeight / 2) + (screenHeight * 0.15)
    case .deadcenter: return screenHeight / 2
    case .bottom: return padding
    }
}

func setWindowXPos(screenWidth: CGFloat, position: NSWindow.Position.Horizontal) -> CGFloat {
    let padding : CGFloat = 16
    switch position {
    case .left: return padding
    case .center: return screenWidth / 2
    case .right: return screenWidth - padding
    }
}
