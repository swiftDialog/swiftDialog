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
    
    //var imageArray : Array
    //var mainImage: NSImage
    //var imageCaption: String = ""
    
    @State var index = 0
    
    var images : Array = [NSImage]()
    var captions : Array = [String]()
    var autoPlaySeconds : CGFloat
    
    
    init(imageArray: Array<String>, captionArray: Array<String>, autoPlaySeconds : CGFloat) {
        //mainImage = getImageFromPath(fileImagePath: imagePath ?? "")
        //imageCaption = caption ?? ""
        for imagePath in imageArray {
            images.append(getImageFromPath(fileImagePath: imagePath))
        }
        for imageCaption in captionArray {
            captions.append(imageCaption)
        }
        
        while captions.count < images.count {
            captions.append("")
        }
        
        self.autoPlaySeconds = autoPlaySeconds
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
                ImageSlider(index: $index.animation(), maxIndex: images.count - 1, autoPlaySeconds: autoPlaySeconds) {
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
    }        
}
