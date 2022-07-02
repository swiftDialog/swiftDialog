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
    
    @State var index = 0
    
    var images : Array = [NSImage]()
    var captions : Array = [String]()
    var autoPlaySeconds : CGFloat
    
    
    init(imageArray: Array<String>, captionArray: Array<String>, autoPlaySeconds : CGFloat) {
        for imagePath in imageArray {
            if imagePath != "" {
                images.append(getImageFromPath(fileImagePath: imagePath))
            }
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

        VStack(spacing: 20) {
            ImageSlider(index: $index.animation(), maxIndex: images.count - 1, autoPlaySeconds: autoPlaySeconds) {
                ForEach(Array(self.images.enumerated()), id: \.offset) { imageIndex, imageName in
                    VStack() {
                        Image(nsImage: imageName)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(10)
                        if captions.count > 0 {
                            if appArguments.fullScreenWindow.present {
                                Text(captions[imageIndex])
                                    .font(.system(size: 60))
                                    .foregroundColor(.white)
                            } else {
                                Text(captions[imageIndex])
                                    .font(.system(size: 20))
                                    .italic()
                            }
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        //.padding()
        .border(appvars.debugBorderColour, width: 2)
    }        
}
