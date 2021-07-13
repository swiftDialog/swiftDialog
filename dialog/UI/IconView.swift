//
//  IconView.swift
//  Dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 19/3/21.
//

import Foundation
import SwiftUI


struct IconView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var messageUserImagePath: String = CLOptionText(OptionName: CLOptions.iconOption, DefaultValue: "default")
    var logoWidth: CGFloat = appvars.imageWidth
    var logoHeight: CGFloat  = appvars.imageHeight
    var imgFromURL: Bool = false
    var imgFromAPP: Bool = false
    var imgXOffset: CGFloat = 25
    
    var builtInIconName: String = ""
    var builtInIconColour: Color = Color.primary
    var builtInIconSecondaryColour: Color = Color.secondary
    var builtInIconFill: String = ""
    var builtInIconPresent: Bool = false
    var builtInIconWeight = Font.Weight.thin
    
    var iconRenderingMode = Image.TemplateRenderingMode.original
    
    var sfSymbolName: String = ""
    var sfSymbolWeight = Font.Weight.thin
    var sfSymbolColour1: Color = Color.primary
    var sfSymbolColour2: Color = Color.secondary
    var sfSymbolPresent: Bool = false
    
    func isValidColourHex(_ hexvalue: String) -> Bool {
        let hexRegEx = "^#([a-fA-F0-9]{6})$"
        let hexPred = NSPredicate(format:"SELF MATCHES %@", hexRegEx)
        return hexPred.evaluate(with: hexvalue)
    }
    
    init() {        
        logoWidth = appvars.imageWidth
        logoHeight = appvars.imageHeight
        
        
        // fullscreen runs on a dark background so invert the default icon colour for info and default
        // also set the icon offset to 0
        if CLOptionPresent(OptionName: CLOptions.fullScreenWindow) {
            builtInIconColour = Color.white
            imgXOffset = 0
            
            logoWidth = logoWidth * 5
            logoHeight = logoHeight * 5
        }
        
        if messageUserImagePath.starts(with: "http") {
            imgFromURL = true
        }
        
        if messageUserImagePath.hasSuffix(".app") || messageUserImagePath.hasSuffix("prefPane") {
            imgFromAPP = true
        }
        
        if messageUserImagePath.hasPrefix("SF=") {
            //print("sf present")
            sfSymbolPresent = true
            builtInIconPresent = true
            
            var SFValues = messageUserImagePath.components(separatedBy: ",")
            SFValues = SFValues.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma
            
            for value in SFValues {
                // split by =
                //print(value)
                let item = value.components(separatedBy: "=")
                //print(item[0])
                if item[0] == "SF" {
                    builtInIconName = item[1]
                    //print(item[1])
                }
                if item[0] == "weight" {
                    switch item[1] {
                    case "bold":
                        builtInIconWeight = Font.Weight.bold
                    case "heavy":
                        builtInIconWeight = Font.Weight.heavy
                    case "light":
                        builtInIconWeight = Font.Weight.light
                    case "medium":
                        builtInIconWeight = Font.Weight.medium
                    case "regular":
                        builtInIconWeight = Font.Weight.regular
                    case "thin":
                        builtInIconWeight = Font.Weight.thin
                    default:
                        builtInIconWeight = Font.Weight.thin
                    }
                }
                if item[0] == "colour" || item[0] == "color" {
                    if isValidColourHex(item[1]) {
                        //check to see if it's in the right length and only contains the right characters
                        
                        iconRenderingMode = Image.TemplateRenderingMode.template
                        
                        let colourHash = String(item[1])
                        
                        let colourRedValue = "\(colourHash[1])\(colourHash[2])"
                        let colourRed = Double(Int(colourRedValue, radix: 16)!)/255
                        
                        let colourGreenValue = "\(colourHash[3])\(colourHash[4])"
                        let colourGreen = Double(Int(colourGreenValue, radix: 16)!)/255
                        
                        let colourBlueValue = "\(colourHash[5])\(colourHash[6])"
                        let colourBlue = Double(Int(colourBlueValue, radix: 16)!)/255
                        
                        //print("red: \(colourRedValue) green: \(colourGreenValue) blue:\(colourBlueValue)")
                        //print("red: \(colourRed) green: \(colourGreen) blue:\(colourBlue)")
                        builtInIconColour = Color(red: colourRed, green: colourGreen, blue: colourBlue)
                    } else {
                        quitDialog(exitCode: 14, exitMessage: "Hex value for colour is not valid: \(item[1])")
                        //print("Hex value for colour is not valid: \(item[1])")
                    }
                }
            }
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
            //builtInIconColour = sfSymbolColour1
            //builtInIconWeight = sfSymbolWeight
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
                        .renderingMode(iconRenderingMode)
                        .resizable()
                        .foregroundColor(builtInIconColour)
                        .font(Font.title.weight(builtInIconWeight))
                }
                .aspectRatio(contentMode: .fit)
                .scaledToFit()
                .offset(x: imgXOffset)
                .overlay(IconOverlayView(), alignment: .bottomTrailing)
            } else if imgFromAPP {
                Image(nsImage: getAppIcon(appPath: messageUserImagePath, withSize: self.logoWidth))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        .foregroundColor(Color.yellow)
                        .offset(x: imgXOffset)
                        .overlay(IconOverlayView(), alignment: .bottomTrailing)
            } else {
                let diskImage: NSImage = getImageFromPath(fileImagePath: messageUserImagePath, imgWidth: logoWidth, imgHeight: logoHeight)
                Image(nsImage: diskImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .frame(width: self.logoWidth, height: diskImage.size.height*(logoWidth/diskImage.size.width))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .offset(x: imgXOffset, y: 8)
                    .overlay(IconOverlayView(overlayWidth: logoWidth/2, overlayHeight: diskImage.size.height*(logoWidth/diskImage.size.width)/2), alignment: .bottomTrailing)

            }
        }
        //.overlay(IconOverlayView(), alignment: .topTrailing)
        //.border(Color.red) //debuging
        
    }
}

