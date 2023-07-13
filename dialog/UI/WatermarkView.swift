//
//  watermarkView.swift
//  dialog
//
//  Created by Bart Reardon on 16/9/21.
//

import SwiftUI

struct WatermarkView: View {
    var imageOpacity: Double
    var imagePosition: Alignment = .leading
    var imageAlignmentGuite: Alignment = .center

    @ObservedObject var observedData: DialogUpdatableContent

    init(observedContent: DialogUpdatableContent) {
        self.observedData = observedContent

        imageOpacity = Double(observedContent.args.watermarkAlpha.value) ??  0.5

        writeLog("Displaying background layer with image \(observedContent.args.watermarkImage.value) and alpha value \(observedContent.args.watermarkAlpha.value)")

        switch observedData.args.watermarkPosition.value {
        case "left":
            imagePosition = .leading
        case "topleft":
            imagePosition = .topLeading
        case "bottomleft":
            imagePosition = .bottomLeading
        case "center":
            imagePosition = .center
        case "top":
            imagePosition = .top
        case "bottom":
            imagePosition = .bottom
        case "right":
            imagePosition = .trailing
        case "topright":
            imagePosition = .topTrailing
        case "bottomright":
            imagePosition = .bottomTrailing
        default:
            imagePosition = .center
        }
    }

    var body: some View {
        ZStack {
            if observedData.args.watermarkFill.value == "fill" {
                DisplayImage(observedData.args.watermarkImage.value, rezize: true)
                    .aspectRatio(contentMode: .fill)
                    .scaledToFill()
                    .opacity(imageOpacity)
            } else if observedData.args.watermarkFill.value == "fit" {
                DisplayImage(observedData.args.watermarkImage.value, rezize: true)
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .opacity(imageOpacity)
            } else {
                DisplayImage(observedData.args.watermarkImage.value, rezize: false)
                    .fixedSize()
                    .opacity(imageOpacity)
            }
        }
        .frame(width: observedData.appProperties.windowWidth, height: observedData.appProperties.windowHeight, alignment: imagePosition)
    }
}

