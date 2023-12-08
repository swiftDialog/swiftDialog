//
//  SolidColourView.swift
//  Dialog
//
//  Created by Bart E Reardon on 8/12/2023.
//

import SwiftUI

struct SolidColourView: View {
    var colourValue: String
    var body: some View {
        Color(argument: colourValue.components(separatedBy: "=").last ?? "clear")
            .ignoresSafeArea(.all)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.white, .clear, .black]),
                    startPoint: .top,
                    endPoint: .bottom)
                .opacity(0.15)
            )
    }
}

#Preview {
    SolidColourView(colourValue: "blue")
}
