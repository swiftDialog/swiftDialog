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
    
    //check debug mode
    if cloptions.debug.present {
        appvars.debugMode = true
        appvars.debugBorderColour = Color.green
    }
    
    if cloptions.textField.present {
        appvars.textOptionsArray = CLOptionTextField()
    }
    
    // process command line options that just display info and exit before we show the main window
    if (cloptions.helpOption.present || CommandLine.arguments.count == 1) {
        print(helpText)
        quitDialog(exitCode: 0)
        //exit(0)
    }
    if cloptions.getVersion.present {
        printVersionString()
        quitDialog(exitCode: 0)
        //exit(0)
    }
    if cloptions.showLicense.present {
        print(licenseText)
        quitDialog(exitCode: 0)
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
    
    //check for DND and exit if it's on
    if isDNDEnabled() && !appvars.willDisturb {
        quitDialog(exitCode: 20, exitMessage: "Do Not Disturb is enabled. Exiting")
    }
        
    if cloptions.windowWidth.present {
        //appvars.windowWidth = CGFloat() //CLOptionText(OptionName: cloptions.windowWidth)
        appvars.windowWidth = NumberFormatter().number(from: cloptions.windowWidth.value) as! CGFloat
    }
    if cloptions.windowHeight.present {
        //appvars.windowHeight = CGFloat() //CLOptionText(OptionName: cloptions.windowHeight)
        appvars.windowHeight = NumberFormatter().number(from: cloptions.windowHeight.value) as! CGFloat
    }
    
    if cloptions.iconSize.present {
        //appvars.windowWidth = CGFloat() //CLOptionText(OptionName: cloptions.windowWidth)
        appvars.imageWidth = NumberFormatter().number(from: cloptions.iconSize.value) as! CGFloat
    }
    /*
    if cloptions.iconHeight.present {
        //appvars.windowHeight = CGFloat() //CLOptionText(OptionName: cloptions.windowHeight)
        appvars.imageHeight = NumberFormatter().number(from: cloptions.iconHeight.value) as! CGFloat
    }
    */
    // Correct feng shui so the app accepts keyboard input
    // from https://stackoverflow.com/questions/58872398/what-is-the-minimally-viable-gui-for-command-line-swift-scripts
    let app = NSApplication.shared
    //app.setActivationPolicy(.regular)
    app.setActivationPolicy(.accessory)
            
    if cloptions.titleFont.present {
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
            }
            if item[0] == "weight" {
                appvars.titleFontWeight = textToFontWeight(item[1])
            }
            if item[0] == "colour" || item[0] == "color" {
                appvars.titleFontColour = stringToColour(item[1])
            }
            
        }
        
    }
            
    if cloptions.hideIcon.present || cloptions.bannerImage.present {
        appvars.iconIsHidden = true
    }
    
    if cloptions.lockWindow.present {
        appvars.windowIsMoveable = true
    }
    
    if cloptions.forceOnTop.present {
        appvars.windowOnTop = true
    }
    
    if cloptions.jsonOutPut.present {
        appvars.jsonOut = true
    }
    
    // we define this stuff here as we will use the info to draw the window.
    if cloptions.smallWindow.present {
        // scale everything down a notch
        appvars.smallWindow = true
        appvars.scaleFactor = 0.75
    } else if cloptions.bigWindow.present {
        // scale everything up a notch
        appvars.bigWindow = true
        appvars.scaleFactor = 1.25
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

    cloptions.textField.value               = CLOptionText(OptionName: cloptions.textField)
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

}
