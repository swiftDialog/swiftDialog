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
    var showControls: Bool
    var clipRadius: CGFloat


    init(imageArray: [MainImage], captionArray: Array<String>, autoPlaySeconds: CGFloat, showControls: Bool = false, clipRadius: CGFloat = 10) {
        self.showControls = showControls
        self.clipRadius = clipRadius
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
            ImageFader(imageList: imageList, captionsList: captions, autoPlaySeconds: autoPlaySeconds, showControls: showControls, showCorners: clipRadius > 0 ? true : false)
            .clipShape(RoundedRectangle(cornerRadius: clipRadius))
        }
        .border(appvars.debugBorderColour, width: 2)
    }
}
