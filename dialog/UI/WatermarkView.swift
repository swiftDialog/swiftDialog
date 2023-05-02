//
//  watermarkView.swift
//  dialog
//
//  Created by Bart Reardon on 16/9/21.
//

import SwiftUI

struct WatermarkView: View {
    var mainImage: NSImage
    var imageOpacity: Double
    var imagePosition : Alignment = .leading
    var imageAlignmentGuite : Alignment = .center
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    init(observedContent : DialogUpdatableContent) {
        self.observedData = observedContent

        mainImage = getImageFromPath(fileImagePath: observedContent.args.watermarkImage.value)
        imageOpacity = Double(observedContent.args.watermarkAlpha.value) ??  0.5
        
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
        GeometryReader { geometry in
            ZStack {
                if observedData.args.watermarkFill.value == "fill" {
                    Image(nsImage: mainImage)
                        .resizable()
                        .scaledToFill()
                        .opacity(imageOpacity)
                } else if observedData.args.watermarkFill.value == "fit" {
                    Image(nsImage: mainImage)
                        .resizable()
                        .scaledToFit()
                        .opacity(imageOpacity)
                } else {
                    Image(nsImage: mainImage)
                        .opacity(imageOpacity)
                }
                
            }
            .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height, alignment: imagePosition)
        }
    }
}

