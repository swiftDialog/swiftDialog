//
//  WindowAnchoring.swift
//  dialog
//
//  Moves the live window to a declared `windowPosition`; shared by the presets that anchor
//  per step, per item or at launch.
//

import SwiftUI

/// Repositions the window when `position` is set and restores it to center when absent, but only
/// if a previous call moved it (`didMoveWindow`) so a window the user dragged is left alone.
/// Returns the new `didMoveWindow` state for the caller to keep.
@discardableResult
@MainActor
func applyWindowAnchor(position: String?, offset: Double?, didMoveWindow: Bool,
                       label: String, stepId: String? = nil, animated: Bool = true) -> Bool {
    guard let window = NSApp.windows.first else { return didMoveWindow }
    if let pos = position, !pos.isEmpty {
        var (vertical, horozontal) = windowPosition(pos.lowercased())
        // Side positions resolve to a biased-up `.center`; use true center and a default edge margin.
        if case .center = vertical { vertical = .deadcenter }
        placeWindow(window, size: nil, vertical: vertical, horozontal: horozontal,
                    offset: CGFloat(offset ?? 48), animated: animated)
        if let stepId {
            writeLog("\(label): step '\(stepId)' repositioned window to '\(pos)'", logLevel: .info)
        } else {
            writeLog("\(label): anchored window at '\(pos)'", logLevel: .info)
        }
        return true
    } else if didMoveWindow {
        let (vertical, horozontal) = windowPosition("center")
        placeWindow(window, size: nil, vertical: vertical, horozontal: horozontal,
                    offset: 0, animated: animated)
        writeLog("\(label): restored window to center", logLevel: .info)
        return false
    }
    return didMoveWindow
}
