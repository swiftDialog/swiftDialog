//
//  IconOverlayView.swift
//  Dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 19/3/21.
//

import Foundation
import SwiftUI

struct IconOverlayView: View {
    //var overlayWidth: CGFloat = .infinity//= appvars.imageWidth * appvars.overlayIconScale
    //var overlayHeight: CGFloat = .infinity //= appvars.imageHeight * appvars.overlayIconScale
    
    let overlayImagePath: String = CLOptionText(OptionName: CLOptions.overlayIconOption)
    var imgFromURL: Bool = false
    var imgFromAPP: Bool = false
    
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
    
    var sfGradientPresent: Bool = false
        
    //init(overlayIconWidth: CGFloat? = nil, overlayIconHeight: CGFloat? = nil) {
    init() {
        //self.overlayWidth = overlayIconWidth ?? appvars.imageWidth * appvars.overlayIconScale
        //self.overlayHeight = overlayIconHeight ?? appvars.imageHeight * appvars.overlayIconScale
        
        if overlayImagePath.starts(with: "http") {
            imgFromURL = true
        }
        if overlayImagePath.hasSuffix(".app") || overlayImagePath.hasSuffix("prefPane") {
            imgFromAPP = true
        }
        
        if overlayImagePath.hasPrefix("SF=") {
            //print("sf present")
            sfSymbolPresent = true
            builtInIconPresent = true
            
            var SFValues = overlayImagePath.components(separatedBy: ",")
            SFValues = SFValues.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma
            
            for value in SFValues {
                // split by =
                let item = value.components(separatedBy: "=")

                if item[0] == "SF" {
                    builtInIconName = item[1]
                }
                if item[0] == "weight" {
                    builtInIconWeight = textToFontWeight(item[1])
                }
                if item[0].hasPrefix("colour") || item[0].hasPrefix("color") {
                    if item[1] == "auto" {
                        // detecting sf symbol properties seems to be annoying, at least in swiftui 2
                        // this is a bit of a workaround in that we let the user determine if they want the multicolour SF symbol
                        // or a standard template style. sefault is template. "auto" will use the built in SF Symbol colours
                        iconRenderingMode = Image.TemplateRenderingMode.original
                    } else { //check to see if it's in the right length and only contains the right characters
                        
                        iconRenderingMode = Image.TemplateRenderingMode.template // switches to monochrome which allows us to tint the sf symbol
                                                
                        if item[0].hasSuffix("2") {
                            sfGradientPresent = true
                            builtInIconSecondaryColour = stringToColour(item[1])
                        } else {
                            builtInIconColour = stringToColour(item[1])
                        }
                    //} else {
                        //quitDialog(exitCode: 14, exitMessage: "Hex value for colour is not valid: \(item[1])")
                        //print("Hex value for colour is not valid: \(item[1])")
                    }
                } else {
                   iconRenderingMode = Image.TemplateRenderingMode.template
               }
            }
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
                    ZStack {
                        //background square so the SF Symbol "pops"
                        Image(systemName: "square.fill")
                            .resizable()
                            .foregroundColor(.background)
                            //.frame(width: overlayWidth, height: overlayWidth)
                            .font(Font.title.weight(Font.Weight.thin))
                            .opacity(0.90)
                            .shadow(color: .primary, radius: 1, x: 1, y: 1)

                        ZStack() {
                            if sfGradientPresent {
                                LinearGradient(gradient: Gradient(colors: [builtInIconColour, builtInIconSecondaryColour]), startPoint: .top, endPoint: .bottomTrailing)
                                //LinearGradient(gradient: Gradient(colors: [.clear, .clear]), startPoint: .top, endPoint: .bottom)
                                    .mask(
                                    Image(systemName: builtInIconName)
                                        .renderingMode(iconRenderingMode)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundColor(builtInIconColour)
                                        .font(Font.title.weight(builtInIconWeight))
                                )
                            } else {
                                // background colour
                                ZStack {
                                    
                                    Image(systemName: builtInIconFill)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .scaledToFit()
                                        .foregroundColor(Color.white)
                                        .font(Font.title.weight(builtInIconWeight))
                                //}
                                //forground image
                                //ZStack {
                                    Image(systemName: builtInIconName)
                                        .renderingMode(iconRenderingMode)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .scaledToFit()
                                        .foregroundColor(builtInIconColour)
                                        .font(Font.title.weight(builtInIconWeight))
                                }
                            }
                        }
                        .scaleEffect(0.8)
                        //.frame(width: overlayWidth*0.8, height: overlayWidth*0.8)
                        //.shadow(color: stringToColour("#FFEEFF"), radius: 6, x: 1, y: 1)
                    }
                    .aspectRatio(1, contentMode: .fit)
                } else if imgFromAPP {
                    //Image(nsImage: getAppIcon(appPath: overlayImagePath, withSize: overlayWidth))
                    Image(nsImage: getAppIcon(appPath: overlayImagePath))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                } else { //if FileManager.default.fileExists(atPath: overlayImagePath) {
                    let diskImage: NSImage = getImageFromPath(fileImagePath: overlayImagePath, imgWidth: appvars.imageWidth, imgHeight: appvars.imageHeight, returnErrorImage: false)
                    Image(nsImage: diskImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                
            }
            //.frame(width: overlayWidth, height: overlayHeight)
            //.offset(x: appvars.overlayOffsetX, y: appvars.overlayOffsetY)
            .shadow(color: Color.primary.opacity(0.70), radius: appvars.overlayShadow)
            //.border(Color.red)
        }
    }
}

