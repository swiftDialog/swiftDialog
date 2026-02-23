//
//  Markdown+Addittions.swift
//  dialog
//
//  Created by Reardon, Bart (IM&T, Black Mountain) on 11/2/2026.
//

import Textual
import SwiftUI

struct ColoredMarkdownParser: MarkupParser {
    private static let colorPattern = /:([\w]+)\[([^\]]+)\]/
    
    // Zero-width Unicode characters we'll use as markers
    private static let startMarker = "\u{200B}\u{FEFF}" // zero-width space + zero-width no-break space
    private static let endMarker = "\u{FEFF}\u{200B}"
    
    func attributedString(for input: String) throws -> AttributedString {
        // Step 1: Replace color syntax with marked-up text, recording colors in order
        var processed = input
        var colors: [String] = []
        
        let matches = Array(input.matches(of: Self.colorPattern))
        for match in matches.reversed() {
            let colorName = String(match.output.1)
            let innerText = String(match.output.2)
            colors.insert(colorName, at: 0)
            let replacement = "\(Self.startMarker)\(innerText)\(Self.endMarker)"
            processed.replaceSubrange(match.range, with: replacement)
        }
        
        // Step 2: Parse full markdown
        var attributedString = try AttributedString(
            markdown: processed,
            options: .init(interpretedSyntax: .full)
        )
        
        // Step 3: Find markers in the attributed string and apply colors
        var colorIndex = 0
        while colorIndex < colors.count {
            let plain = String(attributedString.characters)
            
            guard let startRange = plain.range(of: Self.startMarker),
                  let endRange = plain.range(of: Self.endMarker) else {
                break
            }
            
            let textStart = startRange.upperBound
            let textEnd = endRange.lowerBound
            
            // Apply color to the text between markers
            if let color = Self.resolveColor(colors[colorIndex]) {
                let attrTextStart = attributedString.index(
                    attributedString.startIndex,
                    offsetByCharacters: plain.distance(from: plain.startIndex, to: textStart)
                )
                let attrTextEnd = attributedString.index(
                    attributedString.startIndex,
                    offsetByCharacters: plain.distance(from: plain.startIndex, to: textEnd)
                )
                attributedString[attrTextStart..<attrTextEnd].foregroundColor = color
            }
            
            // Remove the end marker first (so start positions stay valid)
            let attrEndMarkerStart = attributedString.index(
                attributedString.startIndex,
                offsetByCharacters: plain.distance(from: plain.startIndex, to: endRange.lowerBound)
            )
            let attrEndMarkerEnd = attributedString.index(
                attributedString.startIndex,
                offsetByCharacters: plain.distance(from: plain.startIndex, to: endRange.upperBound)
            )
            attributedString.removeSubrange(attrEndMarkerStart..<attrEndMarkerEnd)
            
            // Remove the start marker
            let plain2 = String(attributedString.characters)
            if let startRange2 = plain2.range(of: Self.startMarker) {
                let attrStartMarkerStart = attributedString.index(
                    attributedString.startIndex,
                    offsetByCharacters: plain2.distance(from: plain2.startIndex, to: startRange2.lowerBound)
                )
                let attrStartMarkerEnd = attributedString.index(
                    attributedString.startIndex,
                    offsetByCharacters: plain2.distance(from: plain2.startIndex, to: startRange2.upperBound)
                )
                attributedString.removeSubrange(attrStartMarkerStart..<attrStartMarkerEnd)
            }
            
            colorIndex += 1
        }
        
        return attributedString
    }
    
    private static func resolveColor(_ name: String) -> Color? {
        switch name.lowercased() {
        case "red":     return .red
        case "blue":    return .blue
        case "green":   return .green
        case "orange":  return .orange
        case "purple":  return .purple
        case "pink":    return .pink
        case "teal":    return .teal
        case "cyan":    return .cyan
        case "yellow":  return .yellow
        case "brown":   return .brown
        case "indigo":  return .indigo
        case "mint":    return .mint
        case "gray", "grey": return .gray
        case "white":   return .white
        case "black":   return .black
        default:
            if let hex = UInt(name, radix: 16), name.count == 6 {
                let r = Double((hex >> 16) & 0xFF) / 255.0
                let g = Double((hex >> 8) & 0xFF) / 255.0
                let b = Double(hex & 0xFF) / 255.0
                return Color(red: r, green: g, blue: b)
            }
            return nil
        }
    }
}
