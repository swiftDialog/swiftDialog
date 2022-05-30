//
//  IconOverlayView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 19/3/21.
//

import Foundation
import SwiftUI

struct IconOverlayView: View {
    
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    
    var overlayImagePath: String // cloptions.overlayIconOption.value // CLOptionText(OptionName: cloptions.overlayIconOption)
    var overlayIconPresent: Bool
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
    var sfBackgroundIconColour: Color = Color.background
        
    init (observedDialogContent : DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
        
        overlayImagePath = observedDialogContent.overlayIconImage
        overlayIconPresent = observedDialogContent.overlayIconPresent
        
        if overlayImagePath.starts(with: "http") {
            imgFromURL = true
        }
        if overlayImagePath.hasSuffix(".app") || overlayImagePath.hasSuffix("prefPane") {
            imgFromAPP = true
        }
        
        if overlayImagePath.hasPrefix("SF=") {
            sfSymbolPresent = true
            builtInIconPresent = true
            
            var SFValues = overlayImagePath.components(separatedBy: ",")
            SFValues = SFValues.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma
            
            for value in SFValues {
                // split by =
                let item = value.components(separatedBy: "=")
                let itemName = item[0]
                let itemValue = item[1]

                if itemName == "SF" {
                    builtInIconName = itemValue
                }
                if itemName == "weight" {
                    builtInIconWeight = textToFontWeight(item[1])
                }
                if itemName.hasPrefix("bgcolour") || itemName.hasPrefix("bgcolor") {
                    if itemValue == "none" {
                        sfBackgroundIconColour = .clear
                    } else {
                        sfBackgroundIconColour = stringToColour(itemValue)
                    }
                }
                if itemName.hasPrefix("colour") || itemName.hasPrefix("color") {
                    if itemValue == "auto" {
                        // detecting sf symbol properties seems to be annoying, at least in swiftui 2
                        // this is a bit of a workaround in that we let the user determine if they want the multicolour SF symbol
                        // or a standard template style. sefault is template. "auto" will use the built in SF Symbol colours
                        iconRenderingMode = Image.TemplateRenderingMode.original
                    } else { //check to see if it's in the right length and only contains the right characters
                        
                        iconRenderingMode = Image.TemplateRenderingMode.template // switches to monochrome which allows us to tint the sf symbol
                                                
                        if itemName.hasSuffix("2") {
                            sfGradientPresent = true
                            builtInIconSecondaryColour = stringToColour(itemValue)
                        } else {
                            builtInIconColour = stringToColour(itemValue)
                        }
                    }
                } else {
                   iconRenderingMode = Image.TemplateRenderingMode.template
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
        
        } else if !FileManager.default.fileExists(atPath: overlayImagePath) {
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
                            if sfGradientPresent {
                                LinearGradient(gradient: Gradient(colors: [builtInIconColour, builtInIconSecondaryColour]), startPoint: .top, endPoint: .bottomTrailing)
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
                                    // first image required to render as background fill (hopefully this is fixed in later versions of sf symbols, e.g. caution symbol
                                    Image(systemName: builtInIconFill)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .scaledToFit()
                                        .foregroundColor(Color.white)
                                        .font(Font.title.weight(builtInIconWeight))
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
                    let diskImage: NSImage = getImageFromPath(fileImagePath: overlayImagePath, imgWidth: appvars.iconWidth, imgHeight: appvars.iconHeight, returnErrorImage: false)
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

