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
    var imageScaleFill : Bool = false
    
    init(imagePath: String?, opacity: Double?, position: String? = "center", scale: String? = "fit") {
        mainImage = getImageFromPath(fileImagePath: imagePath ?? "")
        imageOpacity = opacity ??  0.5
        if scale == "fill" {
            imageScaleFill = true
        }
        
        print("scale = \(String(describing: scale))")
        
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
        VStack {
            if imageScaleFill {
                Image(nsImage: mainImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaledToFill()
                    .opacity(imageOpacity)
                    .frame(width: appvars.windowWidth, height: appvars.windowHeight, alignment: imagePosition)
            } else {
                Image(nsImage: mainImage)
                    //.resizable()
                    //.aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .opacity(imageOpacity)
                    .frame(width: appvars.windowWidth, height: appvars.windowHeight, alignment: imagePosition)
            }
            
        }
        .frame(alignment: .bottom)
        //.border(Color.red)
        .offset(y: 27)
    }
}

