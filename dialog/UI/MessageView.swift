//
//  MessageView.swift
//  dialog
//
//  Created by Bart Reardon on 9/3/21.
//

import Foundation
import SwiftUI
import AppKit


struct MessageView: View {
    
    var body: some View {
        HStack(alignment: .top, spacing: /*@START_MENU_TOKEN@*/nil/*@END_MENU_TOKEN@*/) {
            let iconFrameWidth: CGFloat = AppVariables.imageWidth
            let iconFrameHeight: CGFloat = AppVariables.imageHeight
            HStack {
                if (!CLOptionPresent(OptionName: AppConstants.hideIcon)) {
                    VStack {
                            LogoView()
                    }.frame(width: iconFrameWidth, height: iconFrameHeight, alignment: .top)
                }
                
                VStack(alignment: .center) {
                    //MessageTitle()
                    MessageContent()
                        .padding(30)
                        
                }.frame(width:(AppVariables.windowWidth - iconFrameWidth),
                        height: AppVariables.windowHeight,
                        alignment: .center)
            }
            
        }
    }
}

struct MessageTitle: View {
    var messageTitleOption: String = CLOptionText(OptionName: AppConstants.titleOption, DefaultValue: AppVariables.titleDefault)
    var body: some View {
        VStack {
            Text(messageTitleOption)
                .bold()
                .font(.system(size: 30))
        }
        //.border(Color.purple)
    }
}


struct MessageContent: View {
    init () {
                        
        if (!CLOptionPresent(OptionName: AppConstants.hideIcon)) {
            viewWidth = AppVariables.windowWidth - (AppVariables.imageWidth*1.5)
            viewHeight = AppVariables.windowHeight/1.6
            viewOffset = 20
        } else {
            viewWidth = AppVariables.windowWidth*0.8
            viewHeight = AppVariables.windowHeight/1.6
            viewOffset = 0
        }
    
    }
    
    var viewWidth = CGFloat(0)
    var viewHeight = CGFloat(0)
    var viewOffset = CGFloat(0)
    
    let messageContentOption: String = CLOptionText(OptionName: AppConstants.messageOption, DefaultValue: AppVariables.messageDefault)
        
    var theAllignment: Alignment = .topLeading
    
    var body: some View {
        
        VStack {
            Text(messageContentOption)
                .font(.system(size: 20))
                //.multilineTextAlignment(.leading)
        }
        .frame(width: viewWidth, height: viewHeight, alignment: theAllignment)
        .padding(20)
        .offset(x: viewOffset)
        //.border(Color.orange)
    }
}

struct ImageOverlay: View {
    let overlayWidth: CGFloat?
    let overlayHeight: CGFloat?
    
    let overlayImagePath: String = CLOptionText(OptionName: AppConstants.overlayIconOption, DefaultValue: "")
    var imgFromURL: Bool = false
    var imgFromAPP: Bool = false
    
    init(overlayWidth: CGFloat? = nil, overlayHeight: CGFloat? = nil) {
        self.overlayWidth = AppVariables.imageWidth/2
        self.overlayHeight = AppVariables.imageHeight/2
        if overlayImagePath.starts(with: "http") {
            imgFromURL = true
        }
        if overlayImagePath.hasSuffix(".app") {
            imgFromAPP = true
        }
    }
    
    var body: some View {
        if CLOptionPresent(OptionName: AppConstants.overlayIconOption) {
            ZStack {
                if imgFromURL {
                    let webImage: NSImage = Utils().getImageFromHTTPURL(fileURLString: overlayImagePath)
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
                    let diskImage: NSImage = Utils().createImageData(fileImagePath: overlayImagePath)
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
                            .foregroundColor(Color.red)
                }
            }
            .frame(width: overlayWidth, height: overlayHeight)
            .offset(x: 40, y: 50)
            .shadow(radius: 5)
        }
    }
}

struct LogoView: View {
    let messageUserImagePath: String = CLOptionText(OptionName: AppConstants.iconOption, DefaultValue: "")
    let logoWidth: CGFloat?
    let logoHeight: CGFloat?
    var imgFromURL: Bool = false
    var imgFromAPP: Bool = false
    
    init() {
        self.logoWidth = AppVariables.imageWidth
        self.logoHeight = AppVariables.imageHeight
        if messageUserImagePath.starts(with: "http") {
            imgFromURL = true
        }
        if messageUserImagePath.hasSuffix(".app") {
            imgFromAPP = true
        }
    }
    
    var body: some View {
        VStack {
            if CLOptionPresent(OptionName: AppConstants.infoIcon) {
                Image(systemName: "person.fill.questionmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .foregroundColor(Color.black)
                    .offset(x: 25)
                    .overlay(ImageOverlay(), alignment: .bottomTrailing)
            } else if CLOptionPresent(OptionName: AppConstants.warningIcon) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .foregroundColor(Color.red)
                    .offset(x: 25)
                    .overlay(ImageOverlay(), alignment: .bottomTrailing)
            } else if CLOptionPresent(OptionName: AppConstants.cautionIcon) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .foregroundColor(Color.yellow)
                    .offset(x: 25)
                    .overlay(ImageOverlay(), alignment: .bottomTrailing)
            } else {
                if imgFromURL {
                    let webImage: NSImage = Utils().getImageFromHTTPURL(fileURLString: messageUserImagePath)
                    Image(nsImage: webImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        .frame(width: AppVariables.imageWidth, height: webImage.size.height*(AppVariables.imageWidth/webImage.size.width))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .offset(x: 25)
                        .overlay(ImageOverlay(overlayWidth: AppVariables.imageWidth, overlayHeight: webImage.size.height*(AppVariables.imageWidth/webImage.size.width)), alignment: .bottomTrailing)
                } else if imgFromAPP {
                    Image(nsImage: getAppIcon(appPath: messageUserImagePath, withSize: AppVariables.imageWidth))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaledToFit()
                            .foregroundColor(Color.yellow)
                            .offset(x: 25)
                            .overlay(ImageOverlay(), alignment: .bottomTrailing)
                } else if FileManager.default.fileExists(atPath: messageUserImagePath) {
                    let diskImage: NSImage = Utils().createImageData(fileImagePath: messageUserImagePath)
                    Image(nsImage: diskImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        .frame(width: AppVariables.imageWidth, height: diskImage.size.height*(AppVariables.imageWidth/diskImage.size.width))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .offset(x: 25, y: 8)
                        .overlay(ImageOverlay(overlayWidth: AppVariables.imageWidth/2, overlayHeight: diskImage.size.height*(AppVariables.imageWidth/diskImage.size.width)/2), alignment: .bottomTrailing)
                } else {
                    Image(systemName: "message.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        //.frame(width: AppVariables.imageWidth, height: AppVariables.imageHeight)
                        .foregroundColor(Color.black)
                        .offset(x: 25)
                        .overlay(ImageOverlay(), alignment: .bottomTrailing)
                }
            }
        }
        //.overlay(ImageOverlay(), alignment: .topTrailing)
        //.border(Color.red)
        
    }
}
