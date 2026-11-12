//
//  InspectAppearance.swift
//  Dialog
//
//  The one owner of the inspect window's forced appearance. SwiftUI's .preferredColorScheme
//  does not flip the hosting NSWindow, so the config key and the IPC arm both go through this.
//

import AppKit

enum InspectAppearance {

    /// "dark" / "light" (case-insensitive) force the appearance; nil or
    /// anything else follows the system.
    @MainActor
    static func apply(_ value: String?) {
        switch value?.lowercased() {
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        default: NSApp.appearance = nil  // follow the system
        }
    }
}
