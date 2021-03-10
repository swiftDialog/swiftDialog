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
                if (AppVariables.iconVisible) {
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
        if (iconVisible) {
            viewWidth = AppVariables.windowWidth - (AppVariables.imageWidth*1.5)
            viewHeight = AppVariables.windowHeight/1.6
            viewOffset = 20
        } else {
            viewWidth = AppVariables.windowWidth*0.8
            viewHeight = AppVariables.windowHeight/1.6
            viewOffset = 0
        }
        
        if (AppVariables.textAllignment == "centre") {
            self.theAllignment = .center
        }
    }
    
    let iconVisible: Bool = AppVariables.iconVisible
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

struct LogoView: View {
    let messageUserImagePath: String = CLOptionText(OptionName: AppConstants.iconOption, DefaultValue: "")
    
    init() {
    //    print("messageUserImagePath is \(messageUserImagePath)")
    }
    
    var body: some View {
        

        VStack {
            if FileManager.default.fileExists(atPath: messageUserImagePath) {
                Image(nsImage: Utils().createImageData(fileImagePath: messageUserImagePath))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .frame(width: AppVariables.imageWidth, height: AppVariables.imageHeight)
            } else {
                Image(systemName: "message.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .frame(width: AppVariables.imageWidth, height: AppVariables.imageHeight)
                    .foregroundColor(Color.black)
                    //.background(Color.orange)
                    //.clipShape(Circle())
                    //.mask(LinearGradient(gradient: Gradient(colors: [Color.clear, Color.black]), startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .offset(x: 20, y: -40)
        //.border(Color.red)
        
    }
}
