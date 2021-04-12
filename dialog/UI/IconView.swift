//
//  IconView.swift
//  Dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 19/3/21.
//

import Foundation
import SwiftUI


struct IconView: View {
    var messageUserImagePath: String = CLOptionText(OptionName: CLOptions.iconOption, DefaultValue: "default")
    let logoWidth: CGFloat?
    let logoHeight: CGFloat?
    var imgFromURL: Bool = false
    var imgFromAPP: Bool = false
    var imgXOffset: CGFloat = 25
    
    var builtInIconName: String = ""
    var builtInIconColour: Color = Color.black
    var builtInIconFill: String = ""
    var builtInIconPresent: Bool = false
    
    init() {        
        self.logoWidth = appvars.imageWidth
        self.logoHeight = appvars.imageHeight
        
        if messageUserImagePath.starts(with: "http") {
            imgFromURL = true
        }
        if messageUserImagePath.hasSuffix(".app") {
            imgFromAPP = true
        }
        
        if CLOptionPresent(OptionName: CLOptions.fullScreenWindow) {
            imgXOffset = 0
        }
        
        if CLOptionPresent(OptionName: CLOptions.warningIcon) || messageUserImagePath == "warning" {
            builtInIconName = "exclamationmark.octagon.fill"
            builtInIconFill = "octagon.fill"
            builtInIconColour = Color.red
            builtInIconPresent = true
        } else if CLOptionPresent(OptionName: CLOptions.cautionIcon) || messageUserImagePath == "caution" {
            builtInIconName = "exclamationmark.triangle.fill"
            builtInIconFill = "triangle.fill"
            builtInIconColour = Color.yellow
            builtInIconPresent = true
        } else if CLOptionPresent(OptionName: CLOptions.infoIcon) || messageUserImagePath == "info" {
            builtInIconName = "person.fill.questionmark"
            builtInIconPresent = true
        } else if messageUserImagePath == "default" {
            builtInIconName = "message.circle.fill"
            builtInIconPresent = true
        }
        
        if !FileManager.default.fileExists(atPath: messageUserImagePath) && !imgFromURL && !imgFromAPP && !builtInIconPresent  {
            quitDialog(exitCode: appvars.exit202.code, exitMessage: "\(appvars.exit202.message) \(messageUserImagePath)")
        }
    }
    
    var body: some View {
        VStack {
            if builtInIconPresent {
                ZStack {
                    Image(systemName: builtInIconFill)
                        .resizable()
                        .foregroundColor(Color.white)
                
                    Image(systemName: builtInIconName)
                        .resizable()
                        .foregroundColor(builtInIconColour)
                }
                .aspectRatio(contentMode: .fit)
                .scaledToFit()
                .offset(x: imgXOffset)
                .overlay(IconOverlayView(), alignment: .bottomTrailing)
            } else if imgFromAPP {
                Image(nsImage: getAppIcon(appPath: messageUserImagePath, withSize: appvars.imageWidth))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        .foregroundColor(Color.yellow)
                        .offset(x: imgXOffset)
                        .overlay(IconOverlayView(), alignment: .bottomTrailing)
            } else {
                let diskImage: NSImage = getImageFromPath(fileImagePath: messageUserImagePath, imgWidth: appvars.imageWidth, imgHeight: appvars.imageHeight)
                Image(nsImage: diskImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .frame(width: appvars.imageWidth, height: diskImage.size.height*(appvars.imageWidth/diskImage.size.width))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .offset(x: imgXOffset, y: 8)
                    .overlay(IconOverlayView(overlayWidth: appvars.imageWidth/2, overlayHeight: diskImage.size.height*(appvars.imageWidth/diskImage.size.width)/2), alignment: .bottomTrailing)

            }
        }
        //.overlay(IconOverlayView(), alignment: .topTrailing)
        //.border(Color.red) //debuging
        
    }
}

