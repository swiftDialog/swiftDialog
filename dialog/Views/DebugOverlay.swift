//
//  DebugOverlay.swift
//  Dialog
//
//  Created by Bart E Reardon on 29/5/2024.
//

import SwiftUI

struct DebugOverlay: View {
    @ObservedObject var observedData: DialogUpdatableContent
    @State private var windowFrame: CGSize = CGSize(width: 0, height: 0)

    var body: some View {
        if observedData.args.debug.present {
            // Display window information in the title bar and keep it updated
            VStack {
                HStack {
                    Text("DEBUG - Window width: \(Int(windowFrame.width)) height: \(Int(windowFrame.height-28)) - Icon width: \(Int(observedData.iconSize)) alpha: \(observedData.iconAlpha)")
                    Spacer()
                    Text("quitkey: cmd+\(observedData.args.quitKey.value.uppercased() == observedData.args.quitKey.value ? "shift+" : "")\(observedData.args.quitKey.value.lowercased())")
                }
                .foregroundColor(observedData.appProperties.titleFontColour.opacity(0.7))
                .padding(.top, 5)
                .padding(.leading, observedData.args.windowButtonsEnabled.present ? 70 : 5)
                .padding(.trailing, 5)
                Spacer()
            }
            .background(GeometryReader {child -> Color in
                if observedData.args.debug.present {
                    DispatchQueue.main.async {
                        // update on next cycle with calculated height
                        self.windowFrame = child.size
                    }
                }
                return Color.clear
            })
            .ignoresSafeArea()
            .frame(width: observedData.appProperties.windowWidth, height: observedData.appProperties.windowHeight)
        }
    }
}

