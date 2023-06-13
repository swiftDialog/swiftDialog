//
//  Extensions.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/5/2023.
//

import Foundation
import SwiftUI
import MarkdownUI

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
    
    static let code = Color(
        light: Color(rgba: 0xdc1c_50ff), dark: Color(rgba: 0xdb58_7bff)
    )
    static let text = Color(
        light: Color(rgba: 0x0606_06ff), dark: Color(rgba: 0xfbfb_fcff)
    )
    static let secondaryText = Color(
        light: Color(rgba: 0x6b6e_7bff), dark: Color(rgba: 0x9294_a0ff)
    )
    static let tertiaryText = Color(
        light: Color(rgba: 0x6b6e_7bff), dark: Color(rgba: 0x6d70_7dff)
    )
    static let link = Color(
        light: Color(rgba: 0x2c65_cfff), dark: Color(rgba: 0x4c8e_f8ff)
    )
    static let border = Color(
        light: Color(rgba: 0xe4e4_e8ff), dark: Color(rgba: 0x4244_4eff)
    )
    static let divider = Color(
        light: Color(rgba: 0xd0d0_d3ff), dark: Color(rgba: 0x3334_38ff)
    )
    static let checkbox = Color(rgba: 0xb9b9_bbff)
    static let checkboxBackground = Color(rgba: 0xeeee_efff)
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

// For scroll when needed

struct OverflowContentViewModifier: ViewModifier {
    @State private var contentOverflow: Bool = false
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
            .background(
                GeometryReader { contentGeometry in
                    Color.clear.onAppear {
                        contentOverflow = contentGeometry.size.height > geometry.size.height
                    }
                }
            )
            .wrappedInScrollView(when: contentOverflow)
        }
    }
}

extension View {
    @ViewBuilder
    func wrappedInScrollView(when condition: Bool) -> some View {
        if condition {
            ScrollView {
                self
            }
        } else {
            self
        }
    }
}

extension View {
    func scrollOnOverflow() -> some View {
        modifier(OverflowContentViewModifier())
    }
}

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension Theme {
  static let sdMarkdown = Theme()
    .code {
      FontFamilyVariant(.monospaced)
      FontSize(.em(0.85))
        ForegroundColor(.code)
        BackgroundColor(.background)
    }
    .blockquote { configuration in
      HStack(spacing: 0) {
        RoundedRectangle(cornerRadius: 6)
              .fill(Color.border)
          .relativeFrame(width: .em(0.2))
        configuration.label
              .markdownTextStyle { ForegroundColor(.secondary) }
          .relativePadding(.horizontal, length: .em(1))
      }
      .fixedSize(horizontal: false, vertical: true)
    }
    .codeBlock { configuration in
      ScrollView(.horizontal) {
        configuration.label
          .relativeLineSpacing(.em(0.225))
          .markdownTextStyle {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
          }
          .padding(16)
      }
      .background(Color.secondaryBackground)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .markdownMargin(top: 0, bottom: 16)
    }
    .link {
        ForegroundColor(.link)
    }
    .codeBlock { configuration in
        ScrollView(.horizontal) {
            configuration.label
                .relativeLineSpacing(.em(0.225))
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(0.85))
                }
                .padding(16)
        }
        .background(Color.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .markdownMargin(top: 0, bottom: 16)
    }
}

