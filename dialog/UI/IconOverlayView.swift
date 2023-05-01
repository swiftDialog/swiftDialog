//
//  IconOverlayView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 19/3/21.
//

import Foundation
import SwiftUI

struct IconOverlayView: View {
        
    var overlayImagePath: String
    var overlayIconPresent: Bool = false
    var overlayScaleFactor : CGFloat = 1
    var sfSymbolPresent: Bool = false
    var sfBackgroundIconColour: Color = Color.background
        
    init (image : String = "") {
        overlayImagePath = image
        
        // enable if there is _anything_ specified as an overlay icon
        if overlayImagePath != "" {
            overlayIconPresent = true
        }
        
        // check if it's an SF symbol. That enables the background layer and applies a scale to the symbol
        if overlayImagePath.lowercased().hasPrefix("sf=") {
            sfSymbolPresent = true
            overlayScaleFactor = 0.85
            
            // check to see if we need to set a background colour
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
                    
                    if SFArg.hasPrefix("bgcolo") {
                        if SFArgValue == "none" {
                            sfBackgroundIconColour = .clear
                            overlayScaleFactor = 1
                        } else {
                            sfBackgroundIconColour = stringToColour(SFArgValue)
                        }
                    }
                }
            }
        }
        
        // display an errror image if needed (only used here if it's a local file and it doesn't exist
        if !sfSymbolPresent && !overlayImagePath.hasPrefix("http") && !FileManager.default.fileExists(atPath: overlayImagePath) {
            overlayImagePath = "sf=questionmark.square.dashed"
            sfSymbolPresent = true
        }
    }
    
    var body: some View {
        if overlayIconPresent {
            ZStack {
                if sfSymbolPresent || overlayImagePath == "info" {
                    //background square so the SF Symbol has something to render against
                    Image(systemName: "square.fill")
                        .resizable()
                        .foregroundColor(sfBackgroundIconColour)
                        .font(Font.title.weight(Font.Weight.thin))
                        .opacity(0.90)
                        .shadow(color: .secondaryBackground.opacity(0.50), radius: 4, x:2, y:2) // gives the sf background some pop especially in dark mode
                        .aspectRatio(1, contentMode: .fit)
                }
                IconView(image: overlayImagePath)
                    .scaleEffect(overlayScaleFactor)
            }
            .shadow(color: Color.primary.opacity(0.70), radius: appvars.overlayShadow)
        }
    }
}

