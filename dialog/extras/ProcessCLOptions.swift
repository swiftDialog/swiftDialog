//
//  ProcessCLOptions.swift
//  dialog
//
//  Created by Bart Reardon on 29/8/21.
//

import Foundation
import SwiftUI
import SwiftyJSON

func processJSON(jsonFilePath: String) -> JSON {
    var json = JSON()
    // read in from file
    let jsonDataPath = NSURL(fileURLWithPath: jsonFilePath)
    var jsonData = Data()
      
    // wrap everything in a try block.IF the URL or filepath is unreadable then bail
    do {
        jsonData = try Data(contentsOf: jsonDataPath as URL)
    } catch {
        quitDialog(exitCode: appvars.exit202.code, exitMessage: "\(appvars.exit202.message) \(jsonFilePath)")
    }
    
    do {
        json = try JSON(data: jsonData)
    } catch {
        quitDialog(exitCode: appvars.exit202.code, exitMessage: "JSON import failed")
    }
    return json
}

func processJSONString(jsonString: String) -> JSON {
    var json = JSON()
    let dataFromString = jsonString.replacingOccurrences(of: "\n", with: "\\n").data(using: .utf8)
    do {
        json = try JSON(data: dataFromString!)
    } catch {
        quitDialog(exitCode: appvars.exit202.code, exitMessage: "JSON import failed")
    }
    return json
}

func getJSON() -> JSON {
    var json = JSON()
    if CLOptionPresent(OptionName: cloptions.jsonFile) {
        // read json in from file
        json = processJSON(jsonFilePath: CLOptionText(OptionName: cloptions.jsonFile))
    }
    
    if CLOptionPresent(OptionName: cloptions.jsonString) {
        // read json in from text string
        json = processJSONString(jsonString: CLOptionText(OptionName: cloptions.jsonString))
    }
    return json
}

