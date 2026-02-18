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
            .overlay(
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: .white, location: 0.10),
                        Gradient.Stop(color: colourComponent, location: 0.40),
                        Gradient.Stop(color: .black, location: 0.95)
                    ], startPoint: .top, endPoint: .bottom)
                .opacity(withGradient ? 0.15 : 0)
            )
    }
}

#Preview {
    SolidColourView(colourValue: "blue")
}
