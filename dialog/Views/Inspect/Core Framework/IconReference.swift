//
//  IconReference.swift
//  dialog
//
//  How an authored icon string is read. Policy A: a bare name is a symbol (symbol-only fields).
//  Policy B: only `SF=` (case-insensitive) is a symbol (fields that may hold an image path).
//

import Foundation

/// How an authored icon string resolves to an SF Symbol or a file.
enum IconRef {

    /// Image extensions that make a string a file. A dot alone does not: `gear.badge` is a symbol.
    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "pdf", "tiff", "tif", "heic", "icns", "svg", "webp", "bmp"
    ]

    /// The `computer` keyword (case-insensitive): this Mac's own hardware icon, as `--icon computer`.
    /// Checked before symbol and file matching, so it never reaches `Image(systemName:)`.
    static func isComputer(_ raw: String) -> Bool {
        raw.lowercased() == "computer"
    }

    /// The explicit prefix, matched case-insensitively (`SF=`, `sf=`, `Sf=`).
    static func isSymbolReference(_ raw: String) -> Bool {
        raw.lowercased().hasPrefix("sf=")
    }

    /// Policy B, the strict reading: a symbol only when prefixed; anything else is a file.
    /// Use wherever the same field may also hold an image path.
    ///
    ///     symbol("SF=globe")  -> "globe"
    ///     symbol("globe")     -> nil        (a file named "globe")
    ///     symbol("SF=")       -> nil        (prefix with no name is not a symbol)
    static func symbol(_ raw: String) -> String? {
        guard isSymbolReference(raw) else { return nil }
        let name = String(raw.dropFirst(3))
        return name.isEmpty ? nil : name
    }

    /// Policy A, the lenient reading: the prefix if present, otherwise the bare string unless
    /// it looks like a file. Use where the field only ever holds symbols.
    ///
    ///     symbolOrBareName("SF=globe")   -> "globe"
    ///     symbolOrBareName("globe")      -> "globe"
    ///     symbolOrBareName("logo.png")   -> nil
    static func symbolOrBareName(_ raw: String) -> String? {
        if let explicit = symbol(raw) { return explicit }
        if isSymbolReference(raw) { return nil }   // "SF=" with no name
        if raw.isEmpty || isFilePath(raw) { return nil }
        return raw
    }

    /// Does this name a file? Rooted, a URL, or carrying a known image extension.
    static func isFilePath(_ raw: String) -> Bool {
        if isSymbolReference(raw) { return false }
        if raw.hasPrefix("/") || raw.hasPrefix("~") { return true }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") { return true }
        let ext = (raw as NSString).pathExtension.lowercased()
        return !ext.isEmpty && imageExtensions.contains(ext)
    }
}

// Generated sources (`tile:`, `gradient:`) live in GeneratedImageView.swift: they need SwiftUI's
// `Color`, and this file stays Foundation-only.
