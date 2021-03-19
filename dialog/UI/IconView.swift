//
//  IconView.swift
//  Dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 19/3/21.
//

import Foundation
import SwiftUI


struct IconView: View {
    let messageUserImagePath: String = CLOptionText(OptionName: CLOptions.iconOption, DefaultValue: "")
    let logoWidth: CGFloat?
    let logoHeight: CGFloat?
    var imgFromURL: Bool = false
    var imgFromAPP: Bool = false
    let imgXOffset: CGFloat = 25
    
    init() {
        self.logoWidth = appvars.imageWidth
        self.logoHeight = appvars.imageHeight
        if messageUserImagePath.starts(with: "http") {
            imgFromURL = true
        }
        if messageUserImagePath.hasSuffix(".app") {
            imgFromAPP = true
        }
    }
    
    var body: some View {
        VStack {
            if CLOptionPresent(OptionName: CLOptions.infoIcon) {
                Image(systemName: "person.fill.questionmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .foregroundColor(Color.black)
                    .offset(x: imgXOffset)
                    .overlay(IconOverlayView(), alignment: .bottomTrailing)
            } else if CLOptionPresent(OptionName: CLOptions.warningIcon) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .foregroundColor(Color.red)
                    .offset(x: imgXOffset)
                    .overlay(IconOverlayView(), alignment: .bottomTrailing)
            } else if CLOptionPresent(OptionName: CLOptions.cautionIcon) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .foregroundColor(Color.yellow)
                    .offset(x: imgXOffset)
                    .overlay(IconOverlayView(), alignment: .bottomTrailing)
            } else {
                if imgFromURL {
                    let webImage: NSImage = getImageFromPath(fileImagePath: messageUserImagePath, imgWidth: appvars.imageWidth, imgHeight: appvars.imageHeight)
                    Image(nsImage: webImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        .frame(width: appvars.imageWidth, height: webImage.size.height*(appvars.imageWidth/webImage.size.width))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .offset(x: imgXOffset)
                        .overlay(IconOverlayView(overlayWidth: appvars.imageWidth, overlayHeight: webImage.size.height*(appvars.imageWidth/webImage.size.width)), alignment: .bottomTrailing)
                        //.overlay(IconOverlayView(), alignment: .bottomTrailing)
                } else if imgFromAPP {
                    Image(nsImage: getAppIcon(appPath: messageUserImagePath, withSize: appvars.imageWidth))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaledToFit()
                            .foregroundColor(Color.yellow)
                            .offset(x: imgXOffset)
                            .overlay(IconOverlayView(), alignment: .bottomTrailing)
                } else if FileManager.default.fileExists(atPath: messageUserImagePath) {
                    let diskImage: NSImage = getImageFromPath(fileImagePath: messageUserImagePath, imgWidth: appvars.imageWidth, imgHeight: appvars.imageHeight)
                    Image(nsImage: diskImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        .frame(width: appvars.imageWidth, height: diskImage.size.height*(appvars.imageWidth/diskImage.size.width))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .offset(x: imgXOffset, y: 8)
                        .overlay(IconOverlayView(overlayWidth: appvars.imageWidth/2, overlayHeight: diskImage.size.height*(appvars.imageWidth/diskImage.size.width)/2), alignment: .bottomTrailing)
                } else {
                    Image(systemName: "message.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        //.frame(width: AppVariables.imageWidth, height: AppVariables.imageHeight)
                        .foregroundColor(Color.black)
                        .offset(x: imgXOffset)
                        .overlay(IconOverlayView(), alignment: .bottomTrailing)
                }
            }
        }
        //.overlay(IconOverlayView(), alignment: .topTrailing)
        //.border(Color.red) //debuging
        
    }
}

