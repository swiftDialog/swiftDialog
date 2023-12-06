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

    var messageUserImagePath: String

    var iconOverlay: String
    var imgFromURL: Bool = false
    var imgFromAPP: Bool = false
    var imgFromBase64: Bool = false
    var imgFromText: Bool = false

    var builtInIconName: String = ""
    var builtInIconAutoColor: Bool = false
    var builtInIconColour: Color = Color.primary
    var builtInIconSecondaryColour: Color = Color.secondary
    var builtInIconTertiaryColour: Color = Color.primary
    var builtInIconFill: String = ""
    var builtInIconPresent: Bool = false
    var builtInIconWeight = Font.Weight.thin

    var framePadding: CGFloat = 0

    var iconRenderingMode = Image.TemplateRenderingMode.original

    var sfSymbolName: String = ""
    var sfSymbolWeight = Font.Weight.thin
    var sfSymbolColour1: Color = Color.primary
    var sfSymbolColour2: Color = Color.secondary
    var sfSymbolPresent: Bool = false
    var sfSymbolAnimation: String = ""

    var sfGradientPresent: Bool = false
    var sfPalettePresent: Bool = false
    var sfBackgroundIconColour: Color = Color.background

    var mainImageScale: CGFloat = 1
    var mainImageAlpha: Double

    let mainImageWithOverlayScale: CGFloat = 0.88
    let overlayImageScale: CGFloat = 0.4
    var overlayImageBackgroundScale: CGFloat = 1.1
    var overlayImageBackground: Bool = false

    let argRegex = String("(,? ?[a-zA-Z1-9]+=|(,\\s?editor)|(,\\s?fileselect))|(,\\s?passwordfill)|(,\\s?required)|(,\\s?secure)")

    init(image: String = "", overlay: String = "", alpha: Double = 1.0, padding: Double = 0) {
        writeLog("Displaying icon image \(image), alpha \(alpha)")
        if !overlay.isEmpty {
            writeLog("With overlay \(overlay)")
        }
        mainImageAlpha = alpha
        messageUserImagePath = image
        iconOverlay = overlay

        framePadding = padding

        if overlay != "" {
            mainImageScale = mainImageWithOverlayScale
            if overlay.lowercased().hasPrefix("sf=") {
                if overlay.range(of: "bgcolour=none") == nil && overlay.range(of: "bgcolor=none") == nil && !["info","warning","caution"].contains(overlay) {
                    var SFValues = overlay.components(separatedBy: ",")
                    SFValues = SFValues.map { $0.trimmingCharacters(in: .whitespaces) }
                    for value in SFValues where value.hasPrefix("bgcolo") {
                        if let bgColour = value.components(separatedBy: "=").last {
                            sfBackgroundIconColour = Color(argument: bgColour)
                        }
                    }
                    overlayImageBackground = true
                    overlayImageBackgroundScale = 0.9
                }
            }
        }

        // fullscreen runs on a dark background so invert the default icon colour for info and default
        // also set the icon offset to 0
        if appArguments.fullScreenWindow.present {
            writeLog("Adjusting icon colour for fullscreen display")
            // fullscreen background is dark, so we want to use white as the default colour
            builtInIconColour = Color.white
        }

        if messageUserImagePath.starts(with: "http") {
            writeLog("Image is http source")
            imgFromURL = true
        }

        if messageUserImagePath.starts(with: "base64") {
            writeLog("Image is base64 source")
            imgFromBase64 = true
        }

        if ["app", "prefPane", "framework"].contains(messageUserImagePath.split(separator: ".").last) {
            writeLog("Image is app source")
            imgFromAPP = true
        }

        if messageUserImagePath == "none" {
            writeLog("Icon is disabled")
            builtInIconName = "circle.fill"
            builtInIconPresent = true
            builtInIconColour = .clear
        }

        if messageUserImagePath.lowercased().hasPrefix("text=") {
            writeLog("Image is Text")
            imgFromText = true
        }

        if messageUserImagePath.lowercased().hasPrefix("sf=") {
            writeLog("Image is SF Symbol")
            sfSymbolPresent = true
            builtInIconPresent = true

            var SFValues = messageUserImagePath.split(usingRegex: argRegex)
            SFValues = SFValues.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma

            var SFArg: String = ""
            var SFArgValue: String = ""

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
                            builtInIconWeight = Font.Weight(argument: SFArgValue)
                    case _ where SFArg.hasPrefix("colo"):
                        if SFArgValue == "auto" {
                            // detecting sf symbol properties seems to be annoying, at least in swiftui 2
                            // this is a bit of a workaround in that we let the user determine if they want the multicolour SF symbol
                            // or a standard template style. sefault is template. "auto" will use the built in SF Symbol colours
                            iconRenderingMode = Image.TemplateRenderingMode.original
                            builtInIconAutoColor = true
                        } else {
                            //check to see if it's in the right length and only contains the right characters
                            iconRenderingMode = Image.TemplateRenderingMode.template // switches to monochrome which allows us to tint the sf symbol
                            if SFArg.hasSuffix("2") {
                                sfGradientPresent = true
                                builtInIconSecondaryColour = Color(argument: SFArgValue)
                            } else if SFArg.hasSuffix("3") {
                                builtInIconTertiaryColour = Color(argument: SFArgValue)
                            } else {
                                builtInIconColour = Color(argument: SFArgValue)
                            }
                        }
                    case "palette":
                        let paletteColours = SFArgValue.components(separatedBy: ",".trimmingCharacters(in: .whitespaces))
                        if paletteColours.count > 1 {
                            sfPalettePresent = true
                        }
                        for index in 0...paletteColours.count-1 {
                            switch index {
                            case 0:
                                builtInIconColour = Color(argument: paletteColours[index])
                            case 1:
                                builtInIconSecondaryColour = Color(argument: paletteColours[index])
                            case 2:
                                builtInIconTertiaryColour = Color(argument: paletteColours[index])
                            default: ()
                            }
                        }
                    case "animation":
                        sfSymbolAnimation = SFArgValue
                    default:
                        iconRenderingMode = Image.TemplateRenderingMode.template
                    }
                }
            }
        }

        if appArguments.warningIcon.present || messageUserImagePath == "warning" {
            writeLog("Using default warning icon")
            builtInIconName = "exclamationmark.octagon.fill"
            builtInIconFill = "octagon.fill" //does not have multicolour sf symbol so we have to make out own using a fill layer
            builtInIconColour = Color.red
            iconRenderingMode = Image.TemplateRenderingMode.original
            builtInIconPresent = true
        } else if appArguments.cautionIcon.present || messageUserImagePath == "caution" {
            writeLog("Using default caution icon")
            builtInIconName = "exclamationmark.triangle.fill"  // yay multicolour sf symbol
            builtInIconPresent = true
        } else if appArguments.infoIcon.present || messageUserImagePath == "info" {
            writeLog("Using default info icon")
            builtInIconName = "person.fill.questionmark"
            builtInIconPresent = true
        } else if messageUserImagePath == "default" || (!builtInIconPresent && !FileManager.default.fileExists(atPath: messageUserImagePath) && !imgFromURL && !imgFromBase64 && !imgFromText) {
            writeLog("Icon not specified - using default icon")
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
                        if builtInIconFill != "" {
                            Image(systemName: builtInIconFill)
                                .resizable()
                                .symbolAnimation(effect: sfSymbolAnimation)
                                .foregroundColor(Color.white)
                        }
                        if messageUserImagePath == "default" {
                            Image(systemName: builtInIconName)
                                .resizable()
                                .renderingMode(iconRenderingMode)
                                .font(Font.title.weight(builtInIconWeight))
                                .symbolRenderingMode(.monochrome)
                                .symbolAnimation(effect: sfSymbolAnimation)
                                .foregroundColor(builtInIconColour)
                        } else if messageUserImagePath == "computer" {
                            Image(nsImage: NSImage(named: NSImage.computerName) ?? NSImage())
                                .resizable()
                        } else {
                            Image(systemName: builtInIconName)
                                .resizable()
                                .renderingMode(iconRenderingMode)
                                .font(Font.title.weight(builtInIconWeight))
                                .symbolRenderingMode(builtInIconAutoColor ? .multicolor : .hierarchical)
                                .symbolAnimation(effect: sfSymbolAnimation)
                                .foregroundStyle(builtInIconColour)
                        }
                    }
                }
                .aspectRatio(contentMode: .fit)
                .scaledToFit()
                .scaleEffect(mainImageScale, anchor: .topLeading)
                .opacity(mainImageAlpha)
            } else if imgFromText {
                Text(messageUserImagePath.replacingOccurrences(of: "text=", with: ""))
                .font(.system(size: 300))
                .minimumScaleFactor(0.01)
                .lineLimit(1)
                .opacity(mainImageAlpha)
            } else {
                DisplayImage(messageUserImagePath, corners: true)
                    .scaleEffect(mainImageScale, anchor: .topLeading)
                    .opacity(mainImageAlpha)
            }

            if !iconOverlay.isEmpty {
                ZStack {
                    if overlayImageBackground {
                        //background square so the SF Symbol has something to render against
                        Image(systemName: "square.fill")
                            .resizable()
                            .foregroundColor(sfBackgroundIconColour)
                            .font(Font.title.weight(Font.Weight.thin))
                            .opacity(0.90)
                            .shadow(color: .secondaryBackground.opacity(0.50), radius: 4, x: 2, y: 2) // gives the sf background some pop especially in dark mode
                            .aspectRatio(1, contentMode: .fit)
                    }

                    IconView(image: iconOverlay)
                        //.shadow(color: Color.primary.opacity(0.70), radius: 3)
                        .scaleEffect(overlayImageBackgroundScale)
                }
                .scaleEffect(overlayImageScale, anchor: .bottomTrailing)
            }


        }
        .padding(framePadding)

    }
}

