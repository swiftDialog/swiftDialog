//
//  IconOverlayView.swift
//  Dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 19/3/21.
//

import Foundation
import SwiftUI

struct IconOverlayView: View {
    let overlayWidth: CGFloat?
    let overlayHeight: CGFloat?
    
    let overlayImagePath: String = CLOptionText(OptionName: CLOptions.overlayIconOption, DefaultValue: "")
    var imgFromURL: Bool = false
    var imgFromAPP: Bool = false
    
    init(overlayWidth: CGFloat? = nil, overlayHeight: CGFloat? = nil) {
        self.overlayWidth = appvars.imageWidth/2
        self.overlayHeight = appvars.imageHeight/2
        if overlayImagePath.starts(with: "http") {
            imgFromURL = true
        }
        if overlayImagePath.hasSuffix(".app") {
            imgFromAPP = true
        }
    }
    
    var body: some View {
        if CLOptionPresent(OptionName: CLOptions.overlayIconOption) {
            ZStack {
                if imgFromURL {
                    let webImage: NSImage = getImageFromPath(fileImagePath: overlayImagePath, imgWidth: appvars.imageWidth, imgHeight: appvars.imageHeight)
                    //let webImage: NSImage = Utils().getImageFromHTTPURL(fileURLString: overlayImagePath)
                    Image(nsImage: webImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else if imgFromAPP {
                    Image(nsImage: getAppIcon(appPath: overlayImagePath, withSize: overlayWidth!))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                } else if FileManager.default.fileExists(atPath: overlayImagePath) {
                    let diskImage: NSImage = getImageFromPath(fileImagePath: overlayImagePath, imgWidth: appvars.imageWidth, imgHeight: appvars.imageHeight)
                    Image(nsImage: diskImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    Image(systemName: "questionmark.square.dashed")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaledToFit()
                            .foregroundColor(Color.black)
                }
            }
            .frame(width: overlayWidth, height: overlayHeight)
            .offset(x: 40, y: 50)
            .shadow(radius: 5)
        }
    }
}

