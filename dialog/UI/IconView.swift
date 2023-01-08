//
//  IconView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 19/3/21.
//

import Foundation
import SwiftUI


struct IconView: View {
    @Environment(\.colorScheme) var colorScheme
    
    //@ObservedObject var observedDialogContent : DialogUpdatableContent
    
    var messageUserImagePath: String //= cloptions.iconOption.value // CLOptionText(OptionName: cloptions.iconOption, DefaultValue: "default")
    
    var iconOverlay : String
    var logoWidth: CGFloat = appvars.iconWidth
    var logoHeight: CGFloat  = appvars.iconHeight
    var imgFromURL: Bool = false
    var imgFromAPP: Bool = false
    var imgFromBase64: Bool = false
    
    var builtInIconName: String = ""
    var builtInIconColour: Color = Color.primary
    var builtInIconSecondaryColour: Color = Color.secondary
    var builtInIconTertiaryColour: Color = Color.primary
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
    var sfPalettePresent: Bool = false
    
    var mainImageScale: CGFloat = 1
    let mainImageWithOverlayScale: CGFloat = 0.88
    let overlayImageScale: CGFloat = 0.4
    
  
    init(image : String = "", overlay : String = "") {
        //self.observedDialogContent = observedDialogContent
        
        //if image != "" {
        messageUserImagePath = image
        iconOverlay = overlay
        //} else {
        //    messageUserImagePath = observedDialogContent.iconImage
        //}
        
        logoWidth = appvars.iconWidth
        logoHeight = appvars.iconHeight
        
        if overlay != "" {
            mainImageScale = mainImageWithOverlayScale
        }
        
        // fullscreen runs on a dark background so invert the default icon colour for info and default
        // also set the icon offset to 0
        if appArguments.fullScreenWindow.present {
            // fullscreen background is dark, so we want to use white as the default colour
            builtInIconColour = Color.white
        }
        
        if messageUserImagePath.starts(with: "http") {
            imgFromURL = true
        }
        
        if messageUserImagePath.starts(with: "base64") {
            imgFromBase64 = true
        }
        
        if messageUserImagePath.hasSuffix(".app") || messageUserImagePath.hasSuffix("prefPane") {
            imgFromAPP = true
        }
        
        if messageUserImagePath == "none" {
            builtInIconName = "" 
            builtInIconPresent = true
        }
        
        if messageUserImagePath.lowercased().hasPrefix("sf=") {
            sfSymbolPresent = true
            builtInIconPresent = true
            
            //var SFValues = messageUserImagePath.components(separatedBy: ",")
            var SFValues = messageUserImagePath.split(usingRegex: appvars.argRegex)
            SFValues = SFValues.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma
            
            var SFArg : String = ""
            var SFArgValue : String = ""
                
            if SFValues.count > 0 {
                for index in 0...SFValues.count-1 {
                    SFArg = SFValues[index]
                        .replacingOccurrences(of: ",", with: "")
                        .replacingOccurrences(of: "=", with: "")
                        .trimmingCharacters(in: .whitespaces)
                        .lowercased()
                    
                    if index < SFValues.count-1 {
                        SFArgValue = SFValues[index+1]
                    }
                    
                    switch SFArg {
                    case "sf":
                        builtInIconName = SFArgValue
                    case "weight":
                        builtInIconWeight = textToFontWeight(SFArgValue)
                    case _ where SFArg.hasPrefix("colo"):
                        if SFArgValue == "auto" {
                            // detecting sf symbol properties seems to be annoying, at least in swiftui 2
                            // this is a bit of a workaround in that we let the user determine if they want the multicolour SF symbol
                            // or a standard template style. sefault is template. "auto" will use the built in SF Symbol colours
                            iconRenderingMode = Image.TemplateRenderingMode.original
                        } else {
                            //check to see if it's in the right length and only contains the right characters
                            iconRenderingMode = Image.TemplateRenderingMode.template // switches to monochrome which allows us to tint the sf symbol
                            if SFArg.hasSuffix("2") {
                                sfGradientPresent = true
                                builtInIconSecondaryColour = stringToColour(SFArgValue)
                            } else if SFArg.hasSuffix("3") {
                                builtInIconTertiaryColour = stringToColour(SFArgValue)
                            } else {
                                builtInIconColour = stringToColour(SFArgValue)
                            }
                        }
                    case "palette":
                        let paletteColours = SFArgValue.components(separatedBy: ",".trimmingCharacters(in: .whitespaces))
                        if paletteColours.count > 1 {
                            sfPalettePresent = true
                        }
                        for i in 0...paletteColours.count-1 {
                            switch i {
                            case 0:
                                builtInIconColour = stringToColour(paletteColours[i])
                            case 1:
                                builtInIconSecondaryColour = stringToColour(paletteColours[i])
                            case 2:
                                builtInIconTertiaryColour = stringToColour(paletteColours[i])
                            default: ()
                            }
                        }
                    default:
                        iconRenderingMode = Image.TemplateRenderingMode.template
                    }
                }
            }
        }
            
        if appArguments.warningIcon.present || messageUserImagePath == "warning" {
            builtInIconName = "exclamationmark.octagon.fill"
            builtInIconFill = "octagon.fill" //does not have multicolour sf symbol so we have to make out own using a fill layer
            builtInIconColour = Color.red
            iconRenderingMode = Image.TemplateRenderingMode.original
            builtInIconPresent = true
        } else if appArguments.cautionIcon.present || messageUserImagePath == "caution" {
            builtInIconName = "exclamationmark.triangle.fill"  // yay multicolour sf symbol
            builtInIconPresent = true
        } else if appArguments.infoIcon.present || messageUserImagePath == "info" {
            builtInIconName = "person.fill.questionmark"
            builtInIconPresent = true
        } else if messageUserImagePath == "default" || (!builtInIconPresent && !FileManager.default.fileExists(atPath: messageUserImagePath) && !imgFromURL && !imgFromBase64) {
            builtInIconName = "bubble.left.circle.fill"
            iconRenderingMode = Image.TemplateRenderingMode.template //force monochrome
            builtInIconPresent = true
        }
    }
    
