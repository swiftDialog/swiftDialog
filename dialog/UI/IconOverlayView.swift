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
    
    var builtInIconName: String = ""
    var builtInIconFill: String = ""
    var builtInIconColour: Color = Color.black
    var builtInIconPresent: Bool = false
    
    init(overlayWidth: CGFloat? = nil, overlayHeight: CGFloat? = nil) {
        self.overlayWidth = appvars.imageWidth/2
        self.overlayHeight = appvars.imageHeight/2
        if overlayImagePath.starts(with: "http") {
            imgFromURL = true
        }
        if overlayImagePath.hasSuffix(".app") {
            imgFromAPP = true
        }
        
        if overlayImagePath == "warning" {
            builtInIconName = "exclamationmark.octagon.fill"
            builtInIconFill = "octagon.fill"
            builtInIconColour = Color.red
            builtInIconPresent = true
        }
        if overlayImagePath == "caution" {
            builtInIconName = "exclamationmark.triangle.fill"
            builtInIconFill = "triangle.fill"
            builtInIconColour = Color.yellow
            builtInIconPresent = true
        }
        if overlayImagePath == "info" {
            builtInIconName = "person.fill.questionmark"
            builtInIconPresent = true
        }
    }
    
    var body: some View {
        if CLOptionPresent(OptionName: CLOptions.overlayIconOption) {
            ZStack {
                if builtInIconPresent {
                    // background colour
                    ZStack {
                        Image(systemName: builtInIconFill)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaledToFit()
                            .foregroundColor(Color.white)
                    }
                    //forground image
                    ZStack {
                        Image(systemName: builtInIconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaledToFit()
                            .foregroundColor(builtInIconColour)
                    }
                } else {
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
            }
            .frame(width: overlayWidth, height: overlayHeight)
            .offset(x: 40, y: 50)
            .shadow(radius: 3)
        }
    }
}

