//
//  SolidColourView.swift
//  Dialog
//
//  Created by Bart E Reardon on 8/12/2023.
//

import SwiftUI

struct SolidColourView: View {
    var colourValue: String
    var colourComponent: Color = .clear
    var withGradient: Bool = true

    init(colourValue: String, withGradient: Bool = true) {
        self.colourValue = colourValue
        colourComponent = Color(argument: colourValue.components(separatedBy: "=").last ?? "clear")
        self.withGradient = withGradient
    }

    var body: some View {
        Color(argument: colourValue.components(separatedBy: "=").last ?? "clear")
            .ignoresSafeArea(.all)
            // Closure form of overlay so the gradient is treated as a View. LinearGradient is
            // both a View and a ShapeStyle, and with overlay(_:) accepting either, the newer
            // SDK reports `.opacity` as ambiguous.
            .overlay {
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: .white, location: 0.10),
                        Gradient.Stop(color: colourComponent, location: 0.40),
                        Gradient.Stop(color: .black, location: 0.95)
                    ], startPoint: .top, endPoint: .bottom)
                .opacity(withGradient ? 0.15 : 0)
            }
    }
}

struct GradientColourView: View {
    var colours: [Color]
    var angleDegrees: Double

    /// Create a gradient view from an array of colour strings and a direction in degrees.
    /// - Parameters:
    ///   - colourValues: Comma-separated colour names or hex values (e.g. "red, green, blue, #FF8800").
    ///                   Defaults to the equivalent of SolidColourView: a single colour with a
    ///                   white-to-colour-to-black gradient overlay.
    ///   - angleDegrees: The gradient direction in degrees (0 = bottom-to-top, 90 = left-to-right,
    ///                   180 = top-to-bottom). Defaults to 180 (top-to-bottom).
    init(colourValues: String = "accent", angleDegrees: Double = 90) {
        let parsed = colourValues
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.components(separatedBy: "=").last ?? "clear" }
            .map { Color(argument: $0) }

        // If only one colour was supplied, mimic SolidColourView's default gradient
        if parsed.count < 2 {
            let base = parsed.first ?? .clear
            self.colours = [
                .white.opacity(0.15),
                base,
                .black.opacity(0.15)
            ]
        } else {
            self.colours = parsed
        }
        self.angleDegrees = angleDegrees
    }

    /// Convert an angle in degrees to a SwiftUI `UnitPoint` pair.
    /// 0° = bottom-to-top, 90° = left-to-right, 180° = top-to-bottom, 270° = right-to-left.
    private var gradientPoints: (start: UnitPoint, end: UnitPoint) {
        let radians = angleDegrees * .pi / 180
        // Unit circle: sin gives x component, cos gives y component.
        // We negate cos so that 0° means "upward" (bottom-to-top) matching common CSS/design convention.
        let dx = sin(radians)
        let dy = -cos(radians)
        let start = UnitPoint(x: 0.5 - dx / 2, y: 0.5 - dy / 2)
        let end   = UnitPoint(x: 0.5 + dx / 2, y: 0.5 + dy / 2)
        return (start, end)
    }

    var body: some View {
        let points = gradientPoints
        LinearGradient(
            colors: colours,
            startPoint: points.start,
            endPoint: points.end
        )
        .ignoresSafeArea(.all)
    }
}

#Preview("Solid Colour") {
    SolidColourView(colourValue: "blue")
}
#Preview("Gradient Colour") {
    GradientColourView(colourValues: "red, green, blue, orange", angleDegrees: 135)
}

