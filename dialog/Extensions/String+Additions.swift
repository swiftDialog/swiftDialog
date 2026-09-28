//
//  String+Additions.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation
import CryptoKit
import SwiftUI

extension String {

    var sha256Hash: String {
        // Returns a sha256 hash of the given text
        let inputData = Data(self.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    var localized: String {
      return NSLocalizedString(self, comment: "\(self)_comment")
    }

    func localized(_ args: CVarArg...) -> String {
        return String(format: localized, arguments: args)
    }
}

extension String {
    func split(usingRegex pattern: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: self, range: NSRange(startIndex..., in: self))
            let splits = [startIndex]
            + matches
                .map { Range($0.range, in: self)! }
                .flatMap { [ $0.lowerBound, $0.upperBound ] }
            + [endIndex]

            return zip(splits, splits.dropFirst())
                .map { String(self[$0 ..< $1])}
        } catch {
            return [self]
        }
    }
}

extension String {
    private static let numberFormatter = NumberFormatter()
    var isNumeric: Bool {
        Self.numberFormatter.number(from: self) != nil
    }
}

extension StringProtocol {
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
}

extension String {
    var boolValue: Bool {
        return (self as NSString).boolValue
    }
}

extension String {
    func floatValue(defaultValue: CGFloat = 0) -> CGFloat {
        return CGFloat(truncating: Self.numberFormatter.number(from: self) ?? defaultValue as NSNumber)
    }
}

extension CGFloat {
    var stringValue: String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: self as NSNumber) ?? "0"
    }
}

extension String {
    var toSymbolRenderingMode: SymbolRenderingMode? {
        switch self.lowercased() {
        case "hierarchical":
            return .hierarchical
        case "monochrome":
            return .monochrome
        case "multicolor", "multicolour":
            return .multicolor
        case "palette":
            return .palette
        default:
            return nil
        }
    }
}

enum IconPosition {
    case leading
    case top
    case bottom
    case trailing
}

/// If `raw` (trimmed) is a JSON object, returns the equivalent legacy button-symbol string
/// (e.g. ["name":"gear","position":"trailing","colour":"red"] -> "gear,trailing,colour=red");
/// otherwise returns `raw` unchanged so the existing comma-separated form is untouched.
func normalizedButtonSymbol(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("{"),
          let data = trimmed.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return raw
    }
    return buttonSymbolLegacyString(fromJSONObject: object)
}

/// Converts a JSON button-symbol object into the legacy comma-separated string the button symbol
/// parser understands. `position`/`rendering` are emitted as bare keywords; `size`/`colour` as
/// key=value; `palette` as a dash-joined list (the parser splits button palettes on "-").
func buttonSymbolLegacyString(fromJSONObject object: [String: Any]) -> String {
    func value(_ keys: String...) -> String? {
        for (key, val) in object where keys.contains(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) {
            if val is [Any] { return nil }
            return "\(val)"
        }
        return nil
    }
    func array(_ key: String) -> [String]? {
        for (k, val) in object where k.caseInsensitiveCompare(key) == .orderedSame {
            if let a = val as? [Any] { return a.map { "\($0)" } }
        }
        return nil
    }

    var tokens: [String] = []
    if let name = value("name", "sf", "symbol") { tokens.append(name) }
    if let position = value("position") { tokens.append(position) }
    if let rendering = value("rendering", "renderingmode", "mode") { tokens.append(rendering) }
    if let size = value("size") { tokens.append("size=\(size)") }
    if let colour = value("colour", "color") { tokens.append("colour=\(colour)") }
    if let palette = array("palette"), !palette.isEmpty {
        tokens.append("palette=\(palette.joined(separator: "-"))")
    }
    return tokens.joined(separator: ",")
}

extension String {
    var toSymbolPosition: IconPosition? {
        switch self.lowercased() {
        case "leading":
            return .leading
        case "top":
            return .top
        case "bottom":
            return .bottom
        case "trailing":
            return .trailing
        default:
            return nil
        }
    }
}
