//
//  View+Additions.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation
import SwiftUI

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
    func symbolAnimation(effect: String) -> some View {
        if #available(macOS 14, *) {
            switch effect {
            case "variable":
                return AnyView(symbolEffect(.variableColor, isActive: true))
            case "variable.reversing":
                return AnyView(symbolEffect(.variableColor.reversing, isActive: true))
            case "variable.iterative":
                return AnyView(symbolEffect(.variableColor.iterative, isActive: true))
            case "variable.iterative.reversing":
                return AnyView(symbolEffect(.variableColor.iterative.reversing, isActive: true))
            case "variable.cumulative":
                return AnyView(symbolEffect(.variableColor.cumulative, isActive: true))
            case "pulse":
                return AnyView(symbolEffect(.pulse.wholeSymbol, isActive: true))
            case "pulse.bylayer":
                return AnyView(symbolEffect(.pulse.byLayer, isActive: true))
            default:
                return AnyView(self)
            }
        } else {
            return AnyView(self)
        }
    }
}

extension View {
    func hideRowSeperator() -> some View {
        if #available(macOS 13, *) {
            return listRowSeparator(.hidden)
        } else {
            return self
        }
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
      if enclosingScrollView != nil {
          enclosingScrollView!.drawsBackground = false
      }
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

/// The shake-highlight border drawn around a required input field when the user
/// tries to submit without completing it. `trigger` is the value whose change drives
/// the shake animation (the dialog's `showSheet` flag at the call sites).
struct RequiredFieldHighlight: ViewModifier {
    let highlight: Color
    let trigger: Bool

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(highlight, lineWidth: 2)
                .animation(.easeIn(duration: 0.2).repeatCount(3, autoreverses: true), value: trigger)
        )
    }
}

extension View {
    func requiredFieldHighlight(_ highlight: Color, trigger: Bool) -> some View {
        modifier(RequiredFieldHighlight(highlight: highlight, trigger: trigger))
    }
}

enum glassType {
    case clear
    case regular
}

extension View {
    func useClearGlassEffect(_ type: glassType = .regular) -> some View {
        if #available(macOS 26.0, *) {
            return type == .clear ? glassEffect(.clear) : glassEffect(.regular)
        } else {
            return self
        }
    }
}

/// A binding to one field of `array[index]` that survives the array shrinking underneath it.
///
/// SwiftUI keeps a value action — the closure behind `.onChange(of:)` — alive independently of the
/// body that created it, and flushes it from `Update.dispatchActions()` during a later layout pass.
/// A binding written as `$array[index].field` captures `index` and reads the array at that point, so
/// in workflow mode a card change that empties the array between the action being queued and it
/// being dispatched traps on `Array.subscript`. Reading a fallback and dropping the write is correct
/// here: the value belongs to a card that is no longer on screen, and its input has already been
/// stored by `storeCurrentCardInput`.
func boundedBinding<Element, Field>(
    _ array: Binding<[Element]>,
    _ index: Int,
    _ field: WritableKeyPath<Element, Field>,
    default fallback: Field
) -> Binding<Field> {
    Binding<Field>(
        get: {
            guard array.wrappedValue.indices.contains(index) else { return fallback }
            return array.wrappedValue[index][keyPath: field]
        },
        set: { newValue in
            guard array.wrappedValue.indices.contains(index) else { return }
            array.wrappedValue[index][keyPath: field] = newValue
        }
    )
}

/// Assign into `array[index]` only while that index still exists.
///
/// The counterpart to `boundedBinding` for the plain writes inside those same action closures, which
/// reach past the observed copy straight into `userInputState`.
func setIfInBounds<Element, Field>(
    _ array: inout [Element],
    _ index: Int,
    _ field: WritableKeyPath<Element, Field>,
    _ newValue: Field
) {
    guard array.indices.contains(index) else { return }
    array[index][keyPath: field] = newValue
}
