//
//  String+NilIfEmpty.swift
//  dialog
//
//  An empty string read as absent, so an empty config value falls through like a missing one.
//

import SwiftUI

/// "Empty means unset", for every preset root: Presets 1–4 read `highlightColor` through it and fall
/// back to the system accent.
extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
