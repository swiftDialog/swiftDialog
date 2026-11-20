//
//  ButtonSymbol.swift
//  dialog
//
//  SF Symbol button labels using classic's `buttonNsymbol` grammar
//  ("name[,position][,renderingMode][,size=N][,colo(u)r=X][,palette=a-b-c]"), ported from classic.

import SwiftUI

/// Parsed form of a classic buttonNsymbol argument.
struct InspectButtonSymbolSpec {
    var name: String
    var position: IconPosition = .leading
    var renderingMode: SymbolRenderingMode = .monochrome
    var size: CGFloat = 16
    /// nil inherits the button label's foreground; explicit colo(u)r= or palette= override it.
    var color: Color?
    var color2: Color = .clear
    var color3: Color = .clear

    static func parse(_ argument: String?) -> InspectButtonSymbolSpec? {
        guard let argument, !argument.isEmpty else { return nil }
        let parts = argument.split(separator: ",").map { $0.lowercased() }
        guard let name = parts.first, !name.isEmpty else { return nil }

        var spec = InspectButtonSymbolSpec(name: name)
        for part in parts.dropFirst() {
            if let position = part.toSymbolPosition {
                spec.position = position
            }
            if let renderingMode = part.toSymbolRenderingMode {
                spec.renderingMode = renderingMode
            }
            if part.starts(with: "size=") {
                spec.size = Double(part.split(separator: "=").last ?? "16") ?? 16
            }
            if part.prefixMatch(of: /colou?r=/) != nil {
                spec.color = Color(argument: String(part.split(separator: "=").last ?? "primary"))
            }
            if part.starts(with: "palette=") {
                spec.renderingMode = .palette
                let paletteColours = (part.split(separator: "=").last ?? "").split(separator: "-").map { String($0) }
                switch paletteColours.count {
                case 1:
                    spec.color = Color(argument: paletteColours[0])
                case 2:
                    spec.color = Color(argument: paletteColours[0])
                    spec.color2 = Color(argument: paletteColours[1])
                case 3:
                    spec.color = Color(argument: paletteColours[0])
                    spec.color2 = Color(argument: paletteColours[1])
                    spec.color3 = Color(argument: paletteColours[2])
                default:
                    break
                }
            }
        }
        return spec
    }
}

/// Button label with an optional SF Symbol. top/bottom stack vertically (bottom puts text first),
/// trailing flips layout direction. No spec draws a plain text label.
struct ButtonSymbolLabel: View {
    let text: String
    let spec: InspectButtonSymbolSpec?

    var body: some View {
        if let spec {
            let layout = (spec.position == .top || spec.position == .bottom)
                ? AnyLayout(VStackLayout())
                : AnyLayout(HStackLayout())
            layout {
                if !text.isEmpty && spec.position == .bottom {
                    Text(text)
                }
                symbolImage(spec)
                if !text.isEmpty && spec.position != .bottom {
                    Text(text)
                }
            }
            .environment(\.layoutDirection, (spec.position == .leading) ? .leftToRight : .rightToLeft)
        } else {
            Text(text)
        }
    }

    @ViewBuilder
    private func symbolImage(_ spec: InspectButtonSymbolSpec) -> some View {
        let image = Image(systemName: spec.name)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(spec.renderingMode)
            .frame(height: spec.size)
        if let color = spec.color {
            image
                .foregroundStyle(color, spec.color2, spec.color3)
                .padding(2)
        } else {
            image
                .padding(2)
        }
    }
}
