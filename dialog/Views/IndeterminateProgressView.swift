//
//  IndeterminateProgressView.swift
//  dialog
//
//  Created by Bart Reardon on 12/9/2025.
//

import SwiftUI

// This is required as macOS 26 broke the indeterminate progress view animation
// idea source https://matthewcodes.uk/articles/indeterminate-linear-progress-view/

struct IndeterminateProgressView: View {
    @State private var offset: CGFloat = 0
    @State private var barColour: Color = .accentColor
    @Environment(\.controlActiveState) var controlActiveState

    var body: some View {
        GeometryReader { geometry in
                Rectangle()
                    .foregroundColor(.gray.opacity(0.15))
                    .overlay(
                        Rectangle()
                            .fill(LinearGradient(colors: [.clear, barColour, barColour, .clear], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geometry.size.width * 0.35, height: 8)
                            .clipShape(Capsule())
                            .offset(x: -geometry.size.width * 0.7, y: 0)
                            .offset(x: geometry.size.width * 1.4 * self.offset, y: 0)
                            .animation(.easeInOut.repeatForever().speed(0.25), value: self.offset)
                            .onAppear {
                                withAnimation {
                                    self.offset = 1
                                }
                            }
                    )
                    .clipShape(Capsule())
                    .frame(height: 8)
                    .padding(.top, 6)
                    .onChange(of: controlActiveState) { _, newPhase in
                        if newPhase == .key {
                            barColour = .accentColor
                        } else {
                            barColour = .secondary
                        }
                    }
                    .onAppear {
                        barColour = controlActiveState == .key ? .accentColor : .secondary
                    }
            }
    }
}

