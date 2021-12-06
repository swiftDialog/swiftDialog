//
//  ImageView.swift
//  dialog
//
//  Created by Bart Reardon on 15/8/21.
//

import SwiftUI
import Foundation
import Combine

struct ImageView: View {
    
    var imagePath: String = ""
    var mainImage: NSImage
    var imageCaption: String = ""
    
    @State var index = 0
    
    var images : Array = [NSImage]()
    var captions : Array = [String]()
    
    
    init(imagePath: String?, caption: String?) {
        mainImage = getImageFromPath(fileImagePath: imagePath ?? "")
        imageCaption = caption ?? ""
        
        images.append(getImageFromPath(fileImagePath: imagePath ?? ""))
        captions.append(caption ?? "")
        images.append(getImageFromPath(fileImagePath: imagePath ?? ""))
        captions.append(caption ?? "")
        images.append(getImageFromPath(fileImagePath: imagePath ?? ""))
        captions.append(caption ?? "")
        images.append(getImageFromPath(fileImagePath: imagePath ?? ""))
        captions.append(caption ?? "")
        images.append(getImageFromPath(fileImagePath: imagePath ?? ""))
        captions.append(caption ?? "")
        
    }
    
    var body: some View {
        /*
        VStack {
            Image(nsImage: mainImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(radius: 3)
            Text(imageCaption)
                .font(.system(size: 20))
                .italic()
        }
         */
        VStack(spacing: 20) {
            //HStack() {
                ImageSlider(index: $index.animation(), maxIndex: images.count - 1, autoPlaySeconds: 10) {
                    ForEach(Array(self.images.enumerated()), id: \.offset) { imageIndex, imageName in
                        VStack() {
                            Image(nsImage: imageName)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(10)
                            Text(captions[imageIndex])
                                .font(.system(size: 20))
                                .italic()
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .zIndex(1)
    }
}
