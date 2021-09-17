//
//  watermarkView.swift
//  dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 16/9/21.
//

import SwiftUI

struct watermarkView: View {
    var imagePath: String = ""
    var mainImage: NSImage
    var imageOpacity: Double
    var imagePosition : Alignment = .leading
    var imageScaleFill : String
    
    init(imagePath: String?, opacity: Double?, position: String? = "center", scale: String? = "") {
        mainImage = getImageFromPath(fileImagePath: imagePath ?? "")
        imageOpacity = opacity ??  0.5
        imageScaleFill = scale ?? ""
        
        print("scale = \(imageScaleFill)")
        
        switch position {
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
            VStack {
                if imageScaleFill == "fill" {
                    Image(nsImage: mainImage)
                        .resizable()
                        .scaledToFill()
                        .opacity(imageOpacity)
                } else if imageScaleFill == "fit" {
                    Image(nsImage: mainImage)
                        .resizable()
                        .scaledToFit()
                        .opacity(imageOpacity)
                } else {
                    Image(nsImage: mainImage)
                        .opacity(imageOpacity)
                }
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: imagePosition)
        }
    }
}

