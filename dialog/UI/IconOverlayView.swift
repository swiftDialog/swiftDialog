//
//  IconOverlayView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 19/3/21.
//

import Foundation
import SwiftUI

struct IconOverlayView: View {
    
    //@ObservedObject var observedDialogContent : DialogUpdatableContent
    
    var overlayImagePath: String // appArguments.overlayIconOption.value // CLOptionText(OptionName: appArguments.overlayIconOption)
    var overlayIconPresent: Bool
    var imgFromURL: Bool = false
    var imgFromAPP: Bool = false
    
    var builtInIconName: String = ""
    var builtInIconColour: Color = Color.primary
    var builtInIconSecondaryColour: Color = Color.secondary
    var builtInIconTertiaryColour: Color = Color.tertiaryBackground
    var builtInIconFill: String = ""
    var builtInIconPresent: Bool = false
    var builtInIconWeight = Font.Weight.thin
    
    var iconRenderingMode = Image.TemplateRenderingMode.original
    var sfPalettePresent: Bool = false
    
    var sfSymbolName: String = ""
    var sfSymbolWeight = Font.Weight.thin
    var sfSymbolColour1: Color = Color.primary
    var sfSymbolColour2: Color = Color.secondary
    var sfSymbolPresent: Bool = false
    
    var sfGradientPresent: Bool = false
    var sfBackgroundIconColour: Color = Color.background
        
    init (image : String = "") {
        //self.observedDialogContent = observedDialogContent
        
        overlayImagePath = image
        overlayIconPresent = false
        
        if image != "" {
            overlayIconPresent = true
        }
        
        if overlayImagePath.starts(with: "http") {
            imgFromURL = true
        }
        if overlayImagePath.hasSuffix(".app") || overlayImagePath.hasSuffix("prefPane") {
            imgFromAPP = true
        }
        
        if overlayImagePath.lowercased().hasPrefix("sf=") {
            sfSymbolPresent = true
            builtInIconPresent = true
            
            //var SFValues = messageUserImagePath.components(separatedBy: ",")
            var SFValues = overlayImagePath.split(usingRegex: appvars.argRegex)
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
                    case _ where SFArg.hasPrefix("bgcolo"):
                        if SFArgValue == "none" {
                            sfBackgroundIconColour = .clear
                        } else {
                            sfBackgroundIconColour = stringToColour(SFArgValue)
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
            
        } else if overlayImagePath == "warning" {
            builtInIconName = "exclamationmark.octagon.fill"
            builtInIconFill = "octagon.fill"
            builtInIconColour = Color.red
            iconRenderingMode = Image.TemplateRenderingMode.original
            builtInIconPresent = true
        
        } else if overlayImagePath == "caution" {
            builtInIconName = "exclamationmark.triangle.fill"
            //builtInIconFill = "triangle.fill"
            //builtInIconColour = Color.yellow
            builtInIconPresent = true
        
        } else if overlayImagePath == "info" {
            builtInIconName = "person.fill.questionmark"
            builtInIconPresent = true
        
        } else if !FileManager.default.fileExists(atPath: overlayImagePath) && !imgFromURL {
            overlayIconPresent = false
        }
    }
    
    var body: some View {
        if overlayIconPresent {
            ZStack {
                if builtInIconPresent {
                    ZStack {
                        if sfSymbolPresent || overlayImagePath == "info" {
                            //background square so the SF Symbol has something to render against
                            Image(systemName: "square.fill")
                                .resizable()
                                .foregroundColor(sfBackgroundIconColour)
                                .font(Font.title.weight(Font.Weight.thin))
                                .opacity(0.90)
                                .shadow(color: .secondaryBackground.opacity(0.50), radius: 4, x:2, y:2) // gives the sf background some pop especially in dark mode
                        }
                        ZStack() {
                            if sfGradientPresent || sfPalettePresent {
                                
                                if #available(macOS 12.0, *) {
                                    if sfPalettePresent {
                                        Image(systemName: builtInIconName)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(builtInIconColour, builtInIconSecondaryColour, builtInIconTertiaryColour)
                                    } else {
                                        // gradient instead of palette
                                        Image(systemName: builtInIconName)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .symbolRenderingMode(.monochrome)
                                            .foregroundStyle(
                                                LinearGradient(gradient: Gradient(colors: [builtInIconColour, builtInIconSecondaryColour]), startPoint: .top, endPoint: .bottomTrailing)
                                            )
                                    }
                                } else {
                                LinearGradient(gradient: Gradient(colors: [builtInIconColour, builtInIconSecondaryColour]), startPoint: .top, endPoint: .bottomTrailing)
                                    .mask(
                                    Image(systemName: builtInIconName)
                                        .renderingMode(iconRenderingMode)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundColor(builtInIconColour)
                                        .font(Font.title.weight(builtInIconWeight))
                                )
                                }
                            } else {
                                // background colour
                                ZStack {
                                    // first image required to render as background fill (hopefully this is fixed in later versions of sf symbols, e.g. caution symbol
                                    if builtInIconFill != "" {
                                        Image(systemName: builtInIconFill)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .scaledToFit()
                                            .foregroundColor(Color.white)
                                            .font(Font.title.weight(builtInIconWeight))
                                    }
                                    if #available(macOS 12.0, *) {
                                        Image(systemName: builtInIconName)
                                            .resizable()
                                            .renderingMode(iconRenderingMode)
                                            .font(Font.title.weight(builtInIconWeight))
                                            .symbolRenderingMode(.hierarchical)
                                            .foregroundStyle(builtInIconColour)
                                            .aspectRatio(contentMode: .fit)
                                            .scaledToFit()
                                    } else {
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
                        }
                        .scaleEffect(0.8)
                    }
                    .aspectRatio(1, contentMode: .fit)
                } else if imgFromAPP {
                    Image(nsImage: getAppIcon(appPath: overlayImagePath))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                } else {
                    let diskImage: NSImage = getImageFromPath(fileImagePath: overlayImagePath, imgWidth: appvars.iconWidth, imgHeight: appvars.iconHeight, returnErrorImage: true)
                    Image(nsImage: diskImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
            .shadow(color: Color.primary.opacity(0.70), radius: appvars.overlayShadow)
        }
    }
}

