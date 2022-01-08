//
//  ProcessCLOptions.swift
//  dialog
//
//  Created by Bart Reardon on 29/8/21.
//

import Foundation
import SwiftUI

func processCLOptions() {
    
    // check all options that don't take a text value
        
    if cloptions.textField.present {
        appvars.textOptionsArray = CLOptionMultiOptions(optionName: cloptions.textField.long)
        logger(logMessage: "textOptionsArray : \(appvars.textOptionsArray)")
    }
    
    if cloptions.mainImage.present {
        appvars.imageArray = CLOptionMultiOptions(optionName: cloptions.mainImage.long)
        logger(logMessage: "imageArray : \(appvars.imageArray)")
    }
    
    if cloptions.mainImageCaption.present {
        appvars.imageCaptionArray = CLOptionMultiOptions(optionName: cloptions.mainImageCaption.long)
        logger(logMessage: "imageCaptionArray : \(appvars.imageCaptionArray)")
    }
    
    if !cloptions.autoPlay.present {
        cloptions.autoPlay.value = "0"
        logger(logMessage: "autoPlay.value : \(cloptions.autoPlay.value)")
    }
    
    // process command line options that just display info and exit before we show the main window
    if (cloptions.helpOption.present || CommandLine.arguments.count == 1) {
        print(helpText)
        quitDialog(exitCode: appvars.exit0.code)
        //exit(0)
    }
    if cloptions.getVersion.present {
        printVersionString()
        quitDialog(exitCode: appvars.exit0.code)
        //exit(0)
    }
    if cloptions.showLicense.present {
        print(licenseText)
        quitDialog(exitCode: appvars.exit0.code)
        //exit(0)
    }
    if cloptions.buyCoffee.present {
        //I'm a teapot
        print("If you like this app and want to buy me a coffee https://www.buymeacoffee.com/bartreardon")
        quitDialog(exitCode: 418)
        //exit(418)
    }
    if cloptions.ignoreDND.present {
        appvars.willDisturb = true
    }
    
    if cloptions.listFonts.present {
        //All font Families
        let fontfamilies = NSFontManager.shared.availableFontFamilies
        print("Available font families:")
        for familyname in fontfamilies.enumerated() {
            print("  \(familyname.element)")
        }
        
        // All font names
        let fonts = NSFontManager.shared.availableFonts
        print("Available font names:")
        for fontname in fonts.enumerated() {
            print("  \(fontname.element)")
        }
        quitDialog(exitCode: appvars.exit0.code)
    }
    
    //check for DND and exit if it's on
    if isDNDEnabled() && !appvars.willDisturb {
        quitDialog(exitCode: 20, exitMessage: "Do Not Disturb is enabled. Exiting")
    }
        
    if cloptions.windowWidth.present {
        //appvars.windowWidth = CGFloat() //CLOptionText(OptionName: cloptions.windowWidth)
        if cloptions.windowWidth.value.last == "%" {
            appvars.windowWidth = appvars.screenWidth * (NumberFormatter().number(from: String(cloptions.windowWidth.value.dropLast())) as! CGFloat)/100
        } else {
            appvars.windowWidth = NumberFormatter().number(from: cloptions.windowWidth.value) as! CGFloat
        }
        logger(logMessage: "windowWidth : \(appvars.windowWidth)")
    }
    if cloptions.windowHeight.present {
        //appvars.windowHeight = CGFloat() //CLOptionText(OptionName: cloptions.windowHeight)
        if cloptions.windowHeight.value.last == "%" {
            appvars.windowHeight = appvars.screenHeight * (NumberFormatter().number(from: String(cloptions.windowHeight.value.dropLast())) as! CGFloat)/100
        } else {
            appvars.windowHeight = NumberFormatter().number(from: cloptions.windowHeight.value) as! CGFloat
        }
        logger(logMessage: "windowHeight : \(appvars.windowHeight)")
    }
    
    if cloptions.iconSize.present {
        //appvars.windowWidth = CGFloat() //CLOptionText(OptionName: cloptions.windowWidth)
        appvars.iconWidth = NumberFormatter().number(from: cloptions.iconSize.value) as! CGFloat
        logger(logMessage: "iconWidth : \(appvars.iconWidth)")
    }
    /*
    if cloptions.iconHeight.present {
        //appvars.windowHeight = CGFloat() //CLOptionText(OptionName: cloptions.windowHeight)
        appvars.iconHeight = NumberFormatter().number(from: cloptions.iconHeight.value) as! CGFloat
    }
    */
    // Correct feng shui so the app accepts keyboard input
    // from https://stackoverflow.com/questions/58872398/what-is-the-minimally-viable-gui-for-command-line-swift-scripts
    let app = NSApplication.shared
    //app.setActivationPolicy(.regular)
    app.setActivationPolicy(.accessory)
            
    if cloptions.titleFont.present {
        logger(logMessage: "titleFont.value : \(cloptions.titleFont.value)")
        let fontCLValues = cloptions.titleFont.value
        var fontValues = [""]
        //split by ,
        fontValues = fontCLValues.components(separatedBy: ",")
        fontValues = fontValues.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma
        for value in fontValues {
            // split by =
            let item = value.components(separatedBy: "=")
            if item[0] == "size" {
                appvars.titleFontSize = CGFloat(truncating: NumberFormatter().number(from: item[1]) ?? 20)
                logger(logMessage: "titleFontSize : \(appvars.titleFontSize)")
            }
            if item[0] == "weight" {
                appvars.titleFontWeight = textToFontWeight(item[1])
                logger(logMessage: "titleFontWeight : \(appvars.titleFontWeight)")
            }
            if item[0] == "colour" || item[0] == "color" {
                appvars.titleFontColour = stringToColour(item[1])
                logger(logMessage: "titleFontColour : \(appvars.titleFontColour)")
            }
            if item[0] == "name" {
                appvars.titleFontName = item[1]
                logger(logMessage: "titleFontName : \(appvars.titleFontName)")
            }
            
        }
    }
    
    if cloptions.messageFont.present {
        logger(logMessage: "messageFont.value : \(cloptions.messageFont.value)")
        let fontCLValues = cloptions.messageFont.value
        var fontValues = [""]
        //split by ,
        fontValues = fontCLValues.components(separatedBy: ",")
        fontValues = fontValues.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma
        for value in fontValues {
            // split by =
            let item = value.components(separatedBy: "=")
            if item[0] == "size" {
                appvars.messageFontSize = CGFloat(truncating: NumberFormatter().number(from: item[1]) ?? 20)
                logger(logMessage: "messageFontSize : \(appvars.messageFontSize)")
            }
            if item[0] == "weight" {
                appvars.messageFontWeight = textToFontWeight(item[1])
                logger(logMessage: "messageFontWeight : \(appvars.messageFontWeight)")
            }
            if item[0] == "colour" || item[0] == "color" {
                appvars.messageFontColour = stringToColour(item[1])
                logger(logMessage: "messageFontColour : \(appvars.messageFontColour)")
            }
            if item[0] == "name" {
                appvars.messageFontName = item[1]
                logger(logMessage: "messageFontName : \(appvars.messageFontName)")
            }
        }
    }
            
    if cloptions.hideIcon.present || cloptions.bannerImage.present {
        appvars.iconIsHidden = true
        logger(logMessage: "iconIsHidden = true")
    }
    
    if cloptions.lockWindow.present {
        appvars.windowIsMoveable = true
        logger(logMessage: "windowIsMoveable = true")
    }
    
    if cloptions.forceOnTop.present {
        appvars.windowOnTop = true
        logger(logMessage: "windowOnTop = true")
    }
    
    if cloptions.jsonOutPut.present {
        appvars.jsonOut = true
        logger(logMessage: "jsonOut = true")
    }
    
    // we define this stuff here as we will use the info to draw the window.
    if cloptions.smallWindow.present {
        // scale everything down a notch
        appvars.smallWindow = true
        appvars.scaleFactor = 0.75
        logger(logMessage: "smallWindow.present")
    } else if cloptions.bigWindow.present {
        // scale everything up a notch
        appvars.bigWindow = true
        appvars.scaleFactor = 1.25
        logger(logMessage: "bigWindow.present")
    }
}

