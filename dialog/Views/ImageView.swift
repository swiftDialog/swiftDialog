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

    var imageList: Array = [String]()
    var captions: Array = [String]()
    var autoPlaySeconds: CGFloat


    init(imageArray: [MainImage], captionArray: Array<String>, autoPlaySeconds: CGFloat) {
        for index in 0..<imageArray.count where imageArray[index].path != "" {
            imageList.append(imageArray[index].path)
            captions.append(imageArray[index].caption)
        }

        self.autoPlaySeconds = autoPlaySeconds
        if !imageArray.isEmpty {
            writeLog("Displaying images")
            writeLog("There are \(imageArray.count) images to display")
        }
    }

    var body: some View {

        VStack(spacing: 20) {
            ImageSlider(index: $index.animation(), maxIndex: imageList.count - 1, autoPlaySeconds: autoPlaySeconds) {
                ForEach(Array(self.imageList.enumerated()), id: \.offset) { imageIndex, imageName in
                    VStack {
                        DisplayImage(imageName, corners: true)

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
        .border(appvars.debugBorderColour, width: 2)
    }
}
