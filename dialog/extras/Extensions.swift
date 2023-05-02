//
//  Extensions.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/5/2023.
//

import Foundation
import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

extension Color {
    static let background = Color(NSColor.windowBackgroundColor)
    static let secondaryBackground = Color(NSColor.underPageBackgroundColor)
    static let tertiaryBackground = Color(NSColor.controlBackgroundColor)
}

extension NSTextView {
    open override var frame: CGRect {
        didSet {
            backgroundColor = .clear
            drawsBackground = true
        }

    }
}

extension NSTableView {
  open override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    backgroundColor = NSColor.clear
    enclosingScrollView!.drawsBackground = false
  }
}

extension Scene {
    // Solution for maintaining fixed window size in macOS 13 https://developer.apple.com/forums/thread/719389
    func windowResizabilityContentSize() -> some Scene {
        if #available(macOS 13.0, *) {
            return windowResizability(.contentSize)
        } else {
            return self
        }
    }
}

extension String {
    var boolValue: Bool {
        return (self as NSString).boolValue
    }
}

extension String {
    var localized: String {
      return NSLocalizedString(self, comment: "\(self)_comment")
    }

    func localized(_ args: CVarArg...) -> String {
        return String(format: localized, arguments: args)
    }
}

extension String {
    func split(usingRegex pattern: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: self, range: NSRange(startIndex..., in: self))
        let splits = [startIndex]
            + matches
                .map { Range($0.range, in: self)! }
                .flatMap { [ $0.lowerBound, $0.upperBound ] }
            + [endIndex]

        return zip(splits, splits.dropFirst())
            .map { String(self[$0 ..< $1])}
    }
}

extension StringProtocol {
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
}