func processCLOptionValues() {
        
    cloptions.titleOption.value             = CLOptionText(OptionName: cloptions.titleOption, DefaultValue: appvars.titleDefault)
    cloptions.titleOption.present           = CLOptionPresent(OptionName: cloptions.titleOption)

    cloptions.messageOption.value           = CLOptionText(OptionName: cloptions.messageOption, DefaultValue: appvars.messageDefault)
    cloptions.messageOption.present         = CLOptionPresent(OptionName: cloptions.messageOption)
    
    cloptions.messageAlignment.value        = CLOptionText(OptionName: cloptions.messageAlignment, DefaultValue: appvars.messageAlignmentTextRepresentation)
    cloptions.messageAlignment.present      = CLOptionPresent(OptionName: cloptions.messageAlignment)
    
    if cloptions.messageAlignment.present {
        switch cloptions.messageAlignment.value {
        case "left":
            appvars.messageAlignment = .leading
        case "centre","center":
            appvars.messageAlignment = .center
        case "right":
            appvars.messageAlignment = .trailing
        default:
            appvars.messageAlignment = .leading
        }
    }
    
    // window location on screen
    if CLOptionPresent(OptionName: cloptions.position) {
        switch CLOptionText(OptionName: cloptions.position) {
        case "topleft":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.top
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.left
        case "topright":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.top
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.right
        case "bottomleft":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.bottom
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.left
        case "bottomright":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.bottom
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.right
        case "left":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.center
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.left
        case "right":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.center
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.right
        case "top":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.top
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.center
        case "bottom":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.bottom
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.center
        case "centre","center":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.center
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.center
        default:
            appvars.windowPositionVertical = NSWindow.Position.Vertical.center
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.center
        }
    }

    cloptions.iconOption.value              = CLOptionText(OptionName: cloptions.iconOption, DefaultValue: "default")
    cloptions.iconOption.present            = CLOptionPresent(OptionName: cloptions.iconOption)
    
    cloptions.iconSize.value                = CLOptionText(OptionName: cloptions.iconSize)
    cloptions.iconSize.present              = CLOptionPresent(OptionName: cloptions.iconSize)
    
    //cloptions.iconHeight.value              = CLOptionText(OptionName: cloptions.iconHeight)
    //cloptions.iconHeight.present            = CLOptionPresent(OptionName: cloptions.iconHeight)

    cloptions.overlayIconOption.value       = CLOptionText(OptionName: cloptions.overlayIconOption)
    cloptions.overlayIconOption.present     = CLOptionPresent(OptionName: cloptions.overlayIconOption)

    cloptions.bannerImage.value             = CLOptionText(OptionName: cloptions.bannerImage)
    cloptions.bannerImage.present           = CLOptionPresent(OptionName: cloptions.bannerImage)

    cloptions.button1TextOption.value       = CLOptionText(OptionName: cloptions.button1TextOption, DefaultValue: appvars.button1Default)
    cloptions.button1TextOption.present     = CLOptionPresent(OptionName: cloptions.button1TextOption)

    cloptions.button1ActionOption.value     = CLOptionText(OptionName: cloptions.button1ActionOption)
    cloptions.button1ActionOption.present   = CLOptionPresent(OptionName: cloptions.button1ActionOption)

    cloptions.button1ShellActionOption.value = CLOptionText(OptionName: cloptions.button1ShellActionOption)
    cloptions.button1ShellActionOption.present = CLOptionPresent(OptionName: cloptions.button1ShellActionOption)

    cloptions.button2TextOption.value       = CLOptionText(OptionName: cloptions.button2TextOption, DefaultValue: appvars.button2Default)
    cloptions.button2TextOption.present     = CLOptionPresent(OptionName: cloptions.button2TextOption)

    cloptions.button2ActionOption.value     = CLOptionText(OptionName: cloptions.button2ActionOption)
    cloptions.button2ActionOption.present   = CLOptionPresent(OptionName: cloptions.button2ActionOption)

    cloptions.buttonInfoTextOption.value    = CLOptionText(OptionName: cloptions.buttonInfoTextOption, DefaultValue: appvars.buttonInfoDefault)
    cloptions.buttonInfoTextOption.present  = CLOptionPresent(OptionName: cloptions.buttonInfoTextOption)

    cloptions.buttonInfoActionOption.value  = CLOptionText(OptionName: cloptions.buttonInfoActionOption)
    cloptions.buttonInfoActionOption.present = CLOptionPresent(OptionName: cloptions.buttonInfoActionOption)

    cloptions.dropdownTitle.value           = CLOptionText(OptionName: cloptions.dropdownTitle)
    cloptions.dropdownTitle.present         = CLOptionPresent(OptionName: cloptions.dropdownTitle)

    cloptions.dropdownValues.value          = CLOptionText(OptionName: cloptions.dropdownValues)
    cloptions.dropdownValues.present        = CLOptionPresent(OptionName: cloptions.dropdownValues)

    cloptions.dropdownDefault.value         = CLOptionText(OptionName: cloptions.dropdownDefault)
    cloptions.dropdownDefault.present       = CLOptionPresent(OptionName: cloptions.dropdownDefault)

    cloptions.titleFont.value               = CLOptionText(OptionName: cloptions.titleFont)
    cloptions.titleFont.present             = CLOptionPresent(OptionName: cloptions.titleFont)
    
    cloptions.messageFont.value             = CLOptionText(OptionName: cloptions.messageFont)
    cloptions.messageFont.present           = CLOptionPresent(OptionName: cloptions.messageFont)

    //cloptions.textField.value               = CLOptionText(OptionName: cloptions.textField)
    cloptions.textField.present             = CLOptionPresent(OptionName: cloptions.textField)

    cloptions.timerBar.value                = CLOptionText(OptionName: cloptions.timerBar, DefaultValue: "\(appvars.timerDefaultSeconds)")
    cloptions.timerBar.present              = CLOptionPresent(OptionName: cloptions.timerBar)

    cloptions.mainImage.value               = CLOptionText(OptionName: cloptions.mainImage)
    cloptions.mainImage.present             = CLOptionPresent(OptionName: cloptions.mainImage)
    
    cloptions.mainImageCaption.value        = CLOptionText(OptionName: cloptions.mainImageCaption)
    cloptions.mainImageCaption.present      = CLOptionPresent(OptionName: cloptions.mainImageCaption)

    cloptions.windowWidth.value             = CLOptionText(OptionName: cloptions.windowWidth)
    cloptions.windowWidth.present           = CLOptionPresent(OptionName: cloptions.windowWidth)

    cloptions.windowHeight.value            = CLOptionText(OptionName: cloptions.windowHeight)
    cloptions.windowHeight.present          = CLOptionPresent(OptionName: cloptions.windowHeight)
    
    cloptions.watermarkImage.value          = CLOptionText(OptionName: cloptions.watermarkImage)
    cloptions.watermarkImage.present        = CLOptionPresent(OptionName: cloptions.watermarkImage)
        
    cloptions.watermarkAlpha.value          = CLOptionText(OptionName: cloptions.watermarkAlpha)
    cloptions.watermarkAlpha.present        = CLOptionPresent(OptionName: cloptions.watermarkAlpha)
    
    cloptions.watermarkPosition.value       = CLOptionText(OptionName: cloptions.watermarkPosition)
    cloptions.watermarkPosition.present     = CLOptionPresent(OptionName: cloptions.watermarkPosition)
    
    cloptions.watermarkFill.value           = CLOptionText(OptionName: cloptions.watermarkFill)
    cloptions.watermarkFill.present         = CLOptionPresent(OptionName: cloptions.watermarkFill)
    
    cloptions.autoPlay.value                = CLOptionText(OptionName: cloptions.autoPlay, DefaultValue: "\(appvars.timerDefaultSeconds)")
    cloptions.autoPlay.present              = CLOptionPresent(OptionName: cloptions.autoPlay)
    
    cloptions.video.value                   = CLOptionText(OptionName: cloptions.video)
    cloptions.video.present                 = CLOptionPresent(OptionName: cloptions.video)
    if cloptions.video.present {
        // set a larger window size. 900x600 will fit a standard 16:9 video
        appvars.windowWidth = appvars.videoWindowWidth
        appvars.windowHeight = appvars.videoWindowHeight
    }
    
    cloptions.videoCaption.value            = CLOptionText(OptionName: cloptions.videoCaption)
    cloptions.videoCaption.present          = CLOptionPresent(OptionName: cloptions.videoCaption)

    if cloptions.watermarkImage.present {
        // return the image resolution and re-size the window to match
        let bgImage = getImageFromPath(fileImagePath: cloptions.watermarkImage.value)
        if bgImage.size.width > appvars.windowWidth && bgImage.size.height > appvars.windowHeight && !cloptions.windowHeight.present && !cloptions.watermarkFill.present {
            // keep the same width ratio but change the height
            var wWidth = appvars.windowWidth
            if cloptions.windowWidth.present {
                wWidth = NumberFormatter().number(from: cloptions.windowWidth.value) as! CGFloat
            }
            let widthRatio = wWidth / bgImage.size.width  // get the ration of the image height to the current display width
            let newHeight = (bgImage.size.height * widthRatio) - 28 //28 needs to be removed to account for the phantom title bar height
            appvars.windowHeight = floor(newHeight) // floor() will strip any fractional values as a result of the above multiplication
                                                    // we need to do this as window heights can't be fractional and weird things happen
                        
            if !cloptions.watermarkFill.present {
                cloptions.watermarkFill.present = true
                cloptions.watermarkFill.value = "fill"
            }
        }
    }
    
    // anthing that is an option only with no value
    cloptions.button2Option.present         = CLOptionPresent(OptionName: cloptions.button2Option)
    cloptions.infoButtonOption.present      = CLOptionPresent(OptionName: cloptions.infoButtonOption)
    cloptions.getVersion.present            = CLOptionPresent(OptionName: cloptions.getVersion)
    cloptions.hideIcon.present              = CLOptionPresent(OptionName: cloptions.hideIcon)
    cloptions.helpOption.present            = CLOptionPresent(OptionName: cloptions.helpOption)
    cloptions.demoOption.present            = CLOptionPresent(OptionName: cloptions.demoOption)
    cloptions.buyCoffee.present             = CLOptionPresent(OptionName: cloptions.buyCoffee)
    cloptions.showLicense.present           = CLOptionPresent(OptionName: cloptions.showLicense)
    cloptions.warningIcon.present           = CLOptionPresent(OptionName: cloptions.warningIcon)
    cloptions.infoIcon.present              = CLOptionPresent(OptionName: cloptions.infoIcon)
    cloptions.cautionIcon.present           = CLOptionPresent(OptionName: cloptions.cautionIcon)
    cloptions.lockWindow.present            = CLOptionPresent(OptionName: cloptions.lockWindow)
    cloptions.forceOnTop.present            = CLOptionPresent(OptionName: cloptions.forceOnTop)
    cloptions.smallWindow.present           = CLOptionPresent(OptionName: cloptions.smallWindow)
    cloptions.bigWindow.present             = CLOptionPresent(OptionName: cloptions.bigWindow)
    cloptions.fullScreenWindow.present      = CLOptionPresent(OptionName: cloptions.fullScreenWindow)
    cloptions.jsonOutPut.present            = CLOptionPresent(OptionName: cloptions.jsonOutPut)
    cloptions.ignoreDND.present             = CLOptionPresent(OptionName: cloptions.ignoreDND)
    cloptions.jamfHelperMode.present        = CLOptionPresent(OptionName: cloptions.jamfHelperMode)
    cloptions.debug.present                 = CLOptionPresent(OptionName: cloptions.debug)
    cloptions.hideTimerBar.present          = CLOptionPresent(OptionName: cloptions.hideTimerBar)
    cloptions.quitOnInfo.present            = CLOptionPresent(OptionName: cloptions.quitOnInfo)
    cloptions.listFonts.present             = CLOptionPresent(OptionName: cloptions.listFonts)

}
