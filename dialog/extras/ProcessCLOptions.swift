//
//  ProcessCLOptions.swift
//  dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 29/8/21.
//

import Foundation
import SwiftUI

private func checkCLPresent(CLName: (long: String, short: String)) {
    if CLOptionPresent(OptionName: CLName) {
        print(CLName)
    }
}

func processCLOptions() {
    
    // check all options that don't take a text value
    
    //check debug mode
    if (CLOptionPresent(OptionName: CLOptions.debug)) {
        appvars.debugMode = true
        appvars.debugBorderColour = Color.green
    }
    
    if (CLOptionPresent(OptionName: CLOptions.textField)) {
        appvars.textOptionsArray = CLOptionTextField()
    }
    
    // process command line options that just display info and exit before we show the main window
    if (CLOptionPresent(OptionName: CLOptions.helpOption) || CommandLine.arguments.count == 1) {
        print(helpText)
        quitDialog(exitCode: 0)
        //exit(0)
    }
    if CLOptionPresent(OptionName: CLOptions.getVersion) {
        printVersionString()
        quitDialog(exitCode: 0)
        //exit(0)
    }
    if CLOptionPresent(OptionName: CLOptions.showLicense) {
        print(licenseText)
        quitDialog(exitCode: 0)
        //exit(0)
    }
    if CLOptionPresent(OptionName: CLOptions.buyCoffee) {
        //I'm a teapot
        print("If you like this app and want to buy me a coffee https://www.buymeacoffee.com/bartreardon")
        quitDialog(exitCode: 418)
        //exit(418)
    }
    if CLOptionPresent(OptionName: CLOptions.ignoreDND) {
        appvars.willDisturb = true
    }
    
    //check for DND and exit if it's on
    if isDNDEnabled() && !appvars.willDisturb {
        quitDialog(exitCode: 20, exitMessage: "Do Not Disturb is enabled. Exiting")
    }
        
    if CLOptionPresent(OptionName: CLOptions.windowWidth) {
        //appvars.windowWidth = CGFloat() //CLOptionText(OptionName: CLOptions.windowWidth)
        appvars.windowWidth = NumberFormatter().number(from: CLOptionText(OptionName: CLOptions.windowWidth)) as! CGFloat
    }
    if CLOptionPresent(OptionName: CLOptions.windowHeight) {
        //appvars.windowHeight = CGFloat() //CLOptionText(OptionName: CLOptions.windowHeight)
        appvars.windowHeight = NumberFormatter().number(from: CLOptionText(OptionName: CLOptions.windowHeight)) as! CGFloat
    }
    
    // Correct feng shui so the app accepts keyboard input
    // from https://stackoverflow.com/questions/58872398/what-is-the-minimally-viable-gui-for-command-line-swift-scripts
    let app = NSApplication.shared
    //app.setActivationPolicy(.regular)
    app.setActivationPolicy(.accessory)
            
    if CLOptionPresent(OptionName: CLOptions.titleFont) {
        let fontCLValues = CLOptionText(OptionName: CLOptions.titleFont)
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
            
    if CLOptionPresent(OptionName: CLOptions.hideIcon) {
        appvars.iconIsHidden = true
    //} else {
    //    iconVisible = true
    }
    
    if CLOptionPresent(OptionName: CLOptions.lockWindow) {
        appvars.windowIsMoveable = true
    }
    
    if CLOptionPresent(OptionName: CLOptions.forceOnTop) {
        appvars.windowOnTop = true
    }
    
    if CLOptionPresent(OptionName: CLOptions.jsonOutPut) {
        appvars.jsonOut = true
    }
    
    // we define this stuff here as we will use the info to draw the window.
    if CLOptionPresent(OptionName: CLOptions.smallWindow) {
        // scale everything down a notch
        
        appvars.smallWindow = true
        appvars.scaleFactor = 0.75
        
        //appvars.overlayOffsetX = appvars.overlayOffsetX * (appvars.scaleFactor)
        //appvars.overlayOffsetY = appvars.overlayOffsetY * (appvars.scaleFactor*appvars.scaleFactor)
    } else if CLOptionPresent(OptionName: CLOptions.bigWindow) {
        // scale everything up a notch
        
        appvars.bigWindow = true
        appvars.scaleFactor = 1.25
    }
}

func processCLOptionValues() {
    
    if CLOptionPresent(OptionName: CLOptions.titleOption) {
        optionvalue.titleOption.value = CLOptionText(OptionName: CLOptions.titleOption)
        optionvalue.titleOption.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.messageOption) {
        optionvalue.messageOption.value = CLOptionText(OptionName: CLOptions.messageOption)
        optionvalue.messageOption.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.iconOption) {
        optionvalue.iconOption.value = CLOptionText(OptionName: CLOptions.iconOption)
        optionvalue.iconOption.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.overlayIconOption) {
        optionvalue.overlayIconOption.value = CLOptionText(OptionName: CLOptions.overlayIconOption)
        optionvalue.overlayIconOption.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.bannerImage) {
        optionvalue.bannerImage.value = CLOptionText(OptionName: CLOptions.bannerImage)
        optionvalue.bannerImage.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.button1TextOption) {
        optionvalue.button1TextOption.value = CLOptionText(OptionName: CLOptions.button1TextOption)
        optionvalue.button1TextOption.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.button1ActionOption) {
        optionvalue.button1ActionOption.value = CLOptionText(OptionName: CLOptions.button1ActionOption)
        optionvalue.button1ActionOption.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.button1ShellActionOption) {
        optionvalue.button1ShellActionOption.value = CLOptionText(OptionName: CLOptions.button1ShellActionOption)
        optionvalue.button1ShellActionOption.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.button2TextOption) {
        optionvalue.button2TextOption.value = CLOptionText(OptionName: CLOptions.button2TextOption)
        optionvalue.button2TextOption.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.button2ActionOption) {
        optionvalue.button2ActionOption.value = CLOptionText(OptionName: CLOptions.button2ActionOption)
        optionvalue.button2ActionOption.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.buttonInfoTextOption) {
        optionvalue.buttonInfoTextOption.value = CLOptionText(OptionName: CLOptions.buttonInfoTextOption)
        optionvalue.buttonInfoTextOption.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.buttonInfoActionOption) {
        optionvalue.buttonInfoActionOption.value = CLOptionText(OptionName: CLOptions.buttonInfoActionOption)
        optionvalue.buttonInfoActionOption.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.dropdownTitle) {
        optionvalue.dropdownTitle.value = CLOptionText(OptionName: CLOptions.dropdownTitle)
        optionvalue.dropdownTitle.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.dropdownValues) {
        optionvalue.dropdownValues.value = CLOptionText(OptionName: CLOptions.dropdownValues)
        optionvalue.dropdownValues.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.dropdownDefault) {
        optionvalue.dropdownDefault.value = CLOptionText(OptionName: CLOptions.dropdownDefault)
        optionvalue.dropdownDefault.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.titleFont) {
        optionvalue.titleFont.value = CLOptionText(OptionName: CLOptions.titleFont)
        optionvalue.titleFont.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.textField) {
        optionvalue.textField.value = CLOptionText(OptionName: CLOptions.textField)
        optionvalue.textField.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.timerBar) {
        optionvalue.timerBar.value = CLOptionText(OptionName: CLOptions.timerBar)
        optionvalue.timerBar.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.mainImage) {
        optionvalue.mainImage.value = CLOptionText(OptionName: CLOptions.mainImage)
        optionvalue.mainImage.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.mainImageCaption) {
        optionvalue.mainImageCaption.value = CLOptionText(OptionName: CLOptions.mainImageCaption)
        optionvalue.mainImageCaption.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.windowWidth) {
        optionvalue.windowWidth.value = CLOptionText(OptionName: CLOptions.windowWidth)
        optionvalue.windowWidth.present = true
    }
    if CLOptionPresent(OptionName: CLOptions.windowHeight) {
        optionvalue.windowHeight.value = CLOptionText(OptionName: CLOptions.windowHeight)
        optionvalue.windowHeight.present = true
    }

}
