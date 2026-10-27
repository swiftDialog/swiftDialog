//
//  GeneratedImageView.swift
//  dialog
//
//  Images the dialog draws instead of loading, authored with a scheme prefix in any image path
//  field (like `SF=`). Deterministic: the same string is the same picture on every Mac.
//

import SwiftUI

// MARK: - The authored string

/// A generated image source. A string with neither prefix is still a file path.
///
///     "tile:#455A75"              a flat swatch
///     "tile:#455A75/#233047"      two bands, the second along the bottom
///     "gradient:ocean"            a mesh gradient from a seed
///     "gradient:ocean?style=vivid&palette=#0A6BD6,#43C46B"
enum GeneratedImageRef: Equatable {
    case tile(top: Color, bottom: Color?)
    case gradient(seed: String, style: ProceduralGradientStyle, palette: [Color])

    static func parse(_ raw: String) -> GeneratedImageRef? {
        let lower = raw.lowercased()
        if lower.hasPrefix("tile:") { return parseTile(String(raw.dropFirst(5))) }
        if lower.hasPrefix("gradient:") { return parseGradient(String(raw.dropFirst(9))) }
        return nil
    }

    private static func parseTile(_ body: String) -> GeneratedImageRef? {
        let parts = body.split(separator: "/", maxSplits: 1).map(String.init)
        guard let first = parts.first, !first.isEmpty else { return nil }
        let bottom = parts.count > 1 && !parts[1].isEmpty ? Color(hex: parts[1]) : nil
        return .tile(top: Color(hex: first), bottom: bottom)
    }

    private static func parseGradient(_ body: String) -> GeneratedImageRef? {
        // Query syntax, because a seed is free text and could contain any other delimiter.
        let split = body.split(separator: "?", maxSplits: 1).map(String.init)
        let seed = split.first ?? ""
        guard !seed.isEmpty else { return nil }
        var style: ProceduralGradientStyle = .ethereal
        var palette: [Color] = []
        if split.count > 1 {
            for pair in split[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                guard kv.count == 2 else { continue }
                switch kv[0].lowercased() {
                case "style":
                    style = ProceduralGradientStyle(rawValue: kv[1].lowercased()) ?? .ethereal
                case "palette":
                    palette = kv[1].split(separator: ",").map { Color(hex: String($0)) }
                default:
                    break
                }
            }
        }
        return .gradient(seed: seed, style: style, palette: palette)
    }
}



struct GeneratedImageView: View {
    let ref: GeneratedImageRef

    var body: some View {
        switch ref {
        case .tile(let top, let bottom):
            if let bottom {
                // A hard edge, not a gradient: it reads as a horizon and gives the swatch an orientation.
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        top
                        bottom.frame(height: geo.size.height * 0.28)
                    }
                }
            } else {
                top
            }
        case .gradient(let seed, let style, let palette):
            ProceduralGradientView(seed: seed, palette: palette, style: style)
        }
    }
}