func processCLOptions() {
    
    //this method goes through the arguments that are present and performs any processing required before use
    
    let json : JSON = getJSON()
    
    if cloptions.dropdownValues.present {
        if json[cloptions.dropdownValues.long].exists() {
            appvars.dropdownValuesArray = json[cloptions.dropdownValues.long].arrayValue.map {$0.stringValue}
        } else {
    
            let dropdownValues = cloptions.dropdownValues.value.components(separatedBy: ",")
            appvars.dropdownValuesArray = dropdownValues.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma
        }
    
        if json[cloptions.dropdownDefault.long].exists() || cloptions.dropdownDefault.present {
            appvars.selectedOption = cloptions.dropdownDefault.value
            appvars.selectedIndex = appvars.dropdownValuesArray.firstIndex {$0 == cloptions.dropdownDefault.value} ?? -1
        }
    
    }
    
    
    if cloptions.textField.present {
        if json[cloptions.textField.long].exists() {
            appvars.textOptionsArray = json[cloptions.textField.long].arrayValue.map {$0.stringValue}
        } else {
            appvars.textOptionsArray =  CLOptionMultiOptions(optionName: cloptions.textField.long)
        }
        logger(logMessage: "textOptionsArray : \(appvars.textOptionsArray)")
    }
    
    if cloptions.checkbox.present {
        if json[cloptions.checkbox.long].exists() {
            appvars.checkboxOptionsArray = json[cloptions.checkbox.long].arrayValue.map {$0["label"].stringValue}
            appvars.checkboxValue = json[cloptions.checkbox.long].arrayValue.map {$0["checked"].boolValue}
            appvars.checkboxDisabled = json[cloptions.checkbox.long].arrayValue.map {$0["disabled"].boolValue}
        } else {
            appvars.checkboxOptionsArray =  CLOptionMultiOptions(optionName: cloptions.checkbox.long)
        }
        logger(logMessage: "checkboxOptionsArray : \(appvars.checkboxOptionsArray)")
    }
    
    if cloptions.mainImage.present {
        if json[cloptions.mainImage.long].exists() {
            if json[cloptions.mainImage.long].array == nil {
                // not an array so pull the single value
                appvars.imageArray.append(json[cloptions.mainImage.long].stringValue)
            } else {
                appvars.imageArray = json[cloptions.mainImage.long].arrayValue.map {$0["imagename"].stringValue}
                appvars.imageCaptionArray = json[cloptions.mainImage.long].arrayValue.map {$0["caption"].stringValue}
            }
        } else {
            appvars.imageArray = CLOptionMultiOptions(optionName: cloptions.mainImage.long)
        }
        logger(logMessage: "imageArray : \(appvars.imageArray)")
    }
    
    if cloptions.listItem.present {
        if json[cloptions.listItem.long].exists() {
            appvars.listItemArray = json[cloptions.listItem.long].arrayValue.map {$0.stringValue}
        } else {
            appvars.listItemArray =  CLOptionMultiOptions(optionName: cloptions.listItem.long)
        }
    }
    
    
    if json[cloptions.mainImageCaption.long].exists() || cloptions.mainImageCaption.present {
        if json[cloptions.mainImageCaption.long].exists() {
            appvars.imageCaptionArray.append(json[cloptions.mainImageCaption.long].stringValue)
        } else {
            appvars.imageCaptionArray = CLOptionMultiOptions(optionName: cloptions.mainImageCaption.long)
        }
        logger(logMessage: "imageCaptionArray : \(appvars.imageCaptionArray)")
    }
    
    if !json[cloptions.autoPlay.long].exists() && !cloptions.autoPlay.present {
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
    
    // this method reads in arguments from either json file or from the command line and loads them into the cloptions object
    // also records whether an argument is present or not
    
    let json : JSON = getJSON()
    
    cloptions.titleOption.value             = json[cloptions.titleOption.long].string ?? CLOptionText(OptionName: cloptions.titleOption, DefaultValue: appvars.titleDefault)
    cloptions.titleOption.present           = json[cloptions.titleOption.long].exists() || CLOptionPresent(OptionName: cloptions.titleOption)

    cloptions.messageOption.value           = json[cloptions.messageOption.long].string ?? CLOptionText(OptionName: cloptions.messageOption, DefaultValue: appvars.messageDefault)
    cloptions.messageOption.present         = json[cloptions.titleOption.long].exists() || CLOptionPresent(OptionName: cloptions.messageOption)
    
    cloptions.messageAlignment.value        = json[cloptions.messageAlignment.long].string ?? CLOptionText(OptionName: cloptions.messageAlignment, DefaultValue: appvars.messageAlignmentTextRepresentation)
    cloptions.messageAlignment.present      = json[cloptions.messageAlignment.long].exists() || CLOptionPresent(OptionName: cloptions.messageAlignment)
    
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

    cloptions.iconOption.value              = json[cloptions.iconOption.long].string ?? CLOptionText(OptionName: cloptions.iconOption, DefaultValue: "default")
    cloptions.iconOption.present            = json[cloptions.iconOption.long].exists() || CLOptionPresent(OptionName: cloptions.iconOption)
    
    cloptions.iconSize.value                = json[cloptions.iconOption.long].string ?? CLOptionText(OptionName: cloptions.iconSize)
    cloptions.iconSize.present              = json[cloptions.iconSize.long].exists() || CLOptionPresent(OptionName: cloptions.iconSize)
    
    //cloptions.iconHeight.value              = CLOptionText(OptionName: cloptions.iconHeight)
    //cloptions.iconHeight.present            = CLOptionPresent(OptionName: cloptions.iconHeight)

    cloptions.overlayIconOption.value       = json[cloptions.overlayIconOption.long].string ?? CLOptionText(OptionName: cloptions.overlayIconOption)
    cloptions.overlayIconOption.present     = json[cloptions.overlayIconOption.long].exists() || CLOptionPresent(OptionName: cloptions.overlayIconOption)

    cloptions.bannerImage.value             = json[cloptions.bannerImage.long].string ?? CLOptionText(OptionName: cloptions.bannerImage)
    cloptions.bannerImage.present           = json[cloptions.bannerImage.long].exists() || CLOptionPresent(OptionName: cloptions.bannerImage)

    cloptions.button1TextOption.value       = json[cloptions.button1TextOption.long].string ?? CLOptionText(OptionName: cloptions.button1TextOption, DefaultValue: appvars.button1Default)
    cloptions.button1TextOption.present     = json[cloptions.button1TextOption.long].exists() || CLOptionPresent(OptionName: cloptions.button1TextOption)

    cloptions.button1ActionOption.value     = json[cloptions.button1ActionOption.long].string ?? CLOptionText(OptionName: cloptions.button1ActionOption)
    cloptions.button1ActionOption.present   = json[cloptions.button1ActionOption.long].exists() || CLOptionPresent(OptionName: cloptions.button1ActionOption)

    cloptions.button1ShellActionOption.value = json[cloptions.button1ShellActionOption.long].string ?? CLOptionText(OptionName: cloptions.button1ShellActionOption)
    cloptions.button1ShellActionOption.present = json[cloptions.button1ShellActionOption.long].exists() || CLOptionPresent(OptionName: cloptions.button1ShellActionOption)
    
    cloptions.button1Disabled.present       = json[cloptions.button1Disabled.long].exists() || CLOptionPresent(OptionName: cloptions.button1Disabled)

    cloptions.button2TextOption.value       = json[cloptions.button2TextOption.long].string ?? CLOptionText(OptionName: cloptions.button2TextOption, DefaultValue: appvars.button2Default)
    cloptions.button2TextOption.present     = json[cloptions.button2TextOption.long].exists() || CLOptionPresent(OptionName: cloptions.button2TextOption)

    cloptions.button2ActionOption.value     = json[cloptions.button2ActionOption.long].string ?? CLOptionText(OptionName: cloptions.button2ActionOption)
    cloptions.button2ActionOption.present   = json[cloptions.button2ActionOption.long].exists() || CLOptionPresent(OptionName: cloptions.button2ActionOption)

    cloptions.buttonInfoTextOption.value    = json[cloptions.buttonInfoTextOption.long].string ?? CLOptionText(OptionName: cloptions.buttonInfoTextOption, DefaultValue: appvars.buttonInfoDefault)
    cloptions.buttonInfoTextOption.present  = json[cloptions.buttonInfoTextOption.long].exists() || CLOptionPresent(OptionName: cloptions.buttonInfoTextOption)

    cloptions.buttonInfoActionOption.value  = json[cloptions.buttonInfoActionOption.long].string ?? CLOptionText(OptionName: cloptions.buttonInfoActionOption)
    cloptions.buttonInfoActionOption.present = json[cloptions.buttonInfoActionOption.long].exists() || CLOptionPresent(OptionName: cloptions.buttonInfoActionOption)

    cloptions.dropdownTitle.value           = json[cloptions.dropdownTitle.long].string ?? CLOptionText(OptionName: cloptions.dropdownTitle)
    cloptions.dropdownTitle.present         = json[cloptions.dropdownTitle.long].exists() || CLOptionPresent(OptionName: cloptions.dropdownTitle)

    cloptions.dropdownValues.value          = json[cloptions.dropdownValues.long].string ?? CLOptionText(OptionName: cloptions.dropdownValues)
    cloptions.dropdownValues.present        = json[cloptions.dropdownValues.long].exists() || CLOptionPresent(OptionName: cloptions.dropdownValues)

    cloptions.dropdownDefault.value         = json[cloptions.dropdownDefault.long].string ?? CLOptionText(OptionName: cloptions.dropdownDefault)
    cloptions.dropdownDefault.present       = json[cloptions.dropdownDefault.long].exists() || CLOptionPresent(OptionName: cloptions.dropdownDefault)

    cloptions.titleFont.value               = json[cloptions.titleFont.long].string ?? CLOptionText(OptionName: cloptions.titleFont)
    cloptions.titleFont.present             = json[cloptions.titleFont.long].exists() || CLOptionPresent(OptionName: cloptions.titleFont)
    
    cloptions.messageFont.value             = json[cloptions.messageFont.long].string ?? CLOptionText(OptionName: cloptions.messageFont)
    cloptions.messageFont.present           = json[cloptions.messageFont.long].exists() || CLOptionPresent(OptionName: cloptions.messageFont)

    //cloptions.textField.value               = CLOptionText(OptionName: cloptions.textField)
    cloptions.textField.present             = json[cloptions.textField.long].exists() || CLOptionPresent(OptionName: cloptions.textField)
    
    cloptions.checkbox.present             = json[cloptions.checkbox.long].exists() || CLOptionPresent(OptionName: cloptions.checkbox)

    cloptions.timerBar.value                = json[cloptions.timerBar.long].string ?? CLOptionText(OptionName: cloptions.timerBar, DefaultValue: "\(appvars.timerDefaultSeconds)")
    cloptions.timerBar.present              = json[cloptions.timerBar.long].exists() || CLOptionPresent(OptionName: cloptions.timerBar)
    
    cloptions.progressBar.value             = json[cloptions.progressBar.long].string ?? CLOptionText(OptionName: cloptions.progressBar)
    cloptions.progressBar.present           = json[cloptions.progressBar.long].exists() || CLOptionPresent(OptionName: cloptions.progressBar)
                                                                                                        
    //cloptions.mainImage.value               = CLOptionText(OptionName: cloptions.mainImage)
    cloptions.mainImage.present             = json[cloptions.mainImage.long].exists() || CLOptionPresent(OptionName: cloptions.mainImage)
    
    //cloptions.mainImageCaption.value        = CLOptionText(OptionName: cloptions.mainImageCaption)
    cloptions.mainImageCaption.present      = json[cloptions.mainImageCaption.long].exists() || CLOptionPresent(OptionName: cloptions.mainImageCaption)
    
    cloptions.listItem.present              = json[cloptions.listItem.long].exists() || CLOptionPresent(OptionName: cloptions.listItem)

    cloptions.windowWidth.value             = json[cloptions.windowWidth.long].string ?? CLOptionText(OptionName: cloptions.windowWidth)
    cloptions.windowWidth.present           = json[cloptions.windowWidth.long].exists() || CLOptionPresent(OptionName: cloptions.windowWidth)

    cloptions.windowHeight.value            = json[cloptions.windowHeight.long].string ?? CLOptionText(OptionName: cloptions.windowHeight)
    cloptions.windowHeight.present          = json[cloptions.windowHeight.long].exists() || CLOptionPresent(OptionName: cloptions.windowHeight)
    
    cloptions.watermarkImage.value          = json[cloptions.watermarkImage.long].string ?? CLOptionText(OptionName: cloptions.watermarkImage)
    cloptions.watermarkImage.present        = json[cloptions.watermarkImage.long].exists() || CLOptionPresent(OptionName: cloptions.watermarkImage)
        
    cloptions.watermarkAlpha.value          = json[cloptions.watermarkAlpha.long].string ?? CLOptionText(OptionName: cloptions.watermarkAlpha)
    cloptions.watermarkAlpha.present        = json[cloptions.watermarkAlpha.long].exists() || CLOptionPresent(OptionName: cloptions.watermarkAlpha)
    
    cloptions.watermarkPosition.value       = json[cloptions.watermarkPosition.long].string ?? CLOptionText(OptionName: cloptions.watermarkPosition)
    cloptions.watermarkPosition.present     = json[cloptions.watermarkPosition.long].exists() || CLOptionPresent(OptionName: cloptions.watermarkPosition)
    
    cloptions.watermarkFill.value           = json[cloptions.watermarkFill.long].string ?? CLOptionText(OptionName: cloptions.watermarkFill)
    cloptions.watermarkFill.present         = json[cloptions.watermarkFill.long].exists() || CLOptionPresent(OptionName: cloptions.watermarkFill)
    
    cloptions.autoPlay.value                = json[cloptions.autoPlay.long].string ?? CLOptionText(OptionName: cloptions.autoPlay, DefaultValue: "\(appvars.timerDefaultSeconds)")
    cloptions.autoPlay.present              = json[cloptions.autoPlay.long].exists() || CLOptionPresent(OptionName: cloptions.autoPlay)
    
    cloptions.statusLogFile.value           = json[cloptions.statusLogFile.long].string ?? CLOptionText(OptionName: cloptions.statusLogFile)
    cloptions.statusLogFile.present         = json[cloptions.statusLogFile.long].exists() || CLOptionPresent(OptionName: cloptions.statusLogFile)
    
    if !cloptions.statusLogFile.present {
        cloptions.statusLogFile.value = appvars.defaultStatusLogFile
    }
    
    cloptions.video.value                   = json[cloptions.video.long].string ?? CLOptionText(OptionName: cloptions.video)
    cloptions.video.present                 = json[cloptions.video.long].exists() || CLOptionPresent(OptionName: cloptions.video)
    if cloptions.video.present {
        // set a larger window size. 900x600 will fit a standard 16:9 video
        appvars.windowWidth = appvars.videoWindowWidth
        appvars.windowHeight = appvars.videoWindowHeight
    }
    
    cloptions.videoCaption.value            = json[cloptions.videoCaption.long].string ?? CLOptionText(OptionName: cloptions.videoCaption)
    cloptions.videoCaption.present          = json[cloptions.videoCaption.long].exists() || CLOptionPresent(OptionName: cloptions.videoCaption)

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
    cloptions.button2Option.present         = json[cloptions.button2Option.long].boolValue || CLOptionPresent(OptionName: cloptions.button2Option)
    cloptions.infoButtonOption.present      = json[cloptions.infoButtonOption.long].boolValue || CLOptionPresent(OptionName: cloptions.infoButtonOption)
    cloptions.hideIcon.present              = json[cloptions.hideIcon.long].boolValue || CLOptionPresent(OptionName: cloptions.hideIcon)
    cloptions.warningIcon.present           = json[cloptions.warningIcon.long].boolValue || CLOptionPresent(OptionName: cloptions.warningIcon)
    cloptions.infoIcon.present              = json[cloptions.infoIcon.long].boolValue || CLOptionPresent(OptionName: cloptions.infoIcon)
    cloptions.cautionIcon.present           = json[cloptions.cautionIcon.long].boolValue || CLOptionPresent(OptionName: cloptions.cautionIcon)
    cloptions.lockWindow.present            = json[cloptions.lockWindow.long].boolValue || CLOptionPresent(OptionName: cloptions.lockWindow)
    cloptions.forceOnTop.present            = json[cloptions.forceOnTop.long].boolValue || CLOptionPresent(OptionName: cloptions.forceOnTop)
    cloptions.smallWindow.present           = json[cloptions.smallWindow.long].boolValue || CLOptionPresent(OptionName: cloptions.smallWindow)
    cloptions.bigWindow.present             = json[cloptions.bigWindow.long].boolValue || CLOptionPresent(OptionName: cloptions.bigWindow)
    cloptions.fullScreenWindow.present      = json[cloptions.fullScreenWindow.long].boolValue || CLOptionPresent(OptionName: cloptions.fullScreenWindow)
    cloptions.jsonOutPut.present            = json[cloptions.jsonOutPut.long].boolValue || CLOptionPresent(OptionName: cloptions.jsonOutPut)
    cloptions.ignoreDND.present             = json[cloptions.ignoreDND.long].boolValue || CLOptionPresent(OptionName: cloptions.ignoreDND)
    cloptions.hideTimerBar.present          = json[cloptions.hideTimerBar.long].boolValue || CLOptionPresent(OptionName: cloptions.hideTimerBar)
    cloptions.quitOnInfo.present            = json[cloptions.quitOnInfo.long].boolValue || CLOptionPresent(OptionName: cloptions.quitOnInfo)
    cloptions.blurScreen.present            = json[cloptions.blurScreen.long].boolValue || CLOptionPresent(OptionName: cloptions.blurScreen)
    
    // command line only options
    cloptions.listFonts.present             = CLOptionPresent(OptionName: cloptions.listFonts)
    cloptions.helpOption.present            = CLOptionPresent(OptionName: cloptions.helpOption)
    cloptions.demoOption.present            = CLOptionPresent(OptionName: cloptions.demoOption)
    cloptions.buyCoffee.present             = CLOptionPresent(OptionName: cloptions.buyCoffee)
    cloptions.showLicense.present           = CLOptionPresent(OptionName: cloptions.showLicense)
    cloptions.jamfHelperMode.present        = CLOptionPresent(OptionName: cloptions.jamfHelperMode)
    cloptions.debug.present                 = CLOptionPresent(OptionName: cloptions.debug)
    cloptions.getVersion.present            = CLOptionPresent(OptionName: cloptions.getVersion)

}