    var body: some View {
        ZStack {
            if builtInIconPresent {
                ZStack {
                    if sfGradientPresent || sfPalettePresent {
                        
                        if #available(macOS 12.0, *) {
                            if sfPalettePresent {
                                Image(systemName: builtInIconName)
                                    .resizable()
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(builtInIconColour, builtInIconSecondaryColour, builtInIconTertiaryColour)
                                    .font(Font.title.weight(builtInIconWeight))
                            } else {
                                // gradient instead of palette
                                Image(systemName: builtInIconName)
                                    .resizable()
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(
                                        LinearGradient(gradient: Gradient(colors: [builtInIconColour, builtInIconSecondaryColour]), startPoint: .top, endPoint: .bottomTrailing)
                                    )
                                    .font(Font.title.weight(builtInIconWeight))
                            }
                                
                        } else {
                            // macOS 11 doesn't support foregroundStyle so we'll do it the long way
                            // we need to add this twice - once as a clear version to force the right aspect ratio
                            // and again with the gradiet colour we want
                            // the reason for this is gradient by itself is greedy and will consume the entire height and width of the display area
                            // this causes some SF Symbols like applelogo and applescript to look distorted
                            Image(systemName: builtInIconName)
                                .renderingMode(iconRenderingMode)
                                .resizable()
                                .foregroundColor(.clear)
                                .font(Font.title.weight(builtInIconWeight))
                                
                            LinearGradient(gradient: Gradient(colors: [builtInIconColour, builtInIconSecondaryColour]), startPoint: .top, endPoint: .bottomTrailing)
                                .mask(
                                Image(systemName: builtInIconName)
                                    .renderingMode(iconRenderingMode)
                                    .resizable()
                                    .foregroundColor(builtInIconColour)
                                    .font(Font.title.weight(builtInIconWeight))
                                )
                        }
                        
                    } else {
                        if builtInIconFill != "" {
                            Image(systemName: builtInIconFill)
                                .resizable()
                                .foregroundColor(Color.white)
                        }
                        if #available(macOS 12.0, *) {
                            if messageUserImagePath == "default" {
                                Image(systemName: builtInIconName)
                                    .resizable()
                                    .renderingMode(iconRenderingMode)
                                    .font(Font.title.weight(builtInIconWeight))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundColor(builtInIconColour)
                            } else {
                                Image(systemName: builtInIconName)
                                    .resizable()
                                    .renderingMode(iconRenderingMode)
                                    .font(Font.title.weight(builtInIconWeight))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(builtInIconColour)
                            }
                        } else {
                            // Fallback on earlier versions
                            Image(systemName: builtInIconName)
                                .resizable()
                                .renderingMode(iconRenderingMode)
                                .font(Font.title.weight(builtInIconWeight))
                                .foregroundColor(builtInIconColour)
                        }
                    }
                }
                .aspectRatio(contentMode: .fit)
                .scaledToFit()
                .scaleEffect(mainImageScale)
            } else if imgFromAPP {
                Image(nsImage: getAppIcon(appPath: messageUserImagePath))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        .scaleEffect(mainImageScale)
            } else {
                let diskImage: NSImage = getImageFromPath(fileImagePath: messageUserImagePath, returnErrorImage: true)
                Image(nsImage: diskImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .scaleEffect(mainImageScale)
            }

            IconOverlayView(image: iconOverlay)
                .scaleEffect(overlayImageScale, anchor:.bottomTrailing)

        }
        
    }
}

